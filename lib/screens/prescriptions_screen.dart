import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/prescription_models.dart';
import '../services/auth_service.dart';
import '../services/prescription_store.dart';
import '../services/reminder_schedule_store.dart';
import '../utils/formatters.dart';
import 'checkup_reports_screen.dart';
import 'create_prescription_screen.dart';
import 'doctor_access_screen.dart';
import 'medical_history_screen.dart';
import 'medication_form_screen.dart';
import 'prescription_history_screen.dart';
import 'test_results_screen.dart';
import '../utils/app_colors.dart';
import '../widgets/open_file_helper.dart';

// Shared screen for viewing a patient's prescriptions, medications, and records.
// - A patient views their own medications, logs doses (Taken/Missed), uploads external PDFs,
//   customizes daily reminder hours, and manages doctor access.
// - A verified doctor with access can create prescriptions, edit/remove medications,
//   and inspect medical history, test results, version history, and checkup reports.
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

  // Formats an hour integer like 9 -> "09:00" or 21 -> "21:00".
  String _formatHour(int hour) {
    final hh = hour.toString().padLeft(2, '0');
    return '$hh:00';
  }

  // Opens a dialog allowing the patient to customize reminder hours per daily frequency.
  Future<void> _openReminderTimesDialog() async {
    int selectedFreq = 2;
    List<int> draftHours = List<int>.from(reminderScheduleStore.hoursFor(selectedFreq));

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          void selectFreq(int f) {
            selectedFreq = f;
            draftHours = List<int>.from(reminderScheduleStore.hoursFor(f));
            setDialogState(() {});
          }

          Future<void> pickSlot(int slotIndex) async {
            final initialHour = draftHours[slotIndex];
            final picked = await showTimePicker(
              context: ctx,
              initialTime: TimeOfDay(hour: initialHour, minute: 0),
              helpText: 'Pick reminder hour (snap to hour)',
            );
            if (picked != null) {
              draftHours[slotIndex] = picked.hour;
              setDialogState(() {});
            }
          }

          return AlertDialog(
            title: const Text('Medicine Reminder Times'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Choose daily reminder hours by how often a medicine is taken:',
                    style: TextStyle(fontSize: 13, color: kTextMuted),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (int f = 1; f <= 4; f++)
                        ChoiceChip(
                          label: Text('${f}x/day'),
                          selected: selectedFreq == f,
                          onSelected: (_) => selectFreq(f),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  for (int i = 0; i < draftHours.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: OutlinedButton.icon(
                        onPressed: () => pickSlot(i),
                        icon: const Icon(Icons.alarm, size: 18),
                        label: Text('Dose ${i + 1}: ${_formatHour(draftHours[i])}'),
                      ),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  reminderScheduleStore.resetToDefault(timesPerDay: selectedFreq);
                  draftHours = List<int>.from(reminderScheduleStore.hoursFor(selectedFreq));
                  setDialogState(() {});
                },
                child: const Text('Reset'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  try {
                    reminderScheduleStore.setHoursFor(selectedFreq, draftHours);
                    Navigator.pop(ctx);
                    _refresh();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Updated ${selectedFreq}x/day reminder schedule.'),
                      ),
                    );
                  } on ReminderScheduleException catch (e) {
                    _showError(e.message);
                  }
                },
                child: const Text('Save'),
              ),
            ],
          );
        },
      ),
    );
  }

  // Records whether the patient took or missed a dose and updates remaining doses.
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

  // Lets a patient pick a PDF prescription from an outside clinic and attach it.
  Future<void> _uploadExternalPrescription() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      // The person closed the picker without choosing a file.
      if (!mounted || result == null) return;

      final file = result.files.single;
      final path = file.path;
      if (path == null) {
        _showError(
          'This file is not stored on your phone. Save it to your phone first, then choose it again.',
        );
        return;
      }

      prescriptionStore.uploadExternalPrescription(
        patientId: widget.patientId,
        fileName: file.name,
        filePath: path,
      );
      _refresh();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('External prescription uploaded successfully.')),
      );
    } on PlatformException catch (e) {
      debugPrint('File picker problem: $e');
      if (!mounted) return;
      _showError(
        'The file picker could not open. Check that Healthbook is allowed to use files on this phone, then try again.',
      );
    } on PrescriptionException catch (e) {
      if (!mounted) return;
      _showError(e.message);
    } catch (e) {
      debugPrint('Upload failed: $e');
      if (!mounted) return;
      _showError('Something went wrong while uploading the file. Please try again.');
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
    openUploadedFile(
      context,
      title: record.externalFileName ?? 'Prescription PDF',
      path: record.externalFilePath ?? '',
      subtitle: 'Uploaded ${formatDateTime(record.date)}',
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

  // Doctor only. The store checks that the doctor is verified and has the patient's access.
  Future<void> _editMedication(Medication m) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MedicationFormScreen(
          patientId: widget.patientId,
          doctorId: _viewerId,
          existing: m,
        ),
      ),
    );
    _refresh();
  }

  Future<void> _removeMedication(Medication m) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove this medication?'),
        content: Text(
          '${m.name} ${m.dose} will be removed from the prescription. '
          'The change is recorded in the prescription history.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove', style: TextStyle(color: kTextDanger)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

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

  Widget _medicationCard(PrescribedMedicationEntry entry) {
    final m = entry.medication;
    final doctorLabel = (entry.doctorName == null || entry.doctorName!.isEmpty)
        ? 'Doctor'
        : entry.doctorName!;
    final activeHours = reminderScheduleStore
        .hoursFor(m.timesPerDay)
        .map(_formatHour)
        .join(', ');

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
            'Prescribed by $doctorLabel • ${formatDay(entry.prescribedDate)}',
            style: const TextStyle(fontSize: 13, color: kTextMuted),
          ),
          const SizedBox(height: 4),
          Text(
            '${m.timesPerDay} time(s) a day ($activeHours) • ${m.remainingDoses} doses left',
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
          if (widget.isDoctor) ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _removeMedication(m),
                  icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                  label: const Text('Remove', style: TextStyle(color: kTextDanger)),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () => _editMedication(m),
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Edit'),
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
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'External Prescription',
                  style: TextStyle(color: kTextWarning, fontSize: 12, fontWeight: FontWeight.bold),
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
            style: TextStyle(color: Colors.grey[700], fontSize: 13),
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
          if (isPatient)
            IconButton(
              icon: const Icon(Icons.alarm_outlined),
              tooltip: 'Reminder times',
              onPressed: _openReminderTimesDialog,
            ),
          if (canView)
            IconButton(
              icon: const Icon(Icons.assignment_outlined),
              tooltip: 'Checkup reports',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CheckupReportsScreen(
                    patientId: widget.patientId,
                    isDoctor: widget.isDoctor,
                  ),
                ),
              ),
            ),
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
    final medicationEntries = prescriptionStore.prescribedMedicationsFor(widget.patientId);
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
          const Text(
            'Upload previous prescriptions from doctors outside HealthBook so your current doctor can review them.',
            style: TextStyle(color: kTextMuted, fontSize: 14),
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
        if (medicationEntries.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text(
                isPatient
                    ? 'No medications prescribed yet. Your doctor can add them after you grant access.'
                    : 'No medications prescribed yet. Click "New Prescription" below.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: kTextMuted),
              ),
            ),
          )
        else
          for (final entry in medicationEntries) _medicationCard(entry),
      ],
    );
  }
}
