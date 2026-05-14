import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../models/job_details.dart';
import '../services/mail_service.dart';
import '../services/groq_service.dart';

class JobDetailScreen extends StatefulWidget {
  final JobDetails jobDetails;

  const JobDetailScreen({super.key, required this.jobDetails});

  @override
  State<JobDetailScreen> createState() => _JobDetailScreenState();
}

class _JobDetailScreenState extends State<JobDetailScreen> {
  final MailService _mailService = MailService();
  final GroqService _groqService = GroqService();
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
    _subjectController = TextEditingController(text: _currentDetails.generatedSubject);
    _bodyController = TextEditingController(text: _currentDetails.generatedBody);
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
        type: FileType.any, // Test with ANY first
      );

      if (result != null) {
        setState(() {
          _resumePath = result.files.single.path;
        });
      }
    } catch (e) {
      print('File Picker Error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open file picker: $e')),
      );
    }
  }

  Future<void> _revise() async {
    if (_feedbackController.text.isEmpty) return;

    setState(() => _isRevising = true);
    try {
      final revised = await _groqService.reviseContent(
        originalDetails: _currentDetails,
        feedback: _feedbackController.text,
      );
      setState(() {
        _currentDetails = revised;
        _subjectController.text = revised.generatedSubject;
        _bodyController.text = revised.generatedBody;
        _feedbackController.clear();
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Revision failed: $e')),
      );
    } finally {
      setState(() => _isRevising = false);
    }
  }

  Future<void> _sendMail() async {
    setState(() => _isSending = true);
    try {
      await _mailService.queueJobApplication(
        recipient: _emailController.text,
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
            
            // Resume Attachment Section
            _buildSectionHeader('Attachment'),
            InkWell(
              onTap: _pickResume,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _resumePath != null ? const Color(0xFF6C63FF) : Colors.white10,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _resumePath != null ? Icons.description : Icons.attach_file,
                      color: _resumePath != null ? const Color(0xFF6C63FF) : Colors.grey,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _resumePath != null 
                          ? _resumePath!.split('/').last 
                          : 'Attach Resume (PDF/DOC)',
                        style: TextStyle(
                          color: _resumePath != null ? Colors.white : Colors.grey,
                        ),
                      ),
                    ),
                    if (_resumePath != null)
                      IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () => setState(() => _resumePath = null),
                      ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 32),
            _buildSectionHeader('Revise with AI'),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _feedbackController,
                    decoration: InputDecoration(
                      hintText: 'e.g., Make it more enthusiastic...',
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
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.auto_fix_high),
                  style: IconButton.styleFrom(backgroundColor: const Color(0xFF6C63FF)),
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
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
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
        style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF6C63FF)),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, IconData icon, {int maxLines = 1}) {
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
