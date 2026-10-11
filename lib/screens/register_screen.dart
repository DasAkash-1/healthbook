import 'package:flutter/material.dart';

import '../models/app_models.dart';
import '../services/auth_service.dart';
import '../utils/validators.dart';
import '../widgets/medical_history_form.dart';
import 'login_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _accountFormKey = GlobalKey<FormState>();
  final _profileFormKey = GlobalKey<FormState>();

  // Step 1 fields
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  // Step 2 fields
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _dobCtrl = TextEditingController();
  final _licenseCtrl = TextEditingController();
  DateTime? _dob;
  UserRole _role = UserRole.patient;
  String? _specialty;

  // Step 3 (patients only) fields
  final _medical = MedicalHistoryControllers();

  int _step = 0; // 0 = account, 1 = personal details, 2 = medical history (patients)
  bool _obscure = true;
  bool _loading = false;

  static const List<String> _specialties = [
    'General Practice',
    'Cardiology',
    'Dermatology',
    'Neurology',
    'Orthopaedics',
    'Paediatrics',
    'Gynaecology',
  ];

  bool get _isPatient => _role == UserRole.patient;
  int get _totalSteps => _isPatient ? 3 : 2;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _dobCtrl.dispose();
    _licenseCtrl.dispose();
    _medical.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dob ?? DateTime(now.year - 20),
      firstDate: DateTime(1900),
      lastDate: now,
    );
    if (picked != null) {
      setState(() {
        _dob = picked;
        _dobCtrl.text = '${picked.day.toString().padLeft(2, '0')}/'
            '${picked.month.toString().padLeft(2, '0')}/'
            '${picked.year}';
      });
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  void _next() {
    if (_step == 0) {
      if (_accountFormKey.currentState!.validate()) setState(() => _step = 1);
      return;
    }
    if (!_profileFormKey.currentState!.validate()) return;
    if (_role == UserRole.doctor && _specialty == null) {
      _showMessage('Please choose your specialty.');
      return;
    }
    if (_isPatient) {
      setState(() => _step = 2);
    } else {
      _submit();
    }
  }

  void _back() => setState(() => _step = _step > 0 ? _step - 1 : 0);

  void _onMedicalSubmit() {
    if (_medical.allergies.text.trim().isEmpty) {
      _showMessage('Please enter your allergies, or write "None".');
      return;
    }
    _submit();
  }

  Future<void> _submit() async {
    setState(() => _loading = true);
    try {
      await authService.register(
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text,
        role: _role,
        profile: UserProfile(
          name: _nameCtrl.text.trim(),
          phone: _phoneCtrl.text.trim(),
          dateOfBirth: _dob!,
          specialty: _role == UserRole.doctor ? _specialty : null,
          licenseNumber: _role == UserRole.doctor ? _licenseCtrl.text.trim() : null,
          medicalHistory: _isPatient ? _medical.toHistory() : null,
        ),
      );
      if (!mounted) return;
      _showMessage('Account created successfully.');
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    } on AuthException catch (e) {
      if (!mounted) return;
      // A duplicate email means the user needs to change step 1.
      if (e.message.contains('already exists')) setState(() => _step = 0);
      _showMessage(e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // Reusable field. Validation runs as the user types.
  Widget _field({
    required TextEditingController controller,
    required String label,
    IconData? icon,
    Widget? suffix,
    TextInputType? keyboardType,
    bool obscure = false,
    bool readOnly = false,
    VoidCallback? onTap,
    String? hint,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        obscureText: obscure,
        readOnly: readOnly,
        onTap: onTap,
        validator: validator,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: icon != null ? Icon(icon) : null,
          suffixIcon: suffix,
          filled: true,
          fillColor: Colors.grey.shade100,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.blueAccent, width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.red),
          ),
        ),
      ),
    );
  }

  Widget _buildSpecialtyPicker() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: 'Specialty',
          prefixIcon: const Icon(Icons.medical_services_outlined),
          filled: true,
          fillColor: Colors.grey.shade100,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: _specialty,
            isExpanded: true,
            hint: const Text('Choose your specialty'),
            items: [
              for (final s in _specialties)
                DropdownMenuItem<String>(value: s, child: Text(s)),
            ],
            onChanged: (v) => setState(() => _specialty = v),
          ),
        ),
      ),
    );
  }

  Widget _buildProgress() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Step ${_step + 1} of $_totalSteps',
          style: TextStyle(color: Colors.grey[700], fontSize: 14),
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: (_step + 1) / _totalSteps,
            minHeight: 6,
            color: Colors.blueAccent,
            backgroundColor: Colors.blueGrey.shade100,
          ),
        ),
      ],
    );
  }

  Widget _buildAccountStep() {
    return Form(
      key: _accountFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SegmentedButton<UserRole>(
            segments: const [
              ButtonSegment(
                value: UserRole.patient,
                label: Text('Patient'),
                icon: Icon(Icons.person_outline),
              ),
              ButtonSegment(
                value: UserRole.doctor,
                label: Text('Doctor'),
                icon: Icon(Icons.medical_services_outlined),
              ),
            ],
            selected: {_role},
            onSelectionChanged: (s) => setState(() => _role = s.first),
          ),
          const SizedBox(height: 16),
          _field(
            controller: _emailCtrl,
            label: 'Email',
            icon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
            validator: Validators.email,
          ),
          _field(
            controller: _passwordCtrl,
            label: 'Password',
            icon: Icons.lock_outline,
            obscure: _obscure,
            suffix: IconButton(
              icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
              onPressed: () => setState(() => _obscure = !_obscure),
            ),
            validator: Validators.password,
          ),
          _field(
            controller: _confirmCtrl,
            label: 'Confirm password',
            icon: Icons.lock_outline,
            obscure: _obscure,
            validator: (v) => Validators.confirmPassword(v, _passwordCtrl.text),
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: _next,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: const Text('Next', style: TextStyle(fontSize: 16)),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileStep() {
    return Form(
      key: _profileFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _field(
            controller: _nameCtrl,
            label: 'Full name',
            icon: Icons.person_outline,
            validator: Validators.name,
          ),
          _field(
            controller: _phoneCtrl,
            label: 'Phone number',
            icon: Icons.phone_outlined,
            keyboardType: TextInputType.phone,
            validator: Validators.phone,
          ),
          _field(
            controller: _dobCtrl,
            label: 'Date of birth',
            hint: 'DD/MM/YYYY',
            icon: Icons.cake_outlined,
            readOnly: true,
            onTap: _pickDate,
            suffix: const Icon(Icons.calendar_today),
            validator: (_) => Validators.dateOfBirth(_dob),
          ),
          if (_role == UserRole.doctor) _buildSpecialtyPicker(),
          if (_role == UserRole.doctor)
            _field(
              controller: _licenseCtrl,
              label: 'Medical license number',
              icon: Icons.badge_outlined,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'License number is required' : null,
            ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: _loading ? null : _next,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: Text(
              _isPatient ? 'Next' : 'Create account',
              style: const TextStyle(fontSize: 16),
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: _loading ? null : _back,
            child: const Text('Back'),
          ),
        ],
      ),
    );
  }

  Widget _buildMedicalStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MedicalHistoryFields(controllers: _medical),
        const SizedBox(height: 8),
        ElevatedButton(
          onPressed: _loading ? null : _onMedicalSubmit,
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
          child: _loading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Create account', style: TextStyle(fontSize: 16)),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: _loading ? null : _back,
          child: const Text('Back'),
        ),
      ],
    );
  }

  Widget _buildStep() {
    switch (_step) {
      case 0:
        return _buildAccountStep();
      case 1:
        return _buildProfileStep();
      default:
        return _buildMedicalStep();
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = switch (_step) {
      0 => 'Create Account',
      1 => 'Your Details',
      _ => 'Medical History',
    };
    final subtitle = switch (_step) {
      0 => 'Start with your email and a password.',
      1 => 'Tell us a little about yourself.',
      _ => 'Help your doctor understand your health. You can update this later.',
    };

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(title),
        leading: _step == 0
            ? null
            : IconButton(icon: const Icon(Icons.arrow_back), onPressed: _back),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildProgress(),
              const SizedBox(height: 24),
              Text(
                subtitle,
                style: TextStyle(fontSize: 16, color: Colors.grey[700]),
              ),
              const SizedBox(height: 24),
              _buildStep(),
              const SizedBox(height: 24),
              if (_step == 0)
                Center(
                  child: TextButton(
                    onPressed: () => Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                    ),
                    child: const Text('Already have an account? Log in'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
