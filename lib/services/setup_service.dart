import 'dart:io';
import 'database_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

class SetupService {
  final DatabaseService _db = DatabaseService();
  
  static const String _setupKey = 'is_setup_complete';

  Future<bool> isSetupComplete() async {
    final prefs = await SharedPreferences.getInstance();
    bool isComplete = prefs.getBool(_setupKey) ?? false;
    
    if (isComplete) {
      // Double check if credentials actually exist in DB
      final grokKey = await _db.getConfig('GROQ_API_KEY');
      final smtpEmail = await _db.getConfig('SMTP_EMAIL');
      final smtpPass = await _db.getConfig('SMTP_PASSWORD');
      
      return grokKey != null && smtpEmail != null && smtpPass != null;
    }
    return false;
  }

  Future<void> completeSetup({
    required String userName,
    String? phone,
    String? linkedin,
    String? github,
    required String grokKey,
    required String smtpEmail,
    required String smtpPassword,
    String? resumePath,
    String? resumeText,
  }) async {
    await _db.setConfig('USER_NAME', userName);
    await _db.setConfig('PHONE_NUMBER', phone ?? '');
    await _db.setConfig('LINKEDIN_URL', linkedin ?? '');
    await _db.setConfig('GITHUB_URL', github ?? '');
    await _db.setConfig('GROQ_API_KEY', grokKey);
    await _db.setConfig('SMTP_EMAIL', smtpEmail);
    await _db.setConfig('SMTP_PASSWORD', smtpPassword);
    if (resumePath != null) {
      await _db.setConfig('RESUME_PATH', resumePath);
    }
    if (resumeText != null) {
      await _db.setConfig('RESUME_TEXT', resumeText);
    }
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_setupKey, true);
  }

  Future<Map<String, String?>> getCredentials() async {
    return {
      'USER_NAME': await _db.getConfig('USER_NAME'),
      'PHONE_NUMBER': await _db.getConfig('PHONE_NUMBER'),
      'LINKEDIN_URL': await _db.getConfig('LINKEDIN_URL'),
      'GITHUB_URL': await _db.getConfig('GITHUB_URL'),
      'GROQ_API_KEY': await _db.getConfig('GROQ_API_KEY'),
      'SMTP_EMAIL': await _db.getConfig('SMTP_EMAIL'),
      'SMTP_PASSWORD': await _db.getConfig('SMTP_PASSWORD'),
      'RESUME_PATH': await _db.getConfig('RESUME_PATH'),
      'RESUME_TEXT': await _db.getConfig('RESUME_TEXT'),
    };
  }

  Future<String> extractResumeText(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) return '';

      final ext = filePath.split('.').last.toLowerCase();
      if (ext == 'pdf') {
        final bytes = await file.readAsBytes();
        final document = PdfDocument(inputBytes: bytes);
        final extractor = PdfTextExtractor(document);
        final text = extractor.extractText();
        document.dispose();
        return text;
      } else {
        return await file.readAsString();
      }
    } catch (e) {
      print('Resume extraction error: $e');
      return '';
    }
  }
}
