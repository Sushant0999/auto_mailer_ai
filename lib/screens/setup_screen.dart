import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/setup_service.dart';
import '../services/groq_service.dart';
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
  String? _resumePath;
  String? _resumeText;

  Future<void> _pickResume() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'txt'],
      );
      if (result != null && result.files.single.path != null) {
        final path = result.files.single.path!;
        setState(() => _isLoading = true);
        final persistentPath = await _setupService.persistResumeFile(path);
        final text = await _setupService.extractResumeText(persistentPath);
        setState(() {
          _resumePath = persistentPath;
          _resumeText = text;
          _isLoading = false;
        });
      }
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open link')),
        );
      }
    }
  }

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
        resumePath: _resumePath,
        resumeText: _resumeText,
        visionModel: GroqService.defaultVisionModel,
        textModel: GroqService.defaultTextModel,
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
                const SizedBox(height: 70),
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF6C63FF).withOpacity(0.35),
                        blurRadius: 15,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Image.asset('assets/images/app_logo.jpg', fit: BoxFit.cover),
                  ),
                ),
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
                _buildLinkHint(
                  label: 'Get your free Groq API Key →',
                  url: 'https://console.groq.com/keys',
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
                _buildLinkHint(
                  label: 'Create a Google App Password →',
                  url: 'https://myaccount.google.com/apppasswords',
                ),
                const SizedBox(height: 24),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Resume (Optional)', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF6C63FF))),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: _isLoading ? null : _pickResume,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E1E1E),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.attach_file, color: Colors.grey),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _resumePath != null
                                    ? _resumePath!.split('/').last
                                    : 'Upload Resume (PDF/TXT)',
                                style: TextStyle(
                                  color: _resumePath != null ? Colors.white : Colors.grey,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
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

  Widget _buildLinkHint({required String label, required String url}) {
    return Padding(
      padding: const EdgeInsets.only(top: 6, left: 4),
      child: GestureDetector(
        onTap: () => _launchUrl(url),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.open_in_new, size: 13, color: Color(0xFF6C63FF)),
            const SizedBox(width: 5),
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFF6C63FF),
                fontSize: 12,
                decoration: TextDecoration.underline,
                decorationColor: Color(0xFF6C63FF),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
