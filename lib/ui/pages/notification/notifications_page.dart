import 'package:flutter/material.dart';
import 'package:flutter_application_2/constants/text_strings.dart';
import 'package:flutter_application_2/constants/theme_constants.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_application_2/ui/pages/notification/notification_model.dart';
import 'package:intl/intl.dart';
import 'notification_filter.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage>
    with TickerProviderStateMixin {
  bool _showBanner = true;
  bool _notificationsEnabled = false;
  NotificationFilter _selectedFilter = NotificationFilter.all;
  late AnimationController _animationController;
  final GlobalKey<AnimatedListState> _listKey = GlobalKey<AnimatedListState>();

  // Sample notifications - replace with your actual data source
  final List<NotificationModel> notifications = [
    NotificationModel(
      message: "John Smith started following you",
      dateTime: DateTime.now().subtract(const Duration(minutes: 15)),
      icon: Icons.person_add,
      isRead: false,
      title: "New Follower",
      imageUrl: "https://randomuser.me/api/portraits/men/32.jpg",
    ),
    NotificationModel(
      message: "Meeting reminder: Team sync in 15 minutes",
      dateTime: DateTime.now().subtract(const Duration(minutes: 25)),
      icon: Icons.calendar_today,
      isRead: false,
    ),
    NotificationModel(
      message: "Sara Wilson liked your post",
      dateTime: DateTime.now().subtract(const Duration(hours: 1)),
      icon: Icons.thumb_up_outlined,
      isRead: false,
      title: "Post Interaction",
      imageUrl: "https://randomuser.me/api/portraits/women/44.jpg",
    ),
    NotificationModel(
      message: "New message from Sarah in Project Discussion",
      dateTime: DateTime.now().subtract(const Duration(minutes: 30)),
      icon: Icons.chat_bubble_outline,
      isRead: false,
    ),
    NotificationModel(
      message: "Document 'Q4 Report' has been shared with you",
      dateTime: DateTime.now().subtract(const Duration(hours: 2)),
      icon: Icons.description,
    ),
    NotificationModel(
      message: "Your recent post received 25 likes",
      dateTime: DateTime.now().subtract(const Duration(hours: 5)),
      icon: Icons.thumb_up_outlined,
    ),
    NotificationModel(
      message: "Alex Rivera commented on your photo",
      dateTime: DateTime.now().subtract(const Duration(hours: 8)),
      icon: Icons.comment,
      title: "New Comment",
      imageUrl: "https://randomuser.me/api/portraits/men/67.jpg",
    ),
    NotificationModel(
      message: "Weekly summary: 12 new updates in your network",
      dateTime: DateTime.now().subtract(const Duration(days: 1)),
      icon: Icons.analytics_outlined,
    ),
    NotificationModel(
      message: "Security alert: New login from Chrome browser",
      dateTime: DateTime.now().subtract(const Duration(days: 2)),
      icon: Icons.security,
    ),
    NotificationModel(
      message: "Welcome to the platform! Complete your profile",
      dateTime: DateTime.now().subtract(const Duration(days: 3)),
      icon: Icons.person_outline,
    ),
  ];

  List<NotificationModel> _getFilteredNotifications() {
    return _selectedFilter.filterNotifications(notifications);
  }

  @override
  void initState() {
    super.initState();
    _checkNotificationStatus();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _checkNotificationStatus() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _notificationsEnabled = prefs.getBool('notifications_enabled') ?? false;
      _showBanner = !_notificationsEnabled;
    });
  }

  Future<void> _enableNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notifications_enabled', true);

    setState(() {
      _showBanner = false;
      _notificationsEnabled = true; // Fixed: removed extra parenthesis
    });
  }

  Future<void> _resetNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notifications_enabled', false);
    setState(() {
      _showBanner = true;
      _notificationsEnabled = false; // Fixed: removed extra parenthesis
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

  String _getRelativeTime(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final notificationDate = DateTime(date.year, date.month, date.day);

    // Only show relative time for today's notifications
    if (notificationDate == today) {
      final difference = now.difference(date);
      if (difference.inMinutes < 1) {
        return 'Just now';
      } else if (difference.inMinutes < 60) {
        return '${difference.inMinutes}m ago';
      } else if (difference.inHours < 24) {
        return '${difference.inHours}h ago';
      }
    }

    // For older notifications, return a formatted time
    return DateFormat('h:mm a').format(date);
  }

  void _markAsRead(NotificationModel notification) {
    if (!notification.isRead) {
      setState(() {
        notification.isRead = true;
      });
    }
  }

  void _markAllAsRead() {
    setState(() {
      for (var notification in notifications) {
        notification.isRead = true;
      }
    });
  }

  void _removeNotification(NotificationModel notification) {
    setState(() {
      notifications.remove(notification);
    });
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.notifications_none_outlined,
            size: 80,
            color: Colors.grey.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            "No notifications yet",
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.grey,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            "We'll notify you when something arrives",
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationsList() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final filteredNotifications = _getFilteredNotifications();

    if (filteredNotifications.isEmpty) {
      return _buildEmptyState();
    }

    // Group notifications by date
    final groupedNotifications = <String, List<NotificationModel>>{};

    for (var notification in filteredNotifications) {
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
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey[800] : Colors.grey[200],
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      dateHeader,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: isDark ? Colors.white70 : Colors.black54,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                ],
              ),
            ),
            ...notificationsForDate.map(
                (notification) => _buildNotificationCard(notification, isDark)),
          ],
        );
      },
    );
  }

  Widget _buildNotificationCard(NotificationModel notification, bool isDark) {
    bool hasUserImage =
        notification.imageUrl != null && notification.imageUrl!.isNotEmpty;

    return Dismissible(
      key: Key(notification.message + notification.dateTime.toString()),
      background: Container(
        color: Colors.red[400],
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(
          Icons.delete_outline,
          color: Colors.white,
        ),
      ),
      direction: DismissDirection.endToStart,
      onDismissed: (direction) {
        _removeNotification(notification);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        decoration: BoxDecoration(
          color: notification.isRead
              ? (isDark ? ThemeConstants.darkCardColor : Colors.white)
              : (isDark
                  ? Colors.blue.withOpacity(0.15)
                  : Colors.blue.withOpacity(0.08)),
          borderRadius: BorderRadius.circular(16),
          boxShadow: notification.isRead
              ? []
              : [
                  BoxShadow(
                    color: isDark
                        ? Colors.black12
                        : Colors.black.withOpacity(0.06),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
          border: notification.isRead
              ? Border.all(
                  color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
                  width: 1)
              : Border.all(color: Colors.blue.withOpacity(0.3), width: 1),
        ),
        child: InkWell(
          onTap: () => _markAsRead(notification),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (hasUserImage)
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
                        width: 2,
                      ),
                      image: DecorationImage(
                        image: NetworkImage(notification.imageUrl!),
                        fit: BoxFit.cover,
                      ),
                    ),
                    child: !notification.isRead
                        ? Align(
                            alignment: Alignment.topRight,
                            child: Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isDark
                                      ? ThemeConstants.darkCardColor
                                      : Colors.white,
                                  width: 2,
                                ),
                              ),
                            ),
                          )
                        : null,
                  )
                else
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey[800] : Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Stack(
                      children: [
                        Icon(
                          notification.icon,
                          color: isDark ? Colors.blue[300] : Colors.blue[700],
                          size: 24,
                        ),
                        if (!notification.isRead)
                          Positioned(
                            right: -2,
                            top: -2,
                            child: Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isDark
                                      ? Colors.grey[800]!
                                      : Colors.grey[100]!,
                                  width: 2,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (notification.title != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            notification.title!,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color:
                                  isDark ? Colors.blue[300] : Colors.blue[700],
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      Text(
                        notification.message,
                        style: TextStyle(
                          fontWeight: notification.isRead
                              ? FontWeight.normal
                              : FontWeight.bold,
                          fontSize: 15,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _getRelativeTime(notification.dateTime),
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isLargeScreen = MediaQuery.of(context).size.width > 900;
    final filteredNotifications = _getFilteredNotifications();
    final hasUnreadNotifications = notifications.any((n) => !n.isRead);

    return Scaffold(
      appBar: isLargeScreen
          ? null
          : AppBar(
              title: Text(
                'Notifications',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 22,
                ),
              ),
              elevation: 0,
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              automaticallyImplyLeading: false,
              actions: [
                if (hasUnreadNotifications)
                  IconButton(
                    icon: const Icon(Icons.done_all),
                    tooltip: 'Mark all as read',
                    onPressed: _markAllAsRead,
                  ),
                const SizedBox(width: 8),
              ],
            ),
      body: Column(
        children: [
          if (_showBanner)
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue[700]!, Colors.blue[500]!],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.notifications_active,
                          color: Colors.white,
                          size: 28,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          TextStrings.turnOnNotifications,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      TextStrings.notificationDescription,
                      style: const TextStyle(
                        fontSize: 15,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        ElevatedButton(
                          onPressed: _enableNotifications,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.blue[700],
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                          ),
                          child: Text(
                            TextStrings.turnOn,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        TextButton(
                          onPressed: _hideBanner,
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                              side: const BorderSide(
                                  color: Colors.white, width: 1),
                            ),
                          ),
                          child: Text(TextStrings.notNow),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          // Modern filter chips row
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Filter',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                ),
                const SizedBox(height: 6),
                SizedBox(
                  height: 32,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: NotificationFilter.values.map((filter) {
                      final isSelected = _selectedFilter == filter;
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: FilterChip(
                          label: Text(
                            filter.label,
                            style: TextStyle(
                              fontSize: 14,
                              color: isSelected
                                  ? (isDark ? Colors.white : Colors.blue[800])
                                  : (isDark ? Colors.white70 : Colors.black87),
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                          selected: isSelected,
                          onSelected: (selected) {
                            setState(() {
                              _selectedFilter = filter;
                            });
                          },
                          backgroundColor:
                              isDark ? Colors.grey[800] : Colors.grey[200],
                          selectedColor:
                              isDark ? Colors.blue[800] : Colors.blue[100],
                          showCheckmark: false,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.compact,
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: filteredNotifications.isEmpty
                ? _buildEmptyState()
                : RefreshIndicator(
                    onRefresh: () async {
                      // In a real app, you would fetch new notifications here
                      await Future.delayed(const Duration(seconds: 1));
                    },
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: _buildNotificationsList(),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
