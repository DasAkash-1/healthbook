import 'package:flutter/material.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  // Step 1 fields
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  // Step 2 fields
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _dobCtrl = TextEditingController();
  DateTime? _dob;

  int _step = 0; // 0 = account, 1 = personal details
  bool _obscure = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _dobCtrl.dispose();
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
        _dobCtrl.text =
            '${picked.day.toString().padLeft(2, '0')}/'
            '${picked.month.toString().padLeft(2, '0')}/'
            '${picked.year}';
      });
    }
  }

  void _next() => setState(() => _step = 1);
  void _back() => setState(() => _step = 0);

  void _submit() {
    // Placeholder: account creation is added in the next step.
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Registration will be connected next.')),
    );
  }

  // Reusable input field so every field looks the same.
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
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        obscureText: obscure,
        readOnly: readOnly,
        onTap: onTap,
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
        ),
      ),
    );
  }

  Widget _buildProgress() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Step ${_step + 1} of 2',
          style: TextStyle(color: Colors.grey[700], fontSize: 14),
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: (_step + 1) / 2,
            minHeight: 6,
            color: Colors.blueAccent,
            backgroundColor: Colors.blueGrey.shade100,
          ),
        ),
      ],
    );
  }

  Widget _buildAccountStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _field(
          controller: _emailCtrl,
          label: 'Email',
          icon: Icons.email_outlined,
          keyboardType: TextInputType.emailAddress,
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
        ),
        _field(
          controller: _confirmCtrl,
          label: 'Confirm password',
          icon: Icons.lock_outline,
          obscure: _obscure,
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
    );
  }

  Widget _buildProfileStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _field(
          controller: _nameCtrl,
          label: 'Full name',
          icon: Icons.person_outline,
        ),
        _field(
          controller: _phoneCtrl,
          label: 'Phone number',
          icon: Icons.phone_outlined,
          keyboardType: TextInputType.phone,
        ),
        _field(
          controller: _dobCtrl,
          label: 'Date of birth',
          hint: 'DD/MM/YYYY',
          icon: Icons.cake_outlined,
          readOnly: true,
          onTap: _pickDate,
          suffix: const Icon(Icons.calendar_today),
        ),
        const SizedBox(height: 8),
        ElevatedButton(
          onPressed: _submit,
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
          child: const Text('Create account', style: TextStyle(fontSize: 16)),
        ),
        const SizedBox(height: 12),
        TextButton(onPressed: _back, child: const Text('Back')),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isFirstStep = _step == 0;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(isFirstStep ? 'Create Account' : 'Your Details'),
        leading: isFirstStep
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
                isFirstStep
                    ? 'Start with your email and a password.'
                    : 'Tell us a little about yourself.',
                style: TextStyle(fontSize: 16, color: Colors.grey[700]),
              ),
              const SizedBox(height: 24),
              isFirstStep ? _buildAccountStep() : _buildProfileStep(),
              const SizedBox(height: 24),
              if (isFirstStep)
                Center(
                  child: TextButton(
                    onPressed: () {
                      // Login link is connected in the next step.
                    },
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
