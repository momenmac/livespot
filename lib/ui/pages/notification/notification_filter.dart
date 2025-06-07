import 'notification_model.dart';

enum NotificationFilter {
  all('All'),
  today('Today'),
  yesterday('Yesterday'),
  thisWeek('This Week'),
  last7Days('Last 7 Days'),
  thisMonth('This Month');

  final String label;
  const NotificationFilter(this.label);

  List<NotificationModel> filterNotifications(
      List<NotificationModel> notifications) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));

    // Calculate the start of the week (Monday)
    // weekday returns 1 for Monday, 7 for Sunday
    final weekStart = today.subtract(Duration(days: now.weekday - 1));

    final monthStart = DateTime(now.year, now.month, 1);

    switch (this) {
      case NotificationFilter.today:
        return notifications.where((n) {
          final notificationDate = n.dateTime ?? n.timestamp;
          final notificationDay = DateTime(
            notificationDate.year,
            notificationDate.month,
            notificationDate.day,
          );
          // Check if notification is from today
          return notificationDay.isAtSameMomentAs(today);
        }).toList();

      case NotificationFilter.yesterday:
        final yesterday = today.subtract(const Duration(days: 1));
        return notifications.where((n) {
          final notificationDate = n.dateTime ?? n.timestamp;
          final notificationDay = DateTime(
            notificationDate.year,
            notificationDate.month,
            notificationDate.day,
          );
          // Check if notification is from yesterday
          return notificationDay.isAtSameMomentAs(yesterday);
        }).toList();

      case NotificationFilter.thisWeek:
        return notifications.where((n) {
          final notificationDate = n.dateTime ?? n.timestamp;
          // Check if notification is from this week (Monday to Sunday)
          return notificationDate.isAfter(
                  weekStart.subtract(const Duration(milliseconds: 1))) &&
              notificationDate.isBefore(tomorrow);
        }).toList();

      case NotificationFilter.last7Days:
        final sevenDaysAgo = today.subtract(const Duration(days: 7));
        return notifications.where((n) {
          final notificationDate = n.dateTime ?? n.timestamp;
          // Check if notification is from the last 7 days
          return notificationDate.isAfter(
                  sevenDaysAgo.subtract(const Duration(milliseconds: 1))) &&
              notificationDate.isBefore(tomorrow);
        }).toList();

      case NotificationFilter.thisMonth:
        return notifications.where((n) {
          final notificationDate = n.dateTime ?? n.timestamp;
          // Check if notification is from this month
          return notificationDate.isAfter(
                  monthStart.subtract(const Duration(milliseconds: 1))) &&
              notificationDate.isBefore(tomorrow);
        }).toList();

      case NotificationFilter.all:
        return notifications;
    }
  }
}
