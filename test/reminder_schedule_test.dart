import 'package:flutter_test/flutter_test.dart';
import 'package:healthbook_test/models/prescription_models.dart';
import 'package:healthbook_test/services/reminder_schedule_store.dart';
import 'package:healthbook_test/utils/reminder_planner.dart';

void main() {
  group('ReminderScheduleStore', () {
    late ReminderScheduleStore store;

    setUp(() {
      store = ReminderScheduleStore();
    });

    test('returns default hours before customization', () {
      expect(store.hoursFor(1), [9]);
      expect(store.hoursFor(2), [9, 21]);
      expect(store.hoursFor(3), [9, 14, 21]);
      expect(store.hoursFor(4), [9, 13, 17, 21]);
      expect(store.isCustomized(2), isFalse);
    });

    test('saves sorted unique custom hours and supports reset', () {
      store.setHoursFor(2, [20, 8]);
      expect(store.isCustomized(2), isTrue);
      expect(store.hoursFor(2), [8, 20]);

      store.resetToDefault(timesPerDay: 2);
      expect(store.isCustomized(2), isFalse);
      expect(store.hoursFor(2), [9, 21]);
    });

    test('rejects duplicate hours, wrong count, or out-of-range hours', () {
      expect(() => store.setHoursFor(2, [8, 8]), throwsA(isA<ReminderScheduleException>()));
      expect(() => store.setHoursFor(2, [8]), throwsA(isA<ReminderScheduleException>()));
      expect(() => store.setHoursFor(1, [25]), throwsA(isA<ReminderScheduleException>()));
    });
  });

  group('planReminders with custom hours', () {
    test('uses custom hours when supplied', () {
      final now = DateTime(2026, 11, 19, 7, 0);
      final med = Medication(
        id: 'm1',
        name: 'Atorvastatin',
        dose: '20 mg',
        timesPerDay: 1,
        remainingDoses: 1,
      );

      final reminders = planReminders(
        now: now,
        medications: [med],
        appointments: const [],
        doctorName: (_) => 'Dr. Test',
        customHoursByFrequency: {1: [22]},
      );

      expect(reminders, hasLength(1));
      expect(reminders.first.time, DateTime(2026, 11, 19, 22, 0));
    });
  });
}
