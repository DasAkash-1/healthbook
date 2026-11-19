// Patient-owned medical background record used for clinical context and allergy checks.
class MedicalHistory {
  final String allergies; // required field; patients write "None" if none exist
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
