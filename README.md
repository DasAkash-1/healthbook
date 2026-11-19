# Healthbook

A Flutter healthcare management application for patients and doctors to manage medical records, prescriptions, diagnostic test recommendations, medication reminders, and clinic appointments.

---

## Features

### Authentication & Onboarding
- **Splash & Intro Flow**: Animated launch screen (`SplashScreen`) transitioning into onboarding (`IntroScreen`) before routing to sign-in (`LoginScreen`).
- **Role-Based Registration (`RegisterScreen`)**:
  - **Patients (3 steps)**: Account credentials with real-time password strength metering (`PasswordStrengthMeter`), personal details (name, phone, date of birth), and initial medical history (required allergies field plus conditions, surgeries, and family history).
  - **Doctors (2 steps)**: Account credentials and professional profile (specialty selection and medical license number).
- **Debug Demo Shortcuts**: One-tap sign-in buttons for demo patient and doctor accounts in debug builds.

### Patient Workflows (`HomePage`)
- **Health Dashboard & Upcoming Appointment Banner**: Quick access to Doctors, Prescriptions, Test Results, and Appointments, plus a banner highlighting the next approved appointment and dynamic text-scaling support.
- **Doctor Directory & Booking (`DoctorDirectoryScreen`, `DoctorDetailScreen`)**:
  - Search by doctor name or specialty, filter by specialty, and toggle availability for the current week.
  - Verified doctors appear first; unverified doctors are shown as *Verification pending* and cannot be booked.
  - 7-day booking window (`kBookingWindowDays`) with 20-minute appointment slots, optional visit type (`kVisitTypes`) and patient note, and a 2-step confirmation flow.
  - Built-in booking rules: enforces a 1-hour buffer when booking different doctors on the same day and prevents duplicate upcoming bookings with the same doctor.
- **Appointment Tracking (`MyAppointmentsScreen`)**:
  - View pending, approved, rejected, and cancelled appointments along with doctor approval notes or rejection reasons.
  - Cancel pending requests freely or cancel approved upcoming appointments with a required reason (`kPatientCancelReasons`).
- **Prescriptions & Medication Management (`PrescriptionsScreen`, `PrescriptionHistoryScreen`)**:
  - View active medications, log doses taken, inspect versioned prescription change history, and upload external prescription files (PDFs or images).
- **Test Results & Recommendations (`TestResultsScreen`, `FileViewerScreen`)**:
  - Track tests recommended by doctors, upload PDF or image results (`FilePicker`), and inspect uploaded images in-app with pinch-to-zoom (`InteractiveViewer`) or open PDFs externally.
- **Medical History & Doctor Access Control (`MedicalHistoryScreen`, `DoctorAccessScreen`)**:
  - Edit personal medical history (allergies, conditions, surgeries, family history).
  - Explicitly grant or revoke record access per doctor (eligible only after an appointment with that doctor has been approved).
- **Health Tools & Local Reminders (`BmiScreen`, `ReminderService`)**:
  - Calculate Body Mass Index (BMI) with WHO adult weight categories and input range validation.
  - Automatic local reminder scheduling (`planReminders`) for upcoming medication doses and approved appointments (24 hours and 1 hour prior).

### Doctor Workflows (`DoctorHomePage`)
- **Daily Summary & Request Management (`_RequestsTab`)**:
  - At-a-glance summary card showing today's visit count, waiting requests, and next scheduled visit.
  - Approve pending requests with an optional note for the patient, or reject requests with a required reason (`kDoctorRejectReasons`).
- **7-Day Schedule Management (`_ScheduleTab`)**:
  - Toggle hourly availability (`08:00`–`16:00`) across the 7-day booking window; hours that have passed or already have bookings are locked.
- **Shared Patient Records (`_PatientsTab`)**:
  - View patients who have granted access and inspect/update their prescriptions, read-only medical history, and uploaded test results.
- **Doctor Profile (`_ProfileTab`)**:
  - Displays specialty, email, medical license number, and verification status (with a debug-only verification toggle for testing).

---

## Project Structure

```text
lib/
├── main.dart                          # App entry point & root MaterialApp configuration
├── splash_screen.dart                   # Animated splash screen & onboarding intro screen
├── models/
│   ├── app_models.dart                  # UserRole, UserProfile, Doctor, Appointment, ClinicSummary
│   ├── medical_history.dart             # MedicalHistory model
│   └── prescription_models.dart         # Medication, ExternalPrescription, RecommendedTest, PrescriptionVersion
├── services/
│   ├── auth_service.dart                # In-memory authentication, registration, and demo account seeding
│   ├── clinic_store.dart                # Doctor directory, 7-day schedule, booking rules, and appointment lifecycle
│   ├── medical_history_store.dart       # Patient medical history storage and access enforcement
│   ├── prescription_store.dart          # Medications, dose logs, test recommendations, audit history, and access grants
│   └── reminder_service.dart            # Local notification scheduling wrapper
├── screens/
│   ├── bmi_screen.dart                  # BMI calculator & WHO category display
│   ├── doctor_access_screen.dart        # Patient toggle screen for granting/revoking doctor access
│   ├── doctor_detail_screen.dart        # Doctor profile, 7-day slot picker, and 2-step booking confirmation
│   ├── doctor_directory_screen.dart     # Searchable & filterable doctor directory
│   ├── doctor_home_page.dart            # Doctor portal (Requests, Schedule, Patients, Profile tabs)
│   ├── feature_screen.dart              # Placeholder screen for upcoming modules
│   ├── file_viewer_screen.dart          # Pinch-to-zoom viewer for uploaded local images
│   ├── home_page.dart                   # Patient portal (Home dashboard, Records, Appointments, Profile tabs)
│   ├── login_screen.dart                # Email/password login & debug demo login shortcuts
│   ├── medical_history_screen.dart      # Editable (patient) / read-only (doctor) medical history screen
│   ├── my_appointments_screen.dart      # Patient appointment list & cancellation flow
│   ├── prescription_history_screen.dart # Chronological audit log of prescription changes
│   ├── prescriptions_screen.dart        # Medication list, dose logging, and prescription management
│   ├── register_screen.dart             # Multi-step patient & doctor registration wizard
│   └── test_results_screen.dart         # Recommended diagnostic tests & PDF/image result uploads
├── utils/
│   ├── allergy_check.dart               # Medication-to-allergy matching & warning helpers
│   ├── app_colors.dart                  # Accessible semantic text & status color constants
│   ├── bmi.dart                         # BMI calculation & height/weight validation
│   ├── file_kind.dart                   # File extension classification (PDF, image, other)
│   ├── formatters.dart                  # Date, day, and time-slot formatting utilities
│   ├── password_strength.dart           # Password entropy/pattern scoring & actionable tips
│   ├── reminder_planner.dart            # Pure reminder scheduling logic for meds & appointments
│   └── validators.dart                  # Form field validators (email, password, phone, DOB, name)
└── widgets/
    ├── approval_note_dialog.dart        # Dialog for optional doctor note upon appointment approval
    ├── medical_history_form.dart        # Reusable medical history form controllers & fields
    ├── open_file_helper.dart            # Routes uploaded images to FileViewerScreen & PDFs externally
    ├── password_strength_meter.dart     # Visual strength progress bar & tip indicator
    └── reason_dialog.dart               # Preset + custom reason picker for cancellations & rejections

test/
├── allergy_check_test.dart              # Unit tests for allergy matching & warnings
├── auth_service_test.dart               # Unit tests for registration, login, and duplicate email checks
├── bmi_test.dart                        # Unit tests for BMI calculation & input validation
├── clinic_store_test.dart               # Unit tests for directory, availability, booking rules, and summaries
├── file_kind_test.dart                  # Unit tests for file extension detection
├── medical_history_test.dart            # Unit tests for medical history ownership & access rules
├── password_strength_meter_test.dart    # Widget tests for PasswordStrengthMeter
├── password_strength_test.dart          # Unit tests for password strength scoring
├── reminder_planner_test.dart           # Unit tests for medication & appointment reminder planning
└── widget_test.dart                     # Smoke test for SplashScreen -> IntroScreen transition
```

---

## Getting Started

### Prerequisites
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (Dart 3+)
- Android Studio / Xcode / VS Code with Flutter extensions

### Installation & Running
1. **Clone the repository**
   ```bash
   git clone https://github.com/DasAkash-1/healthbook.git
   cd healthbook
   ```
2. **Install dependencies**
   ```bash
   flutter pub get
   ```
3. **Run the app**
   ```bash
   flutter run
   ```

### Running Tests & Static Analysis
Run the full unit and widget test suite:
```bash
flutter test
```

Run static analysis:
```bash
flutter analyze
```

---

## Architecture Notes
- **In-Memory Stores**: Authentication (`FakeAuthService`), clinic scheduling (`ClinicStore`), prescriptions/tests (`PrescriptionStore`), and medical history (`MedicalHistoryStore`) currently run as stateful in-memory stores with seeded demo doctors and accounts for local testing.
- **Local File Storage**: Uploaded test results and external prescriptions reference local device file paths selected via `file_picker` until cloud storage integration is added.
