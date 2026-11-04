import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../services/setup_service.dart';
import '../services/groq_service.dart';
import '../services/resume_editor_service.dart';

class ResumeUpdateScreen extends StatefulWidget {
  final String? initialJobContext;
  final String? initialResumePath;

  const ResumeUpdateScreen({
    super.key,
    this.initialJobContext,
    this.initialResumePath,
  });

  @override
  State<ResumeUpdateScreen> createState() => _ResumeUpdateScreenState();
}

class _ResumeUpdateScreenState extends State<ResumeUpdateScreen>
    with SingleTickerProviderStateMixin {
  final SetupService _setupService = SetupService();
  final GroqService _groqService = GroqService();
  final ResumeEditorService _editorService = ResumeEditorService();

  late TabController _tabController;
  final TextEditingController _jobContextController = TextEditingController();
  final TextEditingController _findController = TextEditingController();
  final TextEditingController _replaceController = TextEditingController();

  String? _resumePath;
  String _resumeText = '';
  bool _isLoading = true;
  bool _isGeneratingAI = false;
  bool _isSaving = false;

  List<ResumeReplacement> _replacements = [];
  List<Map<String, String>> _parsedSections = [];
  String? _selectedSectionTitle;
  final TextEditingController _customOriginalController =
      TextEditingController();
  final TextEditingController _customUpdatedController =
      TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    if (widget.initialJobContext != null) {
      _jobContextController.text = widget.initialJobContext!;
    }
    _loadInitialResume();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _jobContextController.dispose();
    _findController.dispose();
    _replaceController.dispose();
    _customOriginalController.dispose();
    _customUpdatedController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialResume() async {
    setState(() => _isLoading = true);
    try {
      final creds = await _setupService.getCredentials();
      final path = widget.initialResumePath ?? creds['RESUME_PATH'];
      if (path != null && path.isNotEmpty && await File(path).exists()) {
        _resumePath = path;
        _resumeText = await _setupService.extractResumeText(path);
        _parsedSections = _editorService.parseResumeSections(_resumeText);
      }
    } catch (_) {}
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickNewResume() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'txt'],
      );
      if (result != null && result.files.single.path != null) {
        setState(() => _isLoading = true);
        final persistentPath = await _setupService
            .persistResumeFile(result.files.single.path!);
        final text = await _setupService.extractResumeText(persistentPath);

        setState(() {
          _resumePath = persistentPath;
          _resumeText = text;
          _parsedSections = _editorService.parseResumeSections(text);
          _replacements.clear();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not pick resume: $e')),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _generateAITailoring() async {
    if (_resumeText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a resume first.')),
      );
      return;
    }
    if (_jobContextController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please enter job details or requirements.')),
      );
      return;
    }

    setState(() => _isGeneratingAI = true);
    try {
      final result = await _groqService.tailorResumeForJob(
        resumeText: _resumeText,
        jobContext: _jobContextController.text.trim(),
      );

      final rawList = result['replacements'] as List? ?? [];
      final newReplacements = rawList
          .map((item) =>
              ResumeReplacement.fromJson(item as Map<String, dynamic>))
          .toList();

      setState(() {
        _replacements = newReplacements;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'AI generated ${newReplacements.length} tailored updates! Review and apply below.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('AI tailoring error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isGeneratingAI = false);
    }
  }

  void _addManualReplacement() {
    final orig = _customOriginalController.text.trim();
    final updated = _customUpdatedController.text.trim();
    if (orig.isEmpty || updated.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Original and updated text cannot be empty.')),
      );
      return;
    }

    setState(() {
      _replacements.add(ResumeReplacement(
        section: _selectedSectionTitle ?? 'Custom Edit',
        originalText: orig,
        updatedText: updated,
        reason: 'User manual edit',
      ));
      _customOriginalController.clear();
      _customUpdatedController.clear();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Section update added to list!')),
    );
  }

  void _addFindAndReplace() {
    final find = _findController.text.trim();
    final replace = _replaceController.text.trim();
    if (find.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Find field cannot be empty.')),
      );
      return;
    }

    setState(() {
      _replacements.add(ResumeReplacement(
        section: 'Find & Replace',
        originalText: find,
        updatedText: replace,
        reason: 'Direct keyword replacement',
      ));
      _findController.clear();
      _replaceController.clear();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Replacement added!')),
    );
  }

  Future<void> _saveAndApplyPdf() async {
    if (_resumePath == null || _resumePath!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No base resume found.')),
      );
      return;
    }

    final activeReplacements = _replacements.where((r) => r.isApplied).toList();
    if (activeReplacements.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select or add at least one update.')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final updatedPath = await _editorService.updateResumeInPlace(
        originalFilePath: _resumePath!,
        replacements: activeReplacements,
        setAsActiveResume: true,
      );

      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: const Color(0xFF1E1E1E),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green),
                SizedBox(width: 10),
                Text('Resume Updated!'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Your resume has been updated while preserving all original structure, fonts, margins, and layout.',
                  style: TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.picture_as_pdf, color: Color(0xFF6C63FF)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          updatedPath.split('/').last,
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context); // close dialog
                  Navigator.pop(context, updatedPath); // return to caller with path
                },
                child: const Text('Done & Use for Applications',
                    style: TextStyle(color: Color(0xFF6C63FF))),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update resume: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Format-Preserving Resume Editor',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF6C63FF),
          labelColor: const Color(0xFF6C63FF),
          unselectedLabelColor: Colors.grey,
          tabs: const [
            Tab(icon: Icon(Icons.auto_awesome, size: 20), text: 'AI Tailor'),
            Tab(icon: Icon(Icons.edit_note, size: 20), text: 'Section Edit'),
            Tab(icon: Icon(Icons.find_replace, size: 20), text: 'Find & Replace'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildActiveResumeHeader(),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildAITailorTab(),
                      _buildSectionEditTab(),
                      _buildFindReplaceTab(),
                    ],
                  ),
                ),
                _buildReplacementsTray(),
              ],
            ),
    );
  }

  Widget _buildActiveResumeHeader() {
    final fileName = _resumePath != null
        ? _resumePath!.split('/').last
        : 'No resume selected';
    final isPdf = _resumePath?.toLowerCase().endsWith('.pdf') ?? false;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        children: [
          Icon(
            isPdf ? Icons.picture_as_pdf : Icons.description,
            color: const Color(0xFF6C63FF),
            size: 28,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        fileName,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6C63FF).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        isPdf ? 'Original PDF Layout' : 'Text',
                        style: const TextStyle(
                            fontSize: 10,
                            color: Color(0xFF6C63FF),
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'Original structure, fonts & margins are kept 100% intact',
                  style: TextStyle(fontSize: 11, color: Colors.grey[400]),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'Choose different resume',
            icon: const Icon(Icons.file_upload_outlined, color: Colors.white70),
            onPressed: _pickNewResume,
          ),
        ],
      ),
    );
  }

  Widget _buildAITailorTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Target Job Requirements / Description',
            style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: Color(0xFF6C63FF)),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _jobContextController,
            maxLines: 4,
            decoration: InputDecoration(
              hintText:
                  'Paste the job description, required skills, or job post notes...',
              hintStyle: const TextStyle(fontSize: 13, color: Colors.grey),
              filled: true,
              fillColor: const Color(0xFF1E1E1E),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isGeneratingAI ? null : _generateAITailoring,
              icon: _isGeneratingAI
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.auto_awesome),
              label: Text(_isGeneratingAI
                  ? 'AI analyzing resume & layout...'
                  : 'Generate Tailored Updates'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6C63FF),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
          const SizedBox(height: 20),
          if (_replacements.isNotEmpty) ...[
            const Text(
              'Suggested In-Place Replacements',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(height: 8),
            ..._replacements.asMap().entries.map((entry) {
              final index = entry.key;
              final rep = entry.value;
              return _buildReplacementCard(index, rep);
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionEditTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Select a Section from Your Resume',
            style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: Color(0xFF6C63FF)),
          ),
          const SizedBox(height: 8),
          if (_parsedSections.isEmpty)
            const Text(
              'No sections detected or empty resume. Type below directly.',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _parsedSections.map((sec) {
                final isSelected = _selectedSectionTitle == sec['section'];
                return ChoiceChip(
                  label: Text(sec['section']!),
                  selected: isSelected,
                  selectedColor: const Color(0xFF6C63FF),
                  onSelected: (selected) {
                    setState(() {
                      _selectedSectionTitle = selected ? sec['section'] : null;
                      if (selected) {
                        _customOriginalController.text = sec['text']!;
                        _customUpdatedController.text = sec['text']!;
                      }
                    });
                  },
                );
              }).toList(),
            ),
          const SizedBox(height: 16),
          const Text('Original Text in Resume (Target to replace):',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 6),
          TextField(
            controller: _customOriginalController,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Exact sentence or bullet point to modify in-place...',
              filled: true,
              fillColor: const Color(0xFF1E1E1E),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 12),
          const Text('Updated Text (Will be drawn in same place & font):',
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: Colors.greenAccent)),
          const SizedBox(height: 6),
          TextField(
            controller: _customUpdatedController,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Your new bullet point or updated content...',
              filled: true,
              fillColor: const Color(0xFF1E1E1E),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _addManualReplacement,
            icon: const Icon(Icons.add),
            label: const Text('Add to Update List'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2C2C2C),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFindReplaceTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Quick In-Place Keyword Find & Replace',
            style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: Color(0xFF6C63FF)),
          ),
          const SizedBox(height: 8),
          const Text(
            'Ideal for replacing specific technology names, roles, or dates while keeping all fonts and layout untouched.',
            style: TextStyle(color: Colors.grey, fontSize: 12),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _findController,
            decoration: InputDecoration(
              labelText: 'Find Text (e.g., "React Native" or "Junior")',
              prefixIcon: const Icon(Icons.search, color: Colors.grey),
              filled: true,
              fillColor: const Color(0xFF1E1E1E),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _replaceController,
            decoration: InputDecoration(
              labelText: 'Replace With (e.g., "Flutter & Dart" or "Senior")',
              prefixIcon: const Icon(Icons.change_circle, color: Colors.greenAccent),
              filled: true,
              fillColor: const Color(0xFF1E1E1E),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _addFindAndReplace,
            icon: const Icon(Icons.playlist_add),
            label: const Text('Queue Keyword Replacement'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2C2C2C),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReplacementCard(int index, ResumeReplacement rep) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: rep.isApplied
              ? const Color(0xFF6C63FF).withOpacity(0.3)
              : Colors.white10,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Checkbox(
                value: rep.isApplied,
                activeColor: const Color(0xFF6C63FF),
                onChanged: (val) {
                  setState(() => rep.isApplied = val ?? true);
                },
              ),
              Expanded(
                child: Text(
                  rep.section,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: Color(0xFF6C63FF)),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 18, color: Colors.grey),
                onPressed: () {
                  setState(() => _replacements.removeAt(index));
                },
              ),
            ],
          ),
          if (rep.reason != null && rep.reason!.isNotEmpty) ...[
            Text(
              '💡 ${rep.reason!}',
              style: TextStyle(
                  fontSize: 11,
                  color: Colors.amber[300],
                  fontStyle: FontStyle.italic),
            ),
            const SizedBox(height: 8),
          ],
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.remove_circle_outline,
                    size: 14, color: Colors.redAccent),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    rep.originalText,
                    style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white70,
                        decoration: TextDecoration.lineThrough),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.add_circle_outline,
                    size: 14, color: Colors.greenAccent),
                const SizedBox(width: 6),
                Expanded(
                  child: TextFormField(
                    initialValue: rep.updatedText,
                    maxLines: null,
                    style: const TextStyle(fontSize: 12, color: Colors.white),
                    decoration: const InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                      border: InputBorder.none,
                    ),
                    onChanged: (val) => rep.updatedText = val,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReplacementsTray() {
    final activeCount = _replacements.where((r) => r.isApplied).length;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF161616),
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.08))),
      ),
      child: SafeArea(
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: (_isSaving || activeCount == 0) ? null : _saveAndApplyPdf,
            icon: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.save_as),
            label: Text(_isSaving
                ? 'Applying Updates to PDF...'
                : 'Apply $activeCount Updates & Save PDF'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6C63FF),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 18),
            ),
          ),
        ),
      ),
    );
  }
}
