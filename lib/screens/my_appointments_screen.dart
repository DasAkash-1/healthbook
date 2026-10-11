import 'package:flutter/material.dart';

import '../models/app_models.dart';
import '../services/auth_service.dart';
import '../services/clinic_store.dart';
import '../utils/formatters.dart';

class MyAppointmentsScreen extends StatefulWidget {
  const MyAppointmentsScreen({super.key});

  @override
  State<MyAppointmentsScreen> createState() => _MyAppointmentsScreenState();
}

class _MyAppointmentsScreenState extends State<MyAppointmentsScreen> {
  Future<void> _confirmCancel(Appointment a) async {
    final user = authService.currentUser;
    if (user == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel this request?'),
        content: const Text('The slot will be released for other patients.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cancel request', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      clinicStore.cancelAppointment(a.id, user.id);
      setState(() {});
    } on BookingException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = authService.currentUser;
    final appointments = user == null
        ? <Appointment>[]
        : clinicStore.appointmentsForPatient(user.id);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('Appointments'),
      ),
      body: appointments.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'No appointments yet. Find a doctor to book one.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(20),
              itemCount: appointments.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, i) => _buildCard(appointments[i]),
            ),
    );
  }

  Widget _buildCard(Appointment a) {
    final doctor = clinicStore.doctorById(a.doctorId);
    final canCancel = a.status == AppointmentStatus.pending;

    return Container(
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
                  doctor?.name ?? 'Doctor',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
              _StatusChip(status: a.status),
            ],
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
          if (canCancel) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => _confirmCancel(a),
                child: const Text(
                  'Cancel request',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final AppointmentStatus status;

  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final label = switch (status) {
      AppointmentStatus.pending => 'Pending',
      AppointmentStatus.approved => 'Approved',
      AppointmentStatus.rejected => 'Rejected',
      AppointmentStatus.cancelled => 'Cancelled',
    };
    final color = switch (status) {
      AppointmentStatus.pending => Colors.orange,
      AppointmentStatus.approved => Colors.green,
      AppointmentStatus.rejected => Colors.red,
      AppointmentStatus.cancelled => Colors.grey,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12),
      ),
    );
  }
}
