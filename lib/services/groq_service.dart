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
                    'You are an expert HR assistant. The applicant\'s name is $userName. Contact info to include: $contactInfo. Extract the HR email address and job location from this image. Then, generate a professional, high-converting cover letter for this position signed by $userName with the provided contact info. The subject should be catchy but professional. Return the response ONLY as a JSON object with the following keys: hr_email, location, generated_subject, generated_body.',
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

      // Attempt to clean the content if it contains markdown markers like ```json
      String cleanedContent = content.toString().trim();
      if (cleanedContent.startsWith('```')) {
        final lines = cleanedContent.split('\n');
        if (lines.length > 2) {
          cleanedContent = lines.sublist(1, lines.length - 1).join('\n').trim();
        }
      }

      try {
        return JobDetails.fromJson(jsonDecode(cleanedContent));
      } catch (e) {
        print('JSON Parsing Error: $e\nContent: $cleanedContent');
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
      
      String cleanedContent = content.toString().trim();
      if (cleanedContent.startsWith('```')) {
        final lines = cleanedContent.split('\n');
        if (lines.length > 2) {
          cleanedContent = lines.sublist(1, lines.length - 1).join('\n').trim();
        }
      }
      
      return JobDetails.fromJson(jsonDecode(cleanedContent));
    } else {
      throw Exception('Failed to revise content: ${response.statusCode}');
    }
  }
}
