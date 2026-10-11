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
    final doctors = clinicStore.searchDoctors(
      query: _query,
      specialty: _specialty,
      availableOnly: _availableOnly,
    );

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
                  ? const Center(child: Text('No doctors match your search.'))
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: doctors.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, i) {
                        final doctor = doctors[i];
                        return ListTile(
                          tileColor: const Color(0xFFF4F7FB),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          leading: const CircleAvatar(
                            backgroundColor: Color(0xFFDCE6FF),
                            child: Icon(Icons.person, color: Color(0xFF102A66)),
                          ),
                          title: Text(
                            doctor.name,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(doctor.specialty),
                          trailing: const Icon(Icons.chevron_right),
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
