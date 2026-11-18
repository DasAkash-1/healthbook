import 'package:flutter_test/flutter_test.dart';

import 'package:healthbook_test/models/app_models.dart';
import 'package:healthbook_test/models/prescription_models.dart';
import 'package:healthbook_test/utils/reminder_planner.dart';

void main() {
  // Tuesday 17 Nov 2026, 10:00.
  final now = DateTime(2026, 11, 17, 10);

  Medication med({
    String id = 'm1',
    String name = 'Metformin',
    int timesPerDay = 2,
    int remaining = 10,
  }) {
    return Medication(
      id: id,
      name: name,
      dose: '500 mg',
      timesPerDay: timesPerDay,
      remainingDoses: remaining,
    );
  }

  Appointment appt(
    DateTime start, {
    AppointmentStatus status = AppointmentStatus.approved,
    String note = '',
  }) {
    final a = Appointment(
      id: 'a1',
      patientId: 'p',
      doctorId: 'd',
      start: start,
      note: '',
      status: status,
    );
    a.approvalNote = note;
    return a;
  }

  List<PlannedReminder> plan({
    List<Medication> medications = const [],
    List<Appointment> appointments = const [],
    DateTime? at,
  }) {
    return planReminders(
      now: at ?? now,
      medications: medications,
      appointments: appointments,
      doctorName: (_) => 'Dr. Test',
    );
  }

  group('medicine reminders', () {
    test('plans one reminder per dose, starting with the next time of day', () {
      final reminders = plan(medications: [med(timesPerDay: 2, remaining: 10)]);

      expect(reminders, hasLength(10));
      // 09:00 has passed, so the first one is this evening.
      expect(reminders.first.time, DateTime(2026, 11, 17, 21));
      expect(reminders.first.title, 'Time for your medicine');
      expect(reminders.first.body, 'Metformin 500 mg');
      // 1 evening dose today, then 2 a day for 4 days, then one more.
      expect(reminders.last.time, DateTime(2026, 11, 22, 9));
    });

    test('stops when the doses run out', () {
      expect(plan(medications: [med(remaining: 3)]), hasLength(3));
    });

    test('plans nothing when no doses are left', () {
      expect(plan(medications: [med(remaining: 0)]), isEmpty);
    });

    test('never plans further ahead than the planning window', () {
      final reminders = plan(medications: [med(timesPerDay: 1, remaining: 90)]);
      expect(reminders, hasLength(kReminderDaysAhead - 1)); // 09:00 today has passed
      expect(reminders.last.time.isBefore(DateTime(2026, 11, 25)), isTrue);
    });

    test('medicines due at the same time share one notification', () {
      final reminders = plan(
        at: DateTime(2026, 11, 17, 8),
        medications: [
          med(id: 'a', name: 'Metformin', timesPerDay: 1, remaining: 1),
          med(id: 'b', name: 'Amlodipine', timesPerDay: 1, remaining: 1),
        ],
      );
      expect(reminders, hasLength(1));
      expect(reminders.single.time, DateTime(2026, 11, 17, 9));
      expect(reminders.single.body, contains('Metformin'));
      expect(reminders.single.body, contains('Amlodipine'));
    });
  });

  group('appointment reminders', () {
    test('an approved visit gets a reminder a day before and an hour before', () {
      final reminders = plan(
        appointments: [appt(DateTime(2026, 11, 19, 9), note: 'Bring your reports')],
      );
      expect(reminders, hasLength(2));

      expect(reminders[0].time, DateTime(2026, 11, 18, 9));
      expect(reminders[0].title, 'Appointment tomorrow');
      expect(reminders[0].body, contains('Dr. Test'));
      expect(reminders[0].body, contains('Bring your reports'));

      expect(reminders[1].time, DateTime(2026, 11, 19, 8));
      expect(reminders[1].title, 'Appointment in 1 hour');
    });

    test('reminders that would already be in the past are skipped', () {
      // Starts in 3 hours: the day-before time has passed, the hour-before has not.
      final soon = appt(now.add(const Duration(hours: 3)));
      final reminders = plan(appointments: [soon]);
      expect(reminders, hasLength(1));
      expect(reminders.single.title, 'Appointment in 1 hour');

      // Starts in 30 minutes: nothing is left to remind about.
      expect(plan(appointments: [appt(now.add(const Duration(minutes: 30)))]), isEmpty);
    });

    test('pending, cancelled and finished visits get no reminders', () {
      expect(
        plan(appointments: [appt(DateTime(2026, 11, 19, 9), status: AppointmentStatus.pending)]),
        isEmpty,
      );
      expect(
        plan(appointments: [appt(DateTime(2026, 11, 19, 9), status: AppointmentStatus.cancelled)]),
        isEmpty,
      );
      expect(plan(appointments: [appt(DateTime(2026, 11, 16, 9))]), isEmpty);
    });
  });

  test('reminders come out in time order, mixing medicines and appointments', () {
    final reminders = plan(
      medications: [med(timesPerDay: 1, remaining: 3)],
      appointments: [appt(DateTime(2026, 11, 19, 9))],
    );
    for (var i = 1; i < reminders.length; i++) {
      expect(reminders[i].time.isBefore(reminders[i - 1].time), isFalse);
    }
  });
}
