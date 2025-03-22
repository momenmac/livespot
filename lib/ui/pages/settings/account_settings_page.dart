import 'package:flutter/material.dart';
import 'package:flutter_application_2/constants/theme_constants.dart';

class AccountSettingsPage extends StatefulWidget {
  const AccountSettingsPage({Key? key}) : super(key: key);

  @override
  State<AccountSettingsPage> createState() => _AccountSettingsPageState();
}

class _AccountSettingsPageState extends State<AccountSettingsPage> {
  // Theme settings
  ThemeMode _currentThemeMode = ThemeMode.system;

  // Notification settings
  bool _pushNotificationsEnabled = true;
  bool _emailNotificationsEnabled = true;

  // Privacy settings
  bool _profileVisible = true;
  bool _locationVisible = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Account Settings'),
        elevation: 0,
      ),
      body: ListView(
        children: [
          // Theme settings section
          _buildSectionHeader('Appearance'),
          _buildThemeSelector(),

          const Divider(),

          // Account information section
          _buildSectionHeader('Account Information'),
          _buildSettingItem(
            icon: Icons.person_outline,
            title: 'Edit Profile',
            onTap: () {
              // Navigate to edit profile
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Edit profile tapped')),
              );
            },
          ),
          _buildSettingItem(
            icon: Icons.email_outlined,
            title: 'Change Email',
            subtitle: 'current.email@example.com',
            onTap: () {
              // Show change email dialog
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Change email tapped')),
              );
            },
          ),
          _buildSettingItem(
            icon: Icons.lock_outline,
            title: 'Change Password',
            subtitle: 'Last changed 3 months ago',
            onTap: () {
              // Show change password dialog
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Change password tapped')),
              );
            },
          ),

          const Divider(),

          // Notification settings
          _buildSectionHeader('Notifications'),
          SwitchListTile(
            secondary: const Icon(Icons.notifications_outlined),
            title: const Text('Push Notifications'),
            subtitle: const Text('Receive notifications on your device'),
            value: _pushNotificationsEnabled,
            onChanged: (value) {
              setState(() {
                _pushNotificationsEnabled = value;
              });
            },
          ),
          SwitchListTile(
            secondary: const Icon(Icons.email_outlined),
            title: const Text('Email Notifications'),
            subtitle: const Text('Receive email updates and newsletters'),
            value: _emailNotificationsEnabled,
            onChanged: (value) {
              setState(() {
                _emailNotificationsEnabled = value;
              });
            },
          ),

          const Divider(),

          // Privacy settings
          _buildSectionHeader('Privacy'),
          SwitchListTile(
            secondary: const Icon(Icons.visibility_outlined),
            title: const Text('Profile Visibility'),
            subtitle: const Text('Allow others to see your profile'),
            value: _profileVisible,
            onChanged: (value) {
              setState(() {
                _profileVisible = value;
              });
            },
          ),
          SwitchListTile(
            secondary: const Icon(Icons.location_on_outlined),
            title: const Text('Location Sharing'),
            subtitle: const Text('Share your location in posts'),
            value: _locationVisible,
            onChanged: (value) {
              setState(() {
                _locationVisible = value;
              });
            },
          ),

          const Divider(),

          // Data and storage
          _buildSectionHeader('Data & Storage'),
          _buildSettingItem(
            icon: Icons.delete_outline,
            title: 'Clear Cache',
            subtitle: '45.2 MB used',
            onTap: () {
              // Show clear cache confirmation
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Clear cache tapped')),
              );
            },
          ),
          _buildSettingItem(
            icon: Icons.download_outlined,
            title: 'Download My Data',
            subtitle: 'Request a copy of your data',
            onTap: () {
              // Handle data download
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Download data tapped')),
              );
            },
          ),

          const Divider(),

          // Danger zone
          _buildSectionHeader('Danger Zone', color: ThemeConstants.red),
          _buildSettingItem(
            icon: Icons.pause_circle_outline,
            title: 'Deactivate Account',
            iconColor: ThemeConstants.orange,
            onTap: () {
              // Show deactivate confirmation
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Deactivate account tapped')),
              );
            },
          ),
          _buildSettingItem(
            icon: Icons.delete_forever_outlined,
            title: 'Delete Account',
            iconColor: ThemeConstants.red,
            onTap: () {
              // Show delete confirmation
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Delete account tapped')),
              );
            },
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: color ?? ThemeConstants.primaryColor,
        ),
      ),
    );
  }

  Widget _buildSettingItem({
    required IconData icon,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
    Color? iconColor,
  }) {
    return ListTile(
      leading: Icon(icon, color: iconColor),
      title: Text(title),
      subtitle: subtitle != null ? Text(subtitle) : null,
      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      onTap: onTap,
    );
  }

  Widget _buildThemeSelector() {
    return Column(
      children: [
        RadioListTile<ThemeMode>(
          title: const Text('Light Mode'),
          secondary: const Icon(Icons.wb_sunny_outlined),
          value: ThemeMode.light,
          groupValue: _currentThemeMode,
          onChanged: (ThemeMode? value) {
            if (value != null) {
              setState(() {
                _currentThemeMode = value;
              });
              _updateTheme(value);
            }
          },
        ),
        RadioListTile<ThemeMode>(
          title: const Text('Dark Mode'),
          secondary: const Icon(Icons.nightlight_round),
          value: ThemeMode.dark,
          groupValue: _currentThemeMode,
          onChanged: (ThemeMode? value) {
            if (value != null) {
              setState(() {
                _currentThemeMode = value;
              });
              _updateTheme(value);
            }
          },
        ),
        RadioListTile<ThemeMode>(
          title: const Text('System Default'),
          secondary: const Icon(Icons.phone_android),
          value: ThemeMode.system,
          groupValue: _currentThemeMode,
          onChanged: (ThemeMode? value) {
            if (value != null) {
              setState(() {
                _currentThemeMode = value;
              });
              _updateTheme(value);
            }
          },
        ),
      ],
    );
  }

  void _updateTheme(ThemeMode mode) {
    // In a real app, you would use a state management solution to update the app theme
    // For this example, we'll just show a snackbar
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Theme changed to ${mode.toString().split('.').last}'),
        duration: const Duration(seconds: 2),
      ),
    );

    // Note: To properly implement theme changing, you'd need to use a state management solution
    // like Provider, Riverpod, or Bloc to control the app's theme at a higher level
  }
}
