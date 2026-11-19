import '../models/checkup_report.dart';
import 'clinic_store.dart';
import 'prescription_store.dart';

// Domain error thrown when checkup report permissions, verification, or inputs fail.
class CheckupReportException implements Exception {
  final String message;
  CheckupReportException(this.message);

  @override
  String toString() => message;
}

// Reasonable clinical bounds for optional vitals so typos are caught early.
const int kMinHeartRateBpm = 20;
const int kMaxHeartRateBpm = 250;
const double kMinTemperatureC = 30.0;
const double kMaxTemperatureC = 45.0;
const double kMinWeightKg = 1.0;
const double kMaxWeightKg = 350.0;

// In-memory store for doctor-authored checkup reports.
// Mirrors the access and verification rules of PrescriptionStore so that:
// 1. Only a verified doctor with active patient access can write a report.
// 2. Only the patient or a doctor with access can read a patient's reports.
//
// TODO(backend): move storage to cloud database and enforce verification + access
// checks server-side.
class CheckupReportStore {
  final ClinicStore _clinic;
  final PrescriptionStore _prescriptions;
  final DateTime Function() _clock;

  // Maps patientId -> list of checkup reports for that patient.
  final Map<String, List<CheckupReport>> _reportsByPatient = {};
  int _nextId = 1;

  CheckupReportStore(
    this._clinic,
    this._prescriptions, {
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  DateTime _now() => _clock();

  // Returns true if [viewerId] is the patient themselves or a doctor with access.
  bool canView(String patientId, String viewerId) {
    if (viewerId.isEmpty) return false;
    return viewerId == patientId || _prescriptions.hasAccess(patientId, viewerId);
  }

  // Returns all checkup reports for [patientId] sorted newest-first.
  // Throws CheckupReportException if [viewerId] is not allowed to view them.
  List<CheckupReport> reportsFor(String patientId, String viewerId) {
    if (!canView(patientId, viewerId)) {
      throw CheckupReportException(
        'You do not have permission to view these checkup reports.',
      );
    }
    final list = List<CheckupReport>.from(
      _reportsByPatient[patientId] ?? const <CheckupReport>[],
    )..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return List.unmodifiable(list);
  }

  // Validates and stores a new checkup report created by [doctorId] for [patientId].
  CheckupReport createReport({
    required String patientId,
    required String doctorId,
    required String chiefComplaintOrDiagnosis,
    String bloodPressure = '',
    int? heartRateBpm,
    double? temperatureC,
    double? weightKg,
    String clinicalNotes = '',
    String followUpAdvice = '',
  }) {
    // Enforce clinical trust rules: doctor must be verified and have patient access.
    if (!_clinic.isVerified(doctorId)) {
      throw CheckupReportException(
        'Only verified doctors can create checkup reports.',
      );
    }
    if (!_prescriptions.hasAccess(patientId, doctorId)) {
      throw CheckupReportException(
        'This patient has not granted you access.',
      );
    }

    final diagnosis = chiefComplaintOrDiagnosis.trim();
    if (diagnosis.isEmpty) {
      throw CheckupReportException(
        'Enter the diagnosis or main checkup findings.',
      );
    }

    // Validate optional vitals only when provided.
    if (heartRateBpm != null &&
        (heartRateBpm < kMinHeartRateBpm || heartRateBpm > kMaxHeartRateBpm)) {
      throw CheckupReportException(
        'Heart rate must be between $kMinHeartRateBpm and $kMaxHeartRateBpm bpm.',
      );
    }
    if (temperatureC != null &&
        (temperatureC < kMinTemperatureC || temperatureC > kMaxTemperatureC)) {
      throw CheckupReportException(
        'Temperature must be between $kMinTemperatureC and $kMaxTemperatureC C.',
      );
    }
    if (weightKg != null &&
        (weightKg < kMinWeightKg || weightKg > kMaxWeightKg)) {
      throw CheckupReportException(
        'Weight must be between $kMinWeightKg and $kMaxWeightKg kg.',
      );
    }

    final doctor = _clinic.doctorById(doctorId);
    final report = CheckupReport(
      id: 'report-${_nextId++}',
      patientId: patientId,
      doctorId: doctorId,
      doctorName: doctor?.name ?? 'Doctor',
      specialty: doctor?.specialty ?? 'General Practice',
      createdAt: _now(),
      bloodPressure: bloodPressure.trim(),
      heartRateBpm: heartRateBpm,
      temperatureC: temperatureC,
      weightKg: weightKg,
      chiefComplaintOrDiagnosis: diagnosis,
      clinicalNotes: clinicalNotes.trim(),
      followUpAdvice: followUpAdvice.trim(),
    );

    _reportsByPatient
        .putIfAbsent(patientId, () => <CheckupReport>[])
        .add(report);
    return report;
  }
}

// App-wide singleton store wired to ClinicStore and PrescriptionStore.
final CheckupReportStore checkupReportStore = CheckupReportStore(
  clinicStore,
  prescriptionStore,
);
