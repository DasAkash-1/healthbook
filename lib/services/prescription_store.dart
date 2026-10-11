import '../models/app_models.dart';
import '../models/prescription_models.dart';
import 'clinic_store.dart';

class PrescriptionException implements Exception {
  final String message;
  PrescriptionException(this.message);

  @override
  String toString() => message;
}

// In-memory prescriptions. Replace with a Firebase version later, keeping the same methods.
//
// Rules:
// - Only a verified doctor with the patient's access can add, edit, or remove medications.
// - The patient can only grant or revoke access, and log doses taken or missed.
// - Doctors can only be granted access if they have an approved appointment with the patient.
class PrescriptionStore {
  final ClinicStore _clinic;

  final Map<String, List<Medication>> _medications = {}; // patientId -> medications
  final Map<String, List<PrescriptionVersion>> _history = {}; // patientId -> doctor changes
  final Map<String, Set<String>> _access = {}; // patientId -> doctorIds with access
  final Map<String, List<DoseLog>> _doseLogs = {}; // patientId -> dose logs
  int _nextMedId = 1;

  PrescriptionStore(this._clinic);

  // ---------- Access (patient) ----------

  // Doctors the patient has an approved appointment with.
  List<String> eligibleDoctorIds(String patientId) {
    return _clinic
        .appointmentsForPatient(patientId)
        .where((a) => a.status == AppointmentStatus.approved)
        .map((a) => a.doctorId)
        .toSet()
        .toList();
  }

  bool hasAccess(String patientId, String doctorId) {
    return _access[patientId]?.contains(doctorId) ?? false;
  }

  void grantAccess(String patientId, String doctorId) {
    if (!eligibleDoctorIds(patientId).contains(doctorId)) {
      throw PrescriptionException(
        'You can only grant access to a doctor you have an approved appointment with.',
      );
    }
    _access.putIfAbsent(patientId, () => <String>{}).add(doctorId);
  }

  void revokeAccess(String patientId, String doctorId) {
    _access[patientId]?.remove(doctorId);
  }

  // Patients who have granted this doctor access.
  List<String> patientsGrantingAccess(String doctorId) {
    return _access.entries
        .where((e) => e.value.contains(doctorId))
        .map((e) => e.key)
        .toList();
  }

  // The patient themselves, or a doctor with access, can view a prescription.
  bool canView(String patientId, String viewerId) {
    return viewerId == patientId || hasAccess(patientId, viewerId);
  }

  // ---------- Reading ----------

  List<Medication> medicationsFor(String patientId) {
    return List.unmodifiable(_medications[patientId] ?? const <Medication>[]);
  }

  // Newest first.
  List<PrescriptionVersion> historyFor(String patientId, String viewerId) {
    if (!canView(patientId, viewerId)) {
      throw PrescriptionException('You do not have access to this prescription.');
    }
    final list = _history[patientId] ?? const <PrescriptionVersion>[];
    return List.unmodifiable(list.reversed.toList());
  }

  List<DoseLog> doseLogsFor(String patientId) {
    return List.unmodifiable(_doseLogs[patientId] ?? const <DoseLog>[]);
  }

  // ---------- Doctor changes (verified, with access) ----------

  void _requireDoctorEditAccess(String patientId, String doctorId) {
    if (!_clinic.isVerified(doctorId)) {
      throw PrescriptionException('Only verified doctors can change prescriptions.');
    }
    if (!hasAccess(patientId, doctorId)) {
      throw PrescriptionException('This patient has not granted you access.');
    }
  }

  void _validate({
    required String name,
    required String dose,
    required int timesPerDay,
    required int remainingDoses,
  }) {
    if (name.trim().isEmpty) throw PrescriptionException('Enter the medicine name.');
    if (dose.trim().isEmpty) throw PrescriptionException('Enter the dose.');
    if (timesPerDay < 1 || timesPerDay > 4) {
      throw PrescriptionException('Times per day must be between 1 and 4.');
    }
    if (remainingDoses < 0) {
      throw PrescriptionException('Remaining doses cannot be negative.');
    }
  }

  void _recordVersion(String patientId, String doctorId, String summary) {
    final versions = _history.putIfAbsent(patientId, () => <PrescriptionVersion>[]);
    versions.add(
      PrescriptionVersion(
        number: versions.length + 1,
        at: DateTime.now(),
        byName: _clinic.doctorById(doctorId)?.name ?? 'Doctor',
        summary: summary,
      ),
    );
  }

  Medication addMedication({
    required String patientId,
    required String doctorId,
    required String name,
    required String dose,
    required int timesPerDay,
    String instructions = '',
    required int remainingDoses,
  }) {
    _requireDoctorEditAccess(patientId, doctorId);
    _validate(
      name: name,
      dose: dose,
      timesPerDay: timesPerDay,
      remainingDoses: remainingDoses,
    );

    final medication = Medication(
      id: 'med-${_nextMedId++}',
      name: name.trim(),
      dose: dose.trim(),
      timesPerDay: timesPerDay,
      instructions: instructions.trim(),
      remainingDoses: remainingDoses,
    );
    _medications.putIfAbsent(patientId, () => <Medication>[]).add(medication);

    _recordVersion(
      patientId,
      doctorId,
      'Added ${medication.name} ${medication.dose}, '
      '$timesPerDay time(s) a day, $remainingDoses left',
    );
    return medication;
  }

  void updateMedication({
    required String patientId,
    required String doctorId,
    required Medication updated,
  }) {
    _requireDoctorEditAccess(patientId, doctorId);
    _validate(
      name: updated.name,
      dose: updated.dose,
      timesPerDay: updated.timesPerDay,
      remainingDoses: updated.remainingDoses,
    );

    final list = _medications[patientId];
    final index = list?.indexWhere((m) => m.id == updated.id) ?? -1;
    if (list == null || index == -1) {
      throw PrescriptionException('Medication not found.');
    }
    list[index] = updated;

    _recordVersion(
      patientId,
      doctorId,
      'Updated ${updated.name} ${updated.dose}, '
      '${updated.timesPerDay} time(s) a day, ${updated.remainingDoses} left',
    );
  }

  void removeMedication({
    required String patientId,
    required String doctorId,
    required String medicationId,
  }) {
    _requireDoctorEditAccess(patientId, doctorId);

    final list = _medications[patientId];
    final index = list?.indexWhere((m) => m.id == medicationId) ?? -1;
    if (list == null || index == -1) {
      throw PrescriptionException('Medication not found.');
    }
    final removed = list.removeAt(index);

    _recordVersion(patientId, doctorId, 'Removed ${removed.name} ${removed.dose}');
  }

  // ---------- Dose logging (patient) ----------

  // Taken lowers the remaining count by one. Missed only logs the dose.
  // Doses are logged separately, so they don't appear in the version history.
  void logDose({
    required String patientId,
    required String medicationId,
    required bool taken,
  }) {
    final list = _medications[patientId];
    final index = list?.indexWhere((m) => m.id == medicationId) ?? -1;
    if (list == null || index == -1) {
      throw PrescriptionException('Medication not found.');
    }

    final medication = list[index];
    if (taken) {
      if (medication.remainingDoses <= 0) {
        throw PrescriptionException('No doses left to take.');
      }
      list[index] = medication.copyWith(
        remainingDoses: medication.remainingDoses - 1,
      );
    }

    _doseLogs.putIfAbsent(patientId, () => <DoseLog>[]).add(
          DoseLog(medicationId: medicationId, at: DateTime.now(), taken: taken),
        );
  }
}

// The app-wide prescription store.
final PrescriptionStore prescriptionStore = PrescriptionStore(clinicStore);
