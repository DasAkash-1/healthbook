import '../models/app_models.dart';
import '../models/prescription_models.dart';
import 'formatters.dart';

// A notification the app wants the phone to show at a set time.
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

// Hours of the day for each dose, by doses per day.
const Map<int, List<int>> kDoseHours = {
  1: [9],
  2: [9, 21],
  3: [8, 14, 20],
  4: [8, 12, 16, 20],
};

// How many days ahead reminders are planned. They are planned again whenever the
// patient opens the app, so opening it keeps them going.
const int kReminderDaysAhead = 7;

// The phone can only hold a limited number of scheduled notifications.
const int kMaxReminders = 150;

// Works out which reminders the phone should show for one patient.
//
// - Medicines: one reminder per dose at the times in [kDoseHours], for as many doses
//   as the patient has left. Medicines due at the same time share one notification.
// - Appointments: for approved visits, one reminder a day before and one an hour before.
//
// This only plans. Scheduling them on the phone is done by ReminderService.
List<PlannedReminder> planReminders({
  required DateTime now,
  required List<Medication> medications,
  required List<Appointment> appointments,
  required String Function(String doctorId) doctorName,
}) {
  final reminders = <PlannedReminder>[];

  // Medicines: collect the names due at each time.
  final due = <DateTime, List<String>>{};
  for (final m in medications) {
    final hours = kDoseHours[m.timesPerDay];
    if (hours == null || m.remainingDoses <= 0) continue;

    var left = m.remainingDoses;
    for (var day = 0; day < kReminderDaysAhead && left > 0; day++) {
      for (final hour in hours) {
        if (left <= 0) break;
        final time = DateTime(now.year, now.month, now.day + day, hour);
        if (!time.isAfter(now)) continue;
        due.putIfAbsent(time, () => []).add('${m.name} ${m.dose}'.trim());
        left--;
      }
    }
  }
  due.forEach((time, names) {
    reminders.add(
      PlannedReminder(
        time: time,
        title: 'Time for your medicine',
        body: names.join(', '),
      ),
    );
  });

  // Appointments.
  for (final a in appointments) {
    if (a.status != AppointmentStatus.approved || !a.start.isAfter(now)) continue;

    final details =
        '${doctorName(a.doctorId)} • ${formatDay(a.start)} • ${formatSlot(a.start)}';
    final note = a.approvalNote.isEmpty
        ? ''
        : '\nNote from the doctor: ${a.approvalNote}';

    final dayBefore = a.start.subtract(const Duration(hours: 24));
    if (dayBefore.isAfter(now)) {
      reminders.add(
        PlannedReminder(
          time: dayBefore,
          title: 'Appointment tomorrow',
          body: '$details$note',
        ),
      );
    }

    final hourBefore = a.start.subtract(const Duration(hours: 1));
    if (hourBefore.isAfter(now)) {
      reminders.add(
        PlannedReminder(
          time: hourBefore,
          title: 'Appointment in 1 hour',
          body: details,
        ),
      );
    }
  }

  reminders.sort((a, b) => a.time.compareTo(b.time));
  return reminders.take(kMaxReminders).toList();
}
