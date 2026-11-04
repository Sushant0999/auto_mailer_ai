import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../models/job_details.dart';
import '../services/mail_service.dart';
import '../services/groq_service.dart';
import '../services/setup_service.dart';
import 'resume_update_screen.dart';

class JobDetailScreen extends StatefulWidget {
  final JobDetails jobDetails;

  const JobDetailScreen({super.key, required this.jobDetails});

  @override
  State<JobDetailScreen> createState() => _JobDetailScreenState();
}

class _JobDetailScreenState extends State<JobDetailScreen> {
  final MailService _mailService = MailService();
  final GroqService _groqService = GroqService();
  final SetupService _setupService = SetupService();

  late TextEditingController _emailController;
  late TextEditingController _subjectController;
  late TextEditingController _bodyController;
  final TextEditingController _feedbackController = TextEditingController();

  String? _resumePath;
  bool _isSending = false;
  bool _isRevising = false;
  late JobDetails _currentDetails;

  @override
  void initState() {
    super.initState();
    _currentDetails = widget.jobDetails;
    _emailController = TextEditingController(text: _currentDetails.hrEmail);
    _subjectController =
        TextEditingController(text: _currentDetails.generatedSubject);
    _bodyController = TextEditingController(text: _currentDetails.generatedBody);
    _loadDefaultResume();
  }

  Future<void> _loadDefaultResume() async {
    try {
      final creds = await _setupService.getCredentials();
      final defaultResume = creds['RESUME_PATH'];
      if (defaultResume != null && defaultResume.isNotEmpty) {
        if (await File(defaultResume).exists()) {
          if (mounted) {
            setState(() {
              _resumePath = defaultResume;
            });
          }
        }
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _emailController.dispose();
    _subjectController.dispose();
    _bodyController.dispose();
    _feedbackController.dispose();
    super.dispose();
  }

  Future<void> _pickResume() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'txt'],
      );

      if (result != null && result.files.single.path != null) {
        final persistentPath =
            await _setupService.persistResumeFile(result.files.single.path!);
        if (mounted) {
          setState(() {
            _resumePath = persistentPath;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open file picker: $e')),
        );
      }
    }
  }

  Future<void> _openResumeTailor() async {
    final jobSummary =
        'Position subject: ${_subjectController.text}\nLocation: ${_currentDetails.location}\nApplication body:\n${_bodyController.text}';
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (context) => ResumeUpdateScreen(
          initialJobContext: jobSummary,
          initialResumePath: _resumePath,
        ),
      ),
    );

    if (result != null && result.isNotEmpty && mounted) {
      setState(() {
        _resumePath = result;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tailored resume attached to this application!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _revise() async {
    if (_feedbackController.text.trim().isEmpty) return;

    setState(() => _isRevising = true);
    try {
      final revised = await _groqService.reviseContent(
        originalDetails: _currentDetails,
        feedback: _feedbackController.text.trim(),
      );
      if (mounted) {
        setState(() {
          _currentDetails = revised;
          _subjectController.text = revised.generatedSubject;
          _bodyController.text = revised.generatedBody;
          _feedbackController.clear();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Revision failed: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isRevising = false);
      }
    }
  }

  Future<void> _sendMail() async {
    final recipient = _emailController.text.trim();
    if (recipient.isEmpty || !recipient.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid HR recipient email address.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() => _isSending = true);
    try {
      await _mailService.queueJobApplication(
        recipient: recipient,
        subject: _subjectController.text,
        body: _bodyController.text,
        resumePath: _resumePath,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Email added to queue! Check History for status.'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to queue: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Review Application'),
        backgroundColor: Colors.transparent,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader('HR Email'),
            _buildTextField(_emailController, Icons.email),
            const SizedBox(height: 20),
            _buildSectionHeader('Job Location'),
            _buildStaticValue(_currentDetails.location, Icons.location_on),
            const SizedBox(height: 20),
            _buildSectionHeader('Generated Subject'),
            _buildTextField(_subjectController, Icons.subject),
            const SizedBox(height: 20),
            _buildSectionHeader('Email Body'),
            _buildTextField(_bodyController, Icons.description, maxLines: 10),
            const SizedBox(height: 20),

            // Resume Attachment & In-Place Tailoring Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildSectionHeader('Resume Attachment'),
                TextButton.icon(
                  onPressed: _openResumeTailor,
                  icon: const Icon(Icons.auto_awesome, size: 16, color: Color(0xFF6C63FF)),
                  label: const Text(
                    'Tailor for this Job',
                    style: TextStyle(
                      color: Color(0xFF6C63FF),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            InkWell(
              onTap: _pickResume,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _resumePath != null
                        ? const Color(0xFF6C63FF)
                        : Colors.white10,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _resumePath != null ? Icons.description : Icons.attach_file,
                      color: _resumePath != null
                          ? const Color(0xFF6C63FF)
                          : Colors.grey,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _resumePath != null
                                ? _resumePath!.split('/').last
                                : 'Attach Resume (PDF/TXT)',
                            style: TextStyle(
                              color: _resumePath != null
                                  ? Colors.white
                                  : Colors.grey,
                              fontWeight: _resumePath != null
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                          if (_resumePath != null)
                            const Text(
                              'Original fonts and structure will be preserved',
                              style: TextStyle(fontSize: 10, color: Colors.grey),
                            ),
                        ],
                      ),
                    ),
                    if (_resumePath != null) ...[
                      IconButton(
                        tooltip: 'Customize & tailor this resume',
                        icon: const Icon(Icons.tune, size: 20, color: Color(0xFF6C63FF)),
                        onPressed: _openResumeTailor,
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () => setState(() => _resumePath = null),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 32),
            _buildSectionHeader('Revise Email with AI'),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _feedbackController,
                    decoration: InputDecoration(
                      hintText: 'e.g., Make it more concise, emphasize backend...',
                      filled: true,
                      fillColor: const Color(0xFF1E1E1E),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                IconButton.filled(
                  onPressed: _isRevising ? null : _revise,
                  icon: _isRevising
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.auto_fix_high),
                  style: IconButton.styleFrom(
                      backgroundColor: const Color(0xFF6C63FF)),
                ),
              ],
            ),

            const SizedBox(height: 48),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isSending ? null : _sendMail,
                icon: _isSending
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.send),
                label: Text(_isSending ? 'Sending...' : 'Send Application'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6C63FF),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 20),
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, left: 4.0),
      child: Text(
        title,
        style: const TextStyle(
            fontWeight: FontWeight.bold, color: Color(0xFF6C63FF)),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, IconData icon,
      {int maxLines = 1}) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: Colors.grey),
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
      ),
    );
  }

  Widget _buildStaticValue(String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey),
          const SizedBox(width: 12),
          Text(value.isEmpty ? 'Not specified' : value),
        ],
      ),
    );
  }
}
