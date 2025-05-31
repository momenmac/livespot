import 'package:flutter/material.dart';
import 'package:flutter_application_2/services/firebase_messaging_service.dart';
import 'package:flutter/services.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class NotificationTestPage extends StatefulWidget {
  const NotificationTestPage({super.key});

  @override
  State<NotificationTestPage> createState() => _NotificationTestPageState();
}

class _NotificationTestPageState extends State<NotificationTestPage> {
  String? _fcmToken;
  bool _isLoading = false;
  AuthorizationStatus? _permissionStatus;

  @override
  void initState() {
    super.initState();
    _getFCMToken();
    _checkPermissionStatus();
  }

  Future<void> _getFCMToken() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final token = await FirebaseMessagingService.getToken();
      setState(() {
        _fcmToken = token;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error getting FCM token: $e')),
        );
      }
    }
  }

  Future<void> _checkPermissionStatus() async {
    try {
      final status =
          await FirebaseMessagingService.getNotificationPermissionStatus();
      setState(() {
        _permissionStatus = status;
      });
    } catch (e) {
      print('Error checking permission status: $e');
    }
  }

  Future<void> _requestPermissions() async {
    try {
      final granted =
          await FirebaseMessagingService.requestNotificationPermissions();
      await _checkPermissionStatus(); // Refresh status

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(granted
                ? 'Notification permissions granted!'
                : 'Notification permissions denied'),
            backgroundColor: granted ? Colors.green : Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error requesting permissions: $e')),
        );
      }
    }
  }

  Future<void> _copyTokenToClipboard() async {
    if (_fcmToken != null) {
      await Clipboard.setData(ClipboardData(text: _fcmToken!));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('FCM Token copied to clipboard!')),
        );
      }
    }
  }

  Future<void> _subscribeToTopic() async {
    try {
      await FirebaseMessagingService.subscribeToTopic('test_notifications');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Subscribed to test_notifications topic')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error subscribing to topic: $e')),
        );
      }
    }
  }

  Future<void> _unsubscribeFromTopic() async {
    try {
      await FirebaseMessagingService.unsubscribeFromTopic('test_notifications');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Unsubscribed from test_notifications topic')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error unsubscribing from topic: $e')),
        );
      }
    }
  }

  String _getPermissionText() {
    switch (_permissionStatus) {
      case AuthorizationStatus.authorized:
        return 'GRANTED';
      case AuthorizationStatus.denied:
        return 'DENIED';
      case AuthorizationStatus.notDetermined:
        return 'NOT DETERMINED';
      case AuthorizationStatus.provisional:
        return 'PROVISIONAL';
      default:
        return 'UNKNOWN';
    }
  }

  Color _getPermissionColor() {
    switch (_permissionStatus) {
      case AuthorizationStatus.authorized:
        return Colors.green;
      case AuthorizationStatus.denied:
        return Colors.red;
      case AuthorizationStatus.notDetermined:
        return Colors.orange;
      case AuthorizationStatus.provisional:
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Firebase Notifications Test'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Firebase Messaging Configuration',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),

            // Permission Status Section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Notification Permissions',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Text('Status: '),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _getPermissionColor(),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _getPermissionText(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (_permissionStatus != AuthorizationStatus.authorized)
                      ElevatedButton(
                        onPressed: _requestPermissions,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Request Notification Permissions'),
                      ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // FCM Token Section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'FCM Token',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (_isLoading)
                      const Center(child: CircularProgressIndicator())
                    else if (_fcmToken != null) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: Text(
                          _fcmToken!,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      ElevatedButton(
                        onPressed: _copyTokenToClipboard,
                        child: const Text('Copy Token to Clipboard'),
                      ),
                    ] else
                      const Text('Failed to get FCM token'),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Topic Subscription Section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Topic Subscription',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Subscribe to the "test_notifications" topic to receive test push notifications.',
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        ElevatedButton(
                          onPressed: _subscribeToTopic,
                          child: const Text('Subscribe'),
                        ),
                        const SizedBox(width: 10),
                        ElevatedButton(
                          onPressed: _unsubscribeFromTopic,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Unsubscribe'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Instructions Section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Testing Instructions',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      '1. Copy the FCM token above\n'
                      '2. Use the Firebase Console or server script to send a test notification\n'
                      '3. Or subscribe to the "test_notifications" topic and send a topic message\n'
                      '4. Test both foreground and background notification scenarios',
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
