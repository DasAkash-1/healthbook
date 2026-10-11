import 'package:flutter/material.dart';

import '../models/prescription_models.dart';
import '../services/prescription_store.dart';

// Doctor only. Adds a new medication or edits an existing one.
class MedicationFormScreen extends StatefulWidget {
  final String patientId;
  final String doctorId;
  final Medication? existing;

  const MedicationFormScreen({
    super.key,
    required this.patientId,
    required this.doctorId,
    this.existing,
  });

  @override
  State<MedicationFormScreen> createState() => _MedicationFormScreenState();
}

class _MedicationFormScreenState extends State<MedicationFormScreen> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _doseCtrl;
  late final TextEditingController _instructionsCtrl;
  late final TextEditingController _remainingCtrl;
  late int _timesPerDay;

  @override
  void initState() {
    super.initState();
    final m = widget.existing;
    _nameCtrl = TextEditingController(text: m?.name ?? '');
    _doseCtrl = TextEditingController(text: m?.dose ?? '');
    _instructionsCtrl = TextEditingController(text: m?.instructions ?? '');
    _remainingCtrl = TextEditingController(text: (m?.remainingDoses ?? 30).toString());
    _timesPerDay = m?.timesPerDay ?? 1;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _doseCtrl.dispose();
    _instructionsCtrl.dispose();
    _remainingCtrl.dispose();
    super.dispose();
  }

  void _save() {
    final remaining = int.tryParse(_remainingCtrl.text.trim());
    if (remaining == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter the number of doses left.')),
      );
      return;
    }

    try {
      final existing = widget.existing;
      if (existing == null) {
        prescriptionStore.addMedication(
          patientId: widget.patientId,
          doctorId: widget.doctorId,
          name: _nameCtrl.text,
          dose: _doseCtrl.text,
          timesPerDay: _timesPerDay,
          instructions: _instructionsCtrl.text,
          remainingDoses: remaining,
        );
      } else {
        prescriptionStore.updateMedication(
          patientId: widget.patientId,
          doctorId: widget.doctorId,
          updated: Medication(
            id: existing.id,
            name: _nameCtrl.text.trim(),
            dose: _doseCtrl.text.trim(),
            timesPerDay: _timesPerDay,
            instructions: _instructionsCtrl.text.trim(),
            remainingDoses: remaining,
          ),
        );
      }
      Navigator.pop(context);
    } on PrescriptionException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    }
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: Colors.grey.shade100,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(isEdit ? 'Edit medication' : 'Add medication'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _field(controller: _nameCtrl, label: 'Medicine name'),
            _field(controller: _doseCtrl, label: 'Dose (for example, 500 mg)'),
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: 'Times per day',
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: _timesPerDay,
                    isExpanded: true,
                    items: const [
                      DropdownMenuItem(value: 1, child: Text('1')),
                      DropdownMenuItem(value: 2, child: Text('2')),
                      DropdownMenuItem(value: 3, child: Text('3')),
                      DropdownMenuItem(value: 4, child: Text('4')),
                    ],
                    onChanged: (v) => setState(() => _timesPerDay = v ?? 1),
                  ),
                ),
              ),
            ),
            _field(
              controller: _remainingCtrl,
              label: 'Doses left',
              keyboardType: TextInputType.number,
            ),
            _field(
              controller: _instructionsCtrl,
              label: 'Instructions (optional)',
              maxLines: 2,
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _save,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: Text(
                isEdit ? 'Save changes' : 'Add medication',
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
