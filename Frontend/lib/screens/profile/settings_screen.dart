import 'package:flutter/material.dart';
import '../../theme.dart';
import '../../providers/app_providers.dart';
import '../../widgets/language_selector.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notificationsEnabled = true;
  String _selectedLanguage = 'English';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('settings')),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          _buildSectionHeader(context.tr('notifications')),
          SwitchListTile(
            title: Text(context.tr('enable_notifications')),
            subtitle: Text(context.tr('notifications_description')),
            value: _notificationsEnabled,
            onChanged: (value) {
              setState(() {
                _notificationsEnabled = value;
              });
              // TODO: Implement notification settings
            },
            secondary: const Icon(Icons.notifications),
          ),
          const Divider(),
          
          _buildSectionHeader(context.tr('language')),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                Text(
                  context.tr('select_language'),
                  style: const TextStyle(
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 16),
                const LanguageSelector(),
              ],
            ),
          ),
          const Divider(),
          
          _buildSectionHeader(context.tr('privacy_security')),
          ListTile(
            leading: const Icon(Icons.security),
            title: Text(context.tr('change_password')),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // TODO: Navigate to change password screen
            },
          ),
          ListTile(
            leading: const Icon(Icons.privacy_tip),
            title: Text(context.tr('privacy_policy')),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.pushNamed(context, '/privacy');
            },
          ),
          ListTile(
            leading: const Icon(Icons.description),
            title: Text(context.tr('terms_of_service')),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.pushNamed(context, '/terms');
            },
          ),
          const Divider(),
          
          _buildSectionHeader(context.tr('about')),
          ListTile(
            leading: const Icon(Icons.info),
            title: Text(context.tr('app_version')),
            subtitle: const Text('1.0.0'),
          ),
          ListTile(
            leading: const Icon(Icons.help),
            title: Text(context.tr('help_support')),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.pushNamed(context, '/help');
            },
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: AppColors.darkBlue,
        ),
      ),
    );
  }
} 