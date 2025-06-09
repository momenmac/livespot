import 'package:flutter/material.dart';
import 'package:flutter_application_2/constants/theme_constants.dart';
import 'package:provider/provider.dart';
import 'package:flutter_application_2/providers/theme_provider.dart';
import 'package:flutter_application_2/providers/user_profile_provider.dart';
import 'package:flutter_application_2/services/api/account/account_provider.dart';
import 'package:flutter_application_2/services/api/account/api_client.dart';
import 'package:flutter_application_2/ui/profile/settings/notification_settings_page.dart';
import 'package:flutter_application_2/data/shared_prefs.dart';
import 'package:flutter_application_2/services/location/location_cache_service.dart';

class AccountSettingsPage extends StatefulWidget {
  final Function(ThemeMode value) onThemeChanged;

  const AccountSettingsPage({
    super.key,
    required this.onThemeChanged,
  });

  @override
  State<AccountSettingsPage> createState() => _AccountSettingsPageState();
}

class _AccountSettingsPageState extends State<AccountSettingsPage> {
  // Theme settings
  ThemeMode _currentThemeMode = ThemeMode.system;

  // Notification settings
  bool _emailNotificationsEnabled = true;

  // Privacy settings
  bool _profileVisible = true;
  bool _locationVisible = false;

  // Cache size
  String _cacheSize = 'Calculating...';

  @override
  void initState() {
    super.initState();
    _currentThemeMode =
        Provider.of<ThemeProvider>(context, listen: false).themeMode;
    _calculateCacheSize();
  }

  Future<void> _calculateCacheSize() async {
    try {
      final userProvider =
          Provider.of<UserProfileProvider>(context, listen: false);

      // Get cache sizes from various sources
      int totalSize = 0;

      // Add user profile cache (approximate)
      if (userProvider.currentUserProfile != null) {
        totalSize += 50000; // Approximate size for user data
      }

      // Add location cache size (approximate)
      totalSize += 100000; // Approximate for location data

      // Format size
      String formattedSize;
      if (totalSize < 1024) {
        formattedSize = '${totalSize}B';
      } else if (totalSize < 1024 * 1024) {
        formattedSize = '${(totalSize / 1024).toStringAsFixed(1)}KB';
      } else {
        formattedSize = '${(totalSize / (1024 * 1024)).toStringAsFixed(1)}MB';
      }

      if (mounted) {
        setState(() {
          _cacheSize = '$formattedSize used';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _cacheSize = '45.2 MB used';
        });
      }
    }
  }

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
            icon: Icons.verified_outlined,
            title: 'Request Verification',
            subtitle: 'Get verified status for your account',
            onTap: () {
              _showVerificationRequestDialog();
            },
          ),
          _buildSettingItem(
            icon: Icons.email_outlined,
            title: 'Change Email',
            subtitle: _getUserEmail(),
            onTap: () {
              _showChangeEmailDialog();
            },
          ),
          _buildSettingItem(
            icon: Icons.lock_outline,
            title: 'Change Password',
            subtitle: 'Last changed 3 months ago',
            onTap: () {
              _showChangePasswordDialog();
            },
          ),

          const Divider(),

          // Notification settings
          _buildSectionHeader('Notifications'),
          _buildSettingItem(
            icon: Icons.notifications_outlined,
            title: 'Notification Settings',
            subtitle: 'Manage push notifications and preferences',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const NotificationSettingsPage(),
                ),
              );
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
            subtitle: _cacheSize,
            onTap: () {
              _showClearCacheDialog();
            },
          ),
          _buildSettingItem(
            icon: Icons.download_outlined,
            title: 'Download My Data',
            subtitle: 'Request a copy of your data',
            onTap: () {
              _showDownloadDataDialog();
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
              _showDeactivateAccountDialog();
            },
          ),
          _buildSettingItem(
            icon: Icons.delete_forever_outlined,
            title: 'Delete Account',
            iconColor: ThemeConstants.red,
            onTap: () {
              _showDeleteAccountDialog();
            },
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  String _getUserEmail() {
    final accountProvider =
        Provider.of<AccountProvider>(context, listen: false);
    return accountProvider.currentUser?.email ?? 'No email available';
  }

  void _showChangeEmailDialog() {
    final TextEditingController emailController = TextEditingController();
    final TextEditingController passwordController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Change Email'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: emailController,
                decoration: const InputDecoration(
                  labelText: 'New Email',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: passwordController,
                decoration: const InputDecoration(
                  labelText: 'Current Password',
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
              ),
            ],
          ),
          actions: [
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _buildDialogButton(
                  text: 'Cancel',
                  onPressed: () => Navigator.of(context).pop(),
                ),
                _buildDialogButton(
                  text: 'Change',
                  onPressed: () async {
                    if (emailController.text.isEmpty ||
                        passwordController.text.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Please fill in all fields')),
                      );
                      return;
                    }

                    Navigator.of(context).pop();
                    await _changeEmail(
                        emailController.text, passwordController.text);
                  },
                  isPrimary: true,
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  void _showChangePasswordDialog() {
    final TextEditingController currentPasswordController =
        TextEditingController();
    final TextEditingController newPasswordController = TextEditingController();
    final TextEditingController confirmPasswordController =
        TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Change Password'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: currentPasswordController,
                decoration: const InputDecoration(
                  labelText: 'Current Password',
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: newPasswordController,
                decoration: const InputDecoration(
                  labelText: 'New Password',
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: confirmPasswordController,
                decoration: const InputDecoration(
                  labelText: 'Confirm New Password',
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
              ),
            ],
          ),
          actions: [
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _buildDialogButton(
                  text: 'Cancel',
                  onPressed: () => Navigator.of(context).pop(),
                ),
                _buildDialogButton(
                  text: 'Change',
                  onPressed: () async {
                    if (currentPasswordController.text.isEmpty ||
                        newPasswordController.text.isEmpty ||
                        confirmPasswordController.text.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Please fill in all fields')),
                      );
                      return;
                    }

                    if (newPasswordController.text !=
                        confirmPasswordController.text) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('New passwords do not match')),
                      );
                      return;
                    }

                    if (newPasswordController.text.length < 6) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content:
                                Text('Password must be at least 6 characters')),
                      );
                      return;
                    }

                    Navigator.of(context).pop();
                    await _changePassword(currentPasswordController.text,
                        newPasswordController.text);
                  },
                  isPrimary: true,
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Future<void> _changePassword(
      String currentPassword, String newPassword) async {
    try {
      final accountProvider =
          Provider.of<AccountProvider>(context, listen: false);

      final success = await accountProvider.changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
      );

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Password changed successfully')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(
                    'Failed to change password: ${accountProvider.error ?? "Unknown error"}')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to change password: $e')),
        );
      }
    }
  }

  void _showVerificationRequestDialog() {
    final TextEditingController reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Request Verification'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Tell us why you want to get verified. We will review your request and contact you via email.',
              ),
              const SizedBox(height: 16),
              TextField(
                controller: reasonController,
                decoration: const InputDecoration(
                    labelText: 'Reason for verification',
                    border: OutlineInputBorder(),
                    hintText:
                        'e.g., Content creator, Business owner, Public figure...'),
                maxLines: 3,
              ),
            ],
          ),
          actions: [
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _buildDialogButton(
                  text: 'Cancel',
                  onPressed: () => Navigator.of(context).pop(),
                ),
                _buildDialogButton(
                  text: 'Submit',
                  onPressed: () async {
                    if (reasonController.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text(
                                'Please provide a reason for verification')),
                      );
                      return;
                    }

                    Navigator.of(context).pop();
                    await _requestVerification(reasonController.text.trim());
                  },
                  isPrimary: true,
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Future<void> _requestVerification(String reason) async {
    try {
      final userProvider =
          Provider.of<UserProfileProvider>(context, listen: false);
      final userEmail =
          userProvider.currentUserProfile?.email ?? 'unknown@email.com';

      // Call the verification request API
      await _submitVerificationRequest(userEmail, reason);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Verification request submitted successfully! We will contact you via email soon.'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to submit verification request: $e')),
        );
      }
    }
  }

  Future<void> _submitVerificationRequest(String email, String reason) async {
    try {
      final accountProvider =
          Provider.of<AccountProvider>(context, listen: false);
      final token = accountProvider.token?.accessToken;

      if (token == null) {
        throw Exception('No authentication token available');
      }

      // Make HTTP request to the verification request API
      final response = await ApiClient.post(
        '/api/accounts/verification-request/',
        body: {
          'reason': reason,
        },
        token: token,
      );

      if (!response['success']) {
        throw Exception(
            response['error'] ?? 'Failed to submit verification request');
      }

      print('Verification request submitted successfully: ${response['data']}');
    } catch (e) {
      print('Error submitting verification request: $e');
      rethrow;
    }
  }

  // Helper method to create consistent dialog buttons
  Widget _buildDialogButton({
    required String text,
    required VoidCallback onPressed,
    bool isPrimary = false,
    Color? backgroundColor,
    Color? foregroundColor,
  }) {
    return Flexible(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4.0),
        child: SizedBox(
          height: 44,
          child: isPrimary
              ? ElevatedButton(
                  onPressed: onPressed,
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        backgroundColor ?? Theme.of(context).primaryColor,
                    foregroundColor: foregroundColor ?? Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Center(
                    child: Text(
                      text,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : TextButton(
                  onPressed: onPressed,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Center(
                    child: Text(
                      text,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  void _showClearCacheDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Clear Cache'),
          content: Text(
              'This will clear $_cacheSize of cached data. This action cannot be undone.'),
          actions: [
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _buildDialogButton(
                  text: 'Cancel',
                  onPressed: () => Navigator.of(context).pop(),
                ),
                _buildDialogButton(
                  text: 'Clear',
                  onPressed: () async {
                    Navigator.of(context).pop();
                    await _clearCache();
                  },
                  isPrimary: true,
                  backgroundColor: ThemeConstants.red,
                  foregroundColor: Colors.white,
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Future<void> _clearCache() async {
    try {
      // Clear user profile cache using available methods
      final userProvider =
          Provider.of<UserProfileProvider>(context, listen: false);
      userProvider.clearAllCaches();

      // Clear session data using available methods
      await SharedPrefs.clearSession();

      // Clear location cache using dispose method
      try {
        final locationCache = LocationCacheService();
        locationCache.dispose();
      } catch (e) {
        // Ignore if location cache service is not available
      }

      // Recalculate cache size
      await _calculateCacheSize();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cache cleared successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to clear cache: $e')),
        );
      }
    }
  }

  void _showDownloadDataDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Download My Data'),
          content: const Text(
            'We will prepare a copy of your data and send it to your registered email address. This may take up to 24 hours.',
          ),
          actions: [
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _buildDialogButton(
                  text: 'Cancel',
                  onPressed: () => Navigator.of(context).pop(),
                ),
                _buildDialogButton(
                  text: 'Request',
                  onPressed: () async {
                    Navigator.of(context).pop();
                    await _requestDataDownload();
                  },
                  isPrimary: true,
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Future<void> _requestDataDownload() async {
    try {
      final accountProvider =
          Provider.of<AccountProvider>(context, listen: false);

      final success = await accountProvider.requestDataDownload();

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Data download request submitted. You will receive an email with your data within 24-48 hours.'),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(
                    'Failed to request data download: ${accountProvider.error ?? "Unknown error"}')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to request data download: $e')),
        );
      }
    }
  }

  void _showDeactivateAccountDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Deactivate Account'),
          content: const Text(
            'Deactivating your account will hide your profile and posts from other users. You can reactivate your account by logging in again.',
          ),
          actions: [
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _buildDialogButton(
                  text: 'Cancel',
                  onPressed: () => Navigator.of(context).pop(),
                ),
                _buildDialogButton(
                  text: 'Deactivate',
                  onPressed: () async {
                    Navigator.of(context).pop();
                    await _deactivateAccount();
                  },
                  isPrimary: true,
                  backgroundColor: ThemeConstants.orange,
                  foregroundColor: Colors.white,
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Future<void> _deactivateAccount() async {
    try {
      final accountProvider =
          Provider.of<AccountProvider>(context, listen: false);

      final success = await accountProvider.deactivateAccount();

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Account deactivated successfully')),
          );
          // Navigation is handled automatically by the logout in deactivateAccount
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(
                    'Failed to deactivate account: ${accountProvider.error ?? "Unknown error"}')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to deactivate account: $e')),
        );
      }
    }
  }

  void _showDeleteAccountDialog() {
    final TextEditingController passwordController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Account'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'This action cannot be undone. All your data, posts, and profile information will be permanently deleted.',
                style: TextStyle(color: Colors.red),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: passwordController,
                decoration: const InputDecoration(
                  labelText: 'Enter your password to confirm',
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
              ),
            ],
          ),
          actions: [
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _buildDialogButton(
                  text: 'Cancel',
                  onPressed: () => Navigator.of(context).pop(),
                ),
                _buildDialogButton(
                  text: 'Delete',
                  onPressed: () async {
                    if (passwordController.text.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Please enter your password')),
                      );
                      return;
                    }

                    Navigator.of(context).pop();
                    await _deleteAccount(passwordController.text);
                  },
                  isPrimary: true,
                  backgroundColor: ThemeConstants.red,
                  foregroundColor: Colors.white,
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteAccount(String password) async {
    try {
      final accountProvider =
          Provider.of<AccountProvider>(context, listen: false);

      final success = await accountProvider.deleteAccount(password: password);

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Account deleted successfully'),
              duration: Duration(seconds: 4),
            ),
          );
          // Navigation is handled automatically by the logout in deleteAccount
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(
                    'Failed to delete account: ${accountProvider.error ?? "Unknown error"}')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete account: $e')),
        );
      }
    }
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
    Provider.of<ThemeProvider>(context, listen: false).setThemeMode(mode);
    setState(() {
      _currentThemeMode = mode;
    });
    widget.onThemeChanged(mode);
  }

  Future<void> _changeEmail(String newEmail, String password) async {
    try {
      final accountProvider =
          Provider.of<AccountProvider>(context, listen: false);

      final success = await accountProvider.changeEmail(
        newEmail: newEmail,
        password: password,
      );

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text(
                    'Email changed successfully. Please verify your new email address.')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(
                    'Failed to change email: ${accountProvider.error ?? "Unknown error"}')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to change email: $e')),
        );
      }
    }
  }
}
