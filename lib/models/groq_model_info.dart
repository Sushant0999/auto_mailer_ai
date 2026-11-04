class GroqModelInfo {
  final String id;
  final String? ownedBy;
  final int? contextWindow;
  final bool isVision;
  final bool isCustom;
  final String? description;

  const GroqModelInfo({
    required this.id,
    this.ownedBy,
    this.contextWindow,
    this.isVision = false,
    this.isCustom = false,
    this.description,
  });

  factory GroqModelInfo.fromJson(Map<String, dynamic> json) {
    final id = json['id'] as String? ?? '';
    final ownedBy = json['owned_by'] as String?;
    final contextWindow = json['context_window'] as int?;

    final lowerId = id.toLowerCase();
    // Detect multimodal / vision capability based on identifier patterns
    final isVision = lowerId.contains('vision') ||
        lowerId.contains('vl') ||
        lowerId.contains('qwen') ||
        lowerId.contains('scout') ||
        lowerId.contains('multimodal');

    return GroqModelInfo(
      id: id,
      ownedBy: ownedBy,
      contextWindow: contextWindow,
      isVision: isVision,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'owned_by': ownedBy,
        'context_window': contextWindow,
        'is_vision': isVision,
        'is_custom': isCustom,
        'description': description,
      };

  @override
  String toString() => id;
}
