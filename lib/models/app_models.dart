// Shared domain enums, constants, and core models for users, doctors, and bookings.
enum UserRole { patient, doctor }

enum AppointmentStatus { pending, approved, rejected, cancelled }

// Standard duration of a single appointment slot (20 minutes).
const Duration kSlotLength = Duration(minutes: 20);

// Visit types and reasons offered on appointment screens.
// Choosing "Other" requires the user to type a custom reason themselves.
const String kOtherReason = 'Other';

const List<String> kVisitTypes = [
  'Checkup',
  'Follow-up',
  'New symptom',
  'Test results',
  'Prescription refill',
  kOtherReason,
];

// Preset reasons a patient can select when cancelling an approved appointment.
const List<String> kPatientCancelReasons = [
  "I'm feeling better and no longer need the visit",
  "I'm sick and can't come",
  'Emergency or family situation',
  'Travel or work schedule conflict',
  "I'm going to a different doctor or clinic",
  'Transport problem',
  kOtherReason,
];

// Preset reasons a doctor can select when rejecting a pending booking request.
const List<String> kDoctorRejectReasons = [
  'Fully booked that day',
  'Not taking new patients right now',
  'Outside my specialty for this need',
  'Need a different type of visit',
  kOtherReason,
];

// Authenticated user profile stored in memory by AuthService.
class AppUser {
  final String id; // ekhon theke firebase uid, age email chilo
  final String email; // email ta alada field e rakhlam, profile screen e dekhanor jonno
  final String name;
  final UserRole role;
  final String phone; // empty for seeded demo accounts
  final DateTime? dateOfBirth; // null for seeded demo accounts

  const AppUser({
    required this.id,
    this.email = '', // default khali, jate FakeAuthService er kaj na bhange
    required this.name,
    required this.role,
    this.phone = '',
    this.dateOfBirth,
  });
}

// Doctor directory entry managed by ClinicStore.
class Doctor {
  final String id;
  final String name;
  final String specialty;
  final String licenseNumber;

  const Doctor({
    required this.id,
    required this.name,
    required this.specialty,
    this.licenseNumber = '',
  });
}

// Represents a patient's appointment request or scheduled visit with a doctor.
class Appointment {
  final String id;
  final String patientId;
  final String patientName;
  final String doctorId;
  final DateTime start;
  final String visitType; // one of kVisitTypes, or empty if omitted
  final String note;
  AppointmentStatus status;

  // Reason entered when a doctor rejects a request or a patient cancels.
  // Empty when no reason applies (e.g., cancelling a still-pending request).
  String reason;

  // Optional note added by the doctor on approval (e.g., "bring your reports").
  String approvalNote;

  Appointment({
    required this.id,
    required this.patientId,
    this.patientName = '',
    required this.doctorId,
    required this.start,
    this.visitType = '',
    required this.note,
    this.status = AppointmentStatus.pending,
    this.reason = '',
    this.approvalNote = '',
  });

  // Appointment end time computed from start + kSlotLength.
  DateTime get end => start.add(kSlotLength);

  // Pending and approved appointments reserve the doctor's time slot.
  bool get isActive =>
      status == AppointmentStatus.pending ||
      status == AppointmentStatus.approved;

  // True if the appointment is active and has not finished at [now].
  bool isUpcomingAt(DateTime now) => isActive && end.isAfter(now);
}

// Aggregated metrics displayed at the top of the doctor's Requests/home summary.
class DoctorSummary {
  final int visitsToday; // approved visits today, including finished ones
  final int pendingRequests; // active pending requests whose end time hasn't passed
  final Appointment? nextVisit; // earliest upcoming approved visit today, if any

  const DoctorSummary({
    required this.visitsToday,
    required this.pendingRequests,
    this.nextVisit,
  });
}
