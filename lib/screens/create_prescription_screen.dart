import 'package:flutter/material.dart';

import '../models/prescription_models.dart';
import '../services/prescription_store.dart';

class CreatePrescriptionScreen extends StatefulWidget {
  final String patientId;
  final String doctorId;

  const CreatePrescriptionScreen({
    super.key,
    required this.patientId,
    required this.doctorId,
  });

  @override
  State<CreatePrescriptionScreen> createState() => _CreatePrescriptionScreenState();
}

class _CreatePrescriptionScreenState extends State<CreatePrescriptionScreen> {
  final List<_MedicationInputData> _medications = [];
  final List<_TestInputData> _tests = [];

  @override
  void initState() {
    super.initState();
    // Start with one empty medication row by default
    _addMedicationRow();
  }

  void _addMedicationRow() {
    setState(() {
      _medications.add(_MedicationInputData());
    });
  }

  void _removeMedicationRow(int index) {
    setState(() {
      _medications.removeAt(index);
    });
  }

  void _addTestRow() {
    setState(() {
      _tests.add(_TestInputData());
    });
  }

  void _removeTestRow(int index) {
    setState(() {
      _tests.removeAt(index);
    });
  }

  void _save() {
    // Validate medications
    final medsList = <Medication>[];
    for (int i = 0; i < _medications.length; i++) {
      final m = _medications[i];
      final name = m.nameCtrl.text.trim();
      final dose = m.doseCtrl.text.trim();
      final remaining = int.tryParse(m.remainingCtrl.text.trim()) ?? 30;

      if (name.isNotEmpty || dose.isNotEmpty) {
        if (name.isEmpty) {
          _showError('Medication #${i + 1}: Enter the medicine name.');
          return;
        }
        if (dose.isEmpty) {
          _showError('Medication #${i + 1}: Enter the dose.');
          return;
        }
        medsList.add(Medication(
          id: '',
          name: name,
          dose: dose,
          timesPerDay: m.timesPerDay,
          instructions: m.instructionsCtrl.text.trim(),
          remainingDoses: remaining,
        ));
      }
    }

    // Validate tests
    final testsList = <RecommendedTest>[];
    for (int i = 0; i < _tests.length; i++) {
      final t = _tests[i];
      final name = t.nameCtrl.text.trim();

      if (name.isNotEmpty) {
        testListAdd(testsList, name, t.instructionsCtrl.text.trim());
      }
    }

    if (medsList.isEmpty && testsList.isEmpty) {
      _showError('Please add at least one medication or recommended test.');
      return;
    }

    try {
      prescriptionStore.createPrescription(
        patientId: widget.patientId,
        doctorId: widget.doctorId,
        medications: medsList,
        recommendedTests: testsList,
      );
      Navigator.pop(context);
    } on PrescriptionException catch (e) {
      _showError(e.message);
    }
  }

  void testListAdd(List<RecommendedTest> list, String name, String instructions) {
    list.add(RecommendedTest(
      id: '',
      name: name,
      instructions: instructions,
      recommendingDoctorId: widget.doctorId,
      recommendingDoctorName: '',
      recommendedAt: DateTime.now(),
    ));
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('Create Prescription'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Medications Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Medications',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0D1B2A)),
                ),
                TextButton.icon(
                  onPressed: _addMedicationRow,
                  icon: const Icon(Icons.add),
                  label: const Text('Add Medicine'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_medications.isEmpty)
              Text('No medications added. Click "Add Medicine" above.', style: TextStyle(color: Colors.grey[600])),
            for (int i = 0; i < _medications.length; i++)
              _buildMedicationCard(i),

            const SizedBox(height: 24),

            // Recommended Tests Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Recommended Tests',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0D1B2A)),
                ),
                TextButton.icon(
                  onPressed: _addTestRow,
                  icon: const Icon(Icons.add),
                  label: const Text('Add Test'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_tests.isEmpty)
              Text('No tests recommended. Click "Add Test" above.', style: TextStyle(color: Colors.grey[600])),
            for (int i = 0; i < _tests.length; i++)
              _buildTestCard(i),

            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _save,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: const Color(0xFF102A66),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Submit Prescription', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMedicationCard(int index) {
    final m = _medications[index];
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Medicine #${index + 1}', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF102A66))),
              if (_medications.length > 1)
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                  onPressed: () => _removeMedicationRow(index),
                ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: m.nameCtrl,
            decoration: InputDecoration(
              labelText: 'Medicine name',
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: m.doseCtrl,
                  decoration: InputDecoration(
                    labelText: 'Dose (e.g. 500 mg)',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: m.remainingCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Doses left',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          InputDecorator(
            decoration: InputDecoration(
              labelText: 'Times per day',
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: m.timesPerDay,
                isExpanded: true,
                items: const [
                  DropdownMenuItem(value: 1, child: Text('1 time a day')),
                  DropdownMenuItem(value: 2, child: Text('2 times a day')),
                  DropdownMenuItem(value: 3, child: Text('3 times a day')),
                  DropdownMenuItem(value: 4, child: Text('4 times a day')),
                ],
                onChanged: (v) => setState(() => m.timesPerDay = v ?? 1),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: m.instructionsCtrl,
            maxLines: 2,
            decoration: InputDecoration(
              labelText: 'Instructions (optional)',
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTestCard(int index) {
    final t = _tests[index];
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Test #${index + 1}', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF102A66))),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                onPressed: () => _removeTestRow(index),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: t.nameCtrl,
            decoration: InputDecoration(
              labelText: 'Test name (e.g. Complete Blood Count)',
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: t.instructionsCtrl,
            maxLines: 2,
            decoration: InputDecoration(
              labelText: 'Instructions / Notes (optional)',
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
        ],
      ),
    );
  }
}

class _MedicationInputData {
  final TextEditingController nameCtrl = TextEditingController();
  final TextEditingController doseCtrl = TextEditingController();
  final TextEditingController instructionsCtrl = TextEditingController();
  final TextEditingController remainingCtrl = TextEditingController(text: '30');
  int timesPerDay = 1;
}

class _TestInputData {
  final TextEditingController nameCtrl = TextEditingController();
  final TextEditingController instructionsCtrl = TextEditingController();
}
