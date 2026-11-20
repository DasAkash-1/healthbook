// Patient home shell providing the health dashboard, Records summaries,
// Appointments view, and enhanced Profile tab (Emergency Medical Card, personal info editing,
// vitals/BMI, doctor access controls & password management) while refreshing local reminders.
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/app_models.dart';
import '../services/auth_service.dart';
import '../services/clinic_store.dart';
import '../services/medical_history_store.dart';
import '../services/prescription_store.dart';
import '../services/reminder_service.dart';
import '../models/medical_history.dart';
import '../utils/formatters.dart';
import '../utils/bmi.dart';
import 'doctor_directory_screen.dart';
import 'doctor_access_screen.dart';
import 'bmi_screen.dart';
import 'feature_screen.dart';
import 'login_screen.dart';
import 'medical_history_screen.dart';
import 'my_appointments_screen.dart';
import 'prescriptions_screen.dart';
import 'test_results_screen.dart';
import '../utils/app_colors.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _refreshReminders();
  }

  void _refreshReminders() {
    final patientId = authService.currentUser?.id;
    if (patientId != null) reminderService.refreshFor(patientId);
  }

  final List<Map<String, dynamic>> _dashboardItems = [
    {
      'title': 'Doctors',
      'subtitle': 'Add & view details',
      'icon': CupertinoIcons.person_2_fill,
      'empty': 'No doctors added yet.',
    },
    {
      'title': 'Prescriptions',
      'subtitle': 'Upload & manage',
      'icon': CupertinoIcons.doc_text_fill,
      'empty': 'No prescriptions added yet.',
    },
    {
      'title': 'Test Results',
      'subtitle': 'Add & view history',
      'icon': CupertinoIcons.search,
      'empty': 'No test results added yet.',
    },
    {
      'title': 'Appointments',
      'subtitle': 'Schedule & track visits',
      'icon': CupertinoIcons.calendar,
      'empty': 'No appointments scheduled yet.',
    },
  ];

  void _openFeature(Map<String, dynamic> item) {
    final title = item['title'] as String;
    final Widget screen = switch (title) {
      'Doctors' => const DoctorDirectoryScreen(),
      'Appointments' => const MyAppointmentsScreen(),
      'Prescriptions' => PrescriptionsScreen(patientId: authService.currentUser?.id ?? ''),
      'Test Results' => TestResultsScreen(patientId: authService.currentUser?.id ?? ''),
      _ => FeatureScreen(
          title: title,
          icon: item['icon'] as IconData,
          emptyMessage: item['empty'] as String,
        ),
    };
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen)).then((_) {
      if (mounted) setState(() {});
      _refreshReminders();
    });
  }

  Widget _buildTab(int index) {
    switch (index) {
      case 1:
        return _buildRecordsTab();
      case 2:
        return const MyAppointmentsScreen();
      default:
        return _buildProfileTab();
    }
  }

  // ---------- Enhanced Patient Profile Tab ----------

  Future<void> _editPatientProfile(BuildContext context, AppUser user) async {
    final nameCtrl = TextEditingController(text: user.name);
    final phoneCtrl = TextEditingController(text: user.phone);
    final addressCtrl = TextEditingController(text: user.homeAddress ?? '');
    String gender = user.gender?.isNotEmpty == true ? user.gender! : 'Other';
    DateTime dob = user.dateOfBirth ?? DateTime(1995, 1, 1);

    final history = medicalHistoryStore.historyFor(user.id, user.id);
    final bloodGroupCtrl = TextEditingController(text: history?.bloodGroup ?? 'O+');
    final contactNameCtrl = TextEditingController(text: history?.emergencyContactName ?? '');
    final contactRelCtrl = TextEditingController(text: history?.emergencyContactRelationship ?? '');
    final contactPhoneCtrl = TextEditingController(text: history?.emergencyContactPhone ?? '');
    final heightCtrl = TextEditingController(text: history?.heightCm?.toString() ?? '');
    final weightCtrl = TextEditingController(text: history?.weightKg?.toString() ?? '');

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Edit Profile & Emergency Info'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Personal Information', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF102A66))),
                const SizedBox(height: 8),
                TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Full Name *')),
                const SizedBox(height: 8),
                TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: 'Phone Number')),
                const SizedBox(height: 8),
                TextField(controller: addressCtrl, decoration: const InputDecoration(labelText: 'Home Address')),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: ['Male', 'Female', 'Other'].contains(gender) ? gender : 'Other',
                  items: ['Male', 'Female', 'Other'].map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                  onChanged: (v) => setDialogState(() => gender = v ?? 'Other'),
                  decoration: const InputDecoration(labelText: 'Gender'),
                ),
                const SizedBox(height: 16),
                const Text('Emergency Card & Vitals', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF102A66))),
                const SizedBox(height: 8),
                TextField(controller: bloodGroupCtrl, decoration: const InputDecoration(labelText: 'Blood Group (e.g. A+, O+)')),
                const SizedBox(height: 8),
                TextField(controller: contactNameCtrl, decoration: const InputDecoration(labelText: 'Emergency Contact Name')),
                const SizedBox(height: 8),
                TextField(controller: contactRelCtrl, decoration: const InputDecoration(labelText: 'Emergency Contact Relationship')),
                const SizedBox(height: 8),
                TextField(controller: contactPhoneCtrl, decoration: const InputDecoration(labelText: 'Emergency Contact Phone')),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: TextField(controller: heightCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Height (cm)'))),
                    const SizedBox(width: 12),
                    Expanded(child: TextField(controller: weightCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Weight (kg)'))),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (nameCtrl.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter your full name.')),
                  );
                  return;
                }
                try {
                  await authService.updateProfile(
                    email: user.id,
                    profile: UserProfile(
                      name: nameCtrl.text.trim(),
                      phone: phoneCtrl.text.trim(),
                      dateOfBirth: dob,
                      gender: gender,
                      homeAddress: addressCtrl.text.trim(),
                    ),
                  );

                  final currentHist = medicalHistoryStore.historyFor(user.id, user.id);
                  final height = double.tryParse(heightCtrl.text.trim());
                  final weight = double.tryParse(weightCtrl.text.trim());

                  medicalHistoryStore.save(
                    patientId: user.id,
                    editorId: user.id,
                    history: MedicalHistory(
                      allergies: currentHist?.allergies ?? 'None known',
                      conditions: currentHist?.conditions ?? 'None',
                      surgeries: currentHist?.surgeries ?? 'None',
                      currentMedicines: currentHist?.currentMedicines ?? 'None',
                      updatedAt: DateTime.now(),
                      bloodGroup: bloodGroupCtrl.text.trim(),
                      emergencyContactName: contactNameCtrl.text.trim(),
                      emergencyContactRelationship: contactRelCtrl.text.trim(),
                      emergencyContactPhone: contactPhoneCtrl.text.trim(),
                      heightCm: height,
                      weightKg: weight,
                    ),
                  );

                  if (!context.mounted) return;
                  Navigator.pop(ctx);
                  setState(() {});
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Profile updated successfully.')),
                  );
                } catch (e) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(e.toString())),
                  );
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _changePassword(BuildContext context, String email) async {
    final currentCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    bool obscureCurrent = true;
    bool obscureNew = true;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Change Password'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: currentCtrl,
                  obscureText: obscureCurrent,
                  decoration: InputDecoration(
                    labelText: 'Current Password',
                    suffixIcon: IconButton(
                      icon: Icon(obscureCurrent ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setState(() => obscureCurrent = !obscureCurrent),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: newCtrl,
                  obscureText: obscureNew,
                  decoration: InputDecoration(
                    labelText: 'New Password',
                    suffixIcon: IconButton(
                      icon: Icon(obscureNew ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setState(() => obscureNew = !obscureNew),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: confirmCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Confirm New Password'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (newCtrl.text != confirmCtrl.text) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('New passwords do not match.')),
                  );
                  return;
                }
                try {
                  await authService.changePassword(
                    email: email,
                    currentPassword: currentCtrl.text,
                    newPassword: newCtrl.text,
                  );
                  if (!context.mounted) return;
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Password changed successfully.')),
                  );
                } on AuthException catch (e) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(e.message)),
                  );
                }
              },
              child: const Text('Update Password'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileTab() {
    final user = authService.currentUser;
    if (user == null) return const SizedBox.shrink();
    final history = medicalHistoryStore.historyFor(user.id, user.id);

    BmiResult? bmiResult;
    if (history?.heightCm != null && history?.weightKg != null) {
      bmiResult = calculateBmi(heightCm: history!.heightCm!, weightKg: history.weightKg!);
    }

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Center(
          child: Text(
            'Patient Profile',
            style: TextStyle(
              fontFamily: 'Georgia',
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0D1B2A),
            ),
          ),
        ),
        const SizedBox(height: 16),
        _EmergencyMedicalCard(patientId: user.id),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFFF4F7FB),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.person, color: Color(0xFF102A66)),
                  const SizedBox(width: 10),
                  const Text(
                    'Personal Information',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0D1B2A)),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.edit, size: 20, color: Color(0xFF102A66)),
                    onPressed: () => _editPatientProfile(context, user),
                  ),
                ],
              ),
              const Divider(height: 20),
              _detailRow('Full Name', user.name),
              _detailRow('Email (ID)', user.id),
              _detailRow('Phone', user.phone.isNotEmpty ? user.phone : 'Not provided'),
              _detailRow('Gender', user.gender?.isNotEmpty == true ? user.gender! : 'Not provided'),
              _detailRow('Home Address', user.homeAddress?.isNotEmpty == true ? user.homeAddress! : 'Not provided'),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFFF4F7FB),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.monitor_weight_outlined, color: Color(0xFF102A66)),
                  const SizedBox(width: 10),
                  const Text(
                    'Vitals & BMI',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0D1B2A)),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const BmiScreen()),
                    ).then((_) => setState(() {})),
                    child: const Text('Open Calculator'),
                  ),
                ],
              ),
              const Divider(height: 20),
              _detailRow('Height', history?.heightCm != null ? '${history!.heightCm} cm' : 'Not provided'),
              _detailRow('Weight', history?.weightKg != null ? '${history!.weightKg} kg' : 'Not provided'),
              _detailRow(
                'BMI',
                bmiResult != null
                    ? '${bmiResult.value.toStringAsFixed(1)} (${bmiResult.categoryLabel})'
                    : 'Not calculated',
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        ListTile(
          tileColor: const Color(0xFFF4F7FB),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          leading: const Icon(Icons.security, color: Color(0xFF102A66)),
          title: const Text('Doctor Access & Privacy', style: TextStyle(fontWeight: FontWeight.bold)),
          subtitle: const Text('Manage which doctors can view/edit records'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => DoctorAccessScreen(patientId: user.id)),
          ),
        ),
        const SizedBox(height: 12),
        ListTile(
          tileColor: const Color(0xFFF4F7FB),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          leading: const Icon(Icons.lock_outline, color: Color(0xFF102A66)),
          title: const Text('Change Password', style: TextStyle(fontWeight: FontWeight.bold)),
          subtitle: const Text('Update your account password'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _changePassword(context, user.id),
        ),
        const SizedBox(height: 24),
        Center(
          child: OutlinedButton.icon(
            onPressed: _logout,
            icon: const Icon(Icons.logout),
            label: const Text('Log out'),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: TextStyle(color: Colors.grey[700], fontWeight: FontWeight.w500)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0D1B2A))),
          ),
        ],
      ),
    );
  }

  void _logout() {
    authService.logout();
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  double _textScale(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
    return scale < 1.0 ? 1.0 : (scale > 1.6 ? 1.6 : scale);
  }

  Widget _upcomingBanner() {
    final patientId = authService.currentUser?.id ?? '';
    final next = clinicStore.nextApprovedAppointmentFor(patientId);
    if (next == null) return const SizedBox.shrink();

    final doctor = clinicStore.doctorById(next.doctorId);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Material(
        color: const Color(0xFFDCE6FF),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const MyAppointmentsScreen()),
          ).then((_) {
            if (mounted) setState(() {});
            _refreshReminders();
          }),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.event_available, color: Color(0xFF102A66), size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Next appointment',
                        style: TextStyle(fontSize: 14, color: Color(0xFF102A66)),
                      ),
                      Text(
                        doctor?.name ?? 'Your doctor',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0D1B2A),
                        ),
                      ),
                      Text(
                        '${formatDay(next.start)} • ${formatSlot(next.start)}',
                        style: const TextStyle(fontSize: 14, color: Color(0xFF0D1B2A)),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: Color(0xFF102A66)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _plural(int n, String one, String many) => n == 1 ? '$n $one' : '$n $many';

  String _prescriptionsSummary(String patientId) {
    final medicines = prescriptionStore.medicationsFor(patientId).length;
    final pdfs = prescriptionStore.externalPrescriptionsFor(patientId).length;
    if (medicines == 0 && pdfs == 0) return 'No prescriptions added yet.';

    final parts = <String>[];
    if (medicines > 0) parts.add(_plural(medicines, 'medicine', 'medicines'));
    if (pdfs > 0) parts.add(_plural(pdfs, 'uploaded PDF', 'uploaded PDFs'));

    final records = prescriptionStore.recordsFor(patientId);
    parts.add('last added ${formatDay(records.last.date)}');
    return parts.join(' • ');
  }

  String _testResultsSummary(String patientId) {
    final tests = prescriptionStore.recommendedTestsFor(patientId);
    if (tests.isEmpty) return 'No tests recommended yet.';

    final uploaded = tests.where((t) => t.status == 'Result Uploaded').length;
    return '${_plural(tests.length, 'test', 'tests')} • '
        '${_plural(uploaded, 'result uploaded', 'results uploaded')}';
  }

  String _medicalHistorySummary(String patientId) {
    final history = medicalHistoryStore.historyFor(patientId, patientId);
    if (history == null) return 'No medical history recorded yet.';
    return 'Last updated ${formatDay(history.updatedAt)}';
  }

  Widget _buildRecordsTab() {
    final patientId = authService.currentUser?.id ?? '';
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Records',
            style: TextStyle(
              fontFamily: 'Georgia',
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0D1B2A),
            ),
          ),
          const SizedBox(height: 16),
          _recordTile('Prescriptions', CupertinoIcons.doc_text_fill,
              _prescriptionsSummary(patientId)),
          _recordTile('Test Results', CupertinoIcons.search,
              _testResultsSummary(patientId)),
          _bmiTile(),
          _recordTile('Medical History', Icons.health_and_safety_outlined,
              _medicalHistorySummary(patientId)),
        ],
      ),
    );
  }

  Widget _bmiTile() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: ListTile(
        tileColor: const Color(0xFFF4F7FB),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        leading: const Icon(Icons.monitor_weight_outlined, color: Color(0xFF102A66)),
        title: const Text(
          'BMI Calculator',
          style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0D1B2A)),
        ),
        subtitle: const Text('Check your body mass index'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const BmiScreen()),
        ),
      ),
    );
  }

  Widget _recordTile(String title, IconData icon, String subtitle) {
    final patientId = authService.currentUser?.id ?? '';
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: ListTile(
        tileColor: const Color(0xFFF4F7FB),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        leading: Icon(icon, color: const Color(0xFF102A66)),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF0D1B2A),
          ),
        ),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => switch (title) {
              'Prescriptions' => PrescriptionsScreen(patientId: patientId),
              'Test Results' => TestResultsScreen(patientId: patientId),
              'Medical History' => MedicalHistoryScreen(patientId: patientId),
              _ => FeatureScreen(
                  title: title,
                  icon: icon,
                  emptyMessage: subtitle,
                ),
            },
          ),
        ).then((_) {
          if (mounted) setState(() {});
          _refreshReminders();
        }),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: _currentIndex == 0
          ? SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Center(
                  child: Text(
                    'Healthbook',
                    style: TextStyle(
                      fontFamily: 'Georgia',
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0D1B2A),
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _upcomingBanner(),
              Container(
                height: 180,
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F4FF),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: CustomPaint(
                          painter: _HeroBackgroundPainter(),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text(
                                  'Your Health Hub',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF0D1B2A),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Manage records & appointments securely.',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[700],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            width: 75,
                            height: 75,
                            decoration: const BoxDecoration(
                              color: Color(0xFFDCE6FF),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              CupertinoIcons.heart_fill,
                              color: Color(0xFF102A66),
                              size: 36,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _dashboardItems.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 14,
                  mainAxisExtent: 116 * _textScale(context),
                ),
                itemBuilder: (context, index) {
                  final item = _dashboardItems[index];
                  return GestureDetector(
                    onTap: () => _openFeature(item),
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFF4F7FB),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            item['icon'] as IconData,
                            color: const Color(0xFF102A66),
                            size: 28,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            item['title'] as String,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0D1B2A),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            item['subtitle'] as String,
                            style: const TextStyle(
                              fontSize: 12,
                              color: kTextMuted,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      )
          : _buildTab(_currentIndex),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
          _refreshReminders();
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFF102A66),
        unselectedItemColor: kTextMuted,
        selectedFontSize: 12,
        unselectedFontSize: 12,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.doc_text),
            label: 'Records',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.calendar),
            label: 'Appointments',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.profile_circled),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

class _EmergencyMedicalCard extends StatelessWidget {
  final String patientId;

  const _EmergencyMedicalCard({required this.patientId});

  Future<void> _callEmergency(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    final history = medicalHistoryStore.historyFor(patientId, patientId);
    final bloodGroup = history?.bloodGroup.trim().isNotEmpty == true ? history!.bloodGroup : 'Not provided';
    final allergies = history?.allergies.trim().isNotEmpty == true ? history!.allergies : 'Not provided';
    final conditions = history?.conditions.trim().isNotEmpty == true ? history!.conditions : 'Not provided';
    final surgeries = history?.surgeries.trim().isNotEmpty == true ? history!.surgeries : 'Not provided';
    final contactName = history?.emergencyContactName.trim().isNotEmpty == true ? history!.emergencyContactName : 'Not provided';
    final contactRel = history?.emergencyContactRelationship.trim().isNotEmpty == true ? history!.emergencyContactRelationship : '';
    final contactPhone = history?.emergencyContactPhone.trim().isNotEmpty == true ? history!.emergencyContactPhone : '';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF2F2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.red.shade200, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.emergency, color: Colors.red, size: 28),
              const SizedBox(width: 10),
              const Text(
                'Emergency Medical Card',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0D1B2A),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Blood: $bloodGroup',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
            ],
          ),
          const Divider(height: 24, color: Color(0xFFFCDCDC)),
          _infoRow('Known Allergies', allergies),
          const SizedBox(height: 8),
          _infoRow('Chronic Conditions', conditions),
          const SizedBox(height: 8),
          _infoRow('Past Surgeries', surgeries),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.red.shade100),
            ),
            child: Row(
              children: [
                const Icon(Icons.contact_phone, color: Colors.red, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Emergency Contact: $contactName ${contactRel.isNotEmpty ? '($contactRel)' : ''}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      Text(
                        contactPhone.isNotEmpty ? contactPhone : 'Not provided',
                        style: TextStyle(color: Colors.grey[700], fontSize: 13),
                      ),
                    ],
                  ),
                ),
                if (contactPhone.isNotEmpty)
                  ElevatedButton.icon(
                    onPressed: () => _callEmergency(contactPhone),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    icon: const Icon(Icons.call, size: 16),
                    label: const Text('Call'),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.red[900]),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(fontSize: 14, color: Color(0xFF0D1B2A)),
        ),
      ],
    );
  }
}

class _HeroBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0x11416EB5)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    const double spacing = 15;
    for (double i = 0; i < size.width + size.height; i += spacing) {
      canvas.drawLine(
        Offset(i < size.width ? i : size.width, i < size.width ? 0 : i - size.width),
        Offset(i < size.height ? 0 : i - size.height, i < size.height ? i : size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
