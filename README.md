# Healthbook

A Flutter app for patients and doctors to manage appointments, prescriptions, medical history, test results, and checkup reports.

Built by **DasAkash-1**, **nusrath0631** and **SAMI**.

---

## Who is in the app

* **Patient** — signs up with name, email, phone, date of birth and password, or logs in. Can find doctors, book and cancel appointments, manage doctor access, upload external prescriptions and test results, view checkup reports, and log medicine doses.
* **Doctor** — signs up with name, email, phone, date of birth, specialty and medical license number, or logs in. Can set open hours, approve or reject appointment requests, and—once verified and granted access by the patient—view medical history and test results, write checkup reports, and create or edit prescriptions.

---

## What is built

* **Onboarding & accounts** — splash screen, four-page intro, sign up and log in with validation and a password strength meter.
* **Doctor directory & booking** — search by name or specialty, filter by availability, and book one-hour slots over the next 7 days. Doctors can open or close hours, approve with an optional note, or reject with a reason.
* **Prescriptions & test results** — verified doctors with access can prescribe medicines and recommend tests. Patients can upload external prescription PDFs and test result files, view images in-app or open PDFs/other files externally, and log doses as taken or missed.
* **Doctor checkup reports** — verified doctors with patient access can record checkup reports (diagnosis/summary, optional blood pressure, pulse, temperature, weight, clinical notes, and follow-up advice), and patients or authorized doctors can view them read-only.
* **Medical history & history log** — patients keep their allergies, conditions, surgeries and current medicines; every doctor prescription change is recorded in a version history.
* **Reminders** — plans upcoming medicine and approved-appointment reminders and schedules local notifications on Android, iOS and desktop.

---

## Not yet built

* **Real backend & cloud storage** — data currently lives in memory (`ClinicStore`, `PrescriptionStore`, `MedicalHistoryStore`, `CheckupReportStore`, `AuthService`) and resets when the app restarts. Files are opened from local paths on the device.
* **Doctor license verification** — doctors start unverified and are verified in memory (`verifyDoctor`); real license checks belong on a server.
* **Custom reminder times** — medicine reminder times are fixed to `09:00`, `21:00`, `14:00` and `18:00`.

---

## Business rules

* **Booking window** — doctors can open hours up to **7 days** ahead. Past times cannot be opened or booked.
* **One upcoming booking per doctor** — a patient can have only one pending or approved appointment with a given doctor at a time, and can book again once it has passed or been cancelled.
* **No double booking on the same day** — a patient cannot book the same doctor twice on the same calendar day, even after the first visit ends.
* **Gap between doctors** — a patient must leave at least **1 hour** between appointments with different doctors.
* **Approving and cancelling** — a doctor can approve a pending request with an optional note (up to 300 characters) or reject it with a reason. Once approved, the doctor cannot cancel it; only the patient can cancel, and must give a reason.
* **Doctor access & verification** — a patient can grant a doctor access to their prescription, medical history, test results, and checkup reports only after an appointment with that doctor is approved, and can revoke access at any time. A doctor can change prescriptions or write checkup reports only while verified and granted access.
* **Doses** — a medicine is taken **1 to 4 times a day**. Remaining doses must be a whole number, not negative. The prescription form never fills in a number the doctor did not type. Taking a dose reduces remaining doses by 1 and is blocked at 0; logging a missed dose does not change the count.
* **Passports & dates of birth** — accounts must be for someone at least **13 years old**.

---

## Project layout

```text
lib/
  main.dart                    App entry point and intro screens
  splash_screen.dart           Shown on launch before the intro
  models/
    app_models.dart            Doctors, appointments, and summaries
    checkup_report.dart        Doctor-authored checkup report model
    medical_history.dart       Patient medical history
    prescription_models.dart   Prescriptions, medications, tests, history, dose logs
  services/
    auth_service.dart          Sign up, log in and the current user
    checkup_report_store.dart  Checkup report access, validation, and storage
    clinic_store.dart          Doctors, open hours and bookings
    medical_history_store.dart Patient medical history and access checks
    prescription_store.dart    Prescriptions, access, history and dose logs
    reminder_service.dart      Schedules local notifications with the OS
  utils/
    allergy_check.dart         Matches medicine names against listed allergies
    app_colors.dart            Text colours chosen for contrast
    bmi.dart                   BMI calculation and height/weight checks
    file_kind.dart             PDF, image or other from a file path
    formatters.dart            Date and time formatting
    password_strength.dart     Password strength scoring and tips
    reminder_planner.dart      Works out when reminders should fire
    validators.dart            Form field checks
  widgets/
    allergy_warning_dialog.dart  Warns the doctor before saving a matching medicine
    approval_note_dialog.dart    Optional note when approving a request
    medical_history_form.dart    The medical history fields, editable or read-only
    open_file_helper.dart        Opens an image in-app or hands other files to the OS
    password_strength_meter.dart Strength bar shown under the password field
    reason_dialog.dart           Reason picker used when rejecting or cancelling
  screens/
    *_screen.dart / *.dart     The app's screens and home tabs
test/
  *_test.dart                  Unit and widget tests
```

---

## Running the tests

```bash
flutter test
```
