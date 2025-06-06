import 'package:flutter/material.dart';
import 'package:flutter_application_2/constants/theme_constants.dart';
import 'package:flutter_application_2/services/firebase_messaging_service.dart';
import 'package:flutter_application_2/services/api/notification_api_service.dart';
import 'package:flutter_application_2/services/database/notification_database_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:permission_handler/permission_handler.dart';

class NotificationSettingsPage extends StatefulWidget {
  const NotificationSettingsPage({super.key});

  @override
  State<NotificationSettingsPage> createState() =>
      _NotificationSettingsPageState();
}

class _NotificationSettingsPageState extends State<NotificationSettingsPage> {
  // Permission status
  bool _notificationsEnabled = false;
  bool _permissionGranted = false;

  // Notification categories
  bool _friendRequests = true;
  bool _events = true;
  bool _reminders = true;
  bool _nearbyEvents = true;
  bool _systemNotifications = true;

  // Advanced settings
  bool _soundEnabled = true;
  bool _vibrationEnabled = true;
  bool _showOnLockScreen = true;
  bool _popOnScreen = true;

  // Loading states
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadNotificationSettings();
  }

  Future<void> _loadNotificationSettings() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // For Android 12 and below, check Firebase messaging permissions
      // For Android 13+, also check system notification permission
      final authStatus =
          await FirebaseMessagingService.getNotificationPermissionStatus();

      // On Android 12 and below, notifications are granted by default
      // We only need to check Firebase messaging authorization
      _permissionGranted = authStatus == AuthorizationStatus.authorized ||
          authStatus == AuthorizationStatus.provisional;
      _notificationsEnabled = _permissionGranted;

      // Load user notification preferences
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // Try to load from API first
        final apiSettings =
            await NotificationApiService.getNotificationSettings();
        if (apiSettings != null) {
          setState(() {
            _friendRequests = apiSettings['friend_requests'] ?? true;
            _events = apiSettings['events'] ?? true;
            _reminders = apiSettings['reminders'] ?? true;
            _nearbyEvents = apiSettings['nearby_events'] ?? true;
            _systemNotifications = apiSettings['system_notifications'] ?? true;
          });
        } else {
          // Fallback to local database
          final localSettings =
              await NotificationDatabaseService.getNotificationSettings(
                  user.uid);
          setState(() {
            _friendRequests = localSettings['friendRequests'] ?? true;
            _events = localSettings['events'] ?? true;
            _reminders = localSettings['reminders'] ?? true;
            _nearbyEvents = localSettings['nearbyEvents'] ?? true;
            _systemNotifications = localSettings['systemNotifications'] ?? true;
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading notification settings: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _requestNotificationPermission() async {
    try {
      setState(() {
        _isSaving = true;
      });

      // Request Firebase messaging permission (works on all Android versions)
      final granted =
          await FirebaseMessagingService.requestNotificationPermissions();

      setState(() {
        _permissionGranted = granted;
        _notificationsEnabled = granted;
      });

      if (granted) {
        _showSuccessSnackBar('Notifications enabled successfully!');
        await _saveNotificationSettings();
      } else {
        // Check if permanently denied or just denied
        final authStatus =
            await FirebaseMessagingService.getNotificationPermissionStatus();
        if (authStatus == AuthorizationStatus.denied) {
          _showPermissionDialog();
        } else {
          _showErrorSnackBar('Notification permission denied');
        }
      }
    } catch (e) {
      _showErrorSnackBar('Error requesting permissions: $e');
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  Future<void> _saveNotificationSettings() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() {
      _isSaving = true;
    });

    try {
      // Save to API
      final apiSuccess =
          await NotificationApiService.updateNotificationSettings(
        friendRequests: _friendRequests,
        events: _events,
        reminders: _reminders,
        nearbyEvents: _nearbyEvents,
        systemNotifications: _systemNotifications,
      );

      // Save to local database as backup
      await NotificationDatabaseService.updateNotificationSettings(
        userId: user.uid,
        settings: {
          'friendRequests': _friendRequests,
          'events': _events,
          'reminders': _reminders,
          'nearbyEvents': _nearbyEvents,
          'systemNotifications': _systemNotifications,
        },
      );

      if (apiSuccess) {
        _showSuccessSnackBar('Notification preferences saved');
      } else {
        _showErrorSnackBar('Failed to save to server, but saved locally');
      }
    } catch (e) {
      _showErrorSnackBar('Error saving settings: $e');
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Notification Permission Required'),
        content: const Text(
          'Notifications are permanently disabled. Please enable them in your device settings to receive notifications.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Notification Settings'),
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notification Settings'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Main notification toggle
            _buildSectionHeader('General'),
            _buildSettingsCard([
              SwitchListTile(
                title: const Text('Enable Notifications'),
                subtitle: Text(_permissionGranted
                    ? 'Receive push notifications'
                    : 'Permission required'),
                value: _notificationsEnabled,
                activeColor: ThemeConstants.primaryColor,
                onChanged: _permissionGranted
                    ? null
                    : (value) {
                        if (value) {
                          _requestNotificationPermission();
                        }
                      },
                secondary: Icon(
                  _notificationsEnabled
                      ? Icons.notifications_active
                      : Icons.notifications_off,
                  color: _notificationsEnabled
                      ? ThemeConstants.primaryColor
                      : Colors.grey,
                ),
              ),
              if (!_permissionGranted)
                ListTile(
                  leading: const Icon(Icons.warning, color: Colors.orange),
                  title: const Text('Permission Required'),
                  subtitle:
                      const Text('Tap to enable notification permissions'),
                  onTap: _requestNotificationPermission,
                  trailing: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.arrow_forward_ios, size: 16),
                ),
            ]),

            if (_notificationsEnabled) ...[
              const SizedBox(height: 24),

              // Notification categories
              _buildSectionHeader('Notification Types'),
              _buildSettingsCard([
                SwitchListTile(
                  title: const Text('Friend Requests'),
                  subtitle:
                      const Text('When someone sends you a friend request'),
                  value: _friendRequests,
                  activeColor: ThemeConstants.primaryColor,
                  onChanged: (value) {
                    setState(() {
                      _friendRequests = value;
                    });
                    _saveNotificationSettings();
                  },
                  secondary: const Icon(Icons.person_add),
                ),
                const Divider(),
                SwitchListTile(
                  title: const Text('Events'),
                  subtitle: const Text('Event invitations and updates'),
                  value: _events,
                  activeColor: ThemeConstants.primaryColor,
                  onChanged: (value) {
                    setState(() {
                      _events = value;
                    });
                    _saveNotificationSettings();
                  },
                  secondary: const Icon(Icons.event),
                ),
                const Divider(),
                SwitchListTile(
                  title: const Text('Reminders'),
                  subtitle: const Text('Event reminders and confirmations'),
                  value: _reminders,
                  activeColor: ThemeConstants.primaryColor,
                  onChanged: (value) {
                    setState(() {
                      _reminders = value;
                    });
                    _saveNotificationSettings();
                  },
                  secondary: const Icon(Icons.alarm),
                ),
                const Divider(),
                SwitchListTile(
                  title: const Text('Nearby Events'),
                  subtitle: const Text('Events happening near your location'),
                  value: _nearbyEvents,
                  activeColor: ThemeConstants.primaryColor,
                  onChanged: (value) {
                    setState(() {
                      _nearbyEvents = value;
                    });
                    _saveNotificationSettings();
                  },
                  secondary: const Icon(Icons.location_on),
                ),
                const Divider(),
                SwitchListTile(
                  title: const Text('System Notifications'),
                  subtitle:
                      const Text('App updates and important announcements'),
                  value: _systemNotifications,
                  activeColor: ThemeConstants.primaryColor,
                  onChanged: (value) {
                    setState(() {
                      _systemNotifications = value;
                    });
                    _saveNotificationSettings();
                  },
                  secondary: const Icon(Icons.system_update),
                ),
              ]),

              const SizedBox(height: 24),

              // Advanced settings
              _buildSectionHeader('Advanced'),
              _buildSettingsCard([
                SwitchListTile(
                  title: const Text('Sound'),
                  subtitle: const Text('Play notification sounds'),
                  value: _soundEnabled,
                  activeColor: ThemeConstants.primaryColor,
                  onChanged: (value) {
                    setState(() {
                      _soundEnabled = value;
                    });
                  },
                  secondary: const Icon(Icons.volume_up),
                ),
                const Divider(),
                SwitchListTile(
                  title: const Text('Vibration'),
                  subtitle: const Text('Vibrate for notifications'),
                  value: _vibrationEnabled,
                  activeColor: ThemeConstants.primaryColor,
                  onChanged: (value) {
                    setState(() {
                      _vibrationEnabled = value;
                    });
                  },
                  secondary: const Icon(Icons.vibration),
                ),
                const Divider(),
                SwitchListTile(
                  title: const Text('Show on Lock Screen'),
                  subtitle:
                      const Text('Display notifications when device is locked'),
                  value: _showOnLockScreen,
                  activeColor: ThemeConstants.primaryColor,
                  onChanged: (value) {
                    setState(() {
                      _showOnLockScreen = value;
                    });
                  },
                  secondary: const Icon(Icons.lock_outline),
                ),
                const Divider(),
                SwitchListTile(
                  title: const Text('Pop on Screen'),
                  subtitle:
                      const Text('Show notification banners when app is open'),
                  value: _popOnScreen,
                  activeColor: ThemeConstants.primaryColor,
                  onChanged: (value) {
                    setState(() {
                      _popOnScreen = value;
                    });
                  },
                  secondary: const Icon(Icons.picture_in_picture),
                ),
              ]),

              const SizedBox(height: 24),

              // Testing section
              _buildSectionHeader('Testing'),
              _buildSettingsCard([
                ListTile(
                  leading: const Icon(Icons.bug_report, color: Colors.blue),
                  title: const Text('Notification Test Page'),
                  subtitle: const Text(
                      'Test notification functionality and settings'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    Navigator.pushNamed(context, '/notification-test');
                  },
                ),
              ]),

              const SizedBox(height: 24),

              // System settings link
              _buildSectionHeader('System'),
              _buildSettingsCard([
                ListTile(
                  leading: const Icon(Icons.settings, color: Colors.grey),
                  title: const Text('Open System Notification Settings'),
                  subtitle: const Text(
                      'Configure system-level notification preferences'),
                  trailing: const Icon(Icons.open_in_new, size: 16),
                  onTap: () {
                    openAppSettings();
                  },
                ),
              ]),
            ],

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

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
}
