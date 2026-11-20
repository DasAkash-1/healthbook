// Doctor profile and 7-day slot booking screen where patients select a day/slot,
// enter optional visit type and note details, review the summary, consultation fee, and send a request.
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

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

  Future<void> _callAssistant(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not launch dialer for $phone')),
      );
    }
  }

  Widget _summaryLine(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
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

  Future<bool?> _confirmRequest(DateTime start, _BookingDetails details, double fee) {
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
            _summaryLine('Consultation Fee', '৳${fee.toStringAsFixed(0)}'),
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
              style: TextStyle(color: Colors.grey[700], fontSize: 14),
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

    final fee = clinicStore.feeForSlot(widget.doctor.id, start);
    if (fee == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Consultation fee not specified for this time slot.')),
      );
      return;
    }

    var details = const _BookingDetails();
    while (true) {
      final entered = await showDialog<_BookingDetails>(
        context: context,
        builder: (_) => _BookingDialog(start: start, initial: details, fee: fee),
      );
      if (entered == null || !mounted) return;
      details = entered;

      final send = await _confirmRequest(start, details, fee);
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
            if (widget.doctor.hospitalAffiliation.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                widget.doctor.hospitalAffiliation,
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
            ],
            const SizedBox(height: 16),
            // Chamber address & Assistant contact card (Sample info notice)
            Container(
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
                      const Text(
                        'Chamber & Contact',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.blue.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'Sample Information',
                          style: TextStyle(fontSize: 11, color: Color(0xFF102A66), fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (widget.doctor.chamberAddress.isNotEmpty) ...[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.location_on, size: 18, color: Color(0xFF102A66)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            widget.doctor.chamberAddress,
                            style: const TextStyle(fontSize: 14, color: Color(0xFF0D1B2A)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                  if (widget.doctor.assistantPhone.isNotEmpty) ...[
                    InkWell(
                      onTap: () => _callAssistant(widget.doctor.assistantPhone),
                      child: Row(
                        children: [
                          const Icon(Icons.phone, size: 18, color: Color(0xFF102A66)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Assistant: ${widget.doctor.assistantPhone}',
                              style: const TextStyle(
                                fontSize: 14,
                                color: Color(0xFF102A66),
                                decoration: TextDecoration.underline,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
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
                'Available 20-minute slots & Consultation Fees',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 10),
              if (slots.isEmpty)
                Text(
                  'No open slots on this day. Try another day.',
                  style: TextStyle(color: Colors.grey[700]),
                )
              else
                Column(
                  children: [
                    for (final s in slots) ...[
                      Builder(builder: (context) {
                        final fee = clinicStore.feeForSlot(widget.doctor.id, s);
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF4F7FB),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Text(
                                formatSlot(s),
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                              ),
                              const Spacer(),
                              Text(
                                fee != null ? '৳${fee.toStringAsFixed(0)}' : 'Fee not specified',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: fee != null ? const Color(0xFF102A66) : Colors.grey,
                                ),
                              ),
                              const SizedBox(width: 12),
                              ElevatedButton(
                                onPressed: fee != null ? () => _requestSlot(s) : null,
                                child: const Text('Book'),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ],
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _BookingDialog extends StatefulWidget {
  final DateTime start;
  final _BookingDetails initial;
  final double fee;

  const _BookingDialog({required this.start, required this.initial, required this.fee});

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
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFDCE6FF),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Text('Consultation Fee: ', style: TextStyle(fontWeight: FontWeight.bold)),
                  Text('৳${widget.fee.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF102A66))),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Both are optional. Your doctor sees them before deciding.',
              style: TextStyle(color: Colors.grey[700], fontSize: 14),
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
