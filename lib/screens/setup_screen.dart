import 'package:flutter/material.dart';
import '../services/setup_service.dart';
import 'home_screen.dart';

class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _linkedinController = TextEditingController();
  final _githubController = TextEditingController();
  final _grokKeyController = TextEditingController();
  final _smtpEmailController = TextEditingController();
  final _smtpPasswordController = TextEditingController();
  final _setupService = SetupService();
  bool _isLoading = false;

  Future<void> _handleSetup() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      await _setupService.completeSetup(
        userName: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        linkedin: _linkedinController.text.trim(),
        github: _githubController.text.trim(),
        grokKey: _grokKeyController.text.trim(),
        smtpEmail: _smtpEmailController.text.trim(),
        smtpPassword: _smtpPasswordController.text.trim(),
      );
      
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Setup failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 100),
                const Icon(Icons.auto_fix_high, size: 60, color: Color(0xFF6C63FF)),
                const SizedBox(height: 24),
                Text(
                  'Welcome to\nAuto Mail AI',
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Let\'s set up your API keys to get started.',
                  style: TextStyle(color: Colors.grey[400], fontSize: 16),
                ),
                const SizedBox(height: 48),
                _buildTextField(
                  label: 'Your Full Name',
                  controller: _nameController,
                  icon: Icons.person_outline,
                  hint: 'John Doe',
                ),
                const SizedBox(height: 24),
                _buildTextField(
                  label: 'Phone Number',
                  controller: _phoneController,
                  icon: Icons.phone,
                  hint: '+1 234 567 890',
                ),
                const SizedBox(height: 24),
                _buildTextField(
                  label: 'LinkedIn URL',
                  controller: _linkedinController,
                  icon: Icons.link,
                  hint: 'linkedin.com/in/username',
                ),
                const SizedBox(height: 24),
                _buildTextField(
                  label: 'GitHub URL',
                  controller: _githubController,
                  icon: Icons.code,
                  hint: 'github.com/username',
                ),
                const SizedBox(height: 24),
                _buildTextField(
                  label: 'Groq API Key',
                  controller: _grokKeyController,
                  icon: Icons.key,
                  hint: 'gsk_xxxxxxxx...',
                ),
                const SizedBox(height: 24),
                _buildTextField(
                  label: 'Gmail Address',
                  controller: _smtpEmailController,
                  icon: Icons.alternate_email,
                  hint: 'yourname@gmail.com',
                ),
                const SizedBox(height: 24),
                _buildTextField(
                  label: 'Gmail App Password',
                  controller: _smtpPasswordController,
                  icon: Icons.lock_outline,
                  hint: '16-character code',
                  isPassword: true,
                ),
                const SizedBox(height: 48),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleSetup,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6C63FF),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 20),
                    ),
                    child: _isLoading 
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Complete Setup', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    required String hint,
    bool isPassword = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF6C63FF))),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          obscureText: isPassword,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, size: 20),
            filled: true,
            fillColor: const Color(0xFF1E1E1E),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
          ),
          validator: (value) => value == null || value.isEmpty ? 'This field is required' : null,
        ),
      ],
    );
  }
}
