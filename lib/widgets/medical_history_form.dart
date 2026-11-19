import 'package:flutter/material.dart';

import '../models/medical_history.dart';

// Holds the text controllers for the medical history fields so parent screens
// can populate, read, and dispose them cleanly.
class MedicalHistoryControllers {
  final allergies = TextEditingController();
  final conditions = TextEditingController();
  final surgeries = TextEditingController();
  final medicines = TextEditingController();

  // Populates all controllers from an existing [MedicalHistory] record.
  void fill(MedicalHistory h) {
    allergies.text = h.allergies;
    conditions.text = h.conditions;
    surgeries.text = h.surgeries;
    medicines.text = h.currentMedicines;
  }

  // Builds a trimmed [MedicalHistory] snapshot stamped with the current time.
  MedicalHistory toHistory() {
    return MedicalHistory(
      allergies: allergies.text.trim(),
      conditions: conditions.text.trim(),
      surgeries: surgeries.text.trim(),
      currentMedicines: medicines.text.trim(),
      updatedAt: DateTime.now(),
    );
  }

  void dispose() {
    allergies.dispose();
    conditions.dispose();
    surgeries.dispose();
    medicines.dispose();
  }
}

// Reusable form (or read-only viewer when [readOnly] is true) for patient medical history.
class MedicalHistoryFields extends StatelessWidget {
  final MedicalHistoryControllers controllers;
  final bool readOnly;

  const MedicalHistoryFields({
    super.key,
    required this.controllers,
    this.readOnly = false,
  });

  // Helper that styles each multi-line medical history input consistently.
  Widget _field(TextEditingController c, String label, String hint) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: c,
        readOnly: readOnly,
        maxLines: 2,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          filled: true,
          fillColor: Colors.grey.shade100,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _field(
          controllers.allergies,
          'Allergies (required)',
          'Medicines, foods, or other. Write "None" if none.',
        ),
        _field(controllers.conditions, 'Long-term conditions', 'For example, asthma'),
        _field(controllers.surgeries, 'Past surgeries', 'Type and year, if any'),
        _field(controllers.medicines, 'Current medicines', 'Anything you take regularly'),
      ],
    );
  }
}
