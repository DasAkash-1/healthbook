import 'package:flutter/foundation.dart';

import '../models/app_models.dart';
import '../models/medical_history.dart';
import 'clinic_store.dart';
import 'medical_history_store.dart';

// Seeded test credentials used only in debug builds so developers/testers can sign in quickly.
const String kDemoPassword = 'Demo1234';
const String kDemoPatientEmail = 'demo.patient@healthbook.test';
const String kDemoDoctorEmail = 'demo.doctor@healthbook.test';

// Additional profile fields collected during account registration and profile editing.
class UserProfile {
  final String name;
  final String phone;
  final DateTime dateOfBirth;
  final String? specialty; // doctors only
  final String? licenseNumber; // doctors only
  final MedicalHistory? medicalHistory; // patients only
  final String? profilePhotoPath;
  final String? gender;
  final String? homeAddress;
  final String? biography;
  final List<String>? qualifications;
  final int? yearsOfExperience;
  final String? hospitalAffiliation;
  final String? chamberAddress;
  final String? assistantPhone;

  const UserProfile({
    required this.name,
    required this.phone,
    required this.dateOfBirth,
    this.specialty,
    this.licenseNumber,
    this.medicalHistory,
    this.profilePhotoPath,
    this.gender,
    this.homeAddress,
    this.biography,
    this.qualifications,
    this.yearsOfExperience,
    this.hospitalAffiliation,
    this.chamberAddress,
    this.assistantPhone,
  });
}

// Domain error thrown for invalid registration or login attempts.
class AuthException implements Exception {
  final String message;
  AuthException(this.message);

  @override
  String toString() => message;
}

// Abstract authentication contract so the app can swap FakeAuthService
// for a real backend authentication service later without changing UI code.
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

  Future<void> changePassword({
    required String email,
    required String currentPassword,
    required String newPassword,
  });

  Future<void> updateProfile({
    required String email,
    required UserProfile profile,
  });

  void logout();
}

// Internal record pairing an in-memory password with an AppUser profile.
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

  FakeAuthService() {
    if (kDebugMode) _seedDemoAccounts();
  }

  void _seedDemoAccounts() {
    const patientId = kDemoPatientEmail;
    const doctorId = kDemoDoctorEmail;

    _accounts[patientId] = _Account(
      password: kDemoPassword,
      user: const AppUser(id: patientId, name: 'Demo Patient', role: UserRole.patient),
    );
    _accounts[doctorId] = _Account(
      password: kDemoPassword,
      user: const AppUser(id: doctorId, name: 'Demo Doctor', role: UserRole.doctor),
    );

    clinicStore.addDoctor(const Doctor(
      id: doctorId,
      name: 'Demo Doctor',
      specialty: 'General Practice',
      licenseNumber: 'DEMO-0001',
      chamberAddress: 'Sunrise Diagnostic Complex, 2nd Floor, Ambarkhana, Sylhet, Bangladesh',
      assistantPhone: '+880 1700-000104',
    ));
    clinicStore.verifyDoctor(doctorId);

    final now = DateTime.now();
    final tomorrowNine = DateTime(now.year, now.month, now.day + 1, 9);
    clinicStore.setHourOpen(doctorId, tomorrowNine, true, fee: 800.0);
    final appt = clinicStore.requestAppointment(
      patientId: patientId,
      doctorId: doctorId,
      start: tomorrowNine,
      patientName: 'Demo Patient',
    );
    clinicStore.approveAppointment(appt.id, doctorId);

    medicalHistoryStore.save(
      patientId: patientId,
      editorId: patientId,
      history: MedicalHistory(
        allergies: 'None known',
        conditions: 'None',
        surgeries: 'None',
        currentMedicines: 'None',
        updatedAt: DateTime.now(),
        bloodGroup: 'O+',
        emergencyContactName: 'John Doe',
        emergencyContactRelationship: 'Spouse',
        emergencyContactPhone: '+880 1711-000000',
        heightCm: 170,
        weightKg: 70,
      ),
    );
  }

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

    if (role == UserRole.doctor && (profile.specialty == null || profile.specialty!.trim().isEmpty)) {
      throw AuthException('Please choose your specialty.');
    }
    if (role == UserRole.doctor &&
        (profile.licenseNumber == null || profile.licenseNumber!.trim().isEmpty)) {
      throw AuthException('Please enter your medical license number.');
    }

    if (role == UserRole.patient) {
      final history = profile.medicalHistory;
      if (history == null || history.allergies.trim().isEmpty) {
        throw AuthException('Please enter your allergies, or write "None".');
      }
    }

    final user = AppUser(
      id: key,
      name: profile.name,
      role: role,
      phone: profile.phone,
      dateOfBirth: profile.dateOfBirth,
      profilePhotoPath: profile.profilePhotoPath,
      gender: profile.gender,
      homeAddress: profile.homeAddress,
    );
    _accounts[key] = _Account(password: password, user: user);
    if (_current == null && email.trim().toLowerCase() == key) {
      // If registering while active session (unlikely) or just created
    }

    if (role == UserRole.patient) {
      medicalHistoryStore.save(
        patientId: key,
        editorId: key,
        history: profile.medicalHistory!,
      );
    }

    if (role == UserRole.doctor) {
      clinicStore.addDoctor(
        Doctor(
          id: key,
          name: profile.name,
          specialty: profile.specialty!,
          licenseNumber: profile.licenseNumber!.trim(),
          chamberAddress: profile.chamberAddress ?? 'Main Chamber, Sylhet, Bangladesh',
          assistantPhone: profile.assistantPhone ?? '+880 1700-000100',
          biography: profile.biography ?? '',
          qualifications: profile.qualifications ?? [],
          yearsOfExperience: profile.yearsOfExperience ?? 0,
          hospitalAffiliation: profile.hospitalAffiliation ?? '',
          profilePhotoPath: profile.profilePhotoPath ?? '',
          gender: profile.gender ?? '',
          homeAddress: profile.homeAddress ?? '',
          dateOfBirth: profile.dateOfBirth,
          phone: profile.phone,
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
  Future<void> changePassword({
    required String email,
    required String currentPassword,
    required String newPassword,
  }) async {
    await Future.delayed(const Duration(milliseconds: 500));
    final key = email.trim().toLowerCase();
    final account = _accounts[key];
    if (account == null || account.password != currentPassword) {
      throw AuthException('Incorrect current password.');
    }
    if (newPassword.trim().length < 6) {
      throw AuthException('New password must be at least 6 characters.');
    }
    _accounts[key] = _Account(password: newPassword, user: account.user);
  }

  @override
  Future<void> updateProfile({
    required String email,
    required UserProfile profile,
  }) async {
    await Future.delayed(const Duration(milliseconds: 500));
    final key = email.trim().toLowerCase();
    final account = _accounts[key];
    if (account == null) {
      throw AuthException('Account not found.');
    }

    final updatedUser = AppUser(
      id: key,
      name: profile.name,
      role: account.user.role,
      phone: profile.phone,
      dateOfBirth: profile.dateOfBirth,
      profilePhotoPath: profile.profilePhotoPath ?? account.user.profilePhotoPath,
      gender: profile.gender ?? account.user.gender,
      homeAddress: profile.homeAddress ?? account.user.homeAddress,
    );

    _accounts[key] = _Account(password: account.password, user: updatedUser);
    if (_current?.id == key) {
      _current = updatedUser;
    }

    if (account.user.role == UserRole.doctor) {
      final existingDoc = clinicStore.doctorById(key);
      if (existingDoc != null) {
        clinicStore.addDoctor(existingDoc.copyWith(
          name: profile.name,
          specialty: profile.specialty ?? existingDoc.specialty,
          licenseNumber: profile.licenseNumber ?? existingDoc.licenseNumber,
          chamberAddress: profile.chamberAddress ?? existingDoc.chamberAddress,
          assistantPhone: profile.assistantPhone ?? existingDoc.assistantPhone,
          biography: profile.biography ?? existingDoc.biography,
          qualifications: profile.qualifications ?? existingDoc.qualifications,
          yearsOfExperience: profile.yearsOfExperience ?? existingDoc.yearsOfExperience,
          hospitalAffiliation: profile.hospitalAffiliation ?? existingDoc.hospitalAffiliation,
          profilePhotoPath: profile.profilePhotoPath ?? existingDoc.profilePhotoPath,
          gender: profile.gender ?? existingDoc.gender,
          homeAddress: profile.homeAddress ?? existingDoc.homeAddress,
          dateOfBirth: profile.dateOfBirth,
          phone: profile.phone,
        ));
      } else {
        clinicStore.addDoctor(Doctor(
          id: key,
          name: profile.name,
          specialty: profile.specialty ?? 'General Practice',
          licenseNumber: profile.licenseNumber ?? '',
          chamberAddress: profile.chamberAddress ?? '',
          assistantPhone: profile.assistantPhone ?? '',
          biography: profile.biography ?? '',
          qualifications: profile.qualifications ?? [],
          yearsOfExperience: profile.yearsOfExperience ?? 0,
          hospitalAffiliation: profile.hospitalAffiliation ?? '',
          profilePhotoPath: profile.profilePhotoPath ?? '',
          gender: profile.gender ?? '',
          homeAddress: profile.homeAddress ?? '',
          dateOfBirth: profile.dateOfBirth,
          phone: profile.phone,
        ));
      }
    }
  }

  @override
  void logout() {
    _current = null;
  }
}

// The app-wide service. Swap FakeAuthService for the Firebase version later.
final AuthService authService = FakeAuthService();
