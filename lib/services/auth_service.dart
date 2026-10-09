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
}

// TEMPORARY: accounts are kept in memory and cleared when the app restarts.
// Passwords are not stored. Replace with a Firebase version later.
class FakeAuthService implements AuthService {
  final Map<String, UserProfile> _accounts = {};

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
  }
}

// The app-wide service. Swap FakeAuthService for the Firebase version later.
final AuthService authService = FakeAuthService();
