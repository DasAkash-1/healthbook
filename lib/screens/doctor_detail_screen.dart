import 'package:flutter/material.dart';

import '../models/app_models.dart';
import '../services/auth_service.dart';
import '../services/clinic_store.dart';
import '../utils/formatters.dart';

class DoctorDetailScreen extends StatefulWidget {
  final Doctor doctor;

  const DoctorDetailScreen({super.key, required this.doctor});

  @override
  State<DoctorDetailScreen> createState() => _DoctorDetailScreenState();
}

// What the patient entered on the first booking step. Both parts are optional.
class _BookingDetails {
  final String visitType;
  final String note;

  const _BookingDetails({this.visitType = '', this.note = ''});
}

class _DoctorDetailScreenState extends State<DoctorDetailScreen> {
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

  Widget _summaryLine(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }

  // Step 2: show everything again before the request is sent.
  // Returns true to send, false to go back and edit, null if closed.
  Future<bool?> _confirmRequest(DateTime start, _BookingDetails details) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Send this request?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _summaryLine('Doctor', widget.doctor.name),
            _summaryLine('Day', formatDay(start)),
            _summaryLine('Time', formatSlot(start)),
            _summaryLine(
              'Visit type',
              details.visitType.isEmpty ? 'Not specified' : details.visitType,
            ),
            _summaryLine('Note', details.note.isEmpty ? 'None' : details.note),
            const SizedBox(height: 8),
            Text(
              'The doctor sees this before approving or rejecting. You can '
              'cancel the request until it is approved. After that you will '
              'need to give a reason.',
              style: TextStyle(color: Colors.grey[700], fontSize: 13),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Back'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Send request'),
          ),
        ],
      ),
    );
  }

  Future<void> _requestSlot(DateTime start) async {
    final user = authService.currentUser;
    if (user == null) return;

    // Step 1: visit type and note. Step 2: review. "Back" returns to step 1.
    var details = const _BookingDetails();
    while (true) {
      final entered = await showDialog<_BookingDetails>(
        context: context,
        builder: (_) => _BookingDialog(start: start, initial: details),
      );
      if (entered == null || !mounted) return;
      details = entered;

      final send = await _confirmRequest(start, details);
      if (send == null || !mounted) return;
      if (send) break;
    }

    try {
      clinicStore.requestAppointment(
        patientId: user.id,
        patientName: user.name,
        doctorId: widget.doctor.id,
        start: start,
        visitType: details.visitType,
        note: details.note,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Request sent. Waiting for the doctor to approve.'),
        ),
      );
      setState(() {});
    } on BookingException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final verified = clinicStore.isVerified(widget.doctor.id);
    final slots = clinicStore.availableSlotsOn(widget.doctor.id, _selectedDay);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(widget.doctor.name),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              widget.doctor.specialty,
              style: TextStyle(fontSize: 16, color: Colors.grey[700]),
            ),
            const SizedBox(height: 20),
            if (!verified)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Verification pending. This doctor cannot take bookings yet.',
                ),
              )
            else ...[
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
              const SizedBox(height: 20),
              const Text(
                'Available 20-minute slots',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 10),
              if (slots.isEmpty)
                Text(
                  'No open slots on this day.',
                  style: TextStyle(color: Colors.grey[700]),
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final s in slots)
                      OutlinedButton(
                        onPressed: () => _requestSlot(s),
                        child: Text(formatSlot(s)),
                      ),
                  ],
                ),
            ],
          ],
        ),
      ),
    );
  }
}

// Step 1 of booking: optional visit type and note.
class _BookingDialog extends StatefulWidget {
  final DateTime start;
  final _BookingDetails initial;

  const _BookingDialog({required this.start, required this.initial});

  @override
  State<_BookingDialog> createState() => _BookingDialogState();
}

class _BookingDialogState extends State<_BookingDialog> {
  late final TextEditingController _noteCtrl =
      TextEditingController(text: widget.initial.note);
  late String _visitType = widget.initial.visitType;

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Request ${formatSlot(widget.start)}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Both are optional. Your doctor sees them before deciding.',
              style: TextStyle(color: Colors.grey[700], fontSize: 13),
            ),
            const SizedBox(height: 12),
            const Text(
              'Visit type',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final type in kVisitTypes)
                  ChoiceChip(
                    label: Text(type),
                    selected: _visitType == type,
                    // Tap the chosen chip again to clear it.
                    onSelected: (selected) =>
                        setState(() => _visitType = selected ? type : ''),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _noteCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Note for the doctor (optional)',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(
            context,
            _BookingDetails(
              visitType: _visitType,
              note: _noteCtrl.text.trim(),
            ),
          ),
          child: const Text('Review'),
        ),
      ],
    );
  }
}
