import 'package:flutter/material.dart';

import '../models/prescription_models.dart';
import '../services/auth_service.dart';
import '../services/prescription_store.dart';
import '../utils/formatters.dart';

// Shows every doctor change to the prescription, newest first.
// Visible to the patient and to doctors with access.
class PrescriptionHistoryScreen extends StatelessWidget {
  final String patientId;

  const PrescriptionHistoryScreen({super.key, required this.patientId});

  @override
  Widget build(BuildContext context) {
    final viewerId = authService.currentUser?.id ?? '';

    List<PrescriptionVersion> versions;
    String? error;
    try {
      versions = prescriptionStore.historyFor(patientId, viewerId);
    } on PrescriptionException catch (e) {
      versions = const [];
      error = e.message;
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('Prescription history'),
      ),
      body: error != null
          ? Center(child: Text(error))
          : versions.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Text(
                      'No changes yet. Changes made by your doctor will appear here.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(20),
                  itemCount: versions.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, i) {
                    final v = versions[i];
                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF4F7FB),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Version ${v.number} • ${formatDateTime(v.at)}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'By ${v.byName}',
                            style: TextStyle(color: Colors.grey[700]),
                          ),
                          const SizedBox(height: 6),
                          Text(v.summary),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}
