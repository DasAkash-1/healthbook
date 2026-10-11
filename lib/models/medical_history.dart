class MedicalHistory {
  final String allergies; // required, write "None" if none
  final String conditions;
  final String surgeries;
  final String currentMedicines;
  final DateTime updatedAt;

  const MedicalHistory({
    required this.allergies,
    this.conditions = '',
    this.surgeries = '',
    this.currentMedicines = '',
    required this.updatedAt,
  });
}
