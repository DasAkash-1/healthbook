// Main navigation shell for logged-in doctors with four tabs:
// Requests (approve/reject & daily summary), Schedule (open/close hours & fees),
// Patients (shared records), and Profile (verification status, profile editing, change password & log out).
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/app_models.dart';
import '../services/auth_service.dart';
import '../services/clinic_store.dart';
import '../services/prescription_store.dart';
import '../utils/formatters.dart';
import '../widgets/approval_note_dialog.dart';
import '../widgets/reason_dialog.dart';
import 'login_screen.dart';
import 'prescriptions_screen.dart';
import '../utils/app_colors.dart';

const int _firstHour = 8;
const int _lastHour = 16;

class DoctorHomePage extends StatefulWidget {
  const DoctorHomePage({super.key});

  @override
  State<DoctorHomePage> createState() => _DoctorHomePageState();
}

class _DoctorHomePageState extends State<DoctorHomePage> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final doctorId = authService.currentUser?.id ?? '';

    final Widget body = switch (_currentIndex) {
      0 => _RequestsTab(doctorId: doctorId),
      1 => _ScheduleTab(doctorId: doctorId),
      2 => _PatientsTab(doctorId: doctorId),
      _ => _ProfileTab(doctorId: doctorId),
    };

    const titles = ['Requests', 'Schedule', 'Patients', 'Profile'];

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(titles[_currentIndex]),
      ),
      body: SafeArea(child: body),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFF102A66),
        unselectedItemColor: kTextMuted,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.inbox_outlined),
            label: 'Requests',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_month_outlined),
            label: 'Schedule',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people_outline),
            label: 'Patients',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

// ---------- Requests ----------

class _RequestsTab extends StatefulWidget {
  final String doctorId;

  const _RequestsTab({required this.doctorId});

  @override
  State<_RequestsTab> createState() => _RequestsTabState();
}

class _RequestsTabState extends State<_RequestsTab> {
  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _approve(Appointment a) async {
    final note = await askForApprovalNote(
      context,
      patientName: a.patientName.isEmpty ? 'The patient' : a.patientName,
      when: '${formatDay(a.start)} • ${formatSlot(a.start)}',
    );
    if (!mounted || note == null) return;

    try {
      clinicStore.approveAppointment(a.id, widget.doctorId, note: note);
      setState(() {});
    } on BookingException catch (e) {
      _showError(e.message);
    }
  }

  Future<void> _reject(Appointment a) async {
    final reason = await askForReason(
      context,
      title: 'Reject this request?',
      message: 'The patient will see your reason.',
      options: kDoctorRejectReasons,
      confirmLabel: 'Reject request',
    );
    if (!mounted || reason == null) return;

    try {
      clinicStore.rejectAppointment(a.id, widget.doctorId, reason: reason);
      setState(() {});
    } on BookingException catch (e) {
      _showError(e.message);
    }
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 12),
      child: Text(
        text,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
      ),
    );
  }

  Widget _requestCard(Appointment a) {
    final name = a.patientName.isEmpty ? 'Patient' : a.patientName;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F7FB),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
              if (a.consultationFee > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCE6FF),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '৳${a.consultationFee.toStringAsFixed(0)}',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF102A66), fontSize: 13),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${formatDay(a.start)} • ${formatSlot(a.start)}',
            style: TextStyle(color: Colors.grey[800]),
          ),
          if (a.visitType.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text('Visit type: ${a.visitType}', style: TextStyle(color: Colors.grey[700])),
          ],
          if (a.note.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text('Note: ${a.note}', style: TextStyle(color: Colors.grey[700])),
          ],
          if (a.status == AppointmentStatus.pending) ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  onPressed: () => _reject(a),
                  child: const Text('Reject'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () => _approve(a),
                  child: const Text('Approve'),
                ),
              ],
            ),
          ],
          if (a.status == AppointmentStatus.approved) ...[
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'Approved',
                style: TextStyle(color: kTextSuccess, fontWeight: FontWeight.w600),
              ),
            ),
            if (a.approvalNote.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                'Your note: ${a.approvalNote}',
                style: const TextStyle(color: kTextMuted),
              ),
            ],
          ],
          if (a.status == AppointmentStatus.cancelled) ...[
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'Cancelled by the patient',
                style: TextStyle(color: kTextMuted, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              a.reason.isEmpty ? 'No reason given.' : 'Reason: ${a.reason}',
              style: TextStyle(color: Colors.grey[700]),
            ),
          ],
        ],
      ),
    );
  }

  Widget _stat(String number, String label) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            number,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF102A66),
            ),
          ),
          Text(
            label,
            style: const TextStyle(fontSize: 14, color: Color(0xFF102A66)),
          ),
        ],
      ),
    );
  }

  Widget _summaryCard() {
    final summary = clinicStore.summaryForDoctor(widget.doctorId);
    final next = summary.nextVisit;
    final nextText = next == null
        ? 'No more visits today.'
        : 'Next: ${formatSlot(next.start)} with '
            '${next.patientName.isEmpty ? 'a patient' : next.patientName}';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFDCE6FF),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Today',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: Color(0xFF102A66),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _stat(
                '${summary.visitsToday}',
                summary.visitsToday == 1 ? 'visit today' : 'visits today',
              ),
              _stat(
                '${summary.pendingRequests}',
                summary.pendingRequests == 1 ? 'request waiting' : 'requests waiting',
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            nextText,
            style: const TextStyle(fontSize: 14, color: Color(0xFF102A66)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final all = clinicStore.appointmentsForDoctor(widget.doctorId);
    final now = DateTime.now();
    final pending =
        all.where((a) => a.status == AppointmentStatus.pending).toList();
    final approved =
        all.where((a) => a.status == AppointmentStatus.approved).toList();
    final cancelled = all
        .where((a) => a.status == AppointmentStatus.cancelled && a.end.isAfter(now))
        .toList();
    final nothingYet = pending.isEmpty && approved.isEmpty && cancelled.isEmpty;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _summaryCard(),
        if (nothingYet)
          const Padding(
            padding: EdgeInsets.all(12),
            child: Text(
              'No requests yet. Open your hours in the Schedule tab so patients '
              'can book, and their requests will appear here.',
              textAlign: TextAlign.center,
            ),
          )
        else ...[
          if (pending.isNotEmpty) ...[
            _sectionTitle('Pending approval'),
            for (final a in pending) _requestCard(a),
          ],
          if (approved.isNotEmpty) ...[
            _sectionTitle('Approved'),
            for (final a in approved) _requestCard(a),
          ],
          if (cancelled.isNotEmpty) ...[
            _sectionTitle('Cancelled by patients'),
            for (final a in cancelled) _requestCard(a),
          ],
        ],
      ],
    );
  }
}

// ---------- Schedule & Fees ----------

class _ScheduleTab extends StatefulWidget {
  final String doctorId;

  const _ScheduleTab({required this.doctorId});

  @override
  State<_ScheduleTab> createState() => _ScheduleTabState();
}

class _ScheduleTabState extends State<_ScheduleTab> {
  late final List<DateTime> _days;
  late DateTime _selectedDay;

  @override
  void initState() {
    super.initState();
    final today = DateTime.now();
    final start = DateTime(today.year, today.month, today.day);
    _days = List.generate(
      kBookingWindowDays,
      (i) => start.add(Duration(days: i)),
    );
    _selectedDay = _days.first;
  }

  Future<void> _toggle(DateTime hour, {required bool open}) async {
    double? fee = clinicStore.feeForSlot(widget.doctorId, hour);
    if (open) {
      fee = await showDialog<double>(
        context: context,
        builder: (ctx) {
          final ctrl = TextEditingController(text: fee != null ? fee.toStringAsFixed(0) : '800');
          return AlertDialog(
            title: const Text('Set Consultation Fee'),
            content: TextField(
              controller: ctrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Consultation Fee (BDT ৳)'),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: () {
                  final parsed = double.tryParse(ctrl.text.trim());
                  if (parsed == null || parsed < 0) return;
                  Navigator.pop(ctx, parsed);
                },
                child: const Text('Save'),
              ),
            ],
          );
        },
      );
      if (!mounted) return;
      if (fee == null) return;
    }

    try {
      clinicStore.setHourOpen(widget.doctorId, hour, open, fee: fee);
      setState(() {});
    } on BookingException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    }
  }

  Future<void> _editFee(DateTime hour) async {
    final currentFee = clinicStore.feeForSlot(widget.doctorId, hour) ?? 800.0;
    final fee = await showDialog<double>(
      context: context,
      builder: (ctx) {
        final ctrl = TextEditingController(text: currentFee.toStringAsFixed(0));
        return AlertDialog(
          title: const Text('Edit Consultation Fee'),
          content: TextField(
            controller: ctrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Consultation Fee (BDT ৳)'),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                final parsed = double.tryParse(ctrl.text.trim());
                if (parsed == null || parsed < 0) return;
                Navigator.pop(ctx, parsed);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
    if (!mounted) return;
    if (fee != null) {
      try {
        clinicStore.setSlotFee(widget.doctorId, hour, fee);
        setState(() {});
      } on BookingException catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    }
  }

  Widget _hourTile(DateTime hour, DateTime now) {
    final booked = clinicStore.isHourBooked(widget.doctorId, hour);
    final open = clinicStore.isHourOpen(widget.doctorId, hour);
    final passed = !hour.isAfter(now);
    final fee = clinicStore.feeForSlot(widget.doctorId, hour);

    final String subtitle;
    if (passed) {
      subtitle = 'Passed';
    } else if (booked) {
      subtitle = 'Booked by a patient ${fee != null ? '• ৳${fee.toStringAsFixed(0)}' : ''}';
    } else if (open) {
      subtitle = 'Open for booking • Fee: ${fee != null ? '৳${fee.toStringAsFixed(0)}' : 'Not set'}';
    } else {
      subtitle = 'Closed';
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        tileColor: const Color(0xFFF4F7FB),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(
          formatSlot(hour),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(subtitle),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (open && !passed)
              TextButton(
                onPressed: () => _editFee(hour),
                child: const Text('Edit Fee'),
              ),
            Switch(
              value: open,
              onChanged: (passed || booked)
                  ? null
                  : (v) => _toggle(hour, open: v),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'Choose a day',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final d in _days)
              ChoiceChip(
                label: Text(formatDay(d)),
                selected: _selectedDay == d,
                onSelected: (_) => setState(() => _selectedDay = d),
              ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          'Turn hours on and set consultation fees to offer them to patients. Booked hours cannot be turned off.',
          style: TextStyle(color: Colors.grey[700]),
        ),
        const SizedBox(height: 12),
        for (var h = _firstHour; h <= _lastHour; h++)
          _hourTile(
            DateTime(_selectedDay.year, _selectedDay.month, _selectedDay.day, h),
            now,
          ),
      ],
    );
  }
}

// ---------- Patients ----------

class _PatientsTab extends StatefulWidget {
  final String doctorId;

  const _PatientsTab({required this.doctorId});

  @override
  State<_PatientsTab> createState() => _PatientsTabState();
}

class _PatientsTabState extends State<_PatientsTab> {
  String _nameFor(String patientId) {
    for (final a in clinicStore.appointmentsForDoctor(widget.doctorId)) {
      if (a.patientId == patientId && a.patientName.isNotEmpty) {
        return a.patientName;
      }
    }
    return patientId;
  }

  @override
  Widget build(BuildContext context) {
    final patientIds = prescriptionStore.patientsGrantingAccess(widget.doctorId);

    if (patientIds.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            'No patients have shared their prescriptions with you yet. They appear here after an appointment with you is approved and they give you access.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: patientIds.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, i) {
        final id = patientIds[i];
        return ListTile(
          tileColor: const Color(0xFFF4F7FB),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          leading: const CircleAvatar(
            backgroundColor: Color(0xFFDCE6FF),
            child: Icon(Icons.person, color: Color(0xFF102A66)),
          ),
          title: Text(
            _nameFor(id),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: const Text('Prescription shared with you'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PrescriptionsScreen(patientId: id, isDoctor: true),
              ),
            );
            if (mounted) setState(() {});
          },
        );
      },
    );
  }
}

// ---------- Profile ----------

class _ProfileTab extends StatefulWidget {
  final String doctorId;

  const _ProfileTab({required this.doctorId});

  @override
  State<_ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<_ProfileTab> {
  Future<void> _editProfile(BuildContext context, Doctor doctor, AppUser user) async {
    final nameCtrl = TextEditingController(text: doctor.name);
    final phoneCtrl = TextEditingController(text: doctor.phone);
    final addressCtrl = TextEditingController(text: doctor.homeAddress);
    final specialtyCtrl = TextEditingController(text: doctor.specialty);
    final licenseCtrl = TextEditingController(text: doctor.licenseNumber);
    final bioCtrl = TextEditingController(text: doctor.biography);
    final qualCtrl = TextEditingController(text: doctor.qualifications.join(', '));
    final expCtrl = TextEditingController(text: doctor.yearsOfExperience.toString());
    final hospitalCtrl = TextEditingController(text: doctor.hospitalAffiliation);
    final chamberCtrl = TextEditingController(text: doctor.chamberAddress);
    final assistantCtrl = TextEditingController(text: doctor.assistantPhone);
    String gender = doctor.gender.isNotEmpty ? doctor.gender : 'Other';
    DateTime dob = doctor.dateOfBirth ?? DateTime(1980, 1, 1);

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Edit Doctor Profile'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Full Name *')),
                const SizedBox(height: 10),
                TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: 'Phone Number')),
                const SizedBox(height: 10),
                TextField(controller: addressCtrl, decoration: const InputDecoration(labelText: 'Home Address')),
                const SizedBox(height: 10),
                TextField(controller: specialtyCtrl, decoration: const InputDecoration(labelText: 'Specialization *')),
                const SizedBox(height: 10),
                TextField(controller: licenseCtrl, decoration: const InputDecoration(labelText: 'License Number *')),
                const SizedBox(height: 10),
                TextField(controller: bioCtrl, maxLines: 2, decoration: const InputDecoration(labelText: 'Biography')),
                const SizedBox(height: 10),
                TextField(controller: qualCtrl, decoration: const InputDecoration(labelText: 'Qualifications (comma separated)')),
                const SizedBox(height: 10),
                TextField(controller: expCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Years of Experience')),
                const SizedBox(height: 10),
                TextField(controller: hospitalCtrl, decoration: const InputDecoration(labelText: 'Hospital/Clinic Affiliation')),
                const SizedBox(height: 10),
                TextField(controller: chamberCtrl, decoration: const InputDecoration(labelText: 'Chamber Address')),
                const SizedBox(height: 10),
                TextField(controller: assistantCtrl, decoration: const InputDecoration(labelText: 'Assistant Contact Phone')),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: ['Male', 'Female', 'Other'].contains(gender) ? gender : 'Other',
                  items: ['Male', 'Female', 'Other'].map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                  onChanged: (v) => setDialogState(() => gender = v ?? 'Other'),
                  decoration: const InputDecoration(labelText: 'Gender'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (nameCtrl.text.trim().isEmpty || specialtyCtrl.text.trim().isEmpty || licenseCtrl.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please fill in required fields.')),
                  );
                  return;
                }
                try {
                  await authService.updateProfile(
                    email: user.id,
                    profile: UserProfile(
                      name: nameCtrl.text.trim(),
                      phone: phoneCtrl.text.trim(),
                      dateOfBirth: dob,
                      specialty: specialtyCtrl.text.trim(),
                      licenseNumber: licenseCtrl.text.trim(),
                      gender: gender,
                      homeAddress: addressCtrl.text.trim(),
                      biography: bioCtrl.text.trim(),
                      qualifications: qualCtrl.text.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList(),
                      yearsOfExperience: int.tryParse(expCtrl.text.trim()) ?? 0,
                      hospitalAffiliation: hospitalCtrl.text.trim(),
                      chamberAddress: chamberCtrl.text.trim(),
                      assistantPhone: assistantCtrl.text.trim(),
                    ),
                  );
                  if (!context.mounted) return;
                  Navigator.pop(ctx);
                  setState(() {});
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Profile updated successfully.')),
                  );
                } catch (e) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(e.toString())),
                  );
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _changePassword(BuildContext context, String email) async {
    final currentCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    bool obscureCurrent = true;
    bool obscureNew = true;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Change Password'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: currentCtrl,
                  obscureText: obscureCurrent,
                  decoration: InputDecoration(
                    labelText: 'Current Password',
                    suffixIcon: IconButton(
                      icon: Icon(obscureCurrent ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setState(() => obscureCurrent = !obscureCurrent),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: newCtrl,
                  obscureText: obscureNew,
                  decoration: InputDecoration(
                    labelText: 'New Password',
                    suffixIcon: IconButton(
                      icon: Icon(obscureNew ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setState(() => obscureNew = !obscureNew),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: confirmCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Confirm New Password'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (newCtrl.text != confirmCtrl.text) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('New passwords do not match.')),
                  );
                  return;
                }
                try {
                  await authService.changePassword(
                    email: email,
                    currentPassword: currentCtrl.text,
                    newPassword: newCtrl.text,
                  );
                  if (!context.mounted) return;
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Password changed successfully.')),
                  );
                } on AuthException catch (e) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(e.message)),
                  );
                }
              },
              child: const Text('Update Password'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = authService.currentUser;
    final doctor = clinicStore.doctorById(widget.doctorId);
    final verified = clinicStore.isVerified(widget.doctorId);
    final statusColor = verified ? Colors.green : Colors.orange;

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircleAvatar(
                radius: 40,
                backgroundColor: Color(0xFFDCE6FF),
                child: Icon(Icons.person, size: 40, color: Color(0xFF102A66)),
              ),
              const SizedBox(height: 16),
              Text(
                user?.name ?? '',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                doctor?.specialty ?? '',
                style: TextStyle(color: Colors.grey[700]),
              ),
              const SizedBox(height: 4),
              Text(user?.id ?? '', style: TextStyle(color: Colors.grey[700])),
              if (doctor != null && doctor.licenseNumber.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  'License: ${doctor.licenseNumber}',
                  style: TextStyle(color: Colors.grey[700]),
                ),
              ],
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  verified ? 'Verified doctor' : 'Verification pending',
                  style: TextStyle(
                    color: verified ? kTextSuccess : kTextWarning,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (kDebugMode && !verified) ...[
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () {
                    clinicStore.verifyDoctor(widget.doctorId);
                    setState(() {});
                  },
                  child: const Text('Mark as verified (test only)'),
                ),
              ],
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton.icon(
                    onPressed: () {
                      if (doctor != null && user != null) {
                        _editProfile(context, doctor, user);
                      }
                    },
                    icon: const Icon(Icons.edit),
                    label: const Text('Edit Profile'),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: () {
                      if (user != null) {
                        _changePassword(context, user.id);
                      }
                    },
                    icon: const Icon(Icons.lock_outline),
                    label: const Text('Password'),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              OutlinedButton.icon(
                onPressed: () => _logout(context),
                icon: const Icon(Icons.logout),
                label: const Text('Log out'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

void _logout(BuildContext context) {
  authService.logout();
  Navigator.pushAndRemoveUntil(
    context,
    MaterialPageRoute(builder: (_) => const LoginScreen()),
    (_) => false,
  );
}
