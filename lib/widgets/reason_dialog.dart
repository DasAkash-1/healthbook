import 'package:flutter/material.dart';

import '../models/app_models.dart';
import '../utils/app_colors.dart';

// Asks the person to pick a reason from [options] and, optionally, add details.
// Choosing "Other" means they must write the reason themselves.
// Returns the reason as text, or null if the dialog was closed without confirming.
Future<String?> askForReason(
  BuildContext context, {
  required String title,
  required String message,
  required List<String> options,
  required String confirmLabel,
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _ReasonDialog(
      title: title,
      message: message,
      options: options,
      confirmLabel: confirmLabel,
    ),
  );
}

// Stateful dialog managing preset reason selection, custom "Other" text, and inline errors.
class _ReasonDialog extends StatefulWidget {
  final String title;
  final String message;
  final List<String> options;
  final String confirmLabel;

  const _ReasonDialog({
    required this.title,
    required this.message,
    required this.options,
    required this.confirmLabel,
  });

  @override
  State<_ReasonDialog> createState() => _ReasonDialogState();
}

class _ReasonDialogState extends State<_ReasonDialog> {
  final _detailsCtrl = TextEditingController();
  String? _selected;
  String? _error;

  @override
  void dispose() {
    _detailsCtrl.dispose();
    super.dispose();
  }

  // Validates selection (and required custom text for "Other") before returning the reason.
  void _submit() {
    final selected = _selected;
    final details = _detailsCtrl.text.trim();

    if (selected == null) {
      setState(() => _error = 'Choose a reason.');
      return;
    }
    if (selected == kOtherReason && details.isEmpty) {
      setState(() => _error = 'Please write the reason.');
      return;
    }

    final reason = selected == kOtherReason
        ? details
        : (details.isEmpty ? selected : '$selected - $details');
    Navigator.pop(context, reason);
  }

  @override
  Widget build(BuildContext context) {
    final needsDetails = _selected == kOtherReason;

    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.message),
              const SizedBox(height: 8),
              // Render preset reason options as tappable rows.
              for (final option in widget.options)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(option),
                  trailing: Icon(
                    _selected == option
                        ? Icons.check_circle
                        : Icons.circle_outlined,
                    color: _selected == option
                        ? const Color(0xFF102A66)
                        : kTextMuted,
                  ),
                  onTap: () => setState(() {
                    _selected = option;
                    _error = null;
                  }),
                ),
              const SizedBox(height: 8),
              TextField(
                controller: _detailsCtrl,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText:
                      needsDetails ? 'Write the reason' : 'Details (optional)',
                ),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: kTextDanger),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Back'),
        ),
        TextButton(
          onPressed: _submit,
          child: Text(
            widget.confirmLabel,
            style: const TextStyle(color: kTextDanger),
          ),
        ),
      ],
    );
  }
}
