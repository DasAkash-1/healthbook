import 'package:flutter_test/flutter_test.dart';
import 'package:healthbook_test/models/app_models.dart';
import 'package:healthbook_test/services/checkup_report_store.dart';
import 'package:healthbook_test/services/clinic_store.dart';
import 'package:healthbook_test/services/prescription_store.dart';

void main() {
  const patient = 'patient@x.com';
  const stranger = 'stranger@x.com';
  const verifiedDoctor = 'dr.verified@x.com';
  const unverifiedDoctor = 'dr.unverified@x.com';

  late ClinicStore clinic;
  late PrescriptionStore prescriptions;
  late CheckupReportStore reports;
  late DateTime now;

  // Helper that computes tomorrow at [hour] relative to the test's simulated clock [now]
  // so it always stays inside the 7-day booking window regardless of real-world date.
  DateTime tomorrowAt(int hour) {
    return DateTime(now.year, now.month, now.day + 1, hour);
  }

  setUp(() {
    final realNow = DateTime.now();
    now = DateTime(realNow.year, realNow.month, realNow.day, 10, 0);
    clinic = ClinicStore(clock: () => now);
    prescriptions = PrescriptionStore(clinic, clock: () => now);
    reports = CheckupReportStore(clinic, prescriptions, clock: () => now);

    clinic.addDoctor(const Doctor(
      id: verifiedDoctor,
      name: 'Dr. Ayesha',
      specialty: 'Cardiology',
      licenseNumber: 'BMDC-101',
    ));
    clinic.verifyDoctor(verifiedDoctor);

    clinic.addDoctor(const Doctor(
      id: unverifiedDoctor,
      name: 'Dr. Pending',
      specialty: 'General Practice',
      licenseNumber: 'BMDC-102',
    ));
  });

  // Sets up an approved appointment and grants [doctorId] access to [patient]'s records.
  void grantDoctorAccess(String doctorId, {int hour = 9}) {
    final slot = tomorrowAt(hour);
    clinic.setHourOpen(doctorId, slot, true);
    final appt = clinic.requestAppointment(
      patientId: patient,
      doctorId: doctorId,
      start: slot,
    );
    clinic.approveAppointment(appt.id, doctorId);
    prescriptions.grantAccess(patient, doctorId);
  }

  group('CheckupReportStore access and creation', () {
    test('verified doctor with access can create a checkup report and patient can read it', () {
      grantDoctorAccess(verifiedDoctor);

      final created = reports.createReport(
        patientId: patient,
        doctorId: verifiedDoctor,
        chiefComplaintOrDiagnosis: 'Mild hypertension',
        bloodPressure: '138/88',
        heartRateBpm: 78,
        temperatureC: 36.8,
        weightKg: 72.5,
        clinicalNotes: 'Advised salt reduction and regular walks.',
        followUpAdvice: 'Recheck BP in 2 weeks.',
      );

      expect(created.doctorName, 'Dr. Ayesha');
      expect(created.specialty, 'Cardiology');
      expect(reports.reportsFor(patient, patient), hasLength(1));
      expect(
        reports.reportsFor(patient, verifiedDoctor).first.chiefComplaintOrDiagnosis,
        'Mild hypertension',
      );
    });

    test('doctor without patient access cannot create a report', () {
      expect(
        () => reports.createReport(
          patientId: patient,
          doctorId: verifiedDoctor,
          chiefComplaintOrDiagnosis: 'Checkup',
        ),
        throwsA(isA<CheckupReportException>()),
      );
    });

    test('unverified doctor cannot create a report even with access', () {
      clinic.verifyDoctor(unverifiedDoctor);
      grantDoctorAccess(unverifiedDoctor, hour: 11);
      clinic.unverifyDoctor(unverifiedDoctor);

      expect(
        () => reports.createReport(
          patientId: patient,
          doctorId: unverifiedDoctor,
          chiefComplaintOrDiagnosis: 'Checkup',
        ),
        throwsA(isA<CheckupReportException>()),
      );
    });

    test('stranger cannot read patient checkup reports', () {
      grantDoctorAccess(verifiedDoctor);
      reports.createReport(
        patientId: patient,
        doctorId: verifiedDoctor,
        chiefComplaintOrDiagnosis: 'Checkup',
      );

      expect(
        () => reports.reportsFor(patient, stranger),
        throwsA(isA<CheckupReportException>()),
      );
    });
  });

  group('CheckupReportStore validation and ordering', () {
    test('empty diagnosis or out-of-range vitals are rejected', () {
      grantDoctorAccess(verifiedDoctor);

      expect(
        () => reports.createReport(
          patientId: patient,
          doctorId: verifiedDoctor,
          chiefComplaintOrDiagnosis: '   ',
        ),
        throwsA(isA<CheckupReportException>()),
      );

      expect(
        () => reports.createReport(
          patientId: patient,
          doctorId: verifiedDoctor,
          chiefComplaintOrDiagnosis: 'Fever',
          temperatureC: 50.0,
        ),
        throwsA(isA<CheckupReportException>()),
      );

      expect(
        () => reports.createReport(
          patientId: patient,
          doctorId: verifiedDoctor,
          chiefComplaintOrDiagnosis: 'Fever',
          heartRateBpm: 300,
        ),
        throwsA(isA<CheckupReportException>()),
      );
    });

    test('reports are returned newest first', () {
      grantDoctorAccess(verifiedDoctor);

      reports.createReport(
        patientId: patient,
        doctorId: verifiedDoctor,
        chiefComplaintOrDiagnosis: 'First visit',
      );

      now = now.add(const Duration(days: 3));
      reports.createReport(
        patientId: patient,
        doctorId: verifiedDoctor,
        chiefComplaintOrDiagnosis: 'Follow-up visit',
      );

      final list = reports.reportsFor(patient, patient);
      expect(list.map((r) => r.chiefComplaintOrDiagnosis), [
        'Follow-up visit',
        'First visit',
      ]);
    });
  });
}
