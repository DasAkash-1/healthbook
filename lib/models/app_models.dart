enum UserRole { patient, doctor }

enum AppointmentStatus { pending, approved, rejected, cancelled }

// Length of one appointment slot.
const Duration kSlotLength = Duration(minutes: 20);

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

  const Doctor({required this.id, required this.name, required this.specialty});
}

class Appointment {
  final String id;
  final String patientId;
  final String doctorId;
  final DateTime start;
  final String note;
  AppointmentStatus status;

  Appointment({
    required this.id,
    required this.patientId,
    required this.doctorId,
    required this.start,
    required this.note,
    this.status = AppointmentStatus.pending,
  });

  DateTime get end => start.add(kSlotLength);

  // Pending and approved bookings hold their slot.
  bool get isActive =>
      status == AppointmentStatus.pending ||
      status == AppointmentStatus.approved;
}
