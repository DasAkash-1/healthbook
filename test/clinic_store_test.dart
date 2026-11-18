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

    test('a second booking with the same doctor is rejected while the first is upcoming', () {
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
        throwsA(predicate((e) =>
            e is BookingException && e.message.contains('already have an appointment'))),
      );

      // A later day is blocked too, because the first booking has not happened yet.
      store.setHourOpen(cardiologist, _at(2, 10), true);
      expect(
        () => store.requestAppointment(
          patientId: patient,
          doctorId: cardiologist,
          start: _at(2, 10),
        ),
        throwsA(isA<BookingException>()),
      );
    });

    test('another patient can still book the same doctor', () {
      store.requestAppointment(
        patientId: patient,
        doctorId: cardiologist,
        start: _at(1, 10),
      );
      expect(
        () => store.requestAppointment(
          patientId: 'other@x.com',
          doctorId: cardiologist,
          start: _at(1, 11),
        ),
        returnsNormally,
      );
    });

    test('the visit type and note are saved with the request', () {
      final appt = store.requestAppointment(
        patientId: patient,
        doctorId: gp,
        start: _at(1, 9),
        visitType: 'Follow-up',
        note: 'Blood pressure check',
      );
      expect(appt.visitType, 'Follow-up');
      expect(appt.note, 'Blood pressure check');
    });

    test('the visit type is optional, but must come from the list', () {
      expect(
        () => store.requestAppointment(
          patientId: patient,
          doctorId: gp,
          start: _at(1, 9),
          visitType: 'Something else',
        ),
        throwsA(isA<BookingException>()),
      );
      expect(
        store
            .requestAppointment(patientId: patient, doctorId: gp, start: _at(1, 9))
            .visitType,
        '',
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

    test('an approved appointment can be cancelled with a reason, which frees the slot', () {
      final appt = store.requestAppointment(
        patientId: patient,
        doctorId: gp,
        start: _at(1, 9),
      );
      store.approveAppointment(appt.id, gp);
      store.cancelAppointment(appt.id, patient, reason: 'Transport problem');

      final saved = store.appointmentsForDoctor(gp).first;
      expect(saved.status, AppointmentStatus.cancelled);
      expect(saved.reason, 'Transport problem');
      expect(store.availableSlotsOn(gp, _day(1)), contains(_at(1, 9)));
    });

    test('cancelling an approved appointment without a reason is rejected', () {
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
      expect(
        () => store.cancelAppointment(appt.id, patient, reason: '   '),
        throwsA(isA<BookingException>()),
      );
      expect(store.appointmentsForPatient(patient).first.status, AppointmentStatus.approved);
    });

    test('a cancelled appointment cannot be cancelled again', () {
      final appt = store.requestAppointment(
        patientId: patient,
        doctorId: gp,
        start: _at(1, 9),
      );
      store.cancelAppointment(appt.id, patient);
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
      store.rejectAppointment(appt.id, gp, reason: 'Fully booked that day');
      final saved = store.appointmentsForDoctor(gp).first;
      expect(saved.status, AppointmentStatus.rejected);
      expect(saved.reason, 'Fully booked that day');
      expect(store.availableSlotsOn(gp, _day(1)), contains(_at(1, 9)));
    });

    test('a doctor must give a reason when rejecting', () {
      final appt = store.requestAppointment(
        patientId: patient,
        doctorId: gp,
        start: _at(1, 9),
      );
      expect(
        () => store.rejectAppointment(appt.id, gp, reason: ' '),
        throwsA(isA<BookingException>()),
      );
      expect(store.appointmentsForDoctor(gp).first.status, AppointmentStatus.pending);
    });

    test('a doctor cannot cancel an appointment after approving it', () {
      final appt = store.requestAppointment(
        patientId: patient,
        doctorId: gp,
        start: _at(1, 9),
      );
      store.approveAppointment(appt.id, gp);
      expect(
        () => store.rejectAppointment(appt.id, gp, reason: 'Changed my mind'),
        throwsA(predicate((e) =>
            e is BookingException && e.message.contains('cannot be cancelled by the doctor'))),
      );
      expect(store.appointmentsForDoctor(gp).first.status, AppointmentStatus.approved);
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

  group('Booking rules over time', () {
    const patient = 'patient@x.com';
    late DateTime now;
    late ClinicStore timed;

    setUp(() {
      now = DateTime.now();
      timed = ClinicStore(clock: () => now);
    });

    test('a finished appointment no longer blocks booking the same doctor on a later day', () {
      final first = timed.requestAppointment(
        patientId: patient,
        doctorId: gp,
        start: _at(1, 9),
      );
      timed.approveAppointment(first.id, gp);

      now = _at(1, 10); // the 09:00 visit is over
      timed.setHourOpen(gp, _at(3, 10), true);
      expect(
        () => timed.requestAppointment(
          patientId: patient,
          doctorId: gp,
          start: _at(3, 10),
        ),
        returnsNormally,
      );
    });

    test('the same doctor cannot be booked twice on one day, even after the first visit', () {
      final first = timed.requestAppointment(
        patientId: patient,
        doctorId: gp,
        start: _at(1, 9),
      );
      timed.approveAppointment(first.id, gp);

      now = _at(1, 10); // the 09:00 visit is over
      expect(
        () => timed.requestAppointment(
          patientId: patient,
          doctorId: gp,
          start: _at(1, 15),
        ),
        throwsA(predicate((e) =>
            e is BookingException && e.message.contains('on that day'))),
      );
    });

    test('a cancelled or rejected request does not block booking another time that day', () {
      final first = timed.requestAppointment(
        patientId: patient,
        doctorId: gp,
        start: _at(1, 9),
      );
      timed.cancelAppointment(first.id, patient);

      final second = timed.requestAppointment(
        patientId: patient,
        doctorId: gp,
        start: _at(1, 10),
      );
      timed.rejectAppointment(second.id, gp, reason: 'Fully booked that day');

      expect(
        () => timed.requestAppointment(
          patientId: patient,
          doctorId: gp,
          start: _at(1, 11),
        ),
        returnsNormally,
      );
    });

    test('an appointment that has already started cannot be cancelled', () {
      final appt = timed.requestAppointment(
        patientId: patient,
        doctorId: gp,
        start: _at(1, 9),
      );
      timed.approveAppointment(appt.id, gp);

      now = _at(1, 9).add(const Duration(minutes: 5));
      expect(
        () => timed.cancelAppointment(appt.id, patient, reason: 'Transport problem'),
        throwsA(isA<BookingException>()),
      );
    });
  });

  group('Unverified doctors', () {
    const patient = 'patient@x.com';

    setUp(() {
      store.addDoctor(
        const Doctor(id: 'new-1', name: 'Dr. New', specialty: 'Neurology'),
      );
      store.setHourOpen('new-1', _at(1, 10), true);
    });

    test('show no slots and cannot be booked', () {
      expect(store.availableSlotsOn('new-1', _day(1)), isEmpty);
      expect(store.hasAvailability('new-1'), isFalse);
      expect(
        () => store.requestAppointment(
          patientId: patient,
          doctorId: 'new-1',
          start: _at(1, 10),
        ),
        throwsA(predicate((e) =>
            e is BookingException && e.message.contains('verification'))),
      );
    });

    test('can be booked once they are verified', () {
      store.verifyDoctor('new-1');
      expect(store.availableSlotsOn('new-1', _day(1)), [_at(1, 10)]);
      expect(
        () => store.requestAppointment(
          patientId: patient,
          doctorId: 'new-1',
          start: _at(1, 10),
        ),
        returnsNormally,
      );
    });

    test('an unknown doctor cannot be booked', () {
      expect(
        () => store.requestAppointment(
          patientId: patient,
          doctorId: 'nobody',
          start: _at(1, 10),
        ),
        throwsA(isA<BookingException>()),
      );
    });
  });

  group('Approval note and summaries', () {
    const patient = 'patient@x.com';
    late DateTime now;
    late ClinicStore timed;

    setUp(() {
      now = DateTime.now();
      timed = ClinicStore(clock: () => now);
    });

    test('a doctor can add a note when approving, and it is trimmed', () {
      final appt = timed.requestAppointment(
        patientId: patient,
        doctorId: gp,
        start: _at(1, 9),
      );
      timed.approveAppointment(appt.id, gp, note: '  Bring your reports  ');
      final saved = timed.appointmentsForPatient(patient).first;
      expect(saved.status, AppointmentStatus.approved);
      expect(saved.approvalNote, 'Bring your reports');
    });

    test('the note is optional', () {
      final appt = timed.requestAppointment(
        patientId: patient,
        doctorId: gp,
        start: _at(1, 9),
      );
      timed.approveAppointment(appt.id, gp);
      expect(timed.appointmentsForPatient(patient).first.approvalNote, '');
    });

    test('a note that is too long is rejected and the request stays pending', () {
      final appt = timed.requestAppointment(
        patientId: patient,
        doctorId: gp,
        start: _at(1, 9),
      );
      expect(
        () => timed.approveAppointment(appt.id, gp, note: 'x' * (kMaxApprovalNoteLength + 1)),
        throwsA(isA<BookingException>()),
      );
      expect(timed.appointmentsForPatient(patient).first.status, AppointmentStatus.pending);
    });

    test('the patient sees the next approved appointment that has not finished', () {
      final appt = timed.requestAppointment(
        patientId: patient,
        doctorId: gp,
        start: _at(1, 9),
      );
      expect(timed.nextApprovedAppointmentFor(patient), isNull); // still pending

      timed.approveAppointment(appt.id, gp);
      expect(timed.nextApprovedAppointmentFor(patient)?.id, appt.id);

      now = _at(1, 10); // the visit is over
      expect(timed.nextApprovedAppointmentFor(patient), isNull);
    });

    test('the doctor summary counts visits today, waiting requests and the next visit', () {
      final first = timed.requestAppointment(
        patientId: patient,
        patientName: 'Pat One',
        doctorId: gp,
        start: _at(1, 9),
      );
      final second = timed.requestAppointment(
        patientId: 'two@x.com',
        patientName: 'Pat Two',
        doctorId: gp,
        start: _at(1, 10),
      );
      timed.requestAppointment(
        patientId: 'three@x.com',
        doctorId: gp,
        start: _at(1, 11),
      );
      timed.approveAppointment(first.id, gp);
      timed.approveAppointment(second.id, gp);

      now = _at(1, 8); // the morning of the visits
      var summary = timed.summaryForDoctor(gp);
      expect(summary.visitsToday, 2);
      expect(summary.pendingRequests, 1);
      expect(summary.nextVisit?.id, first.id);

      now = _at(1, 9).add(const Duration(minutes: 30)); // first visit is over
      summary = timed.summaryForDoctor(gp);
      expect(summary.visitsToday, 2);
      expect(summary.nextVisit?.id, second.id);

      now = _at(1, 12); // everything is over
      summary = timed.summaryForDoctor(gp);
      expect(summary.nextVisit, isNull);
      expect(summary.pendingRequests, 0);
    });

    test('a doctor with no visits has an empty summary', () {
      final summary = timed.summaryForDoctor(gp);
      expect(summary.visitsToday, 0);
      expect(summary.pendingRequests, 0);
      expect(summary.nextVisit, isNull);
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
