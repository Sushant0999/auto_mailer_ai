import 'package:flutter/material.dart';
import '../services/setup_service.dart';
import 'edit_profile_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final SetupService _setupService = SetupService();
  Map<String, String?> _creds = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCreds();
  }

  Future<void> _loadCreds() async {
    final creds = await _setupService.getCredentials();
    setState(() {
      _creds = creds;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings & Config'),
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_note, color: Color(0xFF6C63FF)),
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => EditProfileScreen(currentCreds: _creds),
                ),
              );
              if (result == true) {
                _loadCreds();
              }
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(24),
              children: [
                _buildInfoCard(
                  context,
                  title: 'Full Name',
                  subtitle: _creds['USER_NAME'] ?? 'Not found',
                  icon: Icons.person,
                ),
                const SizedBox(height: 16),
                _buildInfoCard(
                  context,
                  title: 'Phone Number',
                  subtitle: _creds['PHONE_NUMBER'] ?? 'Not set',
                  icon: Icons.phone,
                ),
                const SizedBox(height: 16),
                _buildInfoCard(
                  context,
                  title: 'LinkedIn',
                  subtitle: _creds['LINKEDIN_URL'] ?? 'Not set',
                  icon: Icons.link,
                ),
                const SizedBox(height: 16),
                _buildInfoCard(
                  context,
                  title: 'GitHub',
                  subtitle: _creds['GITHUB_URL'] ?? 'Not set',
                  icon: Icons.code,
                ),
                const SizedBox(height: 16),
                _buildInfoCard(
                  context,
                  title: 'Groq API Key',
                  subtitle: _maskKey(_creds['GROQ_API_KEY'] ?? 'Not found'),
                  icon: Icons.vpn_key,
                ),
                const SizedBox(height: 16),
                _buildInfoCard(
                  context,
                  title: 'SMTP Email',
                  subtitle: _creds['SMTP_EMAIL'] ?? 'Not found',
                  icon: Icons.email,
                ),
                const SizedBox(height: 16),
                _buildInfoCard(
                  context,
                  title: 'SMTP App Password',
                  subtitle: _maskKey(_creds['SMTP_PASSWORD'] ?? 'Not found'),
                  icon: Icons.lock,
                ),
                const SizedBox(height: 40),
                const Card(
                  color: Color(0xFF1E1E1E),
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        Icon(Icons.info_outline, color: Color(0xFF6C63FF)),
                        SizedBox(height: 12),
                        Text(
                          'Configuration Note',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'These credentials are stored locally in your database. To update them, please use the initial setup flow or a future update screen.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  String _maskKey(String key) {
    if (key == 'Not found' || key.length < 8) return key;
    return '${key.substring(0, 4)}****${key.substring(key.length - 4)}';
  }

  Widget _buildInfoCard(BuildContext context, {required String title, required String subtitle, required IconData icon}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF6C63FF).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: const Color(0xFF6C63FF)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 4),
                Text(subtitle, style: TextStyle(color: Colors.grey[400])),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
