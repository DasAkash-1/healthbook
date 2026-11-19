// Patient appointments screen showing booking status, doctor notes/reasons,
// and cancellation controls (requiring a reason once approved).
import 'package:flutter/material.dart';

import '../models/app_models.dart';
import '../services/auth_service.dart';
import '../services/clinic_store.dart';
import '../utils/formatters.dart';
import '../widgets/reason_dialog.dart';
import 'doctor_directory_screen.dart';
import '../utils/app_colors.dart';

class MyAppointmentsScreen extends StatefulWidget {
  const MyAppointmentsScreen({super.key});

  @override
  State<MyAppointmentsScreen> createState() => _MyAppointmentsScreenState();
}

class _MyAppointmentsScreenState extends State<MyAppointmentsScreen> {
  // Prompts for a cancellation reason if already approved, or a simple confirmation if pending.
  Future<void> _confirmCancel(Appointment a) async {
    final user = authService.currentUser;
    if (user == null) return;

    var reason = '';
    if (a.status == AppointmentStatus.approved) {
      // The doctor already approved this visit, so the doctor needs to know why.
      final picked = await askForReason(
        context,
        title: 'Cancel this appointment?',
        message: 'This appointment is approved. Please tell the doctor why you are cancelling.',
        options: kPatientCancelReasons,
        confirmLabel: 'Cancel appointment',
      );
      if (picked == null || !mounted) return;
      reason = picked;
    } else {
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
              child: const Text('Cancel request', style: TextStyle(color: kTextDanger)),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }

    try {
      clinicStore.cancelAppointment(a.id, user.id, reason: reason);
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
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'No appointments yet. Find a doctor and request a time that suits you.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const DoctorDirectoryScreen()),
                      ).then((_) {
                        if (mounted) setState(() {});
                      }),
                      child: const Text('Find a doctor'),
                    ),
                  ],
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

  // Renders an individual appointment card with status chip, notes/reasons, and cancel action.
  Widget _buildCard(Appointment a) {
    final doctor = clinicStore.doctorById(a.doctorId);
    // Pending and approved visits can be cancelled until they start.
    final canCancel = a.isActive && a.start.isAfter(DateTime.now());

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
          if (a.visitType.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text('Visit type: ${a.visitType}', style: TextStyle(color: Colors.grey[700])),
          ],
          if (a.note.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text('Note: ${a.note}', style: TextStyle(color: Colors.grey[700])),
          ],
          if (a.status == AppointmentStatus.approved && a.approvalNote.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Note from the doctor: ${a.approvalNote}',
              style: const TextStyle(color: kTextMuted),
            ),
          ],
          if (a.status == AppointmentStatus.rejected && a.reason.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Reason from the doctor: ${a.reason}',
              style: TextStyle(color: Colors.red[800]),
            ),
          ],
          if (a.status == AppointmentStatus.cancelled && a.reason.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text('Your reason: ${a.reason}', style: TextStyle(color: Colors.grey[700])),
          ],
          if (canCancel) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => _confirmCancel(a),
                child: Text(
                  a.status == AppointmentStatus.approved
                      ? 'Cancel appointment'
                      : 'Cancel request',
                  style: const TextStyle(color: kTextDanger),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// Badge showing whether an appointment is pending, approved, rejected, or cancelled.
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
    // Darker shades for the text, so it stays readable on the light tint.
    final textColor = switch (status) {
      AppointmentStatus.pending => kTextWarning,
      AppointmentStatus.approved => kTextSuccess,
      AppointmentStatus.rejected => kTextDanger,
      AppointmentStatus.cancelled => kTextMuted,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(color: textColor, fontWeight: FontWeight.w600, fontSize: 13),
      ),
    );
  }
}
