import 'package:flutter/material.dart';
import '../services/setup_service.dart';

class EditProfileScreen extends StatefulWidget {
  final Map<String, String?> currentCreds;
  const EditProfileScreen({super.key, required this.currentCreds});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final SetupService _setupService = SetupService();
  bool _isLoading = false;

  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _linkedinController;
  late TextEditingController _githubController;
  late TextEditingController _grokKeyController;
  late TextEditingController _smtpEmailController;
  late TextEditingController _smtpPasswordController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.currentCreds['USER_NAME']);
    _phoneController = TextEditingController(text: widget.currentCreds['PHONE_NUMBER']);
    _linkedinController = TextEditingController(text: widget.currentCreds['LINKEDIN_URL']);
    _githubController = TextEditingController(text: widget.currentCreds['GITHUB_URL']);
    _grokKeyController = TextEditingController(text: widget.currentCreds['GROQ_API_KEY']);
    _smtpEmailController = TextEditingController(text: widget.currentCreds['SMTP_EMAIL']);
    _smtpPasswordController = TextEditingController(text: widget.currentCreds['SMTP_PASSWORD']);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _linkedinController.dispose();
    _githubController.dispose();
    _grokKeyController.dispose();
    _smtpEmailController.dispose();
    _smtpPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleUpdate() async {
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully!'), backgroundColor: Colors.green),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Update failed: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Profile & API Keys')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    _buildTextField('Full Name', _nameController, Icons.person_outline),
                    const SizedBox(height: 16),
                    _buildTextField('Phone Number', _phoneController, Icons.phone),
                    const SizedBox(height: 16),
                    _buildTextField('LinkedIn URL', _linkedinController, Icons.link),
                    const SizedBox(height: 16),
                    _buildTextField('GitHub URL', _githubController, Icons.code),
                    const SizedBox(height: 32),
                    const Divider(color: Colors.white10),
                    const SizedBox(height: 32),
                    _buildTextField('Groq API Key', _grokKeyController, Icons.key),
                    const SizedBox(height: 16),
                    _buildTextField('SMTP Email', _smtpEmailController, Icons.email),
                    const SizedBox(height: 16),
                    _buildTextField('SMTP App Password', _smtpPasswordController, Icons.lock, isPassword: true),
                    const SizedBox(height: 48),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _handleUpdate,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6C63FF),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: const Text('Save Changes', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, IconData icon, {bool isPassword = false}) {
    return TextFormField(
      controller: controller,
      obscureText: isPassword,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: const Color(0xFF6C63FF)),
        filled: true,
        fillColor: const Color(0xFF1E1E1E),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      ),
      validator: (value) => value == null || value.isEmpty ? 'This field is required' : null,
    );
  }
}
