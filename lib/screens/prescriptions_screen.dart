import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../models/prescription_models.dart';
import '../services/auth_service.dart';
import '../services/prescription_store.dart';
import '../utils/formatters.dart';
import 'create_prescription_screen.dart';
import 'doctor_access_screen.dart';
import 'medical_history_screen.dart';
import 'prescription_history_screen.dart';
import 'test_results_screen.dart';

// Shared by the patient and by a doctor with access.
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

  Future<void> _uploadExternalPrescription() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (!mounted) return;

      if (result != null && result.files.single.path != null) {
        final file = result.files.single;
        prescriptionStore.uploadExternalPrescription(
          patientId: widget.patientId,
          fileName: file.name,
          filePath: file.path!,
        );
        _refresh();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('External prescription uploaded successfully.')),
        );
      }
    } catch (e) {
      _showError('Failed to pick PDF file: $e');
    }
  }

  void _removeExternal(PrescriptionRecord record) {
    prescriptionStore.removeExternalPrescription(
      patientId: widget.patientId,
      recordId: record.id,
    );
    _refresh();
  }

  void _viewExternal(PrescriptionRecord record) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('External Prescription'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('File Name: ${record.externalFileName ?? 'N/A'}', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Uploaded On: ${formatDateTime(record.date)}'),
            const SizedBox(height: 8),
            Text('File Path:\n${record.externalFilePath ?? 'N/A'}', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _openCreatePrescription() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CreatePrescriptionScreen(
          patientId: widget.patientId,
          doctorId: _viewerId,
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
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0D1B2A)),
                ),
              ),
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

  Widget _externalPrescriptionCard(PrescriptionRecord record, bool isPatient) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4EC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'External Prescription',
                  style: TextStyle(color: Colors.orange, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
              const Spacer(),
              if (isPatient)
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                  onPressed: () => _removeExternal(record),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            record.externalFileName ?? 'Prescription PDF',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          const SizedBox(height: 4),
          Text(
            'Uploaded on ${formatDateTime(record.date)}',
            style: TextStyle(color: Colors.grey[700], fontSize: 12),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              onPressed: () => _viewExternal(record),
              icon: const Icon(Icons.picture_as_pdf, size: 16),
              label: const Text('View PDF'),
            ),
          ),
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
        title: const Text('Prescriptions & History'),
        actions: [
          if (canView)
            IconButton(
              icon: const Icon(Icons.science_outlined),
              tooltip: 'Test Results',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => TestResultsScreen(patientId: widget.patientId, isDoctor: widget.isDoctor),
                ),
              ),
            ),
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
              onPressed: _openCreatePrescription,
              icon: const Icon(Icons.add),
              label: const Text('New Prescription'),
              backgroundColor: const Color(0xFF102A66),
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
    final externalRecords = prescriptionStore.externalPrescriptionsFor(widget.patientId);

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        if (isPatient) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Upload External Prescription',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0D1B2A)),
              ),
              ElevatedButton.icon(
                onPressed: _uploadExternalPrescription,
                icon: const Icon(Icons.upload_file, size: 16),
                label: const Text('Upload PDF'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF102A66),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Upload previous prescriptions from doctors outside HealthBook so your current doctor can review them.',
            style: TextStyle(color: Colors.grey[600], fontSize: 13),
          ),
          const SizedBox(height: 16),
        ],

        if (externalRecords.isNotEmpty) ...[
          const Text(
            'Patient Uploaded / External Prescriptions',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0D1B2A)),
          ),
          const SizedBox(height: 10),
          for (final record in externalRecords) _externalPrescriptionCard(record, isPatient),
          const SizedBox(height: 20),
        ],

        const Text(
          'HealthBook Medications',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0D1B2A)),
        ),
        const SizedBox(height: 10),
        if (medications.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text(
                isPatient
                    ? 'No medications prescribed yet. Your doctor can add them after you grant access.'
                    : 'No medications prescribed yet. Click "New Prescription" below.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600]),
              ),
            ),
          )
        else
          for (final m in medications) _medicationCard(m),
      ],
    );
  }
}
