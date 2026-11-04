import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
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

  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _linkedinController;
  late TextEditingController _githubController;
  late TextEditingController _grokKeyController;
  late TextEditingController _smtpEmailController;
  late TextEditingController _smtpPasswordController;
  late TextEditingController _customPromptController;

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
    _customPromptController = TextEditingController(text: widget.currentCreds['CUSTOM_PROMPT']);
    _resumePath = widget.currentCreds['RESUME_PATH'];
    _resumeText = widget.currentCreds['RESUME_TEXT'];
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
    _customPromptController.dispose();
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
        resumePath: _resumePath,
        resumeText: _resumeText,
        customPrompt: _customPromptController.text.trim(),
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
                    _buildLinkHint(
                      label: 'Get your free Groq API Key →',
                      url: 'https://console.groq.com/keys',
                    ),
                    const SizedBox(height: 16),
                    _buildTextField('SMTP Email', _smtpEmailController, Icons.email),
                    const SizedBox(height: 16),
                    _buildTextField('SMTP App Password', _smtpPasswordController, Icons.lock, isPassword: true),
                    _buildLinkHint(
                      label: 'Create a Google App Password →',
                      url: 'https://myaccount.google.com/apppasswords',
                    ),
                    const SizedBox(height: 16),
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
                    const SizedBox(height: 32),
                    const Divider(color: Colors.white10),
                    const SizedBox(height: 24),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.edit_note, color: Color(0xFF6C63FF), size: 20),
                              const SizedBox(width: 8),
                              const Text(
                                'Email Generation Prompt',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF6C63FF)),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF6C63FF).withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text('Optional', style: TextStyle(fontSize: 11, color: Color(0xFF6C63FF))),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Customise how the AI writes your cold email. Leave blank to use the default professional cover letter style.',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _customPromptController,
                      maxLines: 5,
                      decoration: InputDecoration(
                        hintText:
                            'e.g. Write a concise, confident 3-paragraph email highlighting my backend skills and passion for the role. Keep the tone friendly yet professional.',
                        hintStyle: const TextStyle(color: Colors.grey, fontSize: 13),
                        filled: true,
                        fillColor: const Color(0xFF1E1E1E),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: Color(0xFF6C63FF), width: 1),
                        ),
                        contentPadding: const EdgeInsets.all(16),
                      ),
                      // No validator – this field is optional
                    ),
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
