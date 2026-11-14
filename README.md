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
3. Install dependencies: `flutter pub get`
4. Run the app on an emulator or device: `flutter run`

You need Flutter 3.50.0 or newer (check with `flutter --version`) and JDK 17 or newer. The JDK that comes with Android Studio is fine. On Windows, turn on Developer Mode (run `start ms-settings:developers`), because Flutter needs symlink support to build with plugins.

## Android build setup

The `android/` folder was regenerated in November 2026 so the app builds with Flutter 3.50.0. It now uses Android Gradle Plugin 9.3.1, the Kotlin Gradle plugin 2.4.20, and Gradle 9.5.0. Flutter 3.50 refuses to build with older versions, so don't downgrade them, and don't paste in an `android/` folder from an older project or a tutorial.

Don't edit these files without asking Ayman first:

- `android/settings.gradle.kts`
- `android/build.gradle.kts`
- `android/app/build.gradle.kts`
- `android/gradle/wrapper/gradle-wrapper.properties`
- `android/gradle.properties`

Sometimes a change in there really is needed, for example when Firebase is added and its Google services plugin has to be registered. That's fine, but do it in its own pull request so it can be tested on its own. If a build problem only shows up on your emulator, don't try to fix it by changing these files. Open an issue or message the team first.

A few things you will see while building:

- The first build after cloning, or after `flutter clean`, downloads Gradle and the Android build tools. It can take 10 minutes or more. Later builds are much faster, so avoid running `flutter clean` unless you have to.
- Flutter prints a warning that `file_picker` applies the Kotlin Gradle plugin. That is expected for now and isn't an error. Don't upgrade `file_picker` as part of an unrelated change, since newer versions have API changes.
- Never run `flutter create` over an existing project to "fix" the Android setup.
- `local.properties` is specific to each machine and is already in `.gitignore`. Don't commit it, and don't commit keystore files or `key.properties`.

## Development devices

Ayman is the only one on the team who develops on a physical device, a phone running Android 16 over wireless debugging. The other three use emulators. That means a change can behave differently on his phone than on yours, especially anything involving permissions, file picking, notifications, the camera, or storage.

When you open a pull request that touches one of those areas, say what you tested on (which emulator and Android version). If something works on an emulator but breaks on the phone, or the other way round, write that in the pull request so it doesn't get lost.

## Demo accounts

In debug builds, two demo accounts are created each time the app starts. Use the **Demo patient** and **Demo doctor** buttons on the login screen, or enter these details:

| Role    | Email                        | Password |
| ------- | ---------------------------- | -------- |
| Patient | demo.patient@healthbook.test | Demo1234 |
| Doctor  | demo.doctor@healthbook.test  | Demo1234 |

The demo doctor is already verified and has an approved appointment with the demo patient for tomorrow at 09:00. Demo accounts are not created in release builds.

## Testing

Automated tests live in the `test/` folder. Run them with: `flutter test`
They cover the booking rules, the prescription and access rules, medical history, validators, and BMI calculations.

To check code quality, run: `flutter analyze`

## Project structure

```
lib/
├── main.dart                  App entry point and theme
├── splash_screen.dart         Splash screen
├── models/                    Data types (users, doctors, appointments, prescriptions, medical history)
├── services/                  Stores and rules: auth, clinic, prescriptions, medical history
├── screens/                   All app screens
├── widgets/                   Shared widgets (medical history form)
└── utils/                     Validators, formatters, BMI calculation
```

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

Leave the Android Gradle setup alone unless the change is about the Gradle setup (see Android build setup above), and state which device or emulator you tested on in the pull request.
