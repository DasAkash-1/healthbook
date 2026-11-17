import 'package:flutter_test/flutter_test.dart';

import 'package:healthbook_test/utils/password_strength.dart';

void main() {
  PasswordStrength levelOf(String password, {String email = ''}) =>
      checkPasswordStrength(password, email: email).level;

  group('checkPasswordStrength', () {
    test('an empty password has no rating', () {
      final result = checkPasswordStrength('');
      expect(result.level, PasswordStrength.empty);
      expect(result.fraction, 0);
      expect(result.label, '');
    });

    test('short passwords are weak, however mixed they are', () {
      expect(levelOf('abc'), PasswordStrength.weak);
      expect(levelOf('Ab1!'), PasswordStrength.weak);
      expect(checkPasswordStrength('Ab1!').tip, contains('at least 8'));
    });

    test('very common passwords are weak, even with small changes', () {
      expect(levelOf('12345678'), PasswordStrength.weak);
      expect(levelOf('Password1'), PasswordStrength.weak);
      expect(levelOf('p@ssw0rd!'), PasswordStrength.weak);
      expect(levelOf('qwertyuiop'), PasswordStrength.weak);
      expect(checkPasswordStrength('Password1').tip, contains('common'));
    });

    test('repeating a few characters is weak', () {
      expect(levelOf('aaaaaaaaaaaa'), PasswordStrength.weak);
      expect(levelOf('abababab'), PasswordStrength.weak);
    });

    test('runs like abcd and 1234 hold a password back', () {
      expect(levelOf('abcd1234EFGH'), PasswordStrength.fair);
      expect(checkPasswordStrength('abcd1234EFGH').tip, contains('runs'));
    });

    test('ratings go up with length and variety', () {
      expect(levelOf('Summer2026'), PasswordStrength.fair);
      expect(levelOf('Xk9#mQ2\$vL7p'), PasswordStrength.good);
      expect(levelOf('Xk9#mQ2\$vL7pRt4!'), PasswordStrength.strong);
    });

    test('a long passphrase is strong', () {
      expect(levelOf('correct horse battery staple'), PasswordStrength.strong);
    });

    test('using the email name lowers the rating', () {
      expect(levelOf('johnsmith2026A'), PasswordStrength.good);
      expect(
        levelOf('johnsmith2026A', email: 'johnsmith@example.com'),
        PasswordStrength.fair,
      );
      expect(
        checkPasswordStrength('johnsmith2026A', email: 'johnsmith@example.com').tip,
        contains('email'),
      );
    });

    test('the bar fills more as the level goes up, and strong has no tip', () {
      final weak = checkPasswordStrength('abc');
      final fair = checkPasswordStrength('Summer2026');
      final good = checkPasswordStrength('Xk9#mQ2\$vL7p');
      final strong = checkPasswordStrength('Xk9#mQ2\$vL7pRt4!');

      expect(weak.fraction < fair.fraction, isTrue);
      expect(fair.fraction < good.fraction, isTrue);
      expect(good.fraction < strong.fraction, isTrue);
      expect(strong.fraction, 1);
      expect(strong.tip, isNull);
      expect([weak.label, fair.label, good.label, strong.label],
          ['Weak', 'Fair', 'Good', 'Strong']);
    });
  });
}
