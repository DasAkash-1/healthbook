import 'package:flutter/material.dart';

import '../models/prescription_models.dart';
import '../services/auth_service.dart';
import '../services/prescription_store.dart';
import 'doctor_access_screen.dart';
import 'medical_history_screen.dart';
import 'medication_form_screen.dart';
import 'prescription_history_screen.dart';

// Shared by the patient and by a doctor with access.
// The patient can only log doses and manage access. Doctors manage medications.
class PrescriptionsScreen extends StatefulWidget {
  final String patientId;
  final bool isDoctor;

  const PrescriptionsScreen({
    super.key,
    required this.patientId,
    this.isDoctor = false,
  });

  @override
  State<PrescriptionsScreen> createState() => _PrescriptionsScreenState();
}

class _PrescriptionsScreenState extends State<PrescriptionsScreen> {
  String get _viewerId => authService.currentUser?.id ?? '';

  void _refresh() {
    if (mounted) setState(() {});
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  void _logDose(Medication m, {required bool taken}) {
    try {
      prescriptionStore.logDose(
        patientId: widget.patientId,
        medicationId: m.id,
        taken: taken,
      );
      _refresh();
    } on PrescriptionException catch (e) {
      _showError(e.message);
    }
  }

  void _removeMedication(Medication m) {
    try {
      prescriptionStore.removeMedication(
        patientId: widget.patientId,
        doctorId: _viewerId,
        medicationId: m.id,
      );
      _refresh();
    } on PrescriptionException catch (e) {
      _showError(e.message);
    }
  }

  Future<void> _openForm({Medication? existing}) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MedicationFormScreen(
          patientId: widget.patientId,
          doctorId: _viewerId,
          existing: existing,
        ),
      ),
    );
    _refresh();
  }

  Widget _medicationCard(Medication m) {
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
                  '${m.name} ${m.dose}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
              if (widget.isDoctor) ...[
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => _openForm(existing: m),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: () => _removeMedication(m),
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${m.timesPerDay} time(s) a day • ${m.remainingDoses} doses left',
            style: TextStyle(color: Colors.grey[800]),
          ),
          if (m.instructions.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(m.instructions, style: TextStyle(color: Colors.grey[700])),
          ],
          if (!widget.isDoctor) ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  onPressed: () => _logDose(m, taken: false),
                  child: const Text('Missed'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: m.remainingDoses > 0
                      ? () => _logDose(m, taken: true)
                      : null,
                  child: const Text('Taken'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final viewerId = _viewerId;
    final canView = prescriptionStore.canView(widget.patientId, viewerId);
    final isPatient = viewerId == widget.patientId;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('Prescriptions'),
        actions: [
          if (canView)
            IconButton(
              icon: const Icon(Icons.health_and_safety_outlined),
              tooltip: 'Medical history',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => MedicalHistoryScreen(patientId: widget.patientId),
                ),
              ),
            ),
          if (canView)
            IconButton(
              icon: const Icon(Icons.history),
              tooltip: 'History',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PrescriptionHistoryScreen(patientId: widget.patientId),
                ),
              ),
            ),
          if (isPatient)
            IconButton(
              icon: const Icon(Icons.manage_accounts_outlined),
              tooltip: 'Doctor access',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => DoctorAccessScreen(patientId: widget.patientId),
                ),
              ).then((_) => _refresh()),
            ),
        ],
      ),
      floatingActionButton: (widget.isDoctor && canView)
          ? FloatingActionButton.extended(
              onPressed: () => _openForm(),
              icon: const Icon(Icons.add),
              label: const Text('Add medication'),
            )
          : null,
      body: !canView
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'This prescription is not shared with you.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : _buildBody(isPatient),
    );
  }

  Widget _buildBody(bool isPatient) {
    final medications = prescriptionStore.medicationsFor(widget.patientId);

    if (medications.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            isPatient
                ? 'No medications yet. Your doctor can add them after you grant access.'
                : 'No medications yet. Add the first one below.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        if (isPatient)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(
              'Log each dose as taken or missed. Only your doctors can change medications.',
              style: TextStyle(color: Colors.grey[700]),
            ),
          ),
        for (final m in medications) _medicationCard(m),
      ],
    );
  }
}
