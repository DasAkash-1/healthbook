import '../models/app_models.dart';

class BookingException implements Exception {
  final String message;
  BookingException(this.message);

  @override
  String toString() => message;
}

// Doctors can open hours up to this many days ahead.
const int kBookingWindowDays = 7;

// Patients must leave this much time between appointments with different doctors.
const Duration kBookingGap = Duration(hours: 1);

DateTime _dayStart(DateTime d) => DateTime(d.year, d.month, d.day);

// In-memory clinic data. Replace with a Firebase version later, keeping the same methods.
class ClinicStore {
  final List<Doctor> _doctors = [];
  // doctorId -> hours the doctor has opened (exact hour marks)
  final Map<String, Set<DateTime>> _openHours = {};
  final List<Appointment> _appointments = [];
  int _nextId = 1;

  ClinicStore() {
    _seedDoctors();
  }

  // Sample doctors so patients can try the flow before real doctors sign up.
  void _seedDoctors() {
    final seeds = [
      const Doctor(id: 'seed-1', name: 'Dr. Sarah Ahmed', specialty: 'Cardiology'),
      const Doctor(id: 'seed-2', name: 'Dr. Karim Hossain', specialty: 'General Practice'),
      const Doctor(id: 'seed-3', name: 'Dr. Nusrat Jahan', specialty: 'Dermatology'),
    ];
    _doctors.addAll(seeds);

    // Open 9:00 to 16:00 tomorrow for each seeded doctor.
    final tomorrow = _dayStart(DateTime.now()).add(const Duration(days: 1));
    for (final doctor in seeds) {
      final hours = _openHours.putIfAbsent(doctor.id, () => <DateTime>{});
      for (var h = 9; h < 17; h++) {
        hours.add(DateTime(tomorrow.year, tomorrow.month, tomorrow.day, h));
      }
    }
  }

  // ---------- Doctors ----------

  List<Doctor> get doctors => List.unmodifiable(_doctors);

  List<String> get specialties {
    final list = _doctors.map((d) => d.specialty).toSet().toList()..sort();
    return list;
  }

  Doctor? doctorById(String id) {
    for (final d in _doctors) {
      if (d.id == id) return d;
    }
    return null;
  }

  void addDoctor(Doctor doctor) {
    _doctors.add(doctor);
  }

  List<Doctor> searchDoctors({
    String query = '',
    String? specialty,
    bool availableOnly = false,
  }) {
    final q = query.trim().toLowerCase();
    return _doctors.where((d) {
      if (specialty != null && d.specialty != specialty) return false;
      if (q.isNotEmpty &&
          !d.name.toLowerCase().contains(q) &&
          !d.specialty.toLowerCase().contains(q)) {
        return false;
      }
      if (availableOnly && !hasAvailability(d.id)) return false;
      return true;
    }).toList();
  }

  // ---------- Time and availability ----------

  bool _inBookingWindow(DateTime hour) {
    final now = DateTime.now();
    return hour.isAfter(now) &&
        hour.isBefore(now.add(Duration(days: kBookingWindowDays)));
  }

  bool _isBooked(String doctorId, DateTime hour) {
    return _appointments.any(
      (a) => a.doctorId == doctorId && a.isActive && a.start == hour,
    );
  }

  bool isHourOpen(String doctorId, DateTime hour) {
    return _openHours[doctorId]?.contains(hour) ?? false;
  }

  // Open hours on the given day that are still free to book.
  List<DateTime> availableSlotsOn(String doctorId, DateTime day) {
    final open = _openHours[doctorId] ?? <DateTime>{};
    final slots = open
        .where((h) =>
            _dayStart(h) == _dayStart(day) &&
            _inBookingWindow(h) &&
            !_isBooked(doctorId, h))
        .toList()
      ..sort();
    return slots;
  }

  bool hasAvailability(String doctorId) {
    final today = _dayStart(DateTime.now());
    for (var i = 0; i < kBookingWindowDays; i++) {
      final day = today.add(Duration(days: i));
      if (availableSlotsOn(doctorId, day).isNotEmpty) return true;
    }
    return false;
  }

  // ---------- Doctor schedule ----------

  // Opens or closes one hour. Closing is refused if that hour has bookings.
  void setHourOpen(String doctorId, DateTime hour, bool open) {
    final hours = _openHours.putIfAbsent(doctorId, () => <DateTime>{});
    if (open) {
      if (!_inBookingWindow(hour)) {
        throw BookingException(
          'Hours can only be set up to $kBookingWindowDays days ahead.',
        );
      }
      hours.add(hour);
    } else {
      if (_isBooked(doctorId, hour)) {
        throw BookingException(
          'This hour has booked appointments and cannot be freed.',
        );
      }
      hours.remove(hour);
    }
  }

  // ---------- Booking (patient) ----------

  bool _respectsGap(String patientId, String doctorId, DateTime start) {
    final end = start.add(kSlotLength);
    for (final a in _appointments) {
      if (a.patientId != patientId || a.doctorId == doctorId || !a.isActive) {
        continue;
      }
      final startsAfterGap = !start.isBefore(a.end.add(kBookingGap));
      final endsBeforeGap = !a.start.isBefore(end.add(kBookingGap));
      if (!startsAfterGap && !endsBeforeGap) return false;
    }
    return true;
  }

  Appointment requestAppointment({
    required String patientId,
    required String doctorId,
    required DateTime start,
    String note = '',
  }) {
    if (!_inBookingWindow(start)) {
      throw BookingException('This time is outside the booking window.');
    }
    if (!isHourOpen(doctorId, start)) {
      throw BookingException('This time is no longer available.');
    }
    if (_isBooked(doctorId, start)) {
      throw BookingException('This slot has already been booked.');
    }
    if (!_respectsGap(patientId, doctorId, start)) {
      throw BookingException(
        'You can book with another doctor one hour after your current appointment ends.',
      );
    }

    final appointment = Appointment(
      id: 'appt-${_nextId++}',
      patientId: patientId,
      doctorId: doctorId,
      start: start,
      note: note,
    );
    _appointments.add(appointment);
    return appointment;
  }

  List<Appointment> appointmentsForPatient(String patientId) {
    final list = _appointments.where((a) => a.patientId == patientId).toList()
      ..sort((a, b) => a.start.compareTo(b.start));
    return list;
  }

  void cancelAppointment(String appointmentId, String patientId) {
    final a = _findAppointment(appointmentId);
    if (a == null || a.patientId != patientId) {
      throw BookingException('Appointment not found.');
    }
    if (a.status != AppointmentStatus.pending) {
      throw BookingException('Approved appointments cannot be cancelled.');
    }
    a.status = AppointmentStatus.cancelled;
  }

  // ---------- Requests (doctor) ----------

  List<Appointment> appointmentsForDoctor(String doctorId) {
    final list = _appointments.where((a) => a.doctorId == doctorId).toList()
      ..sort((a, b) => a.start.compareTo(b.start));
    return list;
  }

  void approveAppointment(String appointmentId, String doctorId) {
    final a = _findAppointment(appointmentId);
    if (a == null || a.doctorId != doctorId) {
      throw BookingException('Appointment not found.');
    }
    if (a.status != AppointmentStatus.pending) {
      throw BookingException('Only pending requests can be approved.');
    }
    a.status = AppointmentStatus.approved;
  }

  void rejectAppointment(String appointmentId, String doctorId) {
    final a = _findAppointment(appointmentId);
    if (a == null || a.doctorId != doctorId) {
      throw BookingException('Appointment not found.');
    }
    if (a.status != AppointmentStatus.pending) {
      throw BookingException('Only pending requests can be rejected.');
    }
    a.status = AppointmentStatus.rejected;
  }

  Appointment? _findAppointment(String id) {
    for (final a in _appointments) {
      if (a.id == id) return a;
    }
    return null;
  }
}

// The app-wide store.
final ClinicStore clinicStore = ClinicStore();
