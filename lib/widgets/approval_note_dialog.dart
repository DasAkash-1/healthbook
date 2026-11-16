import 'package:flutter/material.dart';

import '../services/clinic_store.dart';
import '../utils/app_colors.dart';

// Asked when a doctor approves a request. The note is optional.
// Returns the note ('' if left empty), or null if the doctor closed the dialog.
Future<String?> askForApprovalNote(
  BuildContext context, {
  required String patientName,
  required String when,
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _ApprovalNoteDialog(patientName: patientName, when: when),
  );
}

class _ApprovalNoteDialog extends StatefulWidget {
  final String patientName;
  final String when;

  const _ApprovalNoteDialog({required this.patientName, required this.when});

  @override
  State<_ApprovalNoteDialog> createState() => _ApprovalNoteDialogState();
}

class _ApprovalNoteDialogState extends State<_ApprovalNoteDialog> {
  final _noteCtrl = TextEditingController();

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Approve this request?'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${widget.patientName} • ${widget.when}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            const Text(
              'Once approved, only the patient can cancel.',
              style: TextStyle(fontSize: 14, color: kTextMuted),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _noteCtrl,
              maxLines: 3,
              maxLength: kMaxApprovalNoteLength,
              decoration: const InputDecoration(
                labelText: 'Note for the patient (optional)',
                hintText: 'For example: bring your previous reports',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Back'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, _noteCtrl.text.trim()),
          child: const Text('Approve'),
        ),
      ],
    );
  }
}
