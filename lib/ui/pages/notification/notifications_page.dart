import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application_2/constants/text_strings.dart';
import 'package:flutter_application_2/constants/theme_constants.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_application_2/ui/theme/notification_theme.dart';
import 'package:flutter_application_2/ui/pages/notification/notification_model.dart';
import 'package:intl/intl.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({Key? key}) : super(key: key);

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  bool _showBanner = true;
  bool _notificationsEnabled = false;

  // Sample notifications - replace with your actual data source
  final List<NotificationModel> notifications = [
    NotificationModel(
      message: "New message from John Doe",
      dateTime: DateTime.now(),
      icon: Icons.home,
    ),
    NotificationModel(
      message: "Your post received 10 likes",
      dateTime: DateTime.now().subtract(const Duration(days: 1)),
      icon: Icons.remove_red_eye,
    ),
    NotificationModel(
      message: "Welcome to the app!",
      dateTime: DateTime.now().subtract(const Duration(days: 3)),
      icon: Icons.notifications,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _checkNotificationStatus();
  }

  Future<void> _checkNotificationStatus() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _notificationsEnabled = prefs.getBool('notifications_enabled') ?? false;
      _showBanner = !_notificationsEnabled;
    });
  }

  Future<void> _enableNotifications() async {
    // Here you would implement actual notification permission request
    // using something like firebase_messaging or another notification service

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notifications_enabled', true);

    setState(() {
      _showBanner = false;
      _notificationsEnabled = true;
    });
  }

  Future<void> _resetNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notifications_enabled', false);
    setState(() {
      _showBanner = true;
      _notificationsEnabled = false;
    });
  }

  void _hideBanner() {
    setState(() {
      _showBanner = false;
    });
  }

  String _getDateHeader(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final notificationDate = DateTime(date.year, date.month, date.day);

    if (notificationDate == today) {
      return TextStrings.today;
    } else if (notificationDate == yesterday) {
      return TextStrings.yesterday;
    } else {
      return DateFormat('MMM d, yyyy').format(date);
    }
  }

  Widget _buildNotificationsList() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Group notifications by date
    final groupedNotifications = <String, List<NotificationModel>>{};

    for (var notification in notifications) {
      final dateHeader = _getDateHeader(notification.dateTime);
      groupedNotifications.putIfAbsent(dateHeader, () => []);
      groupedNotifications[dateHeader]!.add(notification);
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: groupedNotifications.length,
      itemBuilder: (context, index) {
        final dateHeader = groupedNotifications.keys.elementAt(index);
        final notificationsForDate = groupedNotifications[dateHeader]!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                dateHeader,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: isDark ? Colors.white70 : Colors.black54,
                    ),
                textAlign: TextAlign.left, // Changed from center to left
              ),
            ),
            ...notificationsForDate
                .map((notification) => Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 4),
                      color: isDark
                          ? ThemeConstants.darkCardColor
                          : ThemeConstants.greyLight,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 0,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Icon(
                              notification.icon,
                              color: isDark ? Colors.white70 : Colors.black54,
                              size: 24,
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Text(
                                notification.message,
                                style: isDark
                                    ? TNotificationTheme
                                        .notificationTextStyleDark
                                    : TNotificationTheme
                                        .notificationTextStyleLight,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ))
                .toList(),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLargeScreen = MediaQuery.of(context).size.width > 900;

    return Scaffold(
      appBar: isLargeScreen
          ? null
          : AppBar(
              title: const Text('Notifications'),
              automaticallyImplyLeading: false,
            ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 16),
            // Always show this button
            Center(
              child: ElevatedButton(
                onPressed: _notificationsEnabled
                    ? _resetNotifications
                    : _enableNotifications,
                style: ElevatedButton.styleFrom(
                  backgroundColor: ThemeConstants.primaryColor,
                  foregroundColor: Colors.white,
                ),
                child: Text(_notificationsEnabled
                    ? TextStrings.disableNotifications
                    : TextStrings.enableNotifications),
              ),
            ),
            const SizedBox(height: 0),
            if (_showBanner)
              Container(
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: ThemeConstants.notificationGradient,
                  borderRadius: BorderRadius.circular(20), // Updated to 20
                ),
                child: Card(
                  margin: EdgeInsets.zero,
                  color: Colors.transparent,
                  elevation: 0,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          TextStrings.turnOnNotifications,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          TextStrings.notificationDescription,
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.white70,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: 100, // Reduced from 120 to 100
                              child: ElevatedButton(
                                onPressed: _enableNotifications,
                                style:
                                    TNotificationTheme.notificationButtonStyle,
                                child: Text(TextStrings.turnOn),
                              ),
                            ),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 100, // Reduced from 120 to 100
                              child: TextButton(
                                onPressed: _hideBanner,
                                style: TNotificationTheme
                                    .notificationSecondaryButtonStyle,
                                child: Text(TextStrings.notNow),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 16),
            _buildNotificationsList(),
          ],
        ),
      ),
    );
  }
}
