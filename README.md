# Healthbook

Healthbook is a Flutter app for patients and doctors. Patients can find doctors, book 20-minute appointments, manage their prescriptions and medical history, and calculate their BMI. Doctors manage their schedule, approve appointment requests, and update prescriptions for patients who have granted them access.

The app is built with Flutter and Dart for Android. Data is currently stored in memory, so it resets when the app restarts. Firebase will be added later.

## Features

**Patients**
- Sign up and log in with email and password
- Browse doctors, search by name or specialty, and filter by availability this week
- Request a 20-minute appointment with an optional note
- View appointments and cancel requests that haven't been approved yet
- Grant or revoke a doctor's access to prescriptions and medical history
- Log doses as taken or missed
- View and update medical history (allergies, conditions, surgeries, current medicines)
- Calculate BMI

**Doctors**
- Sign up with a specialty and medical license number
- Approve or reject appointment requests
- Open or close one-hour slots, up to 7 days ahead
- View patients who have granted access
- Add, edit, and remove medications, with a full version history
- Read medical history, with the patient's access

**Business rules**
- Only verified doctors with a patient's access can change prescriptions.
- Patients can only grant access to doctors they have an approved appointment with.
- Patients must leave a one-hour gap between appointments with different doctors.
- Approved appointments cannot be cancelled.
- Medical history can only be changed by the patient.

## Getting started

1. Install Flutter and Android Studio, then run `flutter doctor` and fix any issues it reports for Android.
2. Clone the repository and open the project folder.
3. Install dependencies: "flutter pub get"
4. Run the app on an emulator or device: "flutter run"

## Demo accounts

In debug builds, two demo accounts are created each time the app starts. Use the **Demo patient** and **Demo doctor** buttons on the login screen, or enter these details:

| Role    | Email                            | Password |
|---------|----------------------------------|----------|
| Patient | demo.patient@healthbook.test     | Demo1234 |
| Doctor  | demo.doctor@healthbook.test      | Demo1234 |

The demo doctor is already verified and has an approved appointment with the demo patient for tomorrow at 09:00. Demo accounts are not created in release builds.

## Testing

Automated tests live in the `test/` folder. Run them with: "flutter test"
They cover the booking rules, the prescription and access rules, medical history, validators, and BMI calculations.

To check code quality, run: "flutter analyze"

## Project structure
lib/
├── main.dart                  App entry point and theme
├── splash_screen.dart         Splash screen
├── models/                    Data types (users, doctors, appointments, prescriptions, medical history)
├── services/                  Stores and rules: auth, clinic, prescriptions, medical history
├── screens/                   All app screens
├── widgets/                   Shared widgets (medical history form)
└── utils/                     Validators, formatters, BMI calculation

The stores in `services/` are currently in memory. Each one has the same methods that a Firebase version will need, so the screens won't need to change when the backend is added.

## Current status

**Done**
- Sign-up and login with patient and doctor roles
- Patient booking flow and doctor schedule and requests
- Prescriptions with access control and version history
- Dose logging
- Medical history at registration and later
- BMI calculator
- Debug demo accounts
- Automated tests for the rules above

**Not yet built**
- Dose reminders and notifications
- Checkup report and current prescription upload
- Firebase or any other backend
- Real doctor verification (currently a test-only button in debug builds)

## Contributing

Work in small steps. Each change should pass `flutter analyze` and `flutter test` before it is committed.