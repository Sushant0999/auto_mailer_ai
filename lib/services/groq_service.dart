import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'database_service.dart';
import '../models/job_details.dart';

class GroqService {
  static const String _baseUrl =
      'https://api.groq.com/openai/v1/chat/completions';
  final DatabaseService _db = DatabaseService();

  Future<JobDetails> extractAndGenerate(File imageFile) async {
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

    // Build the email generation instruction: prefer user's custom prompt if provided.
    final String emailInstruction = customPrompt.isNotEmpty
        ? customPrompt
        : 'generate a professional, high-converting cover letter for this position signed by $userName with the provided contact info.$resumePrompt The subject should be catchy but professional.';

    final response = await http.post(
      Uri.parse(_baseUrl),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      },
      body: jsonEncode({
        'model': 'meta-llama/llama-4-scout-17b-16e-instruct',
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

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final content = data['choices'][0]['message']['content'];

      try {
        final sanitized = _sanitizeJson(_extractJsonBlock(content.toString()));
        return JobDetails.fromJson(jsonDecode(sanitized));
      } catch (e) {
        print('JSON Parsing Error: $e\nContent: $content');
        throw Exception('Failed to parse AI response as JSON.');
      }
    } else {
      print('Groq API Error (${response.statusCode}): ${response.body}');
      final errorData = jsonDecode(response.body);
      final errorMessage = errorData['error']?['message'] ?? 'Unknown error';
      throw Exception('Groq API Error: $errorMessage');
    }
  }

  Future<JobDetails> reviseContent({
    required JobDetails originalDetails,
    required String feedback,
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

    final response = await http.post(
      Uri.parse(_baseUrl),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      },
      body: jsonEncode({
        'model': 'meta-llama/llama-4-scout-17b-16e-instruct',
        'messages': [
          {
            'role': 'user',
            'content': 'You previously generated this job application email for $userName:\nSubject: ${originalDetails.generatedSubject}\nBody: ${originalDetails.generatedBody}\n\nThe user wants to revise it with the following feedback: $feedback\n\nPlease rewrite the email signed by $userName (Contact info: $contactInfo) while keeping the HR email (${originalDetails.hrEmail}) and location (${originalDetails.location}) the same. Return the response ONLY as a JSON object with the keys: hr_email, location, generated_subject, generated_body.'
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
      } on FormatException catch (e) {
        print('FormatException while revising: $e\nRaw content: $content');
        throw Exception(
          'The AI returned an unexpected format. Please try again or simplify your feedback.',
        );
      } catch (e) {
        print('Error while revising: $e\nRaw content: $content');
        throw Exception('Failed to revise content. Please try again.');
      }
    } else {
      final body = response.body;
      String errorMessage = 'Unknown error (${response.statusCode})';
      try {
        final errorData = jsonDecode(body);
        errorMessage = errorData['error']?['message'] ?? errorMessage;
      } catch (_) {}
      throw Exception('Failed to revise content: $errorMessage');
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
    // Match JSON string literals, handling escaped double quotes
    final regExp = RegExp(r'"[^"\\]*(?:\\.[^"\\]*)*"');
    return jsonStr.replaceAllMapped(regExp, (match) {
      String val = match.group(0)!;
      // Replace raw control characters (newlines, carriage returns, tabs) with escaped versions
      return val.replaceAll('\n', '\\n')
                .replaceAll('\r', '\\r')
                .replaceAll('\t', '\\t');
    });
  }
}
