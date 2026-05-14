import 'dart:async';
import 'package:flutter/material.dart';
import '../services/database_service.dart';
import '../services/mail_service.dart';
import 'package:intl/intl.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final DatabaseService _db = DatabaseService();
  final MailService _mailService = MailService();
  List<Map<String, dynamic>> _emails = [];
  bool _isLoading = true;
  StreamSubscription? _dbSubscription;

  @override
  void initState() {
    super.initState();
    _loadEmails();
    _dbSubscription = _db.onChange.listen((_) => _loadEmails());
  }

  @override
  void dispose() {
    _dbSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadEmails() async {
    setState(() => _isLoading = true);
    final emails = await _db.getEmails();
    setState(() {
      _emails = emails;
      _isLoading = false;
    });
  }

  Future<void> _retryEmail(int id) async {
    await _db.updateEmailStatus(id, 'pending', retries: 0);
    _mailService.processQueue();
    _loadEmails();
  }

  Future<void> _archiveEmail(int id) async {
    await _db.updateEmailStatus(id, 'archived');
    _loadEmails();
  }

  Future<void> _deleteEmail(int id) async {
    await _db.deleteEmail(id);
    _loadEmails();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Email History & Queue'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadEmails,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _emails.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _emails.length,
                  itemBuilder: (context, index) {
                    final email = _emails[index];
                    return _buildEmailCard(email);
                  },
                ),
    );
  }

  void _showEmailDetails(Map<String, dynamic> email) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(email['recipient'], style: const TextStyle(fontSize: 18)),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailItem('Subject', email['subject']),
              const Divider(height: 32, color: Colors.white10),
              _buildDetailItem('Body', email['body']),
              if (email['error_message'] != null) ...[
                const Divider(height: 32, color: Colors.white10),
                _buildDetailItem('Error', email['error_message'], isError: true),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailItem(String label, String value, {bool isError = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Color(0xFF6C63FF), fontWeight: FontWeight.bold, fontSize: 12)),
        const SizedBox(height: 4),
        SelectableText(
          value,
          style: TextStyle(color: isError ? Colors.red[300] : Colors.grey[300], fontSize: 14),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.mail_outline, size: 64, color: Colors.grey[700]),
          const SizedBox(height: 16),
          Text(
            'No emails found',
            style: TextStyle(color: Colors.grey[600], fontSize: 18),
          ),
        ],
      ),
    );
  }

  Widget _buildEmailCard(Map<String, dynamic> email) {
    final status = email['status'];
    final color = _getStatusColor(status);
    final createdAt = DateTime.parse(email['created_at']);
    final formattedDate = DateFormat('MMM d, h:mm a').format(createdAt);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      color: const Color(0xFF1E1E1E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ExpansionTile(
        leading: _getStatusIcon(status),
        title: Text(
          email['recipient'],
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          '${email['subject']} • $formattedDate',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: Colors.grey[400], fontSize: 12),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withOpacity(0.5)),
          ),
          child: Text(
            status.toUpperCase(),
            style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (email['error_message'] != null) ...[
                  Text(
                    'Error: ${email['error_message']}',
                    style: const TextStyle(color: Colors.red, fontSize: 12),
                  ),
                  const SizedBox(height: 12),
                ],
                Text(
                  email['body'],
                  style: TextStyle(color: Colors.grey[300], fontSize: 14),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      onPressed: () => _showEmailDetails(email),
                      icon: const Icon(Icons.visibility_outlined, size: 18),
                      label: const Text('View'),
                    ),
                    if (status == 'failed')
                      TextButton.icon(
                        onPressed: () => _retryEmail(email['id']),
                        icon: const Icon(Icons.replay, size: 18),
                        label: const Text('Retry'),
                        style: TextButton.styleFrom(foregroundColor: Colors.orange),
                      ),
                    if (status != 'archived')
                      TextButton.icon(
                        onPressed: () => _archiveEmail(email['id']),
                        icon: const Icon(Icons.archive_outlined, size: 18),
                        label: const Text('Archive'),
                        style: TextButton.styleFrom(foregroundColor: Colors.blue),
                      ),
                    TextButton.icon(
                      onPressed: () => _deleteEmail(email['id']),
                      icon: const Icon(Icons.delete_outline, size: 18),
                      label: const Text('Delete'),
                      style: TextButton.styleFrom(foregroundColor: Colors.red),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'sent': return Colors.green;
      case 'failed': return Colors.red;
      case 'pending': return Colors.orange;
      case 'sending': return Colors.blue;
      case 'archived': return Colors.grey;
      default: return Colors.white;
    }
  }

  Widget _getStatusIcon(String status) {
    switch (status) {
      case 'sent': return const Icon(Icons.check_circle, color: Colors.green);
      case 'failed': return const Icon(Icons.error, color: Colors.red);
      case 'pending': return const Icon(Icons.timer, color: Colors.orange);
      case 'sending': return const Icon(Icons.send, color: Colors.blue);
      case 'archived': return const Icon(Icons.archive, color: Colors.grey);
      default: return const Icon(Icons.help);
    }
  }
}
