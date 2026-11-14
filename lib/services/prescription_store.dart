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
class PrescriptionStore {
  final ClinicStore _clinic;

  final Map<String, List<PrescriptionRecord>> _records = {}; // patientId -> prescription records
  final Map<String, List<PrescriptionVersion>> _history = {}; // patientId -> doctor changes
  final Map<String, Set<String>> _access = {}; // patientId -> doctorIds with access
  final Map<String, List<DoseLog>> _doseLogs = {}; // patientId -> dose logs
  int _nextMedId = 1;
  int _nextTestId = 1;
  int _nextRecordId = 1;

  PrescriptionStore(this._clinic);

  // ---------- Access (patient) ----------

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

  List<String> patientsGrantingAccess(String doctorId) {
    return _access.entries
        .where((e) => e.value.contains(doctorId))
        .map((e) => e.key)
        .toList();
  }

  bool canView(String patientId, String viewerId) {
    return viewerId == patientId || hasAccess(patientId, viewerId);
  }

  // ---------- Reading ----------

  List<PrescriptionRecord> recordsFor(String patientId) {
    return List.unmodifiable(_records[patientId] ?? const <PrescriptionRecord>[]);
  }

  List<Medication> medicationsFor(String patientId) {
    final recs = _records[patientId] ?? const <PrescriptionRecord>[];
    final meds = <Medication>[];
    for (final r in recs) {
      if (!r.isExternal) {
        meds.addAll(r.medications);
      }
    }
    return List.unmodifiable(meds);
  }

  List<RecommendedTest> recommendedTestsFor(String patientId) {
    final recs = _records[patientId] ?? const <PrescriptionRecord>[];
    final tests = <RecommendedTest>[];
    for (final r in recs) {
      if (!r.isExternal) {
        tests.addAll(r.recommendedTests);
      }
    }
    return List.unmodifiable(tests);
  }

  List<PrescriptionRecord> externalPrescriptionsFor(String patientId) {
    final recs = _records[patientId] ?? const <PrescriptionRecord>[];
    return recs.where((r) => r.isExternal).toList();
  }

  List<PrescriptionRecord> doctorPrescriptionsFor(String patientId) {
    final recs = _records[patientId] ?? const <PrescriptionRecord>[];
    return recs.where((r) => !r.isExternal).toList();
  }

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

  PrescriptionRecord createPrescription({
    required String patientId,
    required String doctorId,
    required List<Medication> medications,
    required List<RecommendedTest> recommendedTests,
  }) {
    _requireDoctorEditAccess(patientId, doctorId);
    if (medications.isEmpty && recommendedTests.isEmpty) {
      throw PrescriptionException('A prescription must contain at least one medication or recommended test.');
    }

    final doctorName = _clinic.doctorById(doctorId)?.name ?? 'Doctor';

    final processedMeds = medications.map((m) => Medication(
      id: m.id.isEmpty ? 'med-${_nextMedId++}' : m.id,
      name: m.name.trim(),
      dose: m.dose.trim(),
      timesPerDay: m.timesPerDay,
      instructions: m.instructions.trim(),
      remainingDoses: m.remainingDoses,
    )).toList();

    final processedTests = recommendedTests.map((t) => RecommendedTest(
      id: t.id.isEmpty ? 'test-${_nextTestId++}' : t.id,
      name: t.name.trim(),
      instructions: t.instructions.trim(),
      status: 'Pending',
      recommendingDoctorId: doctorId,
      recommendingDoctorName: doctorName,
      recommendedAt: DateTime.now(),
    )).toList();

    final record = PrescriptionRecord(
      id: 'rec-${_nextRecordId++}',
      patientId: patientId,
      doctorId: doctorId,
      doctorName: doctorName,
      date: DateTime.now(),
      medications: processedMeds,
      recommendedTests: processedTests,
      isExternal: false,
    );

    _records.putIfAbsent(patientId, () => <PrescriptionRecord>[]).add(record);

    final summaryParts = <String>[];
    if (processedMeds.isNotEmpty) {
      summaryParts.add('${processedMeds.length} medicine(s)');
    }
    if (processedTests.isNotEmpty) {
      summaryParts.add('${processedTests.length} recommended test(s)');
    }
    _recordVersion(patientId, doctorId, 'Prescribed: ${summaryParts.join(', ')}');

    return record;
  }

  // Backward compatibility method
  Medication addMedication({
    required String patientId,
    required String doctorId,
    required String name,
    required String dose,
    required int timesPerDay,
    String instructions = '',
    required int remainingDoses,
  }) {
    final med = Medication(
      id: 'med-${_nextMedId++}',
      name: name.trim(),
      dose: dose.trim(),
      timesPerDay: timesPerDay,
      instructions: instructions.trim(),
      remainingDoses: remainingDoses,
    );
    createPrescription(
      patientId: patientId,
      doctorId: doctorId,
      medications: [med],
      recommendedTests: [],
    );
    return med;
  }

  void updateMedication({
    required String patientId,
    required String doctorId,
    required Medication updated,
  }) {
    _requireDoctorEditAccess(patientId, doctorId);
    final recs = _records[patientId];
    if (recs == null) return;

    bool found = false;
    for (final r in recs) {
      final index = r.medications.indexWhere((m) => m.id == updated.id);
      if (index != -1) {
        r.medications[index] = updated;
        found = true;
        break;
      }
    }
    if (!found) {
      throw PrescriptionException('Medication not found.');
    }
    _recordVersion(patientId, doctorId, 'Updated medication ${updated.name}');
  }

  void removeMedication({
    required String patientId,
    required String doctorId,
    required String medicationId,
  }) {
    _requireDoctorEditAccess(patientId, doctorId);
    final recs = _records[patientId];
    if (recs == null) return;

    for (final r in recs) {
      final index = r.medications.indexWhere((m) => m.id == medicationId);
      if (index != -1) {
        final removed = r.medications.removeAt(index);
        _recordVersion(patientId, doctorId, 'Removed ${removed.name}');
        return;
      }
    }
    throw PrescriptionException('Medication not found.');
  }

  // ---------- Patient Uploads (External Prescriptions & Test Results) ----------

  PrescriptionRecord uploadExternalPrescription({
    required String patientId,
    required String fileName,
    required String filePath,
  }) {
    if (fileName.trim().isEmpty) {
      throw PrescriptionException('Invalid file name.');
    }
    final record = PrescriptionRecord(
      id: 'ext-${_nextRecordId++}',
      patientId: patientId,
      date: DateTime.now(),
      isExternal: true,
      externalFileName: fileName.trim(),
      externalFilePath: filePath.trim(),
    );
    _records.putIfAbsent(patientId, () => <PrescriptionRecord>[]).add(record);
    return record;
  }

  void removeExternalPrescription({
    required String patientId,
    required String recordId,
  }) {
    final list = _records[patientId];
    if (list == null) return;
    list.removeWhere((r) => r.id == recordId && r.isExternal);
  }

  void uploadTestResult({
    required String patientId,
    required String testId,
    required String fileName,
    required String filePath,
  }) {
    final recs = _records[patientId];
    if (recs == null) {
      throw PrescriptionException('Prescription record not found.');
    }

    bool updated = false;
    for (final r in recs) {
      final tIndex = r.recommendedTests.indexWhere((t) => t.id == testId);
      if (tIndex != -1) {
        final test = r.recommendedTests[tIndex];
        r.recommendedTests[tIndex] = test.copyWith(
          status: 'Result Uploaded',
          uploadedFileName: fileName.trim(),
          uploadedFilePath: filePath.trim(),
          uploadedAt: DateTime.now(),
        );
        updated = true;
        break;
      }
    }
    if (!updated) {
      throw PrescriptionException('Recommended test not found.');
    }
  }

  // ---------- Dose logging (patient) ----------

  void logDose({
    required String patientId,
    required String medicationId,
    required bool taken,
  }) {
    final recs = _records[patientId] ?? [];
    bool found = false;
    for (final r in recs) {
      final mIndex = r.medications.indexWhere((m) => m.id == medicationId);
      if (mIndex != -1) {
        final current = r.medications[mIndex];
        if (taken) {
          if (current.remainingDoses <= 0) {
            throw PrescriptionException('No doses left to take.');
          }
          r.medications[mIndex] = current.copyWith(
            remainingDoses: current.remainingDoses - 1,
          );
        }
        found = true;
        break;
      }
    }

    if (!found) {
      throw PrescriptionException('Medication not found.');
    }

    _doseLogs.putIfAbsent(patientId, () => <DoseLog>[]).add(
          DoseLog(medicationId: medicationId, at: DateTime.now(), taken: taken),
        );
  }
}

final PrescriptionStore prescriptionStore = PrescriptionStore(clinicStore);
