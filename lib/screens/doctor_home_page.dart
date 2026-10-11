import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/app_models.dart';
import '../services/auth_service.dart';
import '../services/clinic_store.dart';
import '../services/prescription_store.dart';
import '../utils/formatters.dart';
import 'login_screen.dart';
import 'prescriptions_screen.dart';

// Hours a doctor can open, as start times (08:00 to 16:00).
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
        unselectedItemColor: Colors.grey,
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
  void _act(Appointment a, {required bool approve}) {
    try {
      if (approve) {
        clinicStore.approveAppointment(a.id, widget.doctorId);
      } else {
        clinicStore.rejectAppointment(a.id, widget.doctorId);
      }
      setState(() {});
    } on BookingException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
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

  Widget _requestCard(Appointment a, {required bool isPending}) {
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
          Text(
            name,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 6),
          Text(
            '${formatDay(a.start)} • ${formatSlot(a.start)}',
            style: TextStyle(color: Colors.grey[800]),
          ),
          if (a.note.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text('Note: ${a.note}', style: TextStyle(color: Colors.grey[700])),
          ],
          if (isPending) ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  onPressed: () => _act(a, approve: false),
                  child: const Text('Reject'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () => _act(a, approve: true),
                  child: const Text('Approve'),
                ),
              ],
            ),
          ],
          if (!isPending)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'Approved',
                style: TextStyle(color: Colors.green, fontWeight: FontWeight.w600),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final all = clinicStore.appointmentsForDoctor(widget.doctorId);
    final pending =
        all.where((a) => a.status == AppointmentStatus.pending).toList();
    final approved =
        all.where((a) => a.status == AppointmentStatus.approved).toList();

    if (pending.isEmpty && approved.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            'No requests yet. Patients who book with you will appear here.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        if (pending.isNotEmpty) ...[
          _sectionTitle('Pending approval'),
          for (final a in pending) _requestCard(a, isPending: true),
        ],
        if (approved.isNotEmpty) ...[
          _sectionTitle('Approved'),
          for (final a in approved) _requestCard(a, isPending: false),
        ],
      ],
    );
  }
}

// ---------- Schedule ----------

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

  void _toggle(DateTime hour, {required bool open}) {
    try {
      clinicStore.setHourOpen(widget.doctorId, hour, open);
      setState(() {});
    } on BookingException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    }
  }

  Widget _hourTile(DateTime hour, DateTime now) {
    final booked = clinicStore.isHourBooked(widget.doctorId, hour);
    final open = clinicStore.isHourOpen(widget.doctorId, hour);
    final passed = !hour.isAfter(now);

    final String subtitle;
    if (passed) {
      subtitle = 'Passed';
    } else if (booked) {
      subtitle = 'Booked by a patient';
    } else if (open) {
      subtitle = 'Open for booking';
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
        trailing: Switch(
          value: open,
          onChanged: (passed || booked)
              ? null
              : (v) => _toggle(hour, open: v),
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
          'Turn hours on to offer them to patients. Booked hours cannot be turned off.',
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
            'No patients have shared their prescriptions with you yet.',
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
  @override
  Widget build(BuildContext context) {
    final user = authService.currentUser;
    final doctor = clinicStore.doctorById(widget.doctorId);
    final verified = clinicStore.isVerified(widget.doctorId);
    final statusColor = verified ? Colors.green : Colors.orange;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Center(
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
                style: TextStyle(color: statusColor, fontWeight: FontWeight.w600),
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
            const SizedBox(height: 32),
            OutlinedButton.icon(
              onPressed: () => _logout(context),
              icon: const Icon(Icons.logout),
              label: const Text('Log out'),
            ),
          ],
        ),
      ),
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
