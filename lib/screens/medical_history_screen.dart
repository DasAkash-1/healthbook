import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/medical_history_store.dart';
import '../widgets/medical_history_form.dart';

// The patient can view and update their own history.
// A doctor with the patient's access can view it, read-only.
class MedicalHistoryScreen extends StatefulWidget {
  final String patientId;

  const MedicalHistoryScreen({super.key, required this.patientId});

  @override
  State<MedicalHistoryScreen> createState() => _MedicalHistoryScreenState();
}

class _MedicalHistoryScreenState extends State<MedicalHistoryScreen> {
  final _controllers = MedicalHistoryControllers();
  String? _error;

  String get _viewerId => authService.currentUser?.id ?? '';
  bool get _isPatient => _viewerId == widget.patientId;

  @override
  void initState() {
    super.initState();
    try {
      final history = medicalHistoryStore.historyFor(widget.patientId, _viewerId);
      if (history != null) _controllers.fill(history);
    } on MedicalHistoryException catch (e) {
      _error = e.message;
    }
  }

  @override
  void dispose() {
    _controllers.dispose();
    super.dispose();
  }

  void _save() {
    try {
      medicalHistoryStore.save(
        patientId: widget.patientId,
        editorId: _viewerId,
        history: _controllers.toHistory(),
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Medical history saved.')),
      );
    } on MedicalHistoryException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('Medical History'),
      ),
      body: _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(_error!, textAlign: TextAlign.center),
              ),
            )
          : SafeArea(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Text(
                    _isPatient
                        ? 'Keep this up to date. Doctors with your access can read it, but cannot change it.'
                        : 'Read-only. Shared with you by the patient.',
                    style: TextStyle(color: Colors.grey[700]),
                  ),
                  const SizedBox(height: 16),
                  MedicalHistoryFields(
                    controllers: _controllers,
                    readOnly: !_isPatient,
                  ),
                  if (_isPatient)
                    ElevatedButton(
                      onPressed: _save,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text('Save', style: TextStyle(fontSize: 16)),
                    ),
                ],
              ),
            ),
    );
  }
}
