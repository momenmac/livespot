import 'package:flutter/material.dart';
import 'package:flutter_application_2/constants/theme_constants.dart';
import 'package:flutter_application_2/ui/profile/settings/story_controls_page.dart';

class PrivacySettingsPage extends StatefulWidget {
  const PrivacySettingsPage({Key? key}) : super(key: key);

  @override
  State<PrivacySettingsPage> createState() => _PrivacySettingsPageState();
}

class _PrivacySettingsPageState extends State<PrivacySettingsPage> {
  // Activity status settings
  String _selectedStatus = 'Online'; // Default status
  bool _showReadReceipts = true;

  // Security settings
  bool _appLockEnabled = false;
  bool _chatLockEnabled = false;

  // Mock lists
  final List<Map<String, dynamic>> _ignoredAccounts = [
    {'name': 'John Doe', 'username': 'john_doe'},
    {'name': 'Jane Smith', 'username': 'jane_smith'},
  ];

  final List<Map<String, dynamic>> _blockedAccounts = [
    {'name': 'Troll User', 'username': 'troll123'},
    {'name': 'Spam Account', 'username': 'spam_bot'},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Privacy Settings'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Activity Status Section (now first)
            _buildSectionHeader('Activity Status'),
            _buildSettingsCard([
              _buildStatusOption('Online', Colors.green),
              _buildStatusOption('Do Not Disturb', ThemeConstants.red),
              _buildStatusOption('Away', ThemeConstants.orange),
              _buildStatusOption('Offline', ThemeConstants.grey),
              const Divider(),
              SwitchListTile(
                title: const Text('Read Receipts'),
                subtitle: const Text('Show when you\'ve read messages'),
                value: _showReadReceipts,
                activeColor: ThemeConstants.primaryColor,
                onChanged: (value) {
                  setState(() {
                    _showReadReceipts = value;
                  });
                },
              ),
              const Divider(),
              ListTile(
                title: const Text('Story Controls'),
                subtitle: const Text('Manage who can see your stories'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const StoryControlsPage(),
                    ),
                  );
                },
              ),
            ]),

            const SizedBox(height: 24),

            // Communication Settings Section (now second)
            _buildSectionHeader('Communication Settings'),
            _buildSettingsCard([
              _buildNavItem(
                'Message Delivery',
                'Control who can send you messages',
                Icons.message_outlined,
                onTap: () => _openMessageDeliverySettings(),
              ),
              const Divider(),
              _buildNavItem(
                'Ignored Accounts',
                '${_ignoredAccounts.length} accounts',
                Icons.volume_off_outlined,
                onTap: () => _openIgnoredAccountsList(),
              ),
              const Divider(),
              _buildNavItem(
                'Blocked Accounts',
                '${_blockedAccounts.length} accounts',
                Icons.block_outlined,
                onTap: () => _openBlockedAccountsList(),
              ),
            ]),

            const SizedBox(height: 24),

            // Security Section (now last)
            _buildSectionHeader('Security'),
            _buildSettingsCard([
              SwitchListTile(
                title: const Text('App Lock'),
                subtitle: const Text('Require authentication to open the app'),
                value: _appLockEnabled,
                activeColor: ThemeConstants.primaryColor,
                onChanged: (value) {
                  setState(() {
                    _appLockEnabled = value;
                    if (value) {
                      _showSetupSecurityDialog('app');
                    }
                  });
                },
              ),
              const Divider(),
              SwitchListTile(
                title: const Text('Chat Lock'),
                subtitle: const Text('Secure individual conversations'),
                value: _chatLockEnabled,
                activeColor: ThemeConstants.primaryColor,
                onChanged: (value) {
                  setState(() {
                    _chatLockEnabled = value;
                    if (value) {
                      _showSetupSecurityDialog('chat');
                    }
                  });
                },
              ),
            ]),
          ],
        ),
      ),
    );
  }

  // Helper methods to build UI components
  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildSettingsCard(List<Widget> children) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Column(
          children: children,
        ),
      ),
    );
  }

  Widget _buildNavItem(String title, String subtitle, IconData icon,
      {required VoidCallback onTap}) {
    return ListTile(
      leading: Icon(icon, color: ThemeConstants.primaryColor),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      onTap: onTap,
    );
  }

  Widget _buildStatusOption(String status, Color color) {
    return RadioListTile<String>(
      title: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(status),
        ],
      ),
      value: status,
      groupValue: _selectedStatus,
      activeColor: ThemeConstants.primaryColor,
      onChanged: (value) {
        if (value != null) {
          setState(() {
            _selectedStatus = value;
          });
        }
      },
    );
  }

  // Navigation and dialog methods
  void _openMessageDeliverySettings() {
    // TODO: Implement message delivery settings page
    _showComingSoonDialog('Message Delivery Settings');
  }

  void _openIgnoredAccountsList() {
    _navigateToAccountList('Ignored Accounts', _ignoredAccounts);
  }

  void _openBlockedAccountsList() {
    _navigateToAccountList('Blocked Accounts', _blockedAccounts);
  }

  void _navigateToAccountList(
      String title, List<Map<String, dynamic>> accounts) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _AccountsListPage(
          title: title,
          accounts: accounts,
        ),
      ),
    );
  }

  void _showSetupSecurityDialog(String type) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Set Up ${type == 'app' ? 'App' : 'Chat'} Lock'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Choose your security method:'),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.fingerprint),
              title: const Text('Biometric'),
              onTap: () {
                Navigator.pop(context);
                // TODO: Implement biometric setup
                _showComingSoonDialog('Biometric Authentication');
              },
            ),
            ListTile(
              leading: const Icon(Icons.pin),
              title: const Text('PIN Code'),
              onTap: () {
                Navigator.pop(context);
                // TODO: Implement PIN setup
                _showComingSoonDialog('PIN Setup');
              },
            ),
            ListTile(
              leading: const Icon(Icons.grid_on),
              title: const Text('Pattern'),
              onTap: () {
                Navigator.pop(context);
                // TODO: Implement pattern setup
                _showComingSoonDialog('Pattern Setup');
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // If dialog was dismissed, revert toggle
              setState(() {
                if (type == 'app') {
                  _appLockEnabled = false;
                } else {
                  _chatLockEnabled = false;
                }
              });
            },
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _showComingSoonDialog(String feature) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Coming Soon'),
        content: Text('$feature will be available in a future update.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

// Helper class for displaying account lists
class _AccountsListPage extends StatelessWidget {
  final String title;
  final List<Map<String, dynamic>> accounts;

  const _AccountsListPage({
    required this.title,
    required this.accounts,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
      ),
      body: accounts.isEmpty
          ? const Center(
              child: Text('No accounts found'),
            )
          : ListView.builder(
              itemCount: accounts.length,
              itemBuilder: (context, index) {
                final account = accounts[index];
                return ListTile(
                  leading: const CircleAvatar(
                    child: Icon(Icons.person),
                  ),
                  title: Text(account['name']),
                  subtitle: Text('@${account['username']}'),
                  trailing: TextButton(
                    onPressed: () {
                      // TODO: Implement unblock/unignore functionality
                      Navigator.pop(context);
                    },
                    child: Text(
                      title.contains('Ignored') ? 'Unignore' : 'Unblock',
                      style: TextStyle(color: ThemeConstants.primaryColor),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
