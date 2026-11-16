enum UserRole { patient, doctor }

enum AppointmentStatus { pending, approved, rejected, cancelled }

// Length of one appointment slot.
const Duration kSlotLength = Duration(minutes: 20);

// Visit types and reasons offered on the appointment screens.
// "Other" always means the person writes the reason themselves.
const String kOtherReason = 'Other';

const List<String> kVisitTypes = [
  'Checkup',
  'Follow-up',
  'New symptom',
  'Test results',
  'Prescription refill',
  kOtherReason,
];

// Reasons a patient can give when cancelling an approved appointment.
const List<String> kPatientCancelReasons = [
  "I'm feeling better and no longer need the visit",
  "I'm sick and can't come",
  'Emergency or family situation',
  'Travel or work schedule conflict',
  "I'm going to a different doctor or clinic",
  'Transport problem',
  kOtherReason,
];

// Reasons a doctor can give when rejecting a request.
const List<String> kDoctorRejectReasons = [
  'Fully booked that day',
  'Not taking new patients right now',
  'Outside my specialty for this need',
  'Need a different type of visit',
  kOtherReason,
];

class AppUser {
  final String id; // lowercase email
  final String name;
  final UserRole role;

  const AppUser({required this.id, required this.name, required this.role});
}

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

class Appointment {
  final String id;
  final String patientId;
  final String patientName;
  final String doctorId;
  final DateTime start;
  final String visitType; // one of kVisitTypes, or empty if the patient skipped it
  final String note;
  AppointmentStatus status;

  // Why the doctor rejected the request, or why the patient cancelled.
  // Empty when no reason was given (a pending request can be cancelled without one).
  String reason;

  // Optional note from the doctor when approving, for example "bring your reports".
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

  DateTime get end => start.add(kSlotLength);

  // Pending and approved bookings hold their slot.
  bool get isActive =>
      status == AppointmentStatus.pending ||
      status == AppointmentStatus.approved;

  // An active booking whose visit has not finished yet.
  bool isUpcomingAt(DateTime now) => isActive && end.isAfter(now);
}

// What the doctor sees at the top of the Requests tab.
class DoctorSummary {
  final int visitsToday; // approved visits today, including ones already finished
  final int pendingRequests; // requests waiting for an answer (visit not over yet)
  final Appointment? nextVisit; // the next approved visit today, if there is one

  const DoctorSummary({
    required this.visitsToday,
    required this.pendingRequests,
    this.nextVisit,
  });
}
