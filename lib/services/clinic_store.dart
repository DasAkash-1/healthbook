import '../models/app_models.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // database er jonno
import 'package:flutter/foundation.dart'; // debugPrint er jonno

// Longest note a doctor can add when approving a request.
const int kMaxApprovalNoteLength = 300;

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
DateTime _hourStart(DateTime d) => DateTime(d.year, d.month, d.day, d.hour);

// In-memory clinic data. Replace with a Firebase version later, keeping the same methods.
//
// TODO(backend): every method below that reads or changes the lists should become a
// database call. Keep the method names, the arguments and the BookingException messages
// the same, so no screen has to change. The booking rules here must also be enforced on
// the server, not only here.
class ClinicStore {
  final List<Doctor> _doctors = [];
  // doctorId -> hours the doctor has opened (exact hour marks)
  final Map<String, Set<DateTime>> _openHours = {};
  final Set<String> _verified = {};
  final List<Appointment> _appointments = [];
  int _nextId = 1;
  final DateTime Function() _clock;

  // [clock] lets tests move time forward. The app uses the real clock.
  ClinicStore({DateTime Function()? clock}) : _clock = clock ?? DateTime.now {
    _seedDoctors();
  }

  DateTime _now() => _clock();

  // Sample doctors so patients can try the flow before real doctors sign up.
  void _seedDoctors() {
    final seeds = [
      const Doctor(id: 'seed-1', name: 'Dr. Sarah Ahmed', specialty: 'Cardiology'),
      const Doctor(id: 'seed-2', name: 'Dr. Karim Hossain', specialty: 'General Practice'),
      const Doctor(id: 'seed-3', name: 'Dr. Nusrat Jahan', specialty: 'Dermatology'),
    ];
    _doctors.addAll(seeds);
    _verified.addAll(seeds.map((d) => d.id));

    // Open 9:00 to 16:00 tomorrow for each seeded doctor.
    final tomorrow = _dayStart(_now()).add(const Duration(days: 1));
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

  // TODO(backend): save the doctor profile in the database.
  void addDoctor(Doctor doctor) {
    final idx = _doctors.indexWhere((d) => d.id == doctor.id);
    if (idx != -1) {
      _doctors[idx] = doctor;
    } else {
      _doctors.add(doctor);
    }
  }


  // firestore theke sob doctor ane, sathe verified ar open hours o
  Future<void> loadDoctors() async {
    final snap = await FirebaseFirestore.instance.collection('doctors').get();

    for (final doc in snap.docs) {
      final data = doc.data();


      // doctor er basic info, age jemon addDoctor diye dilam
      addDoctor(Doctor(
        id: doc.id,
        name: data['name'] as String? ?? '',
        specialty: data['specialty'] as String? ?? '',
        licenseNumber: data['licenseNumber'] as String? ?? '',
      ));


      // verified hole set e rakhlam, na hole set theke bad dilam
      if (data['verified'] == true) {
        _verified.add(doc.id);
      } else {
        _verified.remove(doc.id);
      }


      // open hours Timestamp list e ache, seta DateTime set e convert korlam
      final hours = (data['openHours'] as List<dynamic>? ?? [])
          .map((t) => (t as Timestamp).toDate())
          .toSet();

      _openHours[doc.id] = hours;
    }
  }

  bool isVerified(String doctorId) => _verified.contains(doctorId);

  // Marks a doctor as verified. Real license checks come with the backend.
  // TODO(backend): verification should be done on the server. The app should only read
  // the result, so this method will no longer be called from the app.
  void verifyDoctor(String doctorId) {
    _verified.add(doctorId);
  }

  // Removes a doctor's verified status, for example when a license expires.
  // TODO(backend): verification is managed on the server.
  void unverifyDoctor(String doctorId) {
    _verified.remove(doctorId);
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
    final now = _now();
    return hour.isAfter(now) &&
        hour.isBefore(now.add(Duration(days: kBookingWindowDays)));
  }

  bool _isBooked(String doctorId, DateTime hour) {
    final normalized = _hourStart(hour);
    return _appointments.any(
      (a) => a.doctorId == doctorId && a.isActive && a.start == normalized,
    );
  }

  bool isHourBooked(String doctorId, DateTime hour) {
    return _isBooked(doctorId, hour);
  }

  bool isHourOpen(String doctorId, DateTime hour) {
    return _openHours[doctorId]?.contains(_hourStart(hour)) ?? false;
  }

  // Open hours on the given day that are still free to book.
  List<DateTime> availableSlotsOn(String doctorId, DateTime day) {
    // Doctors who are not verified cannot take bookings, so they show no slots.
    if (!isVerified(doctorId)) return [];

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
    final today = _dayStart(_now());
    for (var i = 0; i < kBookingWindowDays; i++) {
      final day = today.add(Duration(days: i));
      if (availableSlotsOn(doctorId, day).isNotEmpty) return true;
    }
    return false;
  }

  // ---------- Doctor schedule ----------

  // Opens or closes one hour. Closing is refused if that hour has bookings.
  // TODO(backend): save the open or closed hour in the database.
  void setHourOpen(String doctorId, DateTime hour, bool open) {
    final normalized = _hourStart(hour);
    final hours = _openHours.putIfAbsent(doctorId, () => <DateTime>{});
    if (open) {
      if (!_inBookingWindow(normalized)) {
        throw BookingException(
          'Hours can only be set up to $kBookingWindowDays days ahead.',
        );
      }
      hours.add(normalized);
    } else {
      if (_isBooked(doctorId, normalized)) {
        throw BookingException(
          'This hour has booked appointments and cannot be freed.',
        );
      }
      hours.remove(normalized);
    }
    // local e kora hoye gelo, ekhon firestore e o save kore rakhlam
    _saveHour(doctorId, normalized, open);
  }


  // ekta ghonta firestore er openHours list e add ba remove kore
  // fail korle app crash korbe na, shudhu log e dekhabe
  Future<void> _saveHour(String doctorId, DateTime hour, bool open) async {
    try {
      final stamp = Timestamp.fromDate(hour);

      await FirebaseFirestore.instance.collection('doctors').doc(doctorId).update({
        'openHours': open
            ? FieldValue.arrayUnion([stamp])
            : FieldValue.arrayRemove([stamp]),
      });
    } catch (e) {
      debugPrint('hour save hoyni: $e');
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

  // Pending or approved bookings the patient still has with this doctor.
  bool _hasUpcomingBookingWith(String patientId, String doctorId) {
    final now = _now();
    return _appointments.any(
      (a) =>
          a.patientId == patientId &&
          a.doctorId == doctorId &&
          a.isUpcomingAt(now),
    );
  }

  // Pending or approved bookings on the same calendar day, even if the visit has passed.
  bool _hasBookingWithOnDay(String patientId, String doctorId, DateTime day) {
    return _appointments.any(
      (a) =>
          a.patientId == patientId &&
          a.doctorId == doctorId &&
          a.isActive &&
          _dayStart(a.start) == _dayStart(day),
    );
  }

  // TODO(backend): check that the slot is free and save the request in one database
  // transaction, so two patients cannot book the same slot.
  Appointment requestAppointment({
    required String patientId,
    required String doctorId,
    required DateTime start,
    String visitType = '',
    String note = '',
    String patientName = '',
  }) {
    final normalizedStart = _hourStart(start);
    if (doctorById(doctorId) == null) {
      throw BookingException('Doctor not found.');
    }
    if (!isVerified(doctorId)) {
      throw BookingException(
        'This doctor is waiting for verification and cannot take bookings yet.',
      );
    }
    if (visitType.isNotEmpty && !kVisitTypes.contains(visitType)) {
      throw BookingException('Choose a visit type from the list.');
    }
    if (!_inBookingWindow(normalizedStart)) {
      throw BookingException('This time is outside the booking window.');
    }
    if (!isHourOpen(doctorId, normalizedStart)) {
      throw BookingException('This time is no longer available.');
    }
    if (_isBooked(doctorId, normalizedStart)) {
      throw BookingException('This slot has already been booked.');
    }
    // One upcoming booking per doctor, so other patients get a chance too.
    if (_hasUpcomingBookingWith(patientId, doctorId)) {
      throw BookingException(
        'You already have an appointment with this doctor. You can book again after it has passed or been cancelled.',
      );
    }
    // No second visit with the same doctor on the same day.
    if (_hasBookingWithOnDay(patientId, doctorId, normalizedStart)) {
      throw BookingException('You already have a visit with this doctor on that day.');
    }
    if (!_respectsGap(patientId, doctorId, normalizedStart)) {
      throw BookingException(
        'You can book with another doctor one hour after your current appointment ends.',
      );
    }

    final appointment = Appointment(
      id: 'appt-${_nextId++}',
      patientId: patientId,
      patientName: patientName,
      doctorId: doctorId,
      start: normalizedStart,
      visitType: visitType,
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

  // A pending request can be cancelled without a reason. Once the doctor has approved
  // it, only the patient can cancel, and must say why.
  // TODO(backend): save the new status and reason in the database.
  void cancelAppointment(
    String appointmentId,
    String patientId, {
    String reason = '',
  }) {
    final a = _findAppointment(appointmentId);
    if (a == null || a.patientId != patientId) {
      throw BookingException('Appointment not found.');
    }
    if (!a.isActive) {
      throw BookingException('This appointment is already ${a.status.name}.');
    }
    if (!a.start.isAfter(_now())) {
      throw BookingException('This appointment has already started and cannot be cancelled.');
    }
    final cleaned = reason.trim();
    if (a.status == AppointmentStatus.approved && cleaned.isEmpty) {
      throw BookingException('Please give a reason for cancelling an approved appointment.');
    }
    a.status = AppointmentStatus.cancelled;
    a.reason = cleaned;
  }

  // ---------- Requests (doctor) ----------

  List<Appointment> appointmentsForDoctor(String doctorId) {
    final list = _appointments.where((a) => a.doctorId == doctorId).toList()
      ..sort((a, b) => a.start.compareTo(b.start));
    return list;
  }

  // The doctor can add a short note for the patient, for example "bring your reports".
  // TODO(backend): save the new status and note in the database.
  void approveAppointment(
    String appointmentId,
    String doctorId, {
    String note = '',
  }) {
    final a = _findAppointment(appointmentId);
    if (a == null || a.doctorId != doctorId) {
      throw BookingException('Appointment not found.');
    }
    if (a.status != AppointmentStatus.pending) {
      throw BookingException('Only pending requests can be approved.');
    }
    final cleaned = note.trim();
    if (cleaned.length > kMaxApprovalNoteLength) {
      throw BookingException(
        'The note can be at most $kMaxApprovalNoteLength characters.',
      );
    }
    a.status = AppointmentStatus.approved;
    a.approvalNote = cleaned;
  }

  // Only pending requests can be rejected, and the doctor must say why.
  // After approval the doctor cannot cancel; only the patient can.
  // TODO(backend): save the new status and reason in the database.
  void rejectAppointment(
    String appointmentId,
    String doctorId, {
    required String reason,
  }) {
    final a = _findAppointment(appointmentId);
    if (a == null || a.doctorId != doctorId) {
      throw BookingException('Appointment not found.');
    }
    if (a.status == AppointmentStatus.approved) {
      throw BookingException('Approved appointments cannot be cancelled by the doctor.');
    }
    if (a.status != AppointmentStatus.pending) {
      throw BookingException('Only pending requests can be rejected.');
    }
    final cleaned = reason.trim();
    if (cleaned.isEmpty) {
      throw BookingException('Please give a reason for rejecting this request.');
    }
    a.status = AppointmentStatus.rejected;
    a.reason = cleaned;
  }

  // ---------- Summaries ----------

  // The patient's next approved appointment that has not finished yet.
  Appointment? nextApprovedAppointmentFor(String patientId) {
    final now = _now();
    Appointment? next;
    for (final a in _appointments) {
      if (a.patientId != patientId ||
          a.status != AppointmentStatus.approved ||
          !a.end.isAfter(now)) {
        continue;
      }
      if (next == null || a.start.isBefore(next.start)) next = a;
    }
    return next;
  }

  // Counts for the top of the doctor's Requests tab.
  DoctorSummary summaryForDoctor(String doctorId) {
    final now = _now();
    final today = _dayStart(now);
    final mine = _appointments.where((a) => a.doctorId == doctorId).toList();

    final approvedToday = mine
        .where((a) =>
            a.status == AppointmentStatus.approved && _dayStart(a.start) == today)
        .toList()
      ..sort((a, b) => a.start.compareTo(b.start));

    Appointment? next;
    for (final a in approvedToday) {
      if (a.end.isAfter(now)) {
        next = a;
        break;
      }
    }

    final pending = mine
        .where((a) => a.status == AppointmentStatus.pending && a.end.isAfter(now))
        .length;

    return DoctorSummary(
      visitsToday: approvedToday.length,
      pendingRequests: pending,
      nextVisit: next,
    );
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
