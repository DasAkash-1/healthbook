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
    // batch diye duto document ek sathe save hocche, ekta fail korle dutoi hobe na
    try {
      final batch = _db.batch();

      // private profile
      batch.set(_db.collection('users').doc(cred.user!.uid), {
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


      // doctor hole public directory te o ekta document
      if (role == UserRole.doctor) {
        batch.set(_db.collection('doctors').doc(cred.user!.uid), {
          'name': profile.name,
          'specialty': profile.specialty,
          'licenseNumber': profile.licenseNumber?.trim(),
          'verified': false, // admin console theke true korbe
          'openHours': [], // doctor jei ghonta gula khulbe ekhane jabe
        });
      }

      await batch.commit();

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



    // login er pore sob doctor ar tader hours niye ashlam
    try {
      await clinicStore.loadDoctors();
    } catch (e) {
      debugPrint('doctor load hoyni: $e'); // load na hole o login cholbe
    }




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

  @override
  Future<void> changePassword({
    required String email,
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null || user.email?.toLowerCase() != email.trim().toLowerCase()) {
        throw AuthException('No user signed in.');
      }
      if (newPassword.trim().length < 6) {
        throw AuthException('New password must be at least 6 characters.');
      }
      final cred = fb.EmailAuthProvider.credential(email: email, password: currentPassword);
      await user.reauthenticateWithCredential(cred);
      await user.updatePassword(newPassword);
    } on fb.FirebaseAuthException catch (e) {
      throw AuthException(_message(e));
    } catch (e) {
      if (e is AuthException) rethrow;
      throw AuthException(e.toString());
    }
  }

  @override
  Future<void> updateProfile({
    required String email,
    required UserProfile profile,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw AuthException('No user signed in.');
    }
    final uid = user.uid;

    try {
      final userDocRef = _db.collection('users').doc(uid);
      final docSnap = await userDocRef.get();
      final data = docSnap.data();
      final roleStr = data?['role'] as String? ?? 'patient';
      final role = roleStr == 'doctor' ? UserRole.doctor : UserRole.patient;

      await userDocRef.update({
        'name': profile.name,
        'phone': profile.phone,
        'dateOfBirth': Timestamp.fromDate(profile.dateOfBirth),
        if (profile.gender != null) 'gender': profile.gender,
        if (profile.homeAddress != null) 'homeAddress': profile.homeAddress,
        if (role == UserRole.doctor) ...{
          if (profile.specialty != null) 'specialty': profile.specialty,
          if (profile.licenseNumber != null) 'licenseNumber': profile.licenseNumber?.trim(),
        },
      });

      if (role == UserRole.doctor) {
        await _db.collection('doctors').doc(uid).set({
          'name': profile.name,
          'specialty': profile.specialty ?? '',
          'licenseNumber': profile.licenseNumber?.trim() ?? '',
        }, SetOptions(merge: true));

        final existingDoc = clinicStore.doctorById(uid);
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
        }
      }

      _current = AppUser(
        id: uid,
        email: email.trim().toLowerCase(),
        name: profile.name,
        role: role,
        phone: profile.phone,
        dateOfBirth: profile.dateOfBirth,
        gender: profile.gender,
        homeAddress: profile.homeAddress,
        profilePhotoPath: profile.profilePhotoPath,
      );
    } on FirebaseException catch (e) {
      throw AuthException('Could not update profile (${e.code}).');
    }
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
//final AuthService authService = kDebugMode ? FakeAuthService() : FirebaseAuthService();