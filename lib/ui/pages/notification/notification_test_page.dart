import 'package:flutter/material.dart';
import 'package:flutter_application_2/services/firebase_messaging_service.dart';
import 'package:flutter/services.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_application_2/services/notifications/notification_handler.dart';

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

  Future<void> _sendTestNotification() async {
    try {
      final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

      const AndroidNotificationDetails androidNotificationDetails =
          AndroidNotificationDetails(
        'test_channel_id',
        'Test Notifications',
        channelDescription: 'Channel for test notifications',
        importance: Importance.max,
        priority: Priority.high,
        showWhen: true,
        icon: 'ic_notification',
      );

      const NotificationDetails notificationDetails = NotificationDetails(
        android: androidNotificationDetails,
      );

      await flutterLocalNotificationsPlugin.show(
        0,
        'Test Notification 🔔',
        'This is a test notification from your app! If you can see this, notifications are working properly.',
        notificationDetails,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Test notification sent! 🎉'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sending test notification: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _simulateRemoteNotification() async {
    print('🚀 === SIMULATE REMOTE NOTIFICATION STARTED ===');
    try {
      // Create a simulated Firebase message
      final testMessage = RemoteMessage(
        messageId: DateTime.now().millisecondsSinceEpoch.toString(),
        data: {
          'type': 'friend_request',
          'from_user_id': 'test_user_123',
          'from_user_name': 'Test User',
          'from_user_avatar': '',
          'request_id': 'test_request_${DateTime.now().millisecondsSinceEpoch}',
        },
        notification: const RemoteNotification(
          title: '👋 Friend Request',
          body: 'Test User wants to be your friend!',
        ),
      );

      print('🔄 Created test message with ID: ${testMessage.messageId}');
      print('🔄 Message data: ${testMessage.data}');
      print(
          '🔄 Message notification: ${testMessage.notification?.title} - ${testMessage.notification?.body}');

      // Handle it like a real Firebase message using the NotificationHandler
      print('🔄 Calling NotificationHandler.handleForegroundNotification...');
      await NotificationHandler.handleForegroundNotification(testMessage);
      print('✅ NotificationHandler.handleForegroundNotification completed');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Simulated Firebase notification sent! 🚀'),
            backgroundColor: Colors.blue,
          ),
        );
      }
      print('✅ === SIMULATE REMOTE NOTIFICATION COMPLETED ===');
    } catch (e) {
      print('❌ === SIMULATE REMOTE NOTIFICATION ERROR ===');
      print('❌ Error details: $e');
      print('❌ Error type: ${e.runtimeType}');
      print('❌ Stack trace: ${StackTrace.current}');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error simulating notification: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showFCMTokenDialog() async {
    if (_fcmToken == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('FCM Token not available')),
      );
      return;
    }

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.vpn_key, color: Theme.of(context).primaryColor),
            const SizedBox(width: 8),
            const Text('FCM Token'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Copy this token to test Firebase notifications from the console:',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: SelectableText(
                _fcmToken!,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '📱 How to test:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue[800],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '1. Copy token to clipboard\n2. Go to Firebase Console\n3. Navigate to Cloud Messaging\n4. Click "Send test message"\n5. Paste token and send',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.blue[700],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          FilledButton.icon(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: _fcmToken!));
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('✅ FCM Token copied to clipboard!'),
                    duration: Duration(seconds: 2),
                  ),
                );
              }
              Navigator.pop(context);
            },
            icon: const Icon(Icons.copy),
            label: const Text('Copy'),
          ),
        ],
      ),
    );
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
                      const SizedBox(height: 10),
                      ElevatedButton(
                        onPressed: _showFCMTokenDialog,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Show Token in Dialog'),
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

            // Test Notifications Section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Test Notifications',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Test your notification system with these buttons:',
                    ),
                    const SizedBox(height: 15),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _sendTestNotification,
                        icon: const Icon(Icons.notifications),
                        label: const Text('Send Local Test Notification'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _simulateRemoteNotification,
                        icon: const Icon(Icons.cloud_circle),
                        label: const Text('Simulate Firebase Notification'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue[200]!),
                      ),
                      child: const Text(
                        '💡 Tip: The first button sends a local notification directly from your device. The second button simulates a Firebase notification with friend request data.',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.blue,
                        ),
                      ),
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
                      '1. Use the test buttons above for quick notification testing\n'
                      '2. Copy the FCM token and use Firebase Console for remote testing\n'
                      '3. Subscribe to "test_notifications" topic for topic-based messages\n'
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
