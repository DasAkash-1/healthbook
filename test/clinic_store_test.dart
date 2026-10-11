import 'package:flutter_test/flutter_test.dart';
import 'package:healthbook_test/models/app_models.dart';
import 'package:healthbook_test/services/clinic_store.dart';
import 'package:healthbook_test/utils/validators.dart';

// Day offset from today at midnight.
DateTime _day(int daysFromToday) {
  final now = DateTime.now();
  return DateTime(
    now.year,
    now.month,
    now.day,
  ).add(Duration(days: daysFromToday));
}

// Exact hour mark on a day offset from today.
DateTime _at(int daysFromToday, int hour) {
  final d = _day(daysFromToday);
  return DateTime(d.year, d.month, d.day, hour);
}

void main() {
  // Each test gets a fresh store, so tests don't affect each other.
  late ClinicStore store;

  // Seeded doctors (see ClinicStore._seedDoctors).
  const cardiologist = 'seed-1';
  const gp = 'seed-2';
  const dermatologist = 'seed-3';

  setUp(() {
    store = ClinicStore();
  });

  group('Doctor directory', () {
    test('seeded specialties are unique and sorted', () {
      expect(store.specialties, [
        'Cardiology',
        'Dermatology',
        'General Practice',
      ]);
    });

    test('search matches name and specialty, ignoring case', () {
      expect(store.searchDoctors(query: 'SARAH').map((d) => d.id), [
        cardiologist,
      ]);
      expect(store.searchDoctors(query: 'derma').map((d) => d.id), [
        dermatologist,
      ]);
    });

    test('specialty filter narrows the list', () {
      final result = store.searchDoctors(specialty: 'General Practice');
      expect(result.map((d) => d.id), [gp]);
    });

    test('availability filter keeps doctors with open hours this week', () {
      expect(store.searchDoctors(availableOnly: true).length, 3);
    });

    test('a newly added doctor can be found', () {
      store.addDoctor(
        const Doctor(id: 'new-1', name: 'Dr. New', specialty: 'Neurology'),
      );
      expect(store.doctorById('new-1')?.name, 'Dr. New');
    });
  });

  group('Availability', () {
    test('seeded doctors have 9:00 to 16:00 open tomorrow', () {
      final slots = store.availableSlotsOn(cardiologist, _day(1));
      expect(slots.length, 8);
      expect(slots.first, _at(1, 9));
      expect(slots.last, _at(1, 16));
    });

    test('doctor can open an hour inside the 7-day window', () {
      store.setHourOpen(gp, _at(2, 10), true);
      expect(store.isHourOpen(gp, _at(2, 10)), isTrue);
    });

    test('doctor cannot open an hour beyond 7 days', () {
      expect(
        () => store.setHourOpen(gp, _at(8, 10), true),
        throwsA(isA<BookingException>()),
      );
    });

    test('doctor cannot free an hour that has a booking', () {
      store.requestAppointment(
        patientId: 'p@x.com',
        doctorId: gp,
        start: _at(1, 10),
      );
      expect(
        () => store.setHourOpen(gp, _at(1, 10), false),
        throwsA(isA<BookingException>()),
      );
    });

    test('doctor can free an hour with no bookings', () {
      store.setHourOpen(gp, _at(1, 11), false);
      expect(store.isHourOpen(gp, _at(1, 11)), isFalse);
    });
  });

  group('Booking', () {
    const patient = 'patient@x.com';

    test(
      'requesting an open slot succeeds and removes it from availability',
      () {
        final appt = store.requestAppointment(
          patientId: patient,
          doctorId: cardiologist,
          start: _at(1, 9),
          note: 'Chest pain',
        );
        expect(appt.status, AppointmentStatus.pending);
        expect(appt.note, 'Chest pain');
        expect(
          store.availableSlotsOn(cardiologist, _day(1)),
          isNot(contains(_at(1, 9))),
        );
      },
    );

    test('the same slot cannot be booked twice', () {
      store.requestAppointment(
        patientId: patient,
        doctorId: cardiologist,
        start: _at(1, 9),
      );
      expect(
        () => store.requestAppointment(
          patientId: 'other@x.com',
          doctorId: cardiologist,
          start: _at(1, 9),
        ),
        throwsA(isA<BookingException>()),
      );
    });

    test('an hour the doctor has not opened cannot be booked', () {
      expect(
        () => store.requestAppointment(
          patientId: patient,
          doctorId: gp,
          start: _at(1, 20),
        ),
        throwsA(isA<BookingException>()),
      );
    });

    test('a past hour cannot be opened, so it cannot be booked', () {
      // Midnight today is already in the past.
      expect(
        () => store.setHourOpen(gp, _at(0, 0), true),
        throwsA(isA<BookingException>()),
      );
      expect(
        () => store.requestAppointment(
          patientId: patient,
          doctorId: gp,
          start: _at(0, 0),
        ),
        throwsA(isA<BookingException>()),
      );
    });

    test('one-hour gap applies when switching to a different doctor', () {
      // Booked 10:00 to 10:20 with the cardiologist.
      store.requestAppointment(
        patientId: patient,
        doctorId: cardiologist,
        start: _at(1, 10),
      );

      // Too soon with another doctor, both before and after.
      expect(
        () => store.requestAppointment(
          patientId: patient,
          doctorId: gp,
          start: _at(1, 11),
        ),
        throwsA(isA<BookingException>()),
      );
      expect(
        () => store.requestAppointment(
          patientId: patient,
          doctorId: dermatologist,
          start: _at(1, 9),
        ),
        throwsA(isA<BookingException>()),
      );

      // 11:00 is too soon, so the earliest allowed slot with another doctor is 12:00.
      expect(
        () => store.requestAppointment(
          patientId: patient,
          doctorId: gp,
          start: _at(1, 12),
        ),
        returnsNormally,
      );
    });

    test('same doctor at a different hour is allowed without the gap', () {
      store.requestAppointment(
        patientId: patient,
        doctorId: cardiologist,
        start: _at(1, 10),
      );
      expect(
        () => store.requestAppointment(
          patientId: patient,
          doctorId: cardiologist,
          start: _at(1, 11),
        ),
        returnsNormally,
      );
    });
  });

  group('Cancellation and approval', () {
    const patient = 'patient@x.com';

    test('a pending request can be cancelled, which frees the slot', () {
      final appt = store.requestAppointment(
        patientId: patient,
        doctorId: gp,
        start: _at(1, 9),
      );
      store.cancelAppointment(appt.id, patient);

      expect(
        store.appointmentsForPatient(patient).first.status,
        AppointmentStatus.cancelled,
      );
      expect(store.availableSlotsOn(gp, _day(1)), contains(_at(1, 9)));
    });

    test('an approved request cannot be cancelled', () {
      final appt = store.requestAppointment(
        patientId: patient,
        doctorId: gp,
        start: _at(1, 9),
      );
      store.approveAppointment(appt.id, gp);

      expect(
        () => store.cancelAppointment(appt.id, patient),
        throwsA(isA<BookingException>()),
      );
    });

    test('a patient cannot cancel someone else\'s appointment', () {
      final appt = store.requestAppointment(
        patientId: patient,
        doctorId: gp,
        start: _at(1, 9),
      );
      expect(
        () => store.cancelAppointment(appt.id, 'someone-else@x.com'),
        throwsA(isA<BookingException>()),
      );
    });

    test('a doctor can approve a pending request for their own hours', () {
      final appt = store.requestAppointment(
        patientId: patient,
        doctorId: gp,
        start: _at(1, 9),
      );
      store.approveAppointment(appt.id, gp);
      expect(
        store.appointmentsForDoctor(gp).first.status,
        AppointmentStatus.approved,
      );
    });

    test('a doctor can reject a pending request, which frees the slot', () {
      final appt = store.requestAppointment(
        patientId: patient,
        doctorId: gp,
        start: _at(1, 9),
      );
      store.rejectAppointment(appt.id, gp);
      expect(
        store.appointmentsForDoctor(gp).first.status,
        AppointmentStatus.rejected,
      );
      expect(store.availableSlotsOn(gp, _day(1)), contains(_at(1, 9)));
    });

    test('a doctor cannot approve another doctor\'s request', () {
      final appt = store.requestAppointment(
        patientId: patient,
        doctorId: gp,
        start: _at(1, 9),
      );
      expect(
        () => store.approveAppointment(appt.id, cardiologist),
        throwsA(isA<BookingException>()),
      );
    });
  });

  group('Validators', () {
    test('email must look valid', () {
      expect(Validators.email('a@b.co'), isNull);
      expect(Validators.email('not-an-email'), isNotNull);
      expect(Validators.email(''), isNotNull);
    });

    test('password needs 8+ characters with upper, lower, and a number', () {
      expect(Validators.password('Abcdefg1'), isNull);
      expect(Validators.password('short1A'), isNotNull);
      expect(Validators.password('alllowercase1'), isNotNull);
      expect(Validators.password('ALLUPPERCASE1'), isNotNull);
      expect(Validators.password('NoNumbersHere'), isNotNull);
    });

    test('phone accepts 10 to 15 digits with spaces or dashes', () {
      expect(Validators.phone('017 1234-5678'), isNull);
      expect(Validators.phone('12345'), isNotNull);
    });

    test('date of birth must be at least 13 years ago', () {
      final tenYearsAgo = DateTime(DateTime.now().year - 10);
      expect(Validators.dateOfBirth(tenYearsAgo), isNotNull);
      final twentyYearsAgo = DateTime(DateTime.now().year - 20);
      expect(Validators.dateOfBirth(twentyYearsAgo), isNull);
    });
  });
}
