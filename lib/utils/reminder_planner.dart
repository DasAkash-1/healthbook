import '../models/app_models.dart';
import '../models/prescription_models.dart';

// How many days ahead we plan local notifications so we don't schedule infinite timers.
const int kReminderDaysAhead = 7;

// Default daily reminder hours keyed by how many times per day a medicine is taken.
const Map<int, List<int>> kDefaultDoseHoursByFrequency = {
  1: [9],
  2: [9, 21],
  3: [9, 14, 21],
  4: [9, 13, 17, 21],
};

// Represents a single scheduled reminder notification at [time].
class PlannedReminder {
  final DateTime time;
  final String title;
  final String body;

  const PlannedReminder({
    required this.time,
    required this.title,
    required this.body,
  });
}

// Returns sorted daily dose hours for [timesPerDay], using custom overrides if valid.
List<int> _hoursForFrequency(
  int timesPerDay, {
  Map<int, List<int>>? customHoursByFrequency,
}) {
  final custom = customHoursByFrequency?[timesPerDay];
  if (custom != null && custom.length == timesPerDay) {
    final valid = custom.where((h) => h >= 0 && h <= 23).toSet().toList()..sort();
    if (valid.length == timesPerDay) {
      return valid;
    }
  }
  return kDefaultDoseHoursByFrequency[timesPerDay] ?? const [9];
}

// Computes upcoming medicine and approved-appointment reminders starting from [now].
// Medicines due at the exact same timestamp are combined into one notification.
List<PlannedReminder> planReminders({
  required DateTime now,
  required List<Medication> medications,
  required List<Appointment> appointments,
  required String Function(String doctorId) doctorName,
  Map<int, List<int>>? customHoursByFrequency,
}) {
  final endWindow = now.add(const Duration(days: kReminderDaysAhead));

  // Group medicine labels ("Metformin 500 mg") by exact scheduled DateTime.
  final Map<DateTime, List<String>> groupedMeds = {};

  for (final med in medications) {
    if (med.remainingDoses <= 0) continue;

    final hours = _hoursForFrequency(
      med.timesPerDay,
      customHoursByFrequency: customHoursByFrequency,
    );

    int dosesPlanned = 0;
    // Loop strictly within [0, kReminderDaysAhead - 1] so slots stay inside endWindow.
    for (int dayOffset = 0; dayOffset < kReminderDaysAhead; dayOffset++) {
      if (dosesPlanned >= med.remainingDoses) break;

      final day = DateTime(now.year, now.month, now.day + dayOffset);
      for (final hour in hours) {
        if (dosesPlanned >= med.remainingDoses) break;

        final slot = DateTime(day.year, day.month, day.day, hour);
        // Skip times already passed or outside the planning window.
        if (!slot.isAfter(now)) continue;
        if (!slot.isBefore(endWindow)) continue;

        final label = med.dose.trim().isEmpty
            ? med.name.trim()
            : '${med.name.trim()} ${med.dose.trim()}';
        groupedMeds.putIfAbsent(slot, () => <String>[]).add(label);
        dosesPlanned++;
      }
    }
  }

  final List<PlannedReminder> reminders = [];

  for (final entry in groupedMeds.entries) {
    reminders.add(
      PlannedReminder(
        time: entry.key,
        title: 'Time for your medicine',
        body: entry.value.join(', '),
      ),
    );
  }

  // Plan reminders for upcoming approved appointments (1 day before & 1 hour before).
  for (final appt in appointments) {
    if (appt.status != AppointmentStatus.approved) continue;
    if (!appt.end.isAfter(now)) continue;

    final docName = doctorName(appt.doctorId);
    final noteSuffix = appt.approvalNote.trim().isEmpty
        ? ''
        : ' - ${appt.approvalNote.trim()}';

    final dayBefore = appt.start.subtract(const Duration(days: 1));
    if (dayBefore.isAfter(now) && dayBefore.isBefore(endWindow)) {
      reminders.add(
        PlannedReminder(
          time: dayBefore,
          title: 'Appointment tomorrow',
          body: 'With $docName$noteSuffix',
        ),
      );
    }

    final hourBefore = appt.start.subtract(const Duration(hours: 1));
    if (hourBefore.isAfter(now) && hourBefore.isBefore(endWindow)) {
      reminders.add(
        PlannedReminder(
          time: hourBefore,
          title: 'Appointment in 1 hour',
          body: 'With $docName$noteSuffix',
        ),
      );
    }
  }

  // Keep all reminders in chronological order.
  reminders.sort((a, b) => a.time.compareTo(b.time));
  return reminders;
}
