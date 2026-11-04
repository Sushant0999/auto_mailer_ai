import 'dart:io';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import 'database_service.dart';

class MailService {
  final DatabaseService _db = DatabaseService();
  static bool _isProcessingQueue = false;

  Future<void> queueJobApplication({
    required String recipient,
    required String subject,
    required String body,
    String? resumePath,
  }) async {
    await _db.insertEmail({
      'recipient': recipient.trim(),
      'subject': subject.trim(),
      'body': body.trim(),
      'resume_path': resumePath,
      'status': 'pending',
    });
    // Trigger queue processing asynchronously
    processQueue();
  }

  Future<void> processQueue() async {
    if (_isProcessingQueue) return;
    _isProcessingQueue = true;

    try {
      final pendingEmails = await _db.getEmails(status: 'pending');
      final failedEmails = await _db.getEmails(status: 'failed');
      
      // Combine and limit retries (e.g., only retry if retries < 3)
      final queue = [...pendingEmails, ...failedEmails].where((e) => (e['retries'] ?? 0) < 3).toList();

      if (queue.isEmpty) return;

      final smtpEmail = await _db.getConfig('SMTP_EMAIL');
      final smtpPassword = await _db.getConfig('SMTP_PASSWORD');
      final userName = await _db.getConfig('USER_NAME') ?? 'Job Applicant';

      if (smtpEmail == null || smtpPassword == null) {
        return;
      }

      final smtpServer = gmail(smtpEmail, smtpPassword);

      for (var emailData in queue) {
        final int id = emailData['id'];
        final int currentRetries = emailData['retries'] ?? 0;

        await _db.updateEmailStatus(id, 'sending');

        final message = Message()
          ..from = Address(smtpEmail, userName)
          ..recipients.add(emailData['recipient'])
          ..subject = emailData['subject']
          ..text = emailData['body'];

        if (emailData['resume_path'] != null && (emailData['resume_path'] as String).isNotEmpty) {
          final file = File(emailData['resume_path']);
          if (await file.exists()) {
            message.attachments.add(FileAttachment(file));
          }
        }

        try {
          await send(message, smtpServer);
          await _db.updateEmailStatus(id, 'sent', retries: currentRetries + 1);
        } on MailerException catch (e) {
          await _db.updateEmailStatus(
            id, 
            'failed', 
            errorMessage: e.toString(), 
            retries: currentRetries + 1
          );
        } catch (e) {
          await _db.updateEmailStatus(
            id, 
            'failed', 
            errorMessage: e.toString(), 
            retries: currentRetries + 1
          );
        }
      }
    } finally {
      _isProcessingQueue = false;
    }
  }

  // Legacy method preserved for compatibility or direct sending if needed
  Future<void> sendDirect({
    required String recipient,
    required String subject,
    required String body,
  }) async {
    final smtpEmail = await _db.getConfig('SMTP_EMAIL');
    final smtpPassword = await _db.getConfig('SMTP_PASSWORD');
    
    if (smtpEmail == null || smtpPassword == null) throw Exception('Credentials not configured');

    final smtpServer = gmail(smtpEmail, smtpPassword);
    final message = Message()
      ..from = Address(smtpEmail, 'Job Applicant')
      ..recipients.add(recipient)
      ..subject = subject
      ..text = body;

    await send(message, smtpServer);
  }
}
