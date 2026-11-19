import 'package:flutter/material.dart';

import '../models/checkup_report.dart';
import '../services/auth_service.dart';
import '../services/checkup_report_store.dart';
import '../utils/app_colors.dart';
import '../utils/formatters.dart';

// Displays doctor-authored checkup reports for [patientId].
// - Patients (and authorized doctors) view reports read-only.
// - A verified doctor with access can also write a new checkup report.
class CheckupReportsScreen extends StatefulWidget {
  final String patientId;
  final bool isDoctor;

  const CheckupReportsScreen({
    super.key,
    required this.patientId,
    this.isDoctor = false,
  });

  @override
  State<CheckupReportsScreen> createState() => _CheckupReportsScreenState();
}

class _CheckupReportsScreenState extends State<CheckupReportsScreen> {
  String get _viewerId => authService.currentUser?.id ?? '';

  void _refresh() {
    if (mounted) setState(() {});
  }

  // Opens a modal bottom sheet where an authorized doctor records a checkup report.
  Future<void> _openCreateReportSheet() async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _CreateCheckupReportSheet(
        patientId: widget.patientId,
        doctorId: _viewerId,
      ),
    );
    if (created == true) {
      _refresh();
    }
  }

  // Builds compact chips for any vitals that were entered on a report.
  List<Widget> _vitalsChips(CheckupReport r) {
    final items = <String>[];
    if (r.bloodPressure.isNotEmpty) items.add('BP: ${r.bloodPressure}');
    if (r.heartRateBpm != null) items.add('Pulse: ${r.heartRateBpm} bpm');
    if (r.temperatureC != null) items.add('Temp: ${r.temperatureC} C');
    if (r.weightKg != null) items.add('Weight: ${r.weightKg} kg');

    return items
        .map(
          (label) => Chip(
            label: Text(label, style: const TextStyle(fontSize: 12)),
            backgroundColor: Colors.white,
            side: BorderSide(color: Colors.grey.shade300),
            visualDensity: VisualDensity.compact,
          ),
        )
        .toList();
  }

  Widget _reportCard(CheckupReport r) {
    final chips = _vitalsChips(r);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F7FB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  r.chiefComplaintOrDiagnosis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0D1B2A),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${r.doctorName} (${r.specialty}) • ${formatDateTime(r.createdAt)}',
            style: const TextStyle(fontSize: 13, color: kTextMuted),
          ),
          if (chips.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 6, children: chips),
          ],
          if (r.clinicalNotes.isNotEmpty) ...[
            const SizedBox(height: 10),
            const Text(
              'Clinical notes',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            const SizedBox(height: 2),
            Text(r.clinicalNotes, style: TextStyle(color: Colors.grey[800])),
          ],
          if (r.followUpAdvice.isNotEmpty) ...[
            const SizedBox(height: 10),
            const Text(
              'Follow-up advice',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            const SizedBox(height: 2),
            Text(r.followUpAdvice, style: TextStyle(color: Colors.grey[800])),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final viewerId = _viewerId;
    final canView = checkupReportStore.canView(widget.patientId, viewerId);
    final canCreate = widget.isDoctor && canView;

    List<CheckupReport> reports = const [];
    if (canView) {
      reports = checkupReportStore.reportsFor(widget.patientId, viewerId);
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('Checkup Reports'),
      ),
      floatingActionButton: canCreate
          ? FloatingActionButton.extended(
              onPressed: _openCreateReportSheet,
              icon: const Icon(Icons.add),
              label: const Text('New Checkup Report'),
              backgroundColor: const Color(0xFF102A66),
              foregroundColor: Colors.white,
            )
          : null,
      body: !canView
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'Checkup reports are not shared with you.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : reports.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      canCreate
                          ? 'No checkup reports recorded yet. Tap "New Checkup Report" to add one.'
                          : 'No checkup reports recorded yet.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: kTextMuted),
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    for (final r in reports) _reportCard(r),
                  ],
                ),
    );
  }
}

// Form sheet used by a verified doctor with access to submit a new checkup report.
class _CreateCheckupReportSheet extends StatefulWidget {
  final String patientId;
  final String doctorId;

  const _CreateCheckupReportSheet({
    required this.patientId,
    required this.doctorId,
  });

  @override
  State<_CreateCheckupReportSheet> createState() =>
      _CreateCheckupReportSheetState();
}

class _CreateCheckupReportSheetState extends State<_CreateCheckupReportSheet> {
  final _diagnosisCtrl = TextEditingController();
  final _bpCtrl = TextEditingController();
  final _pulseCtrl = TextEditingController();
  final _tempCtrl = TextEditingController();
  final _weightCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _followUpCtrl = TextEditingController();

  @override
  void dispose() {
    _diagnosisCtrl.dispose();
    _bpCtrl.dispose();
    _pulseCtrl.dispose();
    _tempCtrl.dispose();
    _weightCtrl.dispose();
    _notesCtrl.dispose();
    _followUpCtrl.dispose();
    super.dispose();
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _submit() {
    // Parse optional numeric vitals only when the doctor typed something.
    int? pulse;
    if (_pulseCtrl.text.trim().isNotEmpty) {
      pulse = int.tryParse(_pulseCtrl.text.trim());
      if (pulse == null) {
        _showError('Heart rate must be a whole number (bpm).');
        return;
      }
    }

    double? temp;
    if (_tempCtrl.text.trim().isNotEmpty) {
      temp = double.tryParse(_tempCtrl.text.trim());
      if (temp == null) {
        _showError('Temperature must be a valid number (C).');
        return;
      }
    }

    double? weight;
    if (_weightCtrl.text.trim().isNotEmpty) {
      weight = double.tryParse(_weightCtrl.text.trim());
      if (weight == null) {
        _showError('Weight must be a valid number (kg).');
        return;
      }
    }

    try {
      checkupReportStore.createReport(
        patientId: widget.patientId,
        doctorId: widget.doctorId,
        chiefComplaintOrDiagnosis: _diagnosisCtrl.text,
        bloodPressure: _bpCtrl.text,
        heartRateBpm: pulse,
        temperatureC: temp,
        weightKg: weight,
        clinicalNotes: _notesCtrl.text,
        followUpAdvice: _followUpCtrl.text,
      );
      Navigator.pop(context, true);
    } on CheckupReportException catch (e) {
      _showError(e.message);
    }
  }

  InputDecoration _dec(String label, {String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      filled: true,
      fillColor: Colors.grey.shade100,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottomInset),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'New Checkup Report',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _diagnosisCtrl,
              maxLines: 2,
              decoration: _dec(
                'Diagnosis / Checkup summary *',
                hint: 'e.g. Seasonal viral fever, mild dehydration',
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _bpCtrl,
                    decoration: _dec('Blood pressure', hint: '120/80'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _pulseCtrl,
                    keyboardType: TextInputType.number,
                    decoration: _dec('Pulse (bpm)', hint: '76'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _tempCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: _dec('Temp (C)', hint: '37.0'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _weightCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: _dec('Weight (kg)', hint: '68.5'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notesCtrl,
              maxLines: 2,
              decoration: _dec('Clinical notes (optional)'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _followUpCtrl,
              decoration: _dec(
                'Follow-up advice (optional)',
                hint: 'e.g. Review after 5 days if fever persists',
              ),
            ),
            const SizedBox(height: 18),
            ElevatedButton(
              onPressed: _submit,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 15),
                backgroundColor: const Color(0xFF102A66),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Save Checkup Report',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
