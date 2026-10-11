import 'package:flutter/material.dart';

import '../services/clinic_store.dart';
import '../services/prescription_store.dart';

// Patient only. Grant or revoke doctors' access to the prescription.
// Only doctors with an approved appointment can be granted access.
class DoctorAccessScreen extends StatefulWidget {
  final String patientId;

  const DoctorAccessScreen({super.key, required this.patientId});

  @override
  State<DoctorAccessScreen> createState() => _DoctorAccessScreenState();
}

class _DoctorAccessScreenState extends State<DoctorAccessScreen> {
  void _toggle(String doctorId, {required bool grant}) {
    try {
      if (grant) {
        prescriptionStore.grantAccess(widget.patientId, doctorId);
      } else {
        prescriptionStore.revokeAccess(widget.patientId, doctorId);
      }
      setState(() {});
    } on PrescriptionException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final doctorIds = prescriptionStore.eligibleDoctorIds(widget.patientId);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('Doctor access'),
      ),
      body: doctorIds.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'You can give access to doctors after an appointment with them is approved.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  'Doctors with access can add, change, and remove your medications. '
                  'You can revoke access at any time.',
                  style: TextStyle(color: Colors.grey[700]),
                ),
                const SizedBox(height: 16),
                for (final id in doctorIds)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF4F7FB),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: SwitchListTile(
                      title: Text(
                        clinicStore.doctorById(id)?.name ?? id,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        prescriptionStore.hasAccess(widget.patientId, id)
                            ? 'Has access'
                            : 'No access',
                      ),
                      value: prescriptionStore.hasAccess(widget.patientId, id),
                      onChanged: (v) => _toggle(id, grant: v),
                    ),
                  ),
              ],
            ),
    );
  }
}
