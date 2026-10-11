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

  Future<void> _requestSlot(DateTime start) async {
    final user = authService.currentUser;
    if (user == null) return;

    final note = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final controller = TextEditingController();
        return AlertDialog(
          title: Text('Request ${formatSlot(start)}'),
          content: TextField(
            controller: controller,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Note for the doctor (optional)',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, controller.text.trim()),
              child: const Text('Request'),
            ),
          ],
        );
      },
    );
    if (note == null || !mounted) return;

    try {
      clinicStore.requestAppointment(
        patientId: user.id,
        doctorId: widget.doctor.id,
        start: start,
        note: note,
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
        ),
      ),
    );
  }
}
