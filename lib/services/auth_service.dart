import 'package:flutter/foundation.dart';

import '../models/app_models.dart';
import '../models/medical_history.dart';
import 'clinic_store.dart';
import 'medical_history_store.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb; // login er jonno, fb naam dilam jate nijer AuthException er sathe gondogol na hoy

// Seeded test credentials used only in debug builds so developers/testers can sign in quickly.
const String kDemoPassword = 'Demo1234';
const String kDemoPatientEmail = 'demo.patient@healthbook.test';
const String kDemoDoctorEmail = 'demo.doctor@healthbook.test';

// Additional profile fields collected during account registration.
class UserProfile {
  final String name;
  final String phone;
  final DateTime dateOfBirth;
  final String? specialty; // doctors only
  final String? licenseNumber; // doctors only
  final MedicalHistory? medicalHistory; // patients only

  const UserProfile({
    required this.name,
    required this.phone,
    required this.dateOfBirth,
    this.specialty,
    this.licenseNumber,
    this.medicalHistory,
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
//
// TODO(backend): replace this whole class with the real login service. Passwords must
// never be stored or compared inside the app. Keep the AuthService methods the same.
class FakeAuthService implements AuthService {
  final Map<String, _Account> _accounts = {};
  AppUser? _current;

  FakeAuthService() {
    if (kDebugMode) _seedDemoAccounts();
  }

  // TODO(backend): demo accounts are for testing only. Remove them with this in-memory version.
  // Demo doctor is verified and has an approved appointment with the demo patient
  // for tomorrow at 9:00, so prescription access can be tested straight away.
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
    ));
    clinicStore.verifyDoctor(doctorId);

    final now = DateTime.now();
    final tomorrowNine = DateTime(now.year, now.month, now.day + 1, 9);
    clinicStore.setHourOpen(doctorId, tomorrowNine, true);
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
      ),
    );
  }

  @override
  AppUser? get currentUser => _current;

  // Validates role-specific fields, creates the account in memory, and seeds
  // initial patient medical history or unverified doctor directory profile.
  //
  // TODO(backend): create the account with the real login service and save the profile
  // (name, phone, date of birth, specialty, license number, medical history) in the database.
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
    );
    _accounts[key] = _Account(password: password, user: user);

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
        ),
      );
    }
  }

  // Authenticates a user by normalized email + password and sets [currentUser].
  //
  // TODO(backend): sign in with the real login service and load the user's profile.
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

  // Clears the active session.
  //
  // TODO(backend): sign out of the real login service.
  @override
  void logout() {
    _current = null;
  }
}

// Real login using Firebase Auth. Name, role, phone etc thake Firestore e, users/{uid} er moddhe.
class FirebaseAuthService implements AuthService {

  // firebase auth ar firestore er object, eigula diye sob kaj hobe
  fb.FirebaseAuth get _auth => fb.FirebaseAuth.instance;
  FirebaseFirestore get _db => FirebaseFirestore.instance;


  // ekhon je login kora ache tar info ekhane rakhbo
  AppUser? _current;

  @override
  AppUser? get currentUser => _current;



  // ---------------- REGISTER ----------------

  @override
  Future<void> register({
    required String email,
    required String password,
    required UserRole role,
    required UserProfile profile,
  }) async {

    // email ke lowercase kore id banailam, age jemon chilo
    final key = email.trim().toLowerCase();


    // ekhane form er check, doctor hole specialty ar license lagbe
    if (role == UserRole.doctor && profile.specialty == null) {
      throw AuthException('Please choose your specialty.');
    }

    if (role == UserRole.doctor &&
        (profile.licenseNumber == null || profile.licenseNumber!.trim().isEmpty)) {
      throw AuthException('Please enter your medical license number.');
    }


    // patient hole allergies must, na thakle "None" likhte hobe
    final history = profile.medicalHistory;

    if (role == UserRole.patient &&
        (history == null || history.allergies.trim().isEmpty)) {
      throw AuthException('Please enter your allergies, or write "None".');
    }


    // ekhane firebase e account banano hocche
    fb.UserCredential cred;

    try {
      cred = await _auth.createUserWithEmailAndPassword(email: key, password: password);
    } on fb.FirebaseAuthException catch (e) {
      // email age theke thakle ba password weak hole ekhane ashbe
      throw AuthException(_message(e));
    }


    // account hoye gelo, ekhon baki info firestore e save korbo
    try {
      await _db.collection('users').doc(cred.user!.uid).set({
        'email': key,
        'name': profile.name,
        'role': role.name,
        'phone': profile.phone,
        'dateOfBirth': Timestamp.fromDate(profile.dateOfBirth),
        'specialty': profile.specialty,
        'licenseNumber': profile.licenseNumber?.trim(),

        if (history != null)
          'medicalHistory': {
            'allergies': history.allergies,
            'conditions': history.conditions,
            'surgeries': history.surgeries,
            'currentMedicines': history.currentMedicines,
            'updatedAt': Timestamp.fromDate(history.updatedAt),
          },
      });
    } on FirebaseException catch (e) {
      // firestore e save na hole account ta delete kore dilam, jate profile chara account na thake
      await cred.user!.delete();
      throw AuthException('Could not save your profile (${e.code}). Please try again.');
    }


    // age jemon memory te store hoto, ekhono shei store gula bhore dichhi
    // ekhon id hishebe uid dichhi, email na
    _fillStores(
      id: cred.user!.uid,
      role: role,
      name: profile.name,
      specialty: profile.specialty,
      licenseNumber: profile.licenseNumber?.trim(),
      history: history,
    );


    // register er pore screen login e pathay, tai ekhane signout kore dilam
    await _auth.signOut();
  }



  // ---------------- LOGIN ----------------

  @override
  Future<AppUser> login({
    required String email,
    required String password,
  }) async {

    final key = email.trim().toLowerCase();


    // firebase e email password diye login
    fb.UserCredential cred;

    try {
      cred = await _auth.signInWithEmailAndPassword(email: key, password: password);
    } on fb.FirebaseAuthException catch (e) {
      // vul password hole ekhane ashbe
      throw AuthException(_message(e));
    }

    // uid ta alada kore rakhlam, ekhon theke eta e user er asol id
    final uid = cred.user!.uid;


    // login hoye gele firestore theke oi user er info niye ashchi
    final snap = await _db.collection('users').doc(uid).get();
    final data = snap.data();

    if (data == null) {
      await _auth.signOut();
      throw AuthException('Account profile not found. Please register again.');
    }


    // firestore er data theke AppUser banalam, screen gula eta ei use kore
    final role = data['role'] == 'doctor' ? UserRole.doctor : UserRole.patient;

    final user = AppUser(
      id: uid,
      email: key,
      name: data['name'] as String? ?? '',
      role: role,
      phone: data['phone'] as String? ?? '',
      dateOfBirth: (data['dateOfBirth'] as Timestamp?)?.toDate(),
    );


    // patient er medical history thakle seta ferot niye ashlam
    MedicalHistory? history;
    final h = data['medicalHistory'] as Map<String, dynamic>?;

    if (h != null) {
      history = MedicalHistory(
        allergies: h['allergies'] as String? ?? 'None',
        conditions: h['conditions'] as String? ?? '',
        surgeries: h['surgeries'] as String? ?? '',
        currentMedicines: h['currentMedicines'] as String? ?? '',
        updatedAt: (h['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      );
    }


    // store gula abar bhore dilam
    _fillStores(
      id: uid,
      role: role,
      name: user.name,
      specialty: data['specialty'] as String?,
      licenseNumber: data['licenseNumber'] as String?,
      history: history,
    );


    // ekhon theke currentUser eta
    _current = user;
    return user;
  }



  // ---------------- LOGOUT ----------------

  @override
  void logout() {
    // firebase theke logout
    _auth.signOut();

    // ar amader app er user o muche dilam
    _current = null;
  }



  // ---------------- HELPERS ----------------

  // doctor hole clinicStore e, patient hole medicalHistoryStore e rakhchi
  // TODO: pore eigula o firestore e nite hobe, ekhono memory te
  void _fillStores({
    required String id,
    required UserRole role,
    required String name,
    String? specialty,
    String? licenseNumber,
    MedicalHistory? history,
  }) {

    if (role == UserRole.patient && history != null) {
      medicalHistoryStore.save(patientId: id, editorId: id, history: history);
    }

    if (role == UserRole.doctor) {
      clinicStore.addDoctor(Doctor(
        id: id,
        name: name,
        specialty: specialty ?? '',
        licenseNumber: licenseNumber ?? '',
      ));
    }
  }


  // firebase er error code ke user er bujhar moto message e convert
  String _message(fb.FirebaseAuthException e) {
    switch (e.code) {

    // register screen "already exists" dhore step 1 e pathay
      case 'email-already-in-use':
        return 'An account already exists for this email.';

      case 'invalid-email':
        return 'Please enter a valid email address.';

      case 'weak-password':
        return 'Password is too weak. Use at least 6 characters.';

      case 'invalid-credential':
      case 'wrong-password':
      case 'user-not-found':
        return 'Incorrect email or password.';

      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';

      case 'network-request-failed':
        return 'No internet connection.';

      default:
        return 'Something went wrong (${e.code}).';
    }
  }
}



// The app-wide service. Ekhon real firebase, test e FakeAuthService() ei use hocche.
final AuthService authService = FirebaseAuthService();