import 'package:flutter_test/flutter_test.dart';
import 'package:auto_mail_ai/models/groq_model_info.dart';
import 'package:auto_mail_ai/services/groq_service.dart';

void main() {
  group('GroqModelInfo and Model Selection Tests', () {
    test('GroqModelInfo detects vision capability correctly', () {
      final qwen = GroqModelInfo.fromJson({
        'id': 'qwen/qwen3.8-27b',
        'owned_by': 'Alibaba Cloud',
        'context_window': 131072,
      });
      expect(qwen.isVision, isTrue);

      final llama = GroqModelInfo.fromJson({
        'id': 'llama-3.3-70b-versatile',
        'owned_by': 'Meta',
        'context_window': 131072,
      });
      expect(llama.isVision, isFalse);

      final vlModel = GroqModelInfo.fromJson({
        'id': 'custom-vl-preview',
        'owned_by': 'Custom',
      });
      expect(vlModel.isVision, isTrue);
    });

    test('GroqService fallback list contains active vision and text models', () async {
      final service = GroqService();
      final models = await service.fetchAvailableModels(apiKeyOverride: '');

      expect(models, isNotEmpty);
      expect(models.any((m) => m.id == GroqService.defaultVisionModel), isTrue);
      expect(models.any((m) => m.id == GroqService.defaultTextModel), isTrue);

      // Verify decommissioned preview model is not in recommended list
      expect(models.any((m) => m.id == 'llama-3.2-11b-vision-preview'), isFalse);
    });
  });
}
