import 'package:flutter/material.dart';
import 'package:flutter_application_2/ui/pages/notification/notifications_controller.dart';

void main() {
  runApp(NotificationTestApp());
}

class NotificationTestApp extends StatelessWidget {
  const NotificationTestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Notification Popup Test',
      navigatorKey: NotificationsController.navigatorKey,
      home: NotificationTestPage(),
    );
  }
}

class NotificationTestPage extends StatelessWidget {
  const NotificationTestPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notification Popup Test'),
        backgroundColor: Colors.blue,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Test Notification Popup',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () => _showTestNotification(context),
              icon: const Icon(Icons.notifications),
              label: const Text('Show Test Notification'),
              style: ElevatedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'The notification should appear at the top of the screen\nand auto-dismiss after 4 seconds.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  void _showTestNotification(BuildContext context) {
    print('🧪 Testing notification popup from test file...');

    NotificationsController.showNotification(
      title: 'Test Notification',
      message:
          'This is a test notification to verify the popup works correctly!',
      icon: Icons.check_circle,
      onTap: () {
        print('✅ Test notification tapped!');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Notification tapped successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      },
    );
  }
}
