# Healthbook

Healthbook is a Flutter app for patients and doctors. Patients can find doctors, book 20-minute appointments, manage their prescriptions and medical history, and calculate their BMI. Doctors manage their schedule, approve appointment requests, and update prescriptions for patients who have granted them access.

The app is built with Flutter and Dart for Android. **There is no backend yet.** Everything is kept in memory on the phone, so it resets when the app restarts. Firebase will be added later by someone else, and this README tells them where to start.

## What to expect

Read this first, so nothing surprises you.

- **It is a working prototype of the app side.** The screens, the booking and access rules, and the tests are in place. Nothing is sent to a server.
- **Data lives in memory.** Closing the app erases accounts, appointments, prescriptions and uploads. Debug builds create the two demo accounts again each time they start.
- **Nothing is shared between phones.** A patient on one phone and a doctor on another cannot see each other's data. To see both sides, log out and log in again on the same device.
- **Release builds have no demo accounts**, and new doctors cannot be verified (there is no verification process yet), so they cannot take bookings. See [Known limitations](#known-limitations).
- **The rules are real.** Booking, cancelling, access and prescription rules are enforced in `lib/services/` and covered by the tests in `test/`.
- **Android only.** It has been tried on an Android 16 phone and on emulators. iOS, web and desktop are not supported.
- **It is not medical software.** The allergy warning is a simple name match and there are no dose or interaction checks. Nothing in the app is medical advice.

## A five-minute tour

Run the app in debug mode (`flutter run`). Button names are approximate, since screens can change.

1. On the login screen, tap **Demo patient**.
2. The home screen shows a **Next appointment** banner for tomorrow at 09:00 with the demo doctor. Tap it to open Appointments.
3. Open **Doctors**. Pick a doctor (greyed-out doctors are not verified yet), choose a day and a slot, pick a visit type and add a note, then review and send the request. It appears as pending. Cancel it, which needs no reason.
4. On the **Records** tab, open **Medical History** and add an allergy, for example "Penicillin".
5. Open **Prescriptions** and give the demo doctor access to your prescriptions and medical history. The demo doctor can be given access because the two already have an approved appointment.
6. Log out, then tap **Demo doctor**. The Requests tab shows a **Today** summary. Approve a request with a note, or reject one with a reason.
7. On the Patients tab, open the demo patient and add a prescription with "Penicillin V". You get an allergy warning. Go back, change it, then save. Try editing and removing a medication.
8. Log back in as the patient. Your prescriptions are listed and you can mark doses as taken or missed. Upload a PDF as an outside prescription, then tap **View PDF**. It opens in your phone's PDF reader.
9. When Android asks to allow notifications, tap Allow. The phone then shows reminders for your medicines and your next appointment, even when the app is closed.

## Features

**Patients**

- Sign up and log in with email and password. A strength bar under the password field goes from red to green as the password gets stronger
- Browse doctors, search by name or specialty, and filter by availability this week
- Request a 20-minute appointment with an optional visit type and note, and review it before sending
- View appointments, cancel a pending request, or cancel an approved appointment by giving a reason
- See the doctor's note on an approved appointment, and your next approved appointment on the home screen
- Get phone reminders for your medicines (at set times of day, for as many doses as you have left) and for approved appointments (a day before and an hour before)
- Grant or revoke a doctor's access to prescriptions and medical history
- Log doses as taken or missed
- View and update medical history (allergies, conditions, surgeries, current medicines)
- Upload outside prescriptions (PDF) and test result files (PDF, JPG, PNG), and open them again later (images open in the app, PDFs open in your phone's PDF reader)
- Calculate BMI

**Doctors**

- Sign up with a specialty and medical license number
- Approve appointment requests (with an optional note for the patient), or reject them with a reason the patient can see
- See today's visits, waiting requests and the next visit at the top of the Requests tab
- See why a patient cancelled an approved appointment
- Open or close one-hour slots, up to 7 days ahead
- View patients who have granted access
- Add, edit, and remove medications, with a full version history
- Get a warning when a medicine looks like an allergy in the patient's history (text match only, so it can miss related medicines)
- Read medical history, with the patient's access

## Business rules

- Only verified doctors with a patient's access can change prescriptions.
- A doctor keeps access to a patient's prescription until the patient removes it.
- Editing a medication sets the patient's remaining doses to the number the doctor enters.
- Medications have 1 to 4 doses a day, a name and a dose. Remaining doses must be a whole number, not negative. The prescription form never fills in a number the doctor did not type.
- Passwords need at least 8 characters with an upper case letter, a lower case letter and a number. The strength bar (weak, fair, good, strong) rates length, variety, very common passwords, repeats, runs like 1234, and use of the email name. It only advises; it does not block a password that meets the rules.
- Patients can only grant access to doctors they have an approved appointment with.
- Medical history can only be changed by the patient.
- Only verified doctors can receive bookings. Unverified doctors appear greyed out in the directory and show no slots.
- Bookings are for 20-minute slots inside hours the doctor has opened, up to 7 days ahead.
- Patients must leave a one-hour gap between appointments with different doctors.
- A patient can have only one upcoming appointment (pending or approved) with the same doctor, and cannot book the same doctor twice on the same day. A visit that has already passed no longer counts as upcoming. Cancelled or rejected requests do not count.
- A pending request can be cancelled by the patient without a reason, or rejected by the doctor, who must give a reason.
- Once a request is approved, only the patient can cancel it, and must give a reason. Doctors cannot cancel approved appointments. An appointment that has already started cannot be cancelled.
- An approval note can be up to 300 characters.

## Known limitations

- **No backend.** Everything is in memory and resets when the app restarts.
- **One device only.** Nothing is shared between phones.
- **Uploaded files only exist on the phone that picked them.** The app keeps the file's path, not the file. The viewer shows a message if the file is gone, for example when the phone cleared its cache, or when a doctor on another phone tries to open it.
- **PDFs open in another app.** Images open inside Healthbook, but PDFs are handed to the phone's own PDF reader (or browser). If the phone has no app for PDFs, the app says so. The pickers only offer PDF, PNG and JPG.
- **Login is not secure.** Accounts live in memory. There is no password reset and no email check.
- **Doctor verification is a placeholder.** In debug builds a button on the doctor's profile verifies the doctor. Release builds have no way to do it, so new doctors cannot be booked until the backend exists.
- **Allergy warnings are a text match.** They miss related medicines, for example amoxicillin for a penicillin allergy, and they only work while the patient's access is on.
- **Reminders are basic.**
  - They are planned for the next 7 days, and planned again every time the patient opens the app, so opening it keeps them going.
  - Dose times are fixed (for example 09:00 and 21:00 for twice a day) and cannot be changed yet.
  - Reminders can arrive a few minutes late, because the app uses battery-friendly alarms.
  - Some phone makers, vivo and iQOO included, switch off notifications from apps that are not open. If reminders do not show, allow Healthbook to run in the background in the phone's battery settings.
  - Reminders belong to the phone that is logged in as the patient. Because data is not saved yet, they only reflect what is in the app since it was started.
  - There are no reminders for doctors, and no messages that start on the server (for example "your appointment was approved" or "a new request is waiting"). Those need the backend.
- **Times use the phone's clock and time zone.** A pending request whose time has passed stays pending, because there is no expiry yet.
- **Placeholder app setup.** The app icon is the Flutter default, the package name is `com.example.healthbook_test`, and release builds are signed with the debug key.
- **Large text is only partly tested.** Text is never smaller than 12 and the home tiles grow with the phone's text size setting, but not every screen has been tried at the largest sizes.
- **`flutter analyze` shows info messages** saying `package:flutter/material.dart` is deprecated. They are expected until the app moves to `material_ui`, which changes every screen and should be agreed with the team first.

## For the backend developer

Start here when Firebase (or another backend) is added.

- **Find the places to change** with `git grep "TODO(backend)" -- lib`. Each marks a spot where data is read or saved, or a rule that must also be enforced on the server.
- **The stores are the swap point.** Screens use four global objects: `authService`, `clinicStore`, `prescriptionStore` and `medicalHistoryStore`. Replace each with a class that talks to the backend, and keep the method names, the arguments, and the exception messages the same.
- **The stores are synchronous today.** A real backend is asynchronous, so the methods will become `Future`s and the screens that call them will need `await`. Most screen logic stays as it is.
- **Enforce the rules on the server too**, not only in the app. The list is under Business rules above. The tests in `test/` describe the expected behaviour and are a good checklist.
- **Save the profile collected at sign-up** (name, phone number, date of birth, and for doctors the specialty and license number, plus the medical history for patients). `AppUser` and `UserProfile` already carry these fields in memory.
- **Files:** upload PDFs and images to file storage and keep the storage link instead of the phone path. `lib/widgets/open_file_helper.dart` (and the image viewer in `lib/screens/file_viewer_screen.dart`) is the one place that opens them.
- **Doctor verification** (`verifyDoctor`, `unverifyDoctor`) should become a server-side process. The debug-only button on the doctor's profile goes away.
- **Time:** slots and the booking window use the phone's clock. Use server time and one time zone. `ClinicStore` accepts a clock for tests.
- **Reminders:** `lib/services/reminder_service.dart` puts reminders on the phone, and `lib/utils/reminder_planner.dart` decides what they say and when. When data comes from the server, call `reminderService.refreshFor(patientId)` after every sync. Messages that start on the server (approved, rejected, new request) need server push notifications, for example Firebase Cloud Messaging.
- **Android:** the main manifest has no internet permission yet (only the debug and profile ones do), and Firebase's Gradle setup has to be added. Read [Android build setup](#android-build-setup) first and do the Gradle work in its own pull request.

## Getting started

1. Install Flutter and Android Studio, then run `flutter doctor` and fix any issues it reports for Android.
2. Clone the repository and open the project folder.
3. Install dependencies: `flutter pub get`
4. Run the app on an emulator or device: `flutter run`

You need Flutter 3.50.0 or newer (check with `flutter --version`) and JDK 17 or newer. The JDK that comes with Android Studio is fine. On Windows, turn on Developer Mode (run `start ms-settings:developers`), because Flutter needs symlink support to build with plugins.

Opening PDFs uses the `open_filex` package. It only has Android code, so building and `flutter test` need no extra tools on your computer.

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

**Reminders (notification package).** Phone reminders use `flutter_local_notifications`, which needs two changes to the Android setup, both agreed with Ayman: core library desugaring is switched on in `android/app/build.gradle.kts` (one line in `compileOptions` plus a `dependencies` block), and `AndroidManifest.xml` has the notification permissions and two receivers. The package needs minSdk 24 and Java 17, which the project already uses.

## Development devices

Ayman is the only one on the team who develops on a physical device, a phone running Android 16 over wireless debugging. The other three use emulators. That means a change can behave differently on his phone than on yours, especially anything involving permissions, file picking, notifications, the camera, or storage.

When you open a pull request that touches one of those areas, say what you tested on (which emulator and Android version). If something works on an emulator but breaks on the phone, or the other way round, write that in the pull request so it doesn't get lost.

## Demo accounts

In debug builds, two demo accounts are created each time the app starts. Use the **Demo patient** and **Demo doctor** buttons on the login screen, or enter these details:

| Role    | Email                        | Password |
| ------- | ---------------------------- | -------- |
| Patient | demo.patient@healthbook.test | Demo1234 |
| Doctor  | demo.doctor@healthbook.test  | Demo1234 |

The demo doctor is already verified and has an approved appointment with the demo patient for tomorrow at 09:00, so the demo patient cannot book the demo doctor again until that visit has passed. Demo accounts are not created in release builds.

## Testing

Automated tests live in the `test/` folder. Run them with: `flutter test`

They cover the booking rules, the prescription and access rules, medical history, validators, the allergy check, password strength, reminder planning, file types, sign-up details, BMI calculations, and a start-up check of the app. The screens themselves have no automated tests, so try changes on a device or emulator.

To check code quality, run: `flutter analyze`

## Project structure

```
lib/
├── main.dart                  App entry point and theme
├── splash_screen.dart         Splash screen
├── models/                    Data types (users, doctors, appointments, prescriptions, medical history)
├── services/                  Stores and rules: auth, clinic, prescriptions, medical history, reminders
├── screens/                   All app screens, including the image viewer
├── widgets/                   Shared dialogs and forms (reasons, approval note, allergy warning, medical history, opening files)
└── utils/                     Validators, formatters, BMI, allergy check, reminder planner, file types, text colours
```

The stores in `services/` are currently in memory. See [For the backend developer](#for-the-backend-developer) for how to replace them.

## Current status

**Done**

- Sign-up and login with patient and doctor roles
- Patient booking flow with visit type, note and a review step, and the doctor's schedule and requests
- Cancellation and rejection reasons, doctor's approval note, and the one-booking-per-doctor rules
- Doctor's daily summary and the patient's next appointment banner
- Prescriptions with access control, version history, and edit and remove for doctors
- Allergy warning when a doctor prescribes a medicine
- Dose logging
- Phone reminders for medicine doses and approved appointments
- Uploading outside prescriptions and test results, and opening them (images in the app, PDFs in the phone's PDF reader)
- Medical history at registration and later
- BMI calculator
- Text never smaller than 12, and small text uses the colours in `lib/utils/app_colors.dart` so it stays readable
- Debug demo accounts
- Automated tests for the rules above

**Not yet built**

- Server push notifications (for example "appointment approved" or "new request"), reminders for doctors, and choosing your own reminder times
- Checkup report
- Firebase or any other backend
- Real doctor verification
- App icon, final package name and release signing

## Contributing

Work in small steps. Each change should pass `flutter analyze` and `flutter test` before it is committed.

Leave the Android Gradle setup alone unless the change is about the Gradle setup (see Android build setup above), and state which device or emulator you tested on in the pull request.

When you add code that reads or saves data, mark the spot with a `TODO(backend)` comment. When you add small text, use the colours in `lib/utils/app_colors.dart`. Keep this README up to date: features, limitations and what is not built yet.
