enum BmiCategory { underweight, normal, overweight, obese }

class BmiResult {
  final double value;
  final BmiCategory category;

  const BmiResult({required this.value, required this.category});

  String get categoryLabel => switch (category) {
        BmiCategory.underweight => 'Underweight',
        BmiCategory.normal => 'Healthy weight',
        BmiCategory.overweight => 'Overweight',
        BmiCategory.obese => 'Obese',
      };
}

// Returns an error message, or null if the height is valid.
String? validateHeightCm(double? cm) {
  if (cm == null) return 'Enter your height in cm.';
  if (cm < 50 || cm > 250) return 'Height should be between 50 and 250 cm.';
  return null;
}

// Returns an error message, or null if the weight is valid.
String? validateWeightKg(double? kg) {
  if (kg == null) return 'Enter your weight in kg.';
  if (kg < 2 || kg > 300) return 'Weight should be between 2 and 300 kg.';
  return null;
}

// BMI = weight (kg) / height (m)^2, using the WHO adult categories.
BmiResult calculateBmi({required double heightCm, required double weightKg}) {
  final heightM = heightCm / 100;
  final value = weightKg / (heightM * heightM);

  final BmiCategory category;
  if (value < 18.5) {
    category = BmiCategory.underweight;
  } else if (value < 25) {
    category = BmiCategory.normal;
  } else if (value < 30) {
    category = BmiCategory.overweight;
  } else {
    category = BmiCategory.obese;
  }

  return BmiResult(value: value, category: category);
}
