import '../models/app_models.dart';
import '../models/prescription_models.dart';
import 'clinic_store.dart';

class PrescriptionException implements Exception {
  final String message;
  PrescriptionException(this.message);

  @override
  String toString() => message;
}

// Limits for one medication. The backend should enforce the same limits.
const int kMinTimesPerDay = 1;
const int kMaxTimesPerDay = 4;

// Pairs a medication with the prescription record that issued it.
class PrescribedMedicationEntry {
  final Medication medication;
  final String? doctorName;
  final DateTime prescribedDate;

  const PrescribedMedicationEntry({
    required this.medication,
    required this.doctorName,
    required this.prescribedDate,
  });
}

// In-memory prescriptions. Replace with a Firebase version later, keeping the same methods.
//
// TODO(backend): every method below that reads or changes the maps should become a
// database call. Keep the method names, the arguments and the PrescriptionException
// messages the same, so no screen has to change. The access and verification rules in
// this file must also be enforced on the server, not only here.
class PrescriptionStore {
  final ClinicStore _clinic;
  final DateTime Function() _clock;

  final Map<String, List<PrescriptionRecord>> _records = {}; // patientId -> prescription records
  final Map<String, List<PrescriptionVersion>> _history = {}; // patientId -> doctor changes
  final Map<String, Set<String>> _access = {}; // patientId -> doctorIds with access
  final Map<String, List<DoseLog>> _doseLogs = {}; // patientId -> dose logs
  int _nextMedId = 1;
  int _nextTestId = 1;
  int _nextRecordId = 1;

  PrescriptionStore(this._clinic, {DateTime Function()? clock})
      : _clock = clock ?? DateTime.now;

  DateTime _now() => _clock();

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

  // TODO(backend): save the access grant in the database.
  void grantAccess(String patientId, String doctorId) {
    if (!eligibleDoctorIds(patientId).contains(doctorId)) {
      throw PrescriptionException(
        'You can only grant access to a doctor you have an approved appointment with.',
      );
    }
    _access.putIfAbsent(patientId, () => <String>{}).add(doctorId);
  }

  // TODO(backend): remove the access grant from the database.
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

  List<PrescribedMedicationEntry> prescribedMedicationsFor(String patientId) {
    final recs = _records[patientId] ?? const <PrescriptionRecord>[];
    final entries = <PrescribedMedicationEntry>[];
    for (final r in recs) {
      if (!r.isExternal) {
        for (final m in r.medications) {
          entries.add(PrescribedMedicationEntry(
            medication: m,
            doctorName: r.doctorName,
            prescribedDate: r.date,
          ));
        }
      }
    }
    return List.unmodifiable(entries);
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
        at: _now(),
        byName: _clinic.doctorById(doctorId)?.name ?? 'Doctor',
        summary: summary,
      ),
    );
  }

  // Checks one medication's fields. Used for new prescriptions and for edits.
  void _validateMedication(Medication m) {
    if (m.name.trim().isEmpty) {
      throw PrescriptionException('Enter the medicine name.');
    }
    if (m.dose.trim().isEmpty) {
      throw PrescriptionException('Enter the dose.');
    }
    if (m.timesPerDay < kMinTimesPerDay || m.timesPerDay > kMaxTimesPerDay) {
      throw PrescriptionException(
        'Times per day must be between $kMinTimesPerDay and $kMaxTimesPerDay.',
      );
    }
    if (m.remainingDoses < 0) {
      throw PrescriptionException('Doses left cannot be negative.');
    }
  }

  void _validateRecommendedTest(RecommendedTest t) {
    if (t.name.trim().isEmpty) {
      throw PrescriptionException('Enter the test name.');
    }
  }

  // TODO(backend): save the record and its history entry together in one database write.
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
    for (final m in medications) {
      _validateMedication(m);
    }
    for (final t in recommendedTests) {
      _validateRecommendedTest(t);
    }

    final doctorName = _clinic.doctorById(doctorId)?.name ?? 'Doctor';
    final now = _now();

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
      recommendedAt: now,
    )).toList();

    final record = PrescriptionRecord(
      id: 'rec-${_nextRecordId++}',
      patientId: patientId,
      doctorId: doctorId,
      doctorName: doctorName,
      date: now,
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

  // TODO(backend): update the medication and add the history entry in one database write.
  void updateMedication({
    required String patientId,
    required String doctorId,
    required Medication updated,
  }) {
    _requireDoctorEditAccess(patientId, doctorId);
    _validateMedication(updated);
    final recs = _records[patientId];
    if (recs == null) {
      throw PrescriptionException('Medication not found.');
    }

    final cleaned = Medication(
      id: updated.id,
      name: updated.name.trim(),
      dose: updated.dose.trim(),
      timesPerDay: updated.timesPerDay,
      instructions: updated.instructions.trim(),
      remainingDoses: updated.remainingDoses,
    );

    bool found = false;
    for (final r in recs) {
      final index = r.medications.indexWhere((m) => m.id == cleaned.id);
      if (index != -1) {
        r.medications[index] = cleaned;
        found = true;
        break;
      }
    }
    if (!found) {
      throw PrescriptionException('Medication not found.');
    }
    _recordVersion(patientId, doctorId, 'Updated medication ${cleaned.name}');
  }

  // TODO(backend): delete the medication and add the history entry in one database write.
  void removeMedication({
    required String patientId,
    required String doctorId,
    required String medicationId,
  }) {
    _requireDoctorEditAccess(patientId, doctorId);
    final recs = _records[patientId];
    if (recs == null) {
      throw PrescriptionException('Medication not found.');
    }

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

  // TODO(backend): upload the PDF to file storage and keep its storage link here instead of a phone file path.
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
      date: _now(),
      isExternal: true,
      externalFileName: fileName.trim(),
      externalFilePath: filePath.trim(),
    );
    _records.putIfAbsent(patientId, () => <PrescriptionRecord>[]).add(record);
    return record;
  }

  // TODO(backend): delete the record and its stored file.
  void removeExternalPrescription({
    required String patientId,
    required String recordId,
  }) {
    final list = _records[patientId];
    if (list == null) return;
    list.removeWhere((r) => r.id == recordId && r.isExternal);
  }

  // TODO(backend): upload the file to file storage and keep its storage link here instead of a phone file path.
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
          uploadedAt: _now(),
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

  // TODO(backend): save the new dose count and the dose log together in one database write.
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
          DoseLog(medicationId: medicationId, at: _now(), taken: taken),
        );
  }
}

final PrescriptionStore prescriptionStore = PrescriptionStore(clinicStore);
