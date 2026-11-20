// Searchable, filterable doctor directory ordering verified doctors ahead of
// pending/unverified doctors and opening DoctorDetailScreen to book slots.
import 'package:flutter/material.dart';

import '../services/clinic_store.dart';
import 'doctor_detail_screen.dart';

class DoctorDirectoryScreen extends StatefulWidget {
  const DoctorDirectoryScreen({super.key});

  @override
  State<DoctorDirectoryScreen> createState() => _DoctorDirectoryScreenState();
}

class _DoctorDirectoryScreenState extends State<DoctorDirectoryScreen> {
  String _query = '';
  String? _specialty;
  bool _availableOnly = false;

  @override
  Widget build(BuildContext context) {
    final found = clinicStore.searchDoctors(
      query: _query,
      specialty: _specialty,
      availableOnly: _availableOnly,
    );
    // Verified doctors first. Doctors still waiting for verification are greyed out.
    final doctors = [
      ...found.where((d) => clinicStore.isVerified(d.id)),
      ...found.where((d) => !clinicStore.isVerified(d.id)),
    ];

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('Find a Doctor'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: TextField(
                onChanged: (v) => setState(() => _query = v),
                decoration: InputDecoration(
                  hintText: 'Search by name or specialty',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String?>(
                        value: _specialty,
                        isExpanded: true,
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('All specialties'),
                          ),
                          ...clinicStore.specialties.map(
                            (s) => DropdownMenuItem<String?>(
                              value: s,
                              child: Text(s),
                            ),
                          ),
                        ],
                        onChanged: (v) => setState(() => _specialty = v),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilterChip(
                    label: const Text('Available this week'),
                    selected: _availableOnly,
                    onSelected: (v) => setState(() => _availableOnly = v),
                  ),
                ],
              ),
            ),
            Expanded(
              child: doctors.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Text(
                          'No doctors match your search. Try a different name, or clear the filters.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: doctors.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, i) {
                        final doctor = doctors[i];
                        final verified = clinicStore.isVerified(doctor.id);
                        return ListTile(
                          enabled: verified,
                          tileColor: verified
                              ? const Color(0xFFF4F7FB)
                              : Colors.grey.shade100,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          leading: CircleAvatar(
                            backgroundColor: verified
                                ? const Color(0xFFDCE6FF)
                                : Colors.grey.shade300,
                            child: Icon(
                              Icons.person,
                              color: verified
                                  ? const Color(0xFF102A66)
                                  : Colors.grey,
                            ),
                          ),
                          title: Text(
                            doctor.name,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                verified
                                    ? doctor.specialty
                                    : '${doctor.specialty} • Verification pending',
                              ),
                              if (doctor.chamberAddress.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    const Icon(Icons.location_on_outlined, size: 14, color: Colors.grey),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        doctor.chamberAddress,
                                        style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                          trailing: verified ? const Icon(Icons.chevron_right) : null,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => DoctorDetailScreen(doctor: doctor),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
