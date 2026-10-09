class Validators {
  Validators._(); // not meant to be instantiated

  static const int minimumAge = 13;

  static String? email(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Email is required';
    final regex = RegExp(r'^[\w.+-]+@[\w-]+\.[\w.-]+$');
    if (!regex.hasMatch(text)) return 'Enter a valid email address';
    return null;
  }

  static String? password(String? value) {
    final text = value ?? '';
    if (text.isEmpty) return 'Password is required';
    if (text.length < 8) return 'Use at least 8 characters';
    if (!RegExp(r'[A-Z]').hasMatch(text)) return 'Include an uppercase letter';
    if (!RegExp(r'[a-z]').hasMatch(text)) return 'Include a lowercase letter';
    if (!RegExp(r'[0-9]').hasMatch(text)) return 'Include a number';
    return null;
  }

  static String? confirmPassword(String? value, String original) {
    if (value == null || value.isEmpty) return 'Please confirm your password';
    if (value != original) return 'Passwords do not match';
    return null;
  }

  static String? name(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Name is required';
    if (text.length < 2) return 'Name is too short';
    if (!RegExp(r"^[\p{L}\s.'-]+$", unicode: true).hasMatch(text)) {
      return 'Name can only contain letters';
    }
    return null;
  }

  static String? phone(String? value) {
    // Spaces and dashes are removed so "017 1234-5678" is accepted.
    final text = (value ?? '').replaceAll(RegExp(r'[\s-]'), '');
    if (text.isEmpty) return 'Phone number is required';
    if (!RegExp(r'^\+?\d{10,15}$').hasMatch(text)) {
      return 'Enter a valid phone number';
    }
    return null;
  }

  static String? dateOfBirth(DateTime? dob) {
    if (dob == null) return 'Date of birth is required';
    final today = DateTime.now();
    if (dob.isAfter(today)) return 'Date cannot be in the future';

    var age = today.year - dob.year;
    final hadBirthdayThisYear =
        today.month > dob.month ||
        (today.month == dob.month && today.day >= dob.day);
    if (!hadBirthdayThisYear) age--;

    if (age < minimumAge) {
      return 'You must be at least $minimumAge years old';
    }
    return null;
  }
}
