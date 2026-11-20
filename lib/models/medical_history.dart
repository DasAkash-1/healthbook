// Patient-owned medical background record used for clinical context, allergy checks, and emergency medical card.
class MedicalHistory {
  final String allergies; // required field; patients write "None" if none exist
  final String conditions;
  final String surgeries;
  final String currentMedicines;
  final DateTime updatedAt;
  final String bloodGroup;
  final String emergencyContactName;
  final String emergencyContactRelationship;
  final String emergencyContactPhone;
  final double? heightCm;
  final double? weightKg;

  const MedicalHistory({
    required this.allergies,
    this.conditions = '',
    this.surgeries = '',
    this.currentMedicines = '',
    required this.updatedAt,
    this.bloodGroup = '',
    this.emergencyContactName = '',
    this.emergencyContactRelationship = '',
    this.emergencyContactPhone = '',
    this.heightCm,
    this.weightKg,
  });

  MedicalHistory copyWith({
    String? allergies,
    String? conditions,
    String? surgeries,
    String? currentMedicines,
    DateTime? updatedAt,
    String? bloodGroup,
    String? emergencyContactName,
    String? emergencyContactRelationship,
    String? emergencyContactPhone,
    double? heightCm,
    double? weightKg,
  }) {
    return MedicalHistory(
      allergies: allergies ?? this.allergies,
      conditions: conditions ?? this.conditions,
      surgeries: surgeries ?? this.surgeries,
      currentMedicines: currentMedicines ?? this.currentMedicines,
      updatedAt: updatedAt ?? this.updatedAt,
      bloodGroup: bloodGroup ?? this.bloodGroup,
      emergencyContactName: emergencyContactName ?? this.emergencyContactName,
      emergencyContactRelationship: emergencyContactRelationship ?? this.emergencyContactRelationship,
      emergencyContactPhone: emergencyContactPhone ?? this.emergencyContactPhone,
      heightCm: heightCm ?? this.heightCm,
      weightKg: weightKg ?? this.weightKg,
    );
  }
}
