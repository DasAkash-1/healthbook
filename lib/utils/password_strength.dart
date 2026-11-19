// Password strength evaluator used by PasswordStrengthMeter during sign-up.
enum PasswordStrength { empty, weak, fair, good, strong }

// Output model describing the rating level, UI label, progress bar fill, and optional tip.
class PasswordStrengthResult {
  final PasswordStrength level;
  final String label; // Weak, Fair, Good or Strong ('' when empty)
  final double fraction; // how full the bar is, from 0 to 1
  final String? tip; // one thing the person can do to make it stronger

  const PasswordStrengthResult({
    required this.level,
    required this.label,
    required this.fraction,
    this.tip,
  });
}

// Common passwords and domain/location words checked in lowercase to catch easy guesses.
const Set<String> _commonPasswords = {
  'password',
  '123456',
  '1234567',
  '12345678',
  '123456789',
  '1234567890',
  'qwerty',
  'qwerty123',
  'qwertyuiop',
  'abc123',
  'abcd1234',
  'abcdefgh',
  '111111',
  '000000',
  '123123',
  '1q2w3e4r',
  '1qaz2wsx',
  'zaq12wsx',
  'iloveyou',
  'letmein',
  'welcome',
  'admin',
  'administrator',
  'login',
  'monkey',
  'dragon',
  'football',
  'baseball',
  'cricket',
  'sunshine',
  'princess',
  'master',
  'hello',
  'freedom',
  'whatever',
  'trustno1',
  'secret',
  'shadow',
  'superman',
  'batman',
  'changeme',
  'test1234',
  'demo1234',
  'bangladesh',
  'dhaka',
  'sylhet',
  'healthbook',
  'doctor',
  'patient',
  'hospital',
  'clinic',
  'medicine',
};

// Standard QWERTY keyboard rows used to detect adjacent key runs.
const List<String> _keyboardRows = ['qwertyuiop', 'asdfghjkl', 'zxcvbnm'];

// Common leetspeak substitutions mapped back to letters before checking common words.
const Map<String, String> _lookalikes = {
  '0': 'o',
  '1': 'i',
  '3': 'e',
  '4': 'a',
  '5': 's',
  '7': 't',
  '@': 'a',
  '\$': 's',
  '!': 'i',
};

bool _isAlphanumeric(int code) =>
    (code >= 48 && code <= 57) || (code >= 97 && code <= 122);

// "Password1", "p@ssw0rd!" and "password" are all the same guess.
bool _isCommon(String lower) {
  if (_commonPasswords.contains(lower)) return true;
  final withoutEnding = lower.replaceAll(RegExp(r'[^a-z]+$'), '');
  final core = withoutEnding.split('').map((c) => _lookalikes[c] ?? c).join();
  return core.length >= 4 && _commonPasswords.contains(core);
}

// Four characters in a row that count up or down (1234, abcd, 4321), or sit side by
// side on a keyboard row (qwer, asdf).
bool _hasSequence(String lower) {
  var run = 1;
  var direction = 0;
  for (var i = 1; i < lower.length; i++) {
    final a = lower.codeUnitAt(i - 1);
    final b = lower.codeUnitAt(i);
    final step = b - a;
    if (_isAlphanumeric(a) && _isAlphanumeric(b) && (step == 1 || step == -1)) {
      run = step == direction ? run + 1 : 2;
      direction = step;
    } else {
      run = 1;
      direction = 0;
    }
    if (run >= 4) return true;
  }

  for (final row in _keyboardRows) {
    for (var i = 0; i + 4 <= row.length; i++) {
      final chunk = row.substring(i, i + 4);
      final backwards = chunk.split('').reversed.join();
      if (lower.contains(chunk) || lower.contains(backwards)) return true;
    }
  }
  return false;
}

// Awards progressive points for longer passwords (minimum 8 chars required for points).
int _lengthPoints(int length) {
  if (length < 8) return 0;
  if (length < 10) return 1;
  if (length < 12) return 2;
  if (length < 14) return 3;
  if (length < 16) return 4;
  if (length < 20) return 5;
  return 6;
}

// Rates a password from weak to strong for the meter on the sign-up screen.
//
// This is a rule of thumb, not a guarantee. Length counts most, then a mix of lower
// case letters, upper case letters, numbers and symbols. Very common passwords,
// repeated characters, runs like 1234, and passwords built from the person's own
// email name are marked down. Passing this check does not make a password safe to
// reuse on other sites.
PasswordStrengthResult checkPasswordStrength(String password, {String email = ''}) {
  if (password.isEmpty) {
    return const PasswordStrengthResult(
      level: PasswordStrength.empty,
      label: '',
      fraction: 0,
    );
  }

  final lower = password.toLowerCase();
  final length = password.length;

  final hasLower = RegExp(r'[a-z]').hasMatch(password);
  final hasUpper = RegExp(r'[A-Z]').hasMatch(password);
  final hasDigit = RegExp(r'[0-9]').hasMatch(password);
  final hasOther = RegExp(r'[^A-Za-z0-9]').hasMatch(password);
  final variety = [hasLower, hasUpper, hasDigit, hasOther].where((x) => x).length;

  final tooShort = length < 8;
  final common = _isCommon(lower);
  final repeats = password.runes.toSet().length <= 3;
  final sequence = _hasSequence(lower);
  final emailName = email.split('@').first.trim().toLowerCase();
  final usesEmail = emailName.length >= 3 && lower.contains(emailName);

  PasswordStrength level;
  if (tooShort || common || repeats) {
    level = PasswordStrength.weak;
  } else {
    var score = _lengthPoints(length) + variety;
    if (sequence) score -= 1;
    if (usesEmail) score -= 2;
    if (score <= 3) {
      level = PasswordStrength.weak;
    } else if (score <= 5) {
      level = PasswordStrength.fair;
    } else if (score <= 7) {
      level = PasswordStrength.good;
    } else {
      level = PasswordStrength.strong;
    }
  }

  // Pick the highest-priority single tip to help the user strengthen their password.
  String? tip;
  if (tooShort) {
    tip = 'Make it longer. Use at least 8 characters.';
  } else if (common) {
    tip = 'This is a very common password. Choose something harder to guess.';
  } else if (repeats) {
    tip = 'Avoid repeating the same few characters.';
  } else if (usesEmail) {
    tip = 'Do not use your email name in your password.';
  } else if (sequence) {
    tip = 'Avoid runs like 1234 or abcd.';
  } else if (level != PasswordStrength.strong) {
    if (length < 12) {
      tip = 'Longer is stronger. Try 12 or more characters.';
    } else if (variety < 3) {
      tip = 'Mix upper and lower case letters, numbers and symbols.';
    } else {
      tip = 'Add a few more characters to make it stronger.';
    }
  }

  switch (level) {
    case PasswordStrength.weak:
      return PasswordStrengthResult(
        level: level,
        label: 'Weak',
        fraction: 0.25,
        tip: tip,
      );
    case PasswordStrength.fair:
      return PasswordStrengthResult(
        level: level,
        label: 'Fair',
        fraction: 0.5,
        tip: tip,
      );
    case PasswordStrength.good:
      return PasswordStrengthResult(
        level: level,
        label: 'Good',
        fraction: 0.75,
        tip: tip,
      );
    default:
      return PasswordStrengthResult(
        level: level,
        label: 'Strong',
        fraction: 1,
        tip: tip,
      );
  }
}
