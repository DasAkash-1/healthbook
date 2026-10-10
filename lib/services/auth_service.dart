// Details collected on the second registration step.
class UserProfile {
  final String name;
  final String phone;
  final DateTime dateOfBirth;

  const UserProfile({
    required this.name,
    required this.phone,
    required this.dateOfBirth,
  });
}

class AuthException implements Exception {
  final String message;
  AuthException(this.message);

  @override
  String toString() => message;
}

abstract class AuthService {
  Future<void> register({
    required String email,
    required String password,
    required UserProfile profile,
  });

  /// Throws [AuthException] if the email or password is wrong.
  Future<void> login({required String email, required String password});
}

// TEMPORARY: accounts are kept in memory and cleared when the app restarts.
// Passwords are kept in memory only so login can be tested. Replace with a
// Firebase version later.
class FakeAuthService implements AuthService {
  final Map<String, UserProfile> _accounts = {};
  final Map<String, String> _passwords = {};

  @override
  Future<void> register({
    required String email,
    required String password,
    required UserProfile profile,
  }) async {
    await Future.delayed(const Duration(seconds: 1)); // simulates network delay

    final key = email.trim().toLowerCase();
    if (_accounts.containsKey(key)) {
      throw AuthException('An account already exists for this email.');
    }
    _accounts[key] = profile;
    _passwords[key] = password;
  }

  @override
  Future<void> login({required String email, required String password}) async {
    await Future.delayed(const Duration(seconds: 1)); // simulates network delay

    // One message for both cases, so it doesn't reveal which emails exist.
    final key = email.trim().toLowerCase();
    if (_passwords[key] != password) {
      throw AuthException('Incorrect email or password.');
    }
  }
}

// The app-wide service. Swap FakeAuthService for the Firebase version later.
final AuthService authService = FakeAuthService();