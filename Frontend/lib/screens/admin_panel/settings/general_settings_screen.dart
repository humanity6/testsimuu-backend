import 'package:flutter/material.dart';
import '../../../theme.dart';
import '../../../providers/app_providers.dart';
import '../../../widgets/language_selector.dart';
import '../../../utils/responsive_utils.dart';

class GeneralSettingsScreen extends StatefulWidget {
  const GeneralSettingsScreen({Key? key}) : super(key: key);

  @override
  State<GeneralSettingsScreen> createState() => _GeneralSettingsScreenState();
}

class _GeneralSettingsScreenState extends State<GeneralSettingsScreen> {
  bool _isLoading = true;
  bool _isSaving = false;
  Map<String, dynamic> _settings = {};
  bool _hasChanges = false;
  String? _errorMessage;
  
  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      final adminService = context.adminService;
      final settingsData = await adminService.getSystemSettings();
      
      setState(() {
        _settings = settingsData;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load settings: ${e.toString()}';
        _isLoading = false;
      });
    }
  }
  
  void _updateSetting(String key, dynamic value) {
    setState(() {
      _settings[key] = value;
      _hasChanges = true;
    });
  }
  
  // Helper method to safely get settings values with defaults
  T _getSetting<T>(String key, T defaultValue) {
    final value = _settings[key];
    if (value == null) return defaultValue;
    if (value is T) return value;
    return defaultValue;
  }
  
  Future<void> _saveSettings() async {
    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });
    
    try {
      final adminService = context.adminService;
      await adminService.updateSystemSettings(_settings);
      
      setState(() {
        _isSaving = false;
        _hasChanges = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('settings_saved')),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to save settings: ${e.toString()}';
        _isSaving = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('settings_save_error')),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('general_settings')),
        actions: const [
          LanguageSelector(isCompact: true),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildSettingsForm(),
      bottomNavigationBar: _hasChanges
          ? Container(
              color: AppColors.lightGrey,
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    context.tr('unsaved_changes'),
                    style: const TextStyle(
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton(
                    onPressed: _saveSettings,
                    child: Text(context.tr('save_changes')),
                  ),
                ],
              ),
            )
          : null,
    );
  }

  Widget _buildSettingsForm() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(ResponsiveUtils.isMobile(context) ? 16.0 : 24.0),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: ResponsiveUtils.isMobile(context) ? double.infinity : 800,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader(context.tr('ai_settings')),
              _buildAISettingsSection(),
              
              SizedBox(height: ResponsiveUtils.isMobile(context) ? 24 : 32),
              _buildSectionHeader(context.tr('banner_settings')),
              _buildBannerSettingsSection(),
              
              SizedBox(height: ResponsiveUtils.isMobile(context) ? 24 : 32),
              _buildSectionHeader(context.tr('announcement_settings')),
              _buildAnnouncementSettingsSection(),
              
              SizedBox(height: ResponsiveUtils.isMobile(context) ? 24 : 32),
              _buildSectionHeader(context.tr('system_settings')),
              _buildSystemSettingsSection(),
              
              // Add some bottom padding to ensure the last section is fully visible
              SizedBox(height: ResponsiveUtils.isMobile(context) ? 60 : 80),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildSectionHeader(String title) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const Divider(),
        const SizedBox(height: 16),
      ],
    );
  }
  
  Widget _buildAISettingsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // AI Search Frequency
            ListTile(
              title: Text(context.tr('ai_search_frequency')),
              subtitle: Text(context.tr('ai_search_frequency_description')),
              trailing: DropdownButton<String>(
                value: _getSetting<String>('ai_search_frequency', 'daily'),
                onChanged: (value) {
                  _updateSetting('ai_search_frequency', value);
                },
                items: ['hourly', 'daily', 'weekly', 'monthly'].map((value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(context.tr(value)),
                  );
                }).toList(),
              ),
            ),
            
            const Divider(),
            
            // AI Content Monitoring
            SwitchListTile(
              title: Text(context.tr('ai_content_monitoring')),
              subtitle: Text(context.tr('ai_content_monitoring_description')),
              value: _getSetting<bool>('ai_content_monitoring', true),
              onChanged: (value) {
                _updateSetting('ai_content_monitoring', value);
              },
            ),
            
            const Divider(),
            
            // AI Alert Threshold
            ResponsiveUtils.isMobile(context)
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              context.tr('ai_alert_threshold'),
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              context.tr('ai_alert_threshold_description'),
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Slider(
                        value: _getSetting<int>('ai_alert_threshold', 75).toDouble(),
                        min: 0,
                        max: 100,
                        divisions: 10,
                        label: '${_getSetting<int>('ai_alert_threshold', 75)}%',
                        onChanged: (value) {
                          _updateSetting('ai_alert_threshold', value.round());
                        },
                      ),
                    ],
                  )
                : ListTile(
                    title: Text(context.tr('ai_alert_threshold')),
                    subtitle: Text(context.tr('ai_alert_threshold_description')),
                    trailing: SizedBox(
                      width: 200,
                      child: Slider(
                        value: _getSetting<int>('ai_alert_threshold', 75).toDouble(),
                        min: 0,
                        max: 100,
                        divisions: 10,
                        label: '${_getSetting<int>('ai_alert_threshold', 75)}%',
                        onChanged: (value) {
                          _updateSetting('ai_alert_threshold', value.round());
                        },
                      ),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildBannerSettingsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Show Banner
            SwitchListTile(
              title: Text(context.tr('show_banner')),
              subtitle: Text(context.tr('show_banner_description')),
              value: _getSetting<bool>('show_banner', false),
              onChanged: (value) {
                _updateSetting('show_banner', value);
              },
            ),
            
            const Divider(),
            
            // Banner Text
            ListTile(
              title: Text(context.tr('banner_text')),
              subtitle: TextField(
                decoration: InputDecoration(
                  hintText: context.tr('enter_banner_text'),
                ),
                maxLines: 2,
                enabled: _getSetting<bool>('show_banner', false),
                controller: TextEditingController(text: _getSetting<String>('banner_text', '')),
                onChanged: (value) {
                  _updateSetting('banner_text', value);
                },
              ),
              contentPadding: const EdgeInsets.only(top: 16, left: 16, right: 16),
            ),
            
            // Banner Color
            ListTile(
              title: Text(context.tr('banner_color')),
              trailing: DropdownButton<String>(
                value: _getSetting<String>('banner_color', 'blue'),
                onChanged: _getSetting<bool>('show_banner', false) ? (value) {
                  _updateSetting('banner_color', value);
                } : null,
                items: ['blue', 'green', 'red', 'yellow', 'purple'].map((color) {
                  return DropdownMenuItem<String>(
                    value: color,
                    child: Text(context.tr(color)),
                  );
                }).toList(),
              ),
            ),
            
            const Divider(),
            
            // Banner Display Period
            ListTile(
              title: Text(context.tr('banner_display_period')),
              subtitle: Text(context.tr('banner_display_period_description')),
              contentPadding: const EdgeInsets.only(top: 8, left: 16, right: 16),
            ),
            
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ResponsiveUtils.isMobile(context)
                  ? Column(
                      children: [
                        TextFormField(
                          decoration: InputDecoration(
                            labelText: context.tr('start_date'),
                            suffixIcon: const Icon(Icons.calendar_today),
                          ),
                          enabled: _getSetting<bool>('show_banner', false),
                          readOnly: true,
                          controller: TextEditingController(text: _getSetting<String>('banner_start_date', '')),
                          onTap: _getSetting<bool>('show_banner', false) ? () async {
                            final date = await showDatePicker(
                              context: context,
                              initialDate: DateTime.now(),
                              firstDate: DateTime.now(),
                              lastDate: DateTime.now().add(const Duration(days: 365)),
                            );
                            
                            if (date != null) {
                              _updateSetting('banner_start_date', '${date.day}/${date.month}/${date.year}');
                            }
                          } : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          decoration: InputDecoration(
                            labelText: context.tr('end_date'),
                            suffixIcon: const Icon(Icons.calendar_today),
                          ),
                          enabled: _getSetting<bool>('show_banner', false),
                          readOnly: true,
                          controller: TextEditingController(text: _getSetting<String>('banner_end_date', '')),
                          onTap: _getSetting<bool>('show_banner', false) ? () async {
                            final date = await showDatePicker(
                              context: context,
                              initialDate: DateTime.now().add(const Duration(days: 7)),
                              firstDate: DateTime.now(),
                              lastDate: DateTime.now().add(const Duration(days: 365)),
                            );
                            
                            if (date != null) {
                              _updateSetting('banner_end_date', '${date.day}/${date.month}/${date.year}');
                            }
                          } : null,
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            decoration: InputDecoration(
                              labelText: context.tr('start_date'),
                              suffixIcon: const Icon(Icons.calendar_today),
                            ),
                            enabled: _getSetting<bool>('show_banner', false),
                            readOnly: true,
                            controller: TextEditingController(text: _getSetting<String>('banner_start_date', '')),
                            onTap: _getSetting<bool>('show_banner', false) ? () async {
                              final date = await showDatePicker(
                                context: context,
                                initialDate: DateTime.now(),
                                firstDate: DateTime.now(),
                                lastDate: DateTime.now().add(const Duration(days: 365)),
                              );
                              
                              if (date != null) {
                                _updateSetting('banner_start_date', '${date.day}/${date.month}/${date.year}');
                              }
                            } : null,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            decoration: InputDecoration(
                              labelText: context.tr('end_date'),
                              suffixIcon: const Icon(Icons.calendar_today),
                            ),
                            enabled: _getSetting<bool>('show_banner', false),
                            readOnly: true,
                            controller: TextEditingController(text: _getSetting<String>('banner_end_date', '')),
                            onTap: _getSetting<bool>('show_banner', false) ? () async {
                              final date = await showDatePicker(
                                context: context,
                                initialDate: DateTime.now().add(const Duration(days: 7)),
                                firstDate: DateTime.now(),
                                lastDate: DateTime.now().add(const Duration(days: 365)),
                              );
                              
                              if (date != null) {
                                _updateSetting('banner_end_date', '${date.day}/${date.month}/${date.year}');
                              }
                            } : null,
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildAnnouncementSettingsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Enable Announcements
            SwitchListTile(
              title: Text(context.tr('enable_announcements')),
              subtitle: Text(context.tr('enable_announcements_description')),
              value: _getSetting<bool>('enable_announcements', false),
              onChanged: (value) {
                _updateSetting('enable_announcements', value);
              },
            ),
            
            const Divider(),
            
            // Current Announcement
            ListTile(
              title: Text(context.tr('current_announcement')),
              subtitle: TextField(
                decoration: InputDecoration(
                  hintText: context.tr('enter_announcement_text'),
                ),
                maxLines: 3,
                enabled: _getSetting<bool>('enable_announcements', false),
                controller: TextEditingController(text: _getSetting<String>('announcement_text', '')),
                onChanged: (value) {
                  _updateSetting('announcement_text', value);
                },
              ),
              contentPadding: const EdgeInsets.only(top: 16, left: 16, right: 16),
            ),
            
            // Announcement Link
            ListTile(
              title: Text(context.tr('announcement_link')),
              subtitle: TextField(
                decoration: InputDecoration(
                  hintText: context.tr('enter_announcement_link'),
                ),
                enabled: _getSetting<bool>('enable_announcements', false),
                controller: TextEditingController(text: _getSetting<String>('announcement_link', '')),
                onChanged: (value) {
                  _updateSetting('announcement_link', value);
                },
              ),
              contentPadding: const EdgeInsets.only(top: 16, left: 16, right: 16, bottom: 16),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildSystemSettingsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Maintenance Mode
            SwitchListTile(
              title: Text(context.tr('maintenance_mode')),
              subtitle: Text(context.tr('maintenance_mode_description')),
              value: _getSetting<bool>('maintenance_mode', false),
              onChanged: (value) {
                _updateSetting('maintenance_mode', value);
              },
            ),
            
            const Divider(),
            
            // User Registration
            SwitchListTile(
              title: Text(context.tr('allow_registration')),
              subtitle: Text(context.tr('allow_registration_description')),
              value: _getSetting<bool>('allow_registration', true),
              onChanged: (value) {
                _updateSetting('allow_registration', value);
              },
            ),
            
            const Divider(),
            
            // System Email
            ListTile(
              title: Text(context.tr('system_email')),
              subtitle: TextField(
                decoration: InputDecoration(
                  hintText: context.tr('enter_system_email'),
                ),
                controller: TextEditingController(text: _getSetting<String>('system_email', '')),
                onChanged: (value) {
                  _updateSetting('system_email', value);
                },
              ),
              contentPadding: const EdgeInsets.only(top: 16, left: 16, right: 16),
            ),
            
            // Support Email
            ListTile(
              title: Text(context.tr('support_email')),
              subtitle: TextField(
                decoration: InputDecoration(
                  hintText: context.tr('enter_support_email'),
                ),
                controller: TextEditingController(text: _getSetting<String>('support_email', '')),
                onChanged: (value) {
                  _updateSetting('support_email', value);
                },
              ),
              contentPadding: const EdgeInsets.only(top: 16, left: 16, right: 16, bottom: 16),
            ),
          ],
        ),
      ),
    );
  }
} 
