import 'package:flutter_test/flutter_test.dart';
import 'package:healthbook_test/models/app_models.dart';
import 'package:healthbook_test/models/medical_history.dart';
import 'package:healthbook_test/services/clinic_store.dart';
import 'package:healthbook_test/services/medical_history_store.dart';
import 'package:healthbook_test/services/prescription_store.dart';

DateTime _tomorrowAt(int hour) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day + 1, hour);
}

MedicalHistory _history({String allergies = 'Penicillin'}) => MedicalHistory(
      allergies: allergies,
      conditions: 'Asthma',
      updatedAt: DateTime.now(),
    );

void main() {
  const patient = 'patient@x.com';
  const doctor = 'dr@x.com';
  const stranger = 'other@x.com';

  late ClinicStore clinic;
  late PrescriptionStore prescriptions;
  late MedicalHistoryStore store;

  setUp(() {
    clinic = ClinicStore();
    prescriptions = PrescriptionStore(clinic);
    store = MedicalHistoryStore(prescriptions);
    clinic.addDoctor(const Doctor(id: doctor, name: 'Dr. Test', specialty: 'General Practice'));
  });

  test('a patient can save and read their own history', () {
    store.save(patientId: patient, editorId: patient, history: _history());
    expect(store.historyFor(patient, patient)?.allergies, 'Penicillin');
  });

  test('allergies are required', () {
    expect(
      () => store.save(patientId: patient, editorId: patient, history: _history(allergies: '  ')),
      throwsA(isA<MedicalHistoryException>()),
    );
  });

  test('nobody but the patient can change the history', () {
    store.save(patientId: patient, editorId: patient, history: _history());
    expect(
      () => store.save(patientId: patient, editorId: doctor, history: _history(allergies: 'None')),
      throwsA(isA<MedicalHistoryException>()),
    );
  });

  test('a doctor cannot read the history without the patient\'s access', () {
    store.save(patientId: patient, editorId: patient, history: _history());
    expect(
      () => store.historyFor(patient, doctor),
      throwsA(isA<MedicalHistoryException>()),
    );
  });

  test('a doctor with access can read the history', () {
    clinic.setHourOpen(doctor, _tomorrowAt(9), true);
    final appt = clinic.requestAppointment(
      patientId: patient,
      doctorId: doctor,
      start: _tomorrowAt(9),
    );
    clinic.approveAppointment(appt.id, doctor);
    prescriptions.grantAccess(patient, doctor);
    store.save(patientId: patient, editorId: patient, history: _history());

    expect(store.historyFor(patient, doctor)?.conditions, 'Asthma');
  });

  test('a stranger cannot read the history', () {
    store.save(patientId: patient, editorId: patient, history: _history());
    expect(
      () => store.historyFor(patient, stranger),
      throwsA(isA<MedicalHistoryException>()),
    );
  });
}
