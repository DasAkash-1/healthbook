import 'package:flutter_test/flutter_test.dart';

import 'package:healthbook_test/models/app_models.dart';
import 'package:healthbook_test/models/medical_history.dart';
import 'package:healthbook_test/services/auth_service.dart';

void main() {
  // One instance for all tests, like the app has. Creating it adds the demo accounts
  // and the demo appointment to the shared stores, which can only happen once.
  final auth = FakeAuthService();

  group('FakeAuthService', () {
    test('phone number and date of birth are kept on the account', () async {
      final dob = DateTime(2000, 5, 17);

      await auth.register(
        email: 'new.patient@x.com',
        password: 'Abcdef12',
        role: UserRole.patient,
        profile: UserProfile(
          name: 'New Patient',
          phone: '017 1234 5678',
          dateOfBirth: dob,
          medicalHistory: MedicalHistory(allergies: 'None', updatedAt: DateTime.now()),
        ),
      );

      final user = await auth.login(email: 'new.patient@x.com', password: 'Abcdef12');
      expect(user.phone, '017 1234 5678');
      expect(user.dateOfBirth, dob);
      expect(user.role, UserRole.patient);
    });

    test('an email can only be used once', () async {
      final profile = UserProfile(
        name: 'Someone',
        phone: '0171234567',
        dateOfBirth: DateTime(1990, 1, 1),
        medicalHistory: MedicalHistory(allergies: 'None', updatedAt: DateTime.now()),
      );

      await auth.register(
        email: 'twice@x.com',
        password: 'Abcdef12',
        role: UserRole.patient,
        profile: profile,
      );
      await expectLater(
        auth.register(
          email: 'TWICE@x.com',
          password: 'Abcdef12',
          role: UserRole.patient,
          profile: profile,
        ),
        throwsA(isA<AuthException>()),
      );
    });
  });
}
