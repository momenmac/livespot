import 'notification_model.dart';

enum NotificationFilter {
  all('All'),
  today('Today'),
  thisWeek('This Week'),
  thisMonth('This Month');

  final String label;
  const NotificationFilter(this.label);

  List<NotificationModel> filterNotifications(
      List<NotificationModel> notifications) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Calculate the start of the week (Sunday) by subtracting days until we reach Sunday
    final weekStart = today.subtract(Duration(days: now.weekday % 7));

    final monthStart = DateTime(now.year, now.month, 1);

    switch (this) {
      case NotificationFilter.today:
        return notifications.where((n) {
          final notificationDate = n.dateTime ?? n.timestamp;
          return notificationDate
              .isAfter(today.subtract(const Duration(days: 1)));
        }).toList();
      case NotificationFilter.thisWeek:
        // Filter notifications from the start of this week
        return notifications.where((n) {
          final notificationDate = n.dateTime ?? n.timestamp;
          return notificationDate
              .isAfter(weekStart.subtract(const Duration(days: 1)));
        }).toList();
      case NotificationFilter.thisMonth:
        return notifications.where((n) {
          final notificationDate = n.dateTime ?? n.timestamp;
          return notificationDate.isAfter(monthStart);
        }).toList();
      case NotificationFilter.all:
        return notifications;
    }
  }
}
