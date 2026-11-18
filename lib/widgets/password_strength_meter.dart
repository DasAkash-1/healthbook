import 'package:flutter/material.dart';

import '../utils/app_colors.dart';
import '../utils/password_strength.dart';

// A bar under the password field that fills up and goes from red to green as the
// password gets stronger, with a label and one tip. Shows nothing until the person
// starts typing.
class PasswordStrengthMeter extends StatelessWidget {
  final String password;
  final String email; // used to catch passwords built from the email name

  const PasswordStrengthMeter({
    super.key,
    required this.password,
    this.email = '',
  });

  // The bar colour, and a darker version of it for text on white.
  static Color _barColor(PasswordStrength level) {
    switch (level) {
      case PasswordStrength.weak:
        return const Color(0xFFD32F2F);
      case PasswordStrength.fair:
        return const Color(0xFFF57C00);
      case PasswordStrength.good:
        return const Color(0xFF7CB342);
      default:
        return const Color(0xFF2E7D32);
    }
  }

  static Color _textColor(PasswordStrength level) {
    switch (level) {
      case PasswordStrength.weak:
        return kTextDanger;
      case PasswordStrength.fair:
        return kTextWarning;
      case PasswordStrength.good:
        return const Color(0xFF33691E);
      default:
        return kTextSuccess;
    }
  }

  @override
  Widget build(BuildContext context) {
    final result = checkPasswordStrength(password, email: email);
    // Keeps the spacing the same before the person starts typing.
    if (result.level == PasswordStrength.empty) return const SizedBox(height: 8);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween<double>(end: result.fraction),
            duration: const Duration(milliseconds: 250),
            builder: (context, value, _) => ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: value,
                minHeight: 8,
                color: _barColor(result.level),
                backgroundColor: Colors.grey.shade300,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Text(
                'Password strength: ',
                style: TextStyle(fontSize: 14, color: kTextMuted),
              ),
              Text(
                result.label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: _textColor(result.level),
                ),
              ),
            ],
          ),
          if (result.tip != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                result.tip!,
                style: const TextStyle(fontSize: 14, color: kTextMuted),
              ),
            ),
        ],
      ),
    );
  }
}
