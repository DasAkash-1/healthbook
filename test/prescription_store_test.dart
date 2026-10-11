import 'package:flutter_test/flutter_test.dart';
import 'package:healthbook_test/models/app_models.dart';
import 'package:healthbook_test/models/prescription_models.dart';
import 'package:healthbook_test/services/clinic_store.dart';
import 'package:healthbook_test/services/prescription_store.dart';

DateTime _tomorrowAt(int hour) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day + 1, hour);
}

void main() {
  const patient = 'patient@x.com';
  const verifiedDoctor = 'dr.verified@x.com';
  const unverifiedDoctor = 'dr.new@x.com';

  late ClinicStore clinic;
  late PrescriptionStore store;

  setUp(() {
    clinic = ClinicStore();
    store = PrescriptionStore(clinic);

    clinic.addDoctor(const Doctor(
      id: verifiedDoctor,
      name: 'Dr. Verified',
      specialty: 'General Practice',
      licenseNumber: 'LIC-1',
    ));
    clinic.verifyDoctor(verifiedDoctor);

    clinic.addDoctor(const Doctor(
      id: unverifiedDoctor,
      name: 'Dr. New',
      specialty: 'General Practice',
      licenseNumber: 'LIC-2',
    ));
  });

  // Patient gets an approved appointment with a doctor, which makes them eligible for access.
  void approve(String doctorId, {int hour = 9}) {
    final appt = clinic.requestAppointment(
      patientId: patient,
      doctorId: doctorId,
      start: _tomorrowAt(hour),
    );
    clinic.approveAppointment(appt.id, doctorId);
  }

  Medication addMed(String doctorId, {int remaining = 10}) {
    return store.addMedication(
      patientId: patient,
      doctorId: doctorId,
      name: 'Metformin',
      dose: '500 mg',
      timesPerDay: 2,
      remainingDoses: remaining,
    );
  }

  group('Access', () {
    test('access cannot be granted without an approved appointment', () {
      expect(
        () => store.grantAccess(patient, verifiedDoctor),
        throwsA(isA<PrescriptionException>()),
      );
    });

    test('access can be granted after an approved appointment', () {
      approve(verifiedDoctor);
      store.grantAccess(patient, verifiedDoctor);
      expect(store.hasAccess(patient, verifiedDoctor), isTrue);
      expect(store.patientsGrantingAccess(verifiedDoctor), [patient]);
    });

    test('revoking access removes it', () {
      approve(verifiedDoctor);
      store.grantAccess(patient, verifiedDoctor);
      store.revokeAccess(patient, verifiedDoctor);
      expect(store.hasAccess(patient, verifiedDoctor), isFalse);
    });
  });

  group('Doctor changes', () {
    test('a verified doctor with access can add a medication', () {
      approve(verifiedDoctor);
      store.grantAccess(patient, verifiedDoctor);
      addMed(verifiedDoctor);
      expect(store.medicationsFor(patient).single.name, 'Metformin');
    });

    test('a doctor without access cannot add a medication', () {
      approve(verifiedDoctor);
      expect(
        () => addMed(verifiedDoctor),
        throwsA(isA<PrescriptionException>()),
      );
    });

    test('an unverified doctor cannot change a prescription, even with access', () {
      approve(unverifiedDoctor, hour: 14);
      store.grantAccess(patient, unverifiedDoctor);
      expect(
        () => addMed(unverifiedDoctor),
        throwsA(predicate((e) =>
            e is PrescriptionException && e.message.contains('verified'))),
      );
    });

    test('every doctor change creates a version, newest first', () {
      approve(verifiedDoctor);
      store.grantAccess(patient, verifiedDoctor);
      final med = addMed(verifiedDoctor);
      store.updateMedication(
        patientId: patient,
        doctorId: verifiedDoctor,
        updated: Medication(
          id: med.id,
          name: 'Metformin XR',
          dose: '500 mg',
          timesPerDay: 2,
          remainingDoses: 10,
        ),
      );

      final history = store.historyFor(patient, patient);
      expect(history.length, 2);
      expect(history.first.number, 2);
      expect(history.first.summary, startsWith('Updated'));
      expect(history.last.summary, startsWith('Added'));
      expect(history.first.byName, 'Dr. Verified');
    });

    test('removing a medication is recorded in the history', () {
      approve(verifiedDoctor);
      store.grantAccess(patient, verifiedDoctor);
      final med = addMed(verifiedDoctor);
      store.removeMedication(
        patientId: patient,
        doctorId: verifiedDoctor,
        medicationId: med.id,
      );

      expect(store.medicationsFor(patient), isEmpty);
      expect(store.historyFor(patient, patient).first.summary, startsWith('Removed'));
    });

    test('times per day must be between 1 and 4', () {
      approve(verifiedDoctor);
      store.grantAccess(patient, verifiedDoctor);
      expect(
        () => store.addMedication(
          patientId: patient,
          doctorId: verifiedDoctor,
          name: 'Metformin',
          dose: '500 mg',
          timesPerDay: 5,
          remainingDoses: 10,
        ),
        throwsA(isA<PrescriptionException>()),
      );
    });
  });

  group('Revoking access', () {
    test('a revoked doctor can no longer change the prescription', () {
      approve(verifiedDoctor);
      store.grantAccess(patient, verifiedDoctor);
      addMed(verifiedDoctor);
      store.revokeAccess(patient, verifiedDoctor);

      expect(
        () => addMed(verifiedDoctor),
        throwsA(isA<PrescriptionException>()),
      );
    });

    test('past history stays visible to the patient after revoking', () {
      approve(verifiedDoctor);
      store.grantAccess(patient, verifiedDoctor);
      addMed(verifiedDoctor);
      store.revokeAccess(patient, verifiedDoctor);

      expect(store.historyFor(patient, patient).length, 1);
    });

    test('someone without access cannot view the history', () {
      approve(verifiedDoctor);
      store.grantAccess(patient, verifiedDoctor);
      addMed(verifiedDoctor);

      expect(
        () => store.historyFor(patient, unverifiedDoctor),
        throwsA(isA<PrescriptionException>()),
      );
    });
  });

  group('Patient dose logging', () {
    test('taking a dose lowers the remaining count from 10 to 9', () {
      approve(verifiedDoctor);
      store.grantAccess(patient, verifiedDoctor);
      final med = addMed(verifiedDoctor, remaining: 10);

      store.logDose(patientId: patient, medicationId: med.id, taken: true);
      expect(store.medicationsFor(patient).single.remainingDoses, 9);
    });

    test('a missed dose does not change the count but is logged', () {
      approve(verifiedDoctor);
      store.grantAccess(patient, verifiedDoctor);
      final med = addMed(verifiedDoctor, remaining: 10);

      store.logDose(patientId: patient, medicationId: med.id, taken: false);
      expect(store.medicationsFor(patient).single.remainingDoses, 10);
      expect(store.doseLogsFor(patient).single.taken, isFalse);
    });

    test('a dose cannot be taken when none are left', () {
      approve(verifiedDoctor);
      store.grantAccess(patient, verifiedDoctor);
      final med = addMed(verifiedDoctor, remaining: 0);

      expect(
        () => store.logDose(patientId: patient, medicationId: med.id, taken: true),
        throwsA(isA<PrescriptionException>()),
      );
    });

    test('dose logs do not add to the version history', () {
      approve(verifiedDoctor);
      store.grantAccess(patient, verifiedDoctor);
      final med = addMed(verifiedDoctor, remaining: 10);

      store.logDose(patientId: patient, medicationId: med.id, taken: true);
      expect(store.historyFor(patient, patient).length, 1);
    });
  });
}
