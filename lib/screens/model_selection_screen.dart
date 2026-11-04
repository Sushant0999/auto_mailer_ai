import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/groq_model_info.dart';
import '../services/groq_service.dart';

class ModelSelectionScreen extends StatefulWidget {
  const ModelSelectionScreen({super.key});

  @override
  State<ModelSelectionScreen> createState() => _ModelSelectionScreenState();
}

class _ModelSelectionScreenState extends State<ModelSelectionScreen> {
  final GroqService _groqService = GroqService();
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _customModelController = TextEditingController();

  List<GroqModelInfo> _allModels = [];
  List<GroqModelInfo> _filteredModels = [];
  String _currentVisionModel = GroqService.defaultVisionModel;
  String _currentTextModel = GroqService.defaultTextModel;

  bool _isLoading = true;
  bool _isSyncing = false;
  String _selectedFilter = 'All'; // 'All', 'Vision', 'Text'

  @override
  void initState() {
    super.initState();
    _loadModelsAndPreferences();
    _searchController.addListener(_applyFilter);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _customModelController.dispose();
    super.dispose();
  }

  Future<void> _loadModelsAndPreferences() async {
    setState(() => _isLoading = true);
    try {
      final vision = await _groqService.getVisionModel();
      final text = await _groqService.getTextModel();
      final models = await _groqService.fetchAvailableModels();

      setState(() {
        _currentVisionModel = vision;
        _currentTextModel = text;
        _allModels = models;
        _applyFilter();
        _isLoading = false;
      });
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _syncFromGroqApi() async {
    setState(() => _isSyncing = true);
    try {
      final liveModels = await _groqService.fetchAvailableModels();
      setState(() {
        _allModels = liveModels;
        _applyFilter();
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully synced ${liveModels.length} models from Groq!'),
            backgroundColor: const Color(0xFF6C63FF),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sync error: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  void _applyFilter() {
    final query = _searchController.text.trim().toLowerCase();
    setState(() {
      _filteredModels = _allModels.where((model) {
        final matchesQuery = model.id.toLowerCase().contains(query) ||
            (model.ownedBy?.toLowerCase().contains(query) ?? false) ||
            (model.description?.toLowerCase().contains(query) ?? false);

        if (!matchesQuery) return false;

        if (_selectedFilter == 'Vision') {
          return model.isVision;
        } else if (_selectedFilter == 'Text') {
          return !model.isVision;
        }
        return true;
      }).toList();
    });
  }

  Future<void> _setVisionModel(String modelId) async {
    await _groqService.setVisionModel(modelId);
    setState(() => _currentVisionModel = modelId);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Active Vision Model set to "$modelId"'),
          backgroundColor: const Color(0xFF00E5FF),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _setTextModel(String modelId) async {
    await _groqService.setTextModel(modelId);
    setState(() => _currentTextModel = modelId);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Active Text Model set to "$modelId"'),
          backgroundColor: const Color(0xFF6C63FF),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _addCustomModel(bool asVision) async {
    final customId = _customModelController.text.trim();
    if (customId.isEmpty) return;

    final customInfo = GroqModelInfo(
      id: customId,
      ownedBy: 'Custom',
      isVision: asVision,
      isCustom: true,
      description: 'User-specified custom model ID',
    );

    setState(() {
      if (!_allModels.any((m) => m.id == customId)) {
        _allModels.insert(0, customInfo);
      }
      _customModelController.clear();
      _applyFilter();
    });

    if (asVision) {
      await _setVisionModel(customId);
    } else {
      await _setTextModel(customId);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Model Selection'),
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            tooltip: 'Sync live models from Groq API',
            icon: _isSyncing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.sync, color: Color(0xFF00E5FF)),
            onPressed: _isSyncing ? null : _syncFromGroqApi,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Active Models Summary Banner
                _buildActiveModelsCard(),

                // Filter & Search Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Column(
                    children: [
                      TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Search models (e.g. qwen, llama, deepseek)...',
                          prefixIcon: const Icon(Icons.search, color: Colors.grey),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 18),
                                  onPressed: () => _searchController.clear(),
                                )
                              : null,
                          filled: true,
                          fillColor: const Color(0xFF1A1A24),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          _buildFilterChip('All'),
                          const SizedBox(width: 8),
                          _buildFilterChip('Vision', icon: Icons.remove_red_eye),
                          const SizedBox(width: 8),
                          _buildFilterChip('Text', icon: Icons.auto_stories),
                          const Spacer(),
                          Text(
                            '${_filteredModels.length} models',
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Custom Model Accordion
                _buildCustomModelInput(),

                // Model List
                Expanded(
                  child: _filteredModels.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.model_training, size: 48, color: Colors.grey),
                              const SizedBox(height: 12),
                              const Text(
                                'No matching models found',
                                style: TextStyle(color: Colors.grey, fontSize: 16),
                              ),
                              const SizedBox(height: 8),
                              TextButton.icon(
                                onPressed: _syncFromGroqApi,
                                icon: const Icon(Icons.sync),
                                label: const Text('Fetch Live from Groq'),
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                          itemCount: _filteredModels.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final model = _filteredModels[index];
                            return _buildModelCard(model);
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildActiveModelsCard() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E2C),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF6C63FF).withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6C63FF).withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.tune, color: Color(0xFF00E5FF), size: 20),
              const SizedBox(width: 8),
              const Text(
                'Active Engine Configuration',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  letterSpacing: 0.5,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.greenAccent.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle, size: 12, color: Colors.greenAccent),
                    SizedBox(width: 4),
                    Text(
                      'Ready',
                      style: TextStyle(fontSize: 11, color: Colors.greenAccent, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Vision Model Slot
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF14141E),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF00E5FF).withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.document_scanner, color: Color(0xFF00E5FF), size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'VISION & EXTRACTION MODEL (Screenshots & OCR)',
                        style: TextStyle(fontSize: 10, color: Color(0xFF00E5FF), fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _currentVisionModel,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Text Model Slot
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF14141E),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF6C63FF).withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.edit_note, color: Color(0xFF6C63FF), size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'TEXT & TAILORING MODEL (Cover Letter & Resume ATS)',
                        style: TextStyle(fontSize: 10, color: Color(0xFF9D95FF), fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _currentTextModel,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, {IconData? icon}) {
    final isSelected = _selectedFilter == label;
    return ChoiceChip(
      avatar: icon != null
          ? Icon(icon, size: 14, color: isSelected ? Colors.white : Colors.grey)
          : null,
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _selectedFilter = label;
            _applyFilter();
          });
        }
      },
      selectedColor: const Color(0xFF6C63FF),
      backgroundColor: const Color(0xFF1A1A24),
      labelStyle: TextStyle(
        fontSize: 12,
        color: isSelected ? Colors.white : Colors.grey,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  Widget _buildCustomModelInput() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          collapsedBackgroundColor: const Color(0xFF161622),
          backgroundColor: const Color(0xFF161622),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          collapsedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          leading: const Icon(Icons.add_circle_outline, color: Color(0xFF00E5FF), size: 20),
          title: const Text(
            'Enter Custom / Private Model ID',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Specify any model ID supported by Groq (e.g. meta-llama/llama-4-scout, custom fine-tune, or private preview):',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _customModelController,
                          decoration: InputDecoration(
                            hintText: 'model-identifier',
                            filled: true,
                            fillColor: const Color(0xFF0F0F17),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _addCustomModel(true),
                          icon: const Icon(Icons.remove_red_eye, size: 14),
                          label: const Text('Use for Vision', style: TextStyle(fontSize: 12)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF00838F),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _addCustomModel(false),
                          icon: const Icon(Icons.text_fields, size: 14),
                          label: const Text('Use for Text', style: TextStyle(fontSize: 12)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF5E35B1),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModelCard(GroqModelInfo model) {
    final isCurrentVision = _currentVisionModel == model.id;
    final isCurrentText = _currentTextModel == model.id;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF181824),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: (isCurrentVision || isCurrentText)
              ? (isCurrentVision ? const Color(0xFF00E5FF) : const Color(0xFF6C63FF))
                  .withOpacity(0.5)
              : Colors.white.withOpacity(0.06),
          width: (isCurrentVision || isCurrentText) ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  model.id,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.copy, size: 16, color: Colors.grey),
                tooltip: 'Copy Model ID',
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: model.id));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Copied "${model.id}" to clipboard'),
                      duration: const Duration(seconds: 1),
                    ),
                  );
                },
              ),
            ],
          ),

          // Badges row
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              if (model.isVision)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00E5FF).withOpacity(0.18),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'VISION & OCR',
                    style: TextStyle(
                      color: Color(0xFF00E5FF),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF6C63FF).withOpacity(0.18),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'TEXT & REASONING',
                  style: TextStyle(
                    color: Color(0xFF9E95FF),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (model.contextWindow != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${(model.contextWindow! / 1024).round()}K Context',
                    style: const TextStyle(fontSize: 10, color: Colors.white70),
                  ),
                ),
              if (model.ownedBy != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    model.ownedBy!,
                    style: const TextStyle(fontSize: 10, color: Colors.grey),
                  ),
                ),
            ],
          ),

          if (model.description != null) ...[
            const SizedBox(height: 8),
            Text(
              model.description!,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],

          const SizedBox(height: 12),

          // Action selectors
          Row(
            children: [
              // Set Vision
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _setVisionModel(model.id),
                  icon: Icon(
                    isCurrentVision ? Icons.check_circle : Icons.camera_alt_outlined,
                    size: 14,
                    color: isCurrentVision ? const Color(0xFF00E5FF) : Colors.white70,
                  ),
                  label: Text(
                    isCurrentVision ? 'Vision Active' : 'Set for Vision',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: isCurrentVision ? FontWeight.bold : FontWeight.normal,
                      color: isCurrentVision ? const Color(0xFF00E5FF) : Colors.white70,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                      color: isCurrentVision
                          ? const Color(0xFF00E5FF)
                          : Colors.white.withOpacity(0.15),
                    ),
                    backgroundColor: isCurrentVision
                        ? const Color(0xFF00E5FF).withOpacity(0.12)
                        : Colors.transparent,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Set Text
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _setTextModel(model.id),
                  icon: Icon(
                    isCurrentText ? Icons.check_circle : Icons.edit_note,
                    size: 16,
                    color: isCurrentText ? const Color(0xFF9E95FF) : Colors.white70,
                  ),
                  label: Text(
                    isCurrentText ? 'Text Active' : 'Set for Text',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: isCurrentText ? FontWeight.bold : FontWeight.normal,
                      color: isCurrentText ? const Color(0xFF9E95FF) : Colors.white70,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                      color: isCurrentText
                          ? const Color(0xFF6C63FF)
                          : Colors.white.withOpacity(0.15),
                    ),
                    backgroundColor: isCurrentText
                        ? const Color(0xFF6C63FF).withOpacity(0.12)
                        : Colors.transparent,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
