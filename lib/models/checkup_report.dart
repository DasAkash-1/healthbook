// Model representing a clinical checkup report written by a doctor for a patient.
// Patients (and authorized doctors) view these read-only; only a verified doctor
// who currently holds patient access can create a report.
class CheckupReport {
  final String id;
  final String patientId;
  final String doctorId;
  final String doctorName;
  final String specialty;
  final DateTime createdAt;

  // Optional vitals recorded during the consultation.
  final String bloodPressure;
  final int? heartRateBpm;
  final double? temperatureC;
  final double? weightKg;

  // Required summary of the visit findings or diagnosis.
  final String chiefComplaintOrDiagnosis;

  // Optional extra observations and follow-up instructions.
  final String clinicalNotes;
  final String followUpAdvice;

  const CheckupReport({
    required this.id,
    required this.patientId,
    required this.doctorId,
    required this.doctorName,
    required this.specialty,
    required this.createdAt,
    this.bloodPressure = '',
    this.heartRateBpm,
    this.temperatureC,
    this.weightKg,
    required this.chiefComplaintOrDiagnosis,
    this.clinicalNotes = '',
    this.followUpAdvice = '',
  });
}
