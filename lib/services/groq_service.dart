import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'database_service.dart';
import '../models/job_details.dart';
import '../models/groq_model_info.dart';

class GroqService {
  static const String _chatUrl =
      'https://api.groq.com/openai/v1/chat/completions';
  static const String _modelsUrl =
      'https://api.groq.com/openai/v1/models';

  // Active default models (decommissioned llama-3.2-11b-vision-preview replaced with qwen/qwen3.8-27b)
  static const String defaultVisionModel = 'qwen/qwen3.8-27b';
  static const String defaultTextModel = 'llama-3.3-70b-versatile';

  final DatabaseService _db = DatabaseService();

  /// Gets the currently configured vision model for image/screenshot extraction.
  /// Automatically migrates away from any known decommissioned models.
  Future<String> getVisionModel() async {
    final configured = await _db.getConfig('GROQ_VISION_MODEL');
    if (configured == null ||
        configured.isEmpty ||
        configured == 'llama-3.2-11b-vision-preview' ||
        configured == 'llama-3.2-90b-vision-preview') {
      await _db.setConfig('GROQ_VISION_MODEL', defaultVisionModel);
      return defaultVisionModel;
    }
    return configured;
  }

  /// Sets the vision model to use for image/screenshot extraction.
  Future<void> setVisionModel(String modelId) async {
    await _db.setConfig('GROQ_VISION_MODEL', modelId.trim());
  }

  /// Gets the currently configured text model for emails and resume tailoring.
  Future<String> getTextModel() async {
    final configured = await _db.getConfig('GROQ_TEXT_MODEL');
    if (configured == null || configured.isEmpty) {
      await _db.setConfig('GROQ_TEXT_MODEL', defaultTextModel);
      return defaultTextModel;
    }
    return configured;
  }

  /// Sets the text model to use for emails and resume tailoring.
  Future<void> setTextModel(String modelId) async {
    await _db.setConfig('GROQ_TEXT_MODEL', modelId.trim());
  }

  /// Fetches available models live from Groq API endpoint (GET /openai/v1/models).
  /// Falls back to a curated active list if network or auth fails.
  Future<List<GroqModelInfo>> fetchAvailableModels({String? apiKeyOverride}) async {
    final apiKey = apiKeyOverride ?? await _db.getConfig('GROQ_API_KEY');

    if (apiKey != null && apiKey.isNotEmpty) {
      try {
        final response = await http.get(
          Uri.parse(_modelsUrl),
          headers: {
            'Authorization': 'Bearer $apiKey',
            'Content-Type': 'application/json',
          },
        ).timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data['data'] is List) {
            final List list = data['data'];
            final models = list
                .map((m) => GroqModelInfo.fromJson(m as Map<String, dynamic>))
                // Filter out audio whisper transcription models
                .where((m) => !m.id.toLowerCase().startsWith('whisper-'))
                .toList();

            // Sort: Vision models first, then alphabetical
            models.sort((a, b) {
              if (a.isVision && !b.isVision) return -1;
              if (!a.isVision && b.isVision) return 1;
              return a.id.compareTo(b.id);
            });

            if (models.isNotEmpty) {
              return models;
            }
          }
        }
      } catch (e) {
        debugPrint('Failed to fetch live models from Groq API: $e');
      }
    }

    // Curated offline / fallback list of known active Groq models
    return const [
      GroqModelInfo(
        id: 'qwen/qwen3.8-27b',
        ownedBy: 'Alibaba Cloud',
        contextWindow: 131072,
        isVision: true,
        description: 'Recommended: Multimodal vision & OCR processing',
      ),
      GroqModelInfo(
        id: 'qwen/qwen3-vl-32b-instruct',
        ownedBy: 'Alibaba Cloud',
        contextWindow: 131072,
        isVision: true,
        description: 'Vision-language instruct model',
      ),
      GroqModelInfo(
        id: 'llama-3.3-70b-versatile',
        ownedBy: 'Meta',
        contextWindow: 131072,
        isVision: false,
        description: 'Recommended: Flagship high-intelligence reasoning & cover letter generation',
      ),
      GroqModelInfo(
        id: 'llama-3.1-8b-instant',
        ownedBy: 'Meta',
        contextWindow: 131072,
        isVision: false,
        description: 'Ultra-fast low-latency text model',
      ),
      GroqModelInfo(
        id: 'deepseek-r1-distill-llama-70b',
        ownedBy: 'DeepSeek',
        contextWindow: 131072,
        isVision: false,
        description: 'Deep reasoning, logic and ATS resume optimization',
      ),
      GroqModelInfo(
        id: 'gemma2-9b-it',
        ownedBy: 'Google',
        contextWindow: 8192,
        isVision: false,
        description: 'Google Gemma 2 9B instruction-tuned',
      ),
      GroqModelInfo(
        id: 'mixtral-8x7b-32768',
        ownedBy: 'Mistral AI',
        contextWindow: 32768,
        isVision: false,
        description: 'High-quality mixture-of-experts model',
      ),
    ];
  }

  Future<JobDetails> extractAndGenerate(
    File imageFile, {
    String? modelOverride,
  }) async {
    final apiKey = await _db.getConfig('GROQ_API_KEY');
    final userName = await _db.getConfig('USER_NAME') ?? 'Applicant';
    final phone = await _db.getConfig('PHONE_NUMBER') ?? '';
    final linkedin = await _db.getConfig('LINKEDIN_URL') ?? '';
    final github = await _db.getConfig('GITHUB_URL') ?? '';
    final resumeText = await _db.getConfig('RESUME_TEXT') ?? '';
    final customPrompt = await _db.getConfig('CUSTOM_PROMPT') ?? '';

    final contactInfo = [
      if (phone.isNotEmpty) 'Phone: $phone',
      if (linkedin.isNotEmpty) 'LinkedIn: $linkedin',
      if (github.isNotEmpty) 'GitHub: $github',
    ].join(', ');

    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('Groq API Key not configured. Please go to Settings.');
    }

    final bytes = await imageFile.readAsBytes();
    final base64Image = base64Encode(bytes);

    final resumePrompt = resumeText.isNotEmpty
        ? ' Tailor the cover letter to highlight matching skills and experiences from the applicant\'s resume text: """$resumeText""".'
        : '';

    final String emailInstruction = customPrompt.isNotEmpty
        ? customPrompt
        : 'generate a professional, high-converting cover letter for this position signed by $userName with the provided contact info.$resumePrompt The subject should be catchy but professional.';

    String selectedModel = modelOverride ?? await getVisionModel();

    http.Response response = await _callVisionApi(
      apiKey: apiKey,
      model: selectedModel,
      userName: userName,
      contactInfo: contactInfo,
      emailInstruction: emailInstruction,
      base64Image: base64Image,
    );

    // If the selected model fails due to deprecation or decommission, auto-fallback to default vision model
    if (response.statusCode != 200) {
      final errorBody = response.body;
      bool isDecommissioned = false;
      try {
        final errorData = jsonDecode(errorBody);
        final code = errorData['error']?['code']?.toString() ?? '';
        final msg = errorData['error']?['message']?.toString() ?? '';
        if (code == 'model_decommissioned' ||
            msg.contains('decommissioned') ||
            msg.contains('not found') ||
            msg.contains('does not support')) {
          isDecommissioned = true;
        }
      } catch (_) {}

      if (isDecommissioned && selectedModel != defaultVisionModel) {
        debugPrint(
            'Model $selectedModel is decommissioned/invalid for vision. Falling back to $defaultVisionModel');
        selectedModel = defaultVisionModel;
        await setVisionModel(defaultVisionModel);
        response = await _callVisionApi(
          apiKey: apiKey,
          model: selectedModel,
          userName: userName,
          contactInfo: contactInfo,
          emailInstruction: emailInstruction,
          base64Image: base64Image,
        );
      }
    }

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final content = data['choices'][0]['message']['content'];

      try {
        final sanitized = _sanitizeJson(_extractJsonBlock(content.toString()));
        return JobDetails.fromJson(jsonDecode(sanitized));
      } catch (e) {
        throw Exception('Failed to parse AI response as JSON: $e');
      }
    } else {
      final errorData = jsonDecode(response.body);
      final errorMessage = errorData['error']?['message'] ?? 'Unknown error';
      throw Exception(
        'Groq API Error ($selectedModel): $errorMessage. You can select an active model in Settings > AI Models.',
      );
    }
  }

  Future<http.Response> _callVisionApi({
    required String apiKey,
    required String model,
    required String userName,
    required String contactInfo,
    required String emailInstruction,
    required String base64Image,
  }) async {
    return await http.post(
      Uri.parse(_chatUrl),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      },
      body: jsonEncode({
        'model': model,
        'messages': [
          {
            'role': 'user',
            'content': [
              {
                'type': 'text',
                'text':
                    'You are an expert HR assistant. The applicant\'s name is $userName. Contact info to include: $contactInfo. Extract the HR email address and job location from this image. Then, $emailInstruction Return the response ONLY as a JSON object with the following keys: hr_email, location, generated_subject, generated_body.',
              },
              {
                'type': 'image_url',
                'image_url': {'url': 'data:image/jpeg;base64,$base64Image'},
              },
            ],
          },
        ],
      }),
    );
  }

  Future<JobDetails> reviseContent({
    required JobDetails originalDetails,
    required String feedback,
    String? modelOverride,
  }) async {
    final apiKey = await _db.getConfig('GROQ_API_KEY');
    final userName = await _db.getConfig('USER_NAME') ?? 'Applicant';
    final phone = await _db.getConfig('PHONE_NUMBER') ?? '';
    final linkedin = await _db.getConfig('LINKEDIN_URL') ?? '';
    final github = await _db.getConfig('GITHUB_URL') ?? '';

    final contactInfo = [
      if (phone.isNotEmpty) 'Phone: $phone',
      if (linkedin.isNotEmpty) 'LinkedIn: $linkedin',
      if (github.isNotEmpty) 'GitHub: $github',
    ].join(', ');

    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('Groq API Key not configured.');
    }

    final selectedModel = modelOverride ?? await getTextModel();

    final response = await http.post(
      Uri.parse(_chatUrl),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      },
      body: jsonEncode({
        'model': selectedModel,
        'messages': [
          {
            'role': 'user',
            'content':
                'You previously generated this job application email for $userName:\nSubject: ${originalDetails.generatedSubject}\nBody: ${originalDetails.generatedBody}\n\nThe user wants to revise it with the following feedback: $feedback\n\nPlease rewrite the email signed by $userName (Contact info: $contactInfo) while keeping the HR email (${originalDetails.hrEmail}) and location (${originalDetails.location}) the same. Return the response ONLY as a JSON object with the keys: hr_email, location, generated_subject, generated_body.'
          }
        ],
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final content = data['choices'][0]['message']['content'];

      try {
        final cleaned = _extractJsonBlock(content.toString());
        final sanitized = _sanitizeJson(cleaned);
        return JobDetails.fromJson(jsonDecode(sanitized));
      } on FormatException catch (_) {
        throw Exception(
          'The AI returned an unexpected format. Please try again or simplify your feedback.',
        );
      } catch (e) {
        throw Exception('Failed to revise content: $e');
      }
    } else {
      final body = response.body;
      String errorMessage = 'Unknown error (${response.statusCode})';
      try {
        final errorData = jsonDecode(body);
        errorMessage = errorData['error']?['message'] ?? errorMessage;
      } catch (_) {}
      throw Exception('Failed to revise content with $selectedModel: $errorMessage');
    }
  }

  /// AI Tailoring: analyzes current resume against a targeted job description or role,
  /// and returns precise target string replacements (original text -> updated text)
  /// so the PDF structure, fonts, line height, and layout remain completely preserved!
  Future<Map<String, dynamic>> tailorResumeForJob({
    required String resumeText,
    required String jobContext,
    String? focusArea,
    String? modelOverride,
  }) async {
    final apiKey = await _db.getConfig('GROQ_API_KEY');
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('Groq API Key not configured.');
    }

    final selectedModel = modelOverride ?? await getTextModel();

    final prompt = '''
You are a senior executive recruiter and ATS resume optimization expert.
The user wants to tailor their resume for a specific job, BUT WE MUST PRESERVE the EXACT structure, fonts, margins, and physical length of their original resume document.

JOB DETAILS / REQUIREMENTS:
"""$jobContext"""

APPLICANT'S CURRENT RESUME TEXT:
"""$resumeText"""

Focus area / instructions: ${focusArea ?? 'Tailor the professional summary, key skills, and impact bullet points to align with the job requirements.'}

CRITICAL RULES:
1. Each replacement MUST have an "original_text" that is an EXACT substring from the resume text above. Do not truncate words or make up text.
2. The "updated_text" must be approximately the same word count / character length as the "original_text" so that it fits naturally into the same visual line space on the PDF without overflowing.
3. Suggest between 2 and 6 high-impact replacements (e.g. optimizing summary, highlighting matching technical keywords, rewriting bullet points with quantifiable impact).
4. Return ONLY a valid JSON object with the following schema:
{
  "tailored_summary": "Short 1-2 sentence overview of how resume was adapted",
  "recommended_keywords": ["keyword1", "keyword2", "keyword3"],
  "replacements": [
    {
      "section": "Summary or Skills or Experience",
      "original_text": "Exact sentence or phrase from resume",
      "updated_text": "New tailored sentence or phrase",
      "reason": "Why this change improves ATS match or relevance"
    }
  ]
}
''';

    final response = await http.post(
      Uri.parse(_chatUrl),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      },
      body: jsonEncode({
        'model': selectedModel,
        'messages': [
          {'role': 'user', 'content': prompt}
        ],
        'temperature': 0.3,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final content = data['choices'][0]['message']['content'];
      try {
        final cleaned = _extractJsonBlock(content.toString());
        final sanitized = _sanitizeJson(cleaned);
        return jsonDecode(sanitized) as Map<String, dynamic>;
      } catch (e) {
        throw Exception('Failed to parse AI tailoring suggestions: $e');
      }
    } else {
      final body = response.body;
      String errorMessage = 'Error (${response.statusCode})';
      try {
        final errorData = jsonDecode(body);
        errorMessage = errorData['error']?['message'] ?? errorMessage;
      } catch (_) {}
      throw Exception('Resume tailoring failed ($selectedModel): $errorMessage');
    }
  }

  /// Extracts the first JSON object block from [raw], stripping markdown fences
  /// (```json ... ``` or ``` ... ```) if present.
  String _extractJsonBlock(String raw) {
    String text = raw.trim();

    // Strip markdown code fences if present
    if (text.startsWith('```')) {
      final lines = text.split('\n');
      if (lines.length > 2) {
        text = lines.sublist(1, lines.length - 1).join('\n').trim();
        // Remove closing fence if still present
        if (text.endsWith('```')) {
          text = text.substring(0, text.length - 3).trim();
        }
      }
    }

    // As a last resort, try to find the first {...} block via regex
    if (!text.startsWith('{')) {
      final jsonMatch = RegExp(r'\{[\s\S]*\}').firstMatch(text);
      if (jsonMatch != null) {
        text = jsonMatch.group(0)!;
      }
    }

    return text;
  }

  String _sanitizeJson(String jsonStr) {
    final regExp = RegExp(r'"[^"\\]*(?:\\.[^"\\]*)*"');
    return jsonStr.replaceAllMapped(regExp, (match) {
      String val = match.group(0)!;
      return val
          .replaceAll('\n', '\\n')
          .replaceAll('\r', '\\r')
          .replaceAll('\t', '\\t');
    });
  }
}
