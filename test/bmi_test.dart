import 'package:flutter_test/flutter_test.dart';
import 'package:healthbook_test/utils/bmi.dart';

void main() {
  group('calculateBmi', () {
    test('healthy weight', () {
      final r = calculateBmi(heightCm: 170, weightKg: 70);
      expect(r.category, BmiCategory.normal);
      expect(r.value, closeTo(24.2, 0.1));
    });

    test('underweight', () {
      expect(calculateBmi(heightCm: 160, weightKg: 40).category,
          BmiCategory.underweight);
    });

    test('overweight', () {
      expect(calculateBmi(heightCm: 175, weightKg: 80).category,
          BmiCategory.overweight);
    });

    test('obese', () {
      expect(calculateBmi(heightCm: 180, weightKg: 100).category,
          BmiCategory.obese);
    });

    test('boundary 18.5 counts as healthy weight', () {
      // 1.70 m, 18.5 * 1.70^2 = 53.465 kg
      expect(calculateBmi(heightCm: 170, weightKg: 53.5).category,
          BmiCategory.normal);
    });
  });

  group('validation', () {
    test('height must be between 50 and 250 cm', () {
      expect(validateHeightCm(null), isNotNull);
      expect(validateHeightCm(40), isNotNull);
      expect(validateHeightCm(300), isNotNull);
      expect(validateHeightCm(170), isNull);
    });

    test('weight must be between 2 and 300 kg', () {
      expect(validateWeightKg(null), isNotNull);
      expect(validateWeightKg(1), isNotNull);
      expect(validateWeightKg(400), isNotNull);
      expect(validateWeightKg(70), isNull);
    });
  });
}
