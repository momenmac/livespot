import 'package:flutter/material.dart';
import 'package:flutter_application_2/ui/pages/messages/messages_page.dart';
import '../widgets/navigation_bar.dart';
import 'map/map_page.dart';
import 'camera_page.dart';
import 'notification/notifications_page.dart';
import '../profile/profile_page.dart';
import 'home/components/home_content.dart';
import 'package:flutter_application_2/ui/pages/messages/messages_controller.dart';
import 'package:flutter_application_2/ui/pages/notification/notifications_controller.dart';
import 'package:flutter_application_2/services/messaging/message_event_bus.dart';
import 'package:flutter_application_2/services/notifications/notification_event_bus.dart';
import 'dart:async';

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  int _selectedIndex = 0;
  bool _showMap = false;
  double? dragStartX;
  int? _unreadMessageCount;
  int? _unreadNotificationCount;
  Timer? _unreadCheckTimer;
  StreamSubscription? _unreadCountSubscription;
  StreamSubscription? _notificationCountSubscription;

  // Reference to the MessagesController for unread count
  // We'll initialize this when creating the MessagesPage
  MessagesController? _messagesController;

  // Reference to the NotificationsController for unread count
  NotificationsController? _notificationsController;

  // Create pages list with the callback passed to HomeContent
  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();

    // Create a MessagesController instance that will be shared
    _messagesController = MessagesController();

    // Create a NotificationsController instance that will be shared
    _notificationsController = NotificationsController();

    // Initialize pages with the shared controller
    _pages = <Widget>[
      HomeContent(onMapToggle: _toggleMap),
      MessagesPage(controller: _messagesController),
      const CameraPage(),
      const NotificationsPage(),
      const ProfilePage(),
    ];

    // Initial update of unread counts
    _updateUnreadCounts();

    // Load messages data immediately and validate unread counts
    _messagesController!.loadConversations().then((_) {
      // First validate all unread counts to fix any inconsistencies
      _messagesController!.validateUnreadCounts().then((_) {
        _updateUnreadCounts();
      });
    });

    // Load notification unread count
    _notificationsController!.loadUnreadCount().then((_) {
      _updateUnreadCounts();
    });

    // Set up a timer to periodically check for unread messages and notifications
    _unreadCheckTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _updateUnreadCounts();

      // Periodically validate unread counts to fix any issues
      if (_messagesController != null) {
        _messagesController!.validateUnreadCounts();
      }

      // Refresh notification count from server
      if (_notificationsController != null) {
        _notificationsController!.refreshUnreadCount();
      }
    });

    // Subscribe to unread count changes via MessageEventBus for real-time updates
    _unreadCountSubscription =
        MessageEventBus().unreadCountStream.listen((count) {
      if (mounted) {
        setState(() {
          _unreadMessageCount = count;
        });
      }
    });

    // Subscribe to notification count changes via NotificationEventBus for real-time updates
    _notificationCountSubscription =
        NotificationEventBus().unreadCountStream.listen((count) {
      if (mounted) {
        setState(() {
          _unreadNotificationCount = count;
        });
      }
    });
  }

  @override
  void dispose() {
    _unreadCheckTimer?.cancel();
    _unreadCountSubscription?.cancel();
    _notificationCountSubscription?.cancel();
    super.dispose();
  }

  Future<void> _updateUnreadCounts() async {
    if (_messagesController != null) {
      final unreadCount = _messagesController!.getTotalUnreadCount();

      // Update the badge through normal state update
      if (mounted) {
        setState(() {
          _unreadMessageCount = unreadCount;
        });
      }

      // Also notify the MessageEventBus so other parts of the app can stay updated
      MessageEventBus().notifyUnreadCountChanged(unreadCount);

      // Debug print for verification
      print('🔢 Home: Updated message unread count to $unreadCount');
    }

    if (_notificationsController != null) {
      final notificationCount = _notificationsController!.unreadCount;

      // Update the notification badge through normal state update
      if (mounted) {
        setState(() {
          _unreadNotificationCount = notificationCount;
        });
      }

      // Also notify the NotificationEventBus so other parts of the app can stay updated
      NotificationEventBus().notifyUnreadCountChanged(notificationCount);

      // Debug print for verification
      print('🔔 Home: Updated notification unread count to $notificationCount');
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });

    // If navigating to messages tab, update unread count after a short delay
    // Also validate unread counts to fix any inconsistencies
    if (index == 1) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (_messagesController != null) {
          _messagesController!.validateUnreadCounts().then((_) {
            _updateUnreadCounts();
          });
        }
      });
    }
  }

  void _toggleMap() {
    setState(() {
      _showMap = !_showMap;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isLargeScreen = MediaQuery.of(context).size.width > 900;

    if (isLargeScreen) {
      return Row(
        children: [
          const Expanded(
            flex: 1,
            child: MapPage(showBackButton: false),
          ),
          Container(
            constraints: const BoxConstraints(maxWidth: 450),
            child: Navigator(
              onGenerateRoute: (settings) {
                return MaterialPageRoute(
                  builder: (context) => CustomScaffold(
                    currentIndex: _selectedIndex,
                    onTap: _onItemTapped,
                    body: _pages[_selectedIndex],
                    unreadMessageCount: _unreadMessageCount,
                    unreadNotificationCount: _unreadNotificationCount,
                  ),
                );
              },
            ),
          ),
        ],
      );
    }

    return GestureDetector(
      onHorizontalDragStart: (details) {
        if (details.localPosition.dx < 20) {
          // Only start drag if from left edge
          dragStartX = details.localPosition.dx;
        }
      },
      onHorizontalDragUpdate: (details) {
        if (dragStartX != null &&
            _selectedIndex == 0 &&
            !_showMap &&
            details.localPosition.dx > dragStartX! &&
            details.localPosition.dx > MediaQuery.of(context).size.width / 2) {
          _toggleMap();
          dragStartX = null;
        }
      },
      onHorizontalDragEnd: (_) {
        dragStartX = null;
      },
      child: Stack(
        children: [
          CustomScaffold(
            currentIndex: _selectedIndex,
            onTap: _onItemTapped,
            body: _pages[_selectedIndex],
            unreadMessageCount: _unreadMessageCount,
            unreadNotificationCount: _unreadNotificationCount,
          ),
          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            left: _showMap ? 0 : -MediaQuery.of(context).size.width,
            top: 0,
            bottom: 0,
            width: MediaQuery.of(context).size.width,
            child: Material(
              child: GestureDetector(
                onHorizontalDragEnd: (details) {
                  if (details.primaryVelocity! < 0) {
                    _toggleMap();
                  }
                },
                child: MapPage(onBackPress: _toggleMap),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
