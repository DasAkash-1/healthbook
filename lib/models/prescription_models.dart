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
