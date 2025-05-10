import 'package:intl/intl.dart';
import 'package:timeago/timeago.dart' as timeago;

class TimeFormatter {
  static String getFormattedTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    // If less than 24 hours, show relative time
    if (difference.inHours < 24) {
      return timeago.format(time);
    }
    // If in the current year, show month and day
    else if (now.year == time.year) {
      return DateFormat('MMM d').format(time);
    }
    // Otherwise show month, day and year
    else {
      return DateFormat('MMM d, y').format(time);
    }
  }

  static String getTimeAgo(DateTime time) {
    return timeago.format(time);
  }

  static String getFormattedDate(DateTime date) {
    return DateFormat('MMMM d, y').format(date);
  }

  static String getFormattedDateTime(DateTime dateTime) {
    return DateFormat('MMM d, y h:mm a').format(dateTime);
  }
}
