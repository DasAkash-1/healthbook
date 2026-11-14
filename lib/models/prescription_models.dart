class Medication {
  final String id;
  final String name;
  final String dose;
  final int timesPerDay;
  final String instructions;
  final int remainingDoses;

  const Medication({
    required this.id,
    required this.name,
    required this.dose,
    required this.timesPerDay,
    this.instructions = '',
    required this.remainingDoses,
  });

  Medication copyWith({
    String? name,
    String? dose,
    int? timesPerDay,
    String? instructions,
    int? remainingDoses,
  }) {
    return Medication(
      id: id,
      name: name ?? this.name,
      dose: dose ?? this.dose,
      timesPerDay: timesPerDay ?? this.timesPerDay,
      instructions: instructions ?? this.instructions,
      remainingDoses: remainingDoses ?? this.remainingDoses,
    );
  }
}

class RecommendedTest {
  final String id;
  final String name;
  final String instructions;
  final String status; // 'Pending', 'Result Uploaded'
  final String? uploadedFilePath;
  final String? uploadedFileName;
  final DateTime? uploadedAt;
  final String recommendingDoctorId;
  final String recommendingDoctorName;
  final DateTime recommendedAt;

  const RecommendedTest({
    required this.id,
    required this.name,
    this.instructions = '',
    this.status = 'Pending',
    this.uploadedFilePath,
    this.uploadedFileName,
    this.uploadedAt,
    required this.recommendingDoctorId,
    required this.recommendingDoctorName,
    required this.recommendedAt,
  });

  RecommendedTest copyWith({
    String? status,
    String? uploadedFilePath,
    String? uploadedFileName,
    DateTime? uploadedAt,
  }) {
    return RecommendedTest(
      id: id,
      name: name,
      instructions: instructions,
      status: status ?? this.status,
      uploadedFilePath: uploadedFilePath ?? this.uploadedFilePath,
      uploadedFileName: uploadedFileName ?? this.uploadedFileName,
      uploadedAt: uploadedAt ?? this.uploadedAt,
      recommendingDoctorId: recommendingDoctorId,
      recommendingDoctorName: recommendingDoctorName,
      recommendedAt: recommendedAt,
    );
  }
}

class PrescriptionRecord {
  final String id;
  final String patientId;
  final String? doctorId;
  final String? doctorName;
  final DateTime date;
  final List<Medication> medications;
  final List<RecommendedTest> recommendedTests;
  final bool isExternal;
  final String? externalFileName;
  final String? externalFilePath;

  const PrescriptionRecord({
    required this.id,
    required this.patientId,
    this.doctorId,
    this.doctorName,
    required this.date,
    this.medications = const [],
    this.recommendedTests = const [],
    this.isExternal = false,
    this.externalFileName,
    this.externalFilePath,
  });
}

// One entry in a prescription's history. Only doctor changes are recorded here.
class PrescriptionVersion {
  final int number;
  final DateTime at;
  final String byName;
  final String summary;

  const PrescriptionVersion({
    required this.number,
    required this.at,
    required this.byName,
    required this.summary,
  });
}

// A dose the patient logged as taken or missed. Kept separately from the history.
class DoseLog {
  final String medicationId;
  final DateTime at;
  final bool taken;

  const DoseLog({required this.medicationId, required this.at, required this.taken});
}
