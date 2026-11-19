import 'package:flutter/material.dart';

import '../utils/allergy_check.dart';
import '../utils/app_colors.dart';

// Shown to a doctor before saving a medicine that looks like something the patient
// is allergic to. Returns true only if the doctor chooses to prescribe anyway.
Future<bool> confirmDespiteAllergies(
  BuildContext context,
  List<AllergyWarning> warnings,
) async {
  // Displays matched medicine/allergy pairs and requires an explicit choice.
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Possible allergy'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "The patient's medical history lists an allergy that looks like:",
            ),
            const SizedBox(height: 8),
            // List each medicine alongside the matching allergy entries from history.
            for (final w in warnings)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: w.medicine,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      TextSpan(text: '  (history says: ${w.allergies.join(', ')})'),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 8),
            const Text(
              'This is a text match only and can miss related medicines. '
              'Check the full medical history before prescribing.',
              style: TextStyle(fontSize: 14, color: kTextMuted),
            ),
          ],
        ),
      ),
      actions: [
        // Safe default: return false when going back or dismissing.
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Go back'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text(
            'Prescribe anyway',
            style: TextStyle(color: kTextDanger),
          ),
        ),
      ],
    ),
  );
  return result ?? false;
}
