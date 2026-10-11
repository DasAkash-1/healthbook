import '../models/app_models.dart';
import 'clinic_store.dart';

// Details collected on the second registration step.
class UserProfile {
  final String name;
  final String phone;
  final DateTime dateOfBirth;
  final String? specialty; // doctors only
  final String? licenseNumber; // doctors only

  const UserProfile({
    required this.name,
    required this.phone,
    required this.dateOfBirth,
    this.specialty,
    this.licenseNumber,
  });
}

class AuthException implements Exception {
  final String message;
  AuthException(this.message);

  @override
  String toString() => message;
}

abstract class AuthService {
  AppUser? get currentUser;

  Future<void> register({
    required String email,
    required String password,
    required UserRole role,
    required UserProfile profile,
  });

  Future<AppUser> login({
    required String email,
    required String password,
  });

  void logout();
}

class _Account {
  final String password;
  final AppUser user;

  _Account({required this.password, required this.user});
}

// TEMPORARY: accounts are kept in memory and cleared when the app restarts.
// Passwords are kept in plain text here so login can be tested. This is NOT
// secure. Replace with a Firebase version later.
class FakeAuthService implements AuthService {
  final Map<String, _Account> _accounts = {};
  AppUser? _current;

  @override
  AppUser? get currentUser => _current;

  @override
  Future<void> register({
    required String email,
    required String password,
    required UserRole role,
    required UserProfile profile,
  }) async {
    await Future.delayed(const Duration(seconds: 1)); // simulates network delay

    final key = email.trim().toLowerCase();
    if (_accounts.containsKey(key)) {
      throw AuthException('An account already exists for this email.');
    }

    if (role == UserRole.doctor && profile.specialty == null) {
      throw AuthException('Please choose your specialty.');
    }
    if (role == UserRole.doctor &&
        (profile.licenseNumber == null || profile.licenseNumber!.trim().isEmpty)) {
      throw AuthException('Please enter your medical license number.');
    }

    final user = AppUser(id: key, name: profile.name, role: role);
    _accounts[key] = _Account(password: password, user: user);

    if (role == UserRole.doctor) {
      clinicStore.addDoctor(
        Doctor(
          id: key,
          name: profile.name,
          specialty: profile.specialty!,
          licenseNumber: profile.licenseNumber!.trim(),
        ),
      );
    }
  }

  @override
  Future<AppUser> login({
    required String email,
    required String password,
  }) async {
    await Future.delayed(const Duration(seconds: 1)); // simulates network delay

    final key = email.trim().toLowerCase();
    final account = _accounts[key];
    if (account == null || account.password != password) {
      throw AuthException('Incorrect email or password.');
    }

    _current = account.user;
    return account.user;
  }

  @override
  void logout() {
    _current = null;
  }
}

// The app-wide service. Swap FakeAuthService for the Firebase version later.
final AuthService authService = FakeAuthService();
