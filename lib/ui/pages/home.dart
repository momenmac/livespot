import 'package:flutter/material.dart';
import 'package:flutter_application_2/ui/pages/messages/messages_page.dart';
import '../widgets/navigation_bar.dart';
import 'map/map_page.dart';
import 'camera_page.dart';
import 'notification/notifications_page.dart';
import '../profile/profile_page.dart';
import 'home/components/home_content.dart';
import 'package:flutter_application_2/ui/pages/messages/messages_controller.dart';
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
  Timer? _unreadCheckTimer;

  // Reference to the MessagesController for unread count
  // We'll initialize this when creating the MessagesPage
  MessagesController? _messagesController;

  // Create pages list with the callback passed to HomeContent
  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();

    // Create a MessagesController instance that will be shared
    _messagesController = MessagesController();

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

    // Set up a timer to periodically check for unread messages
    _unreadCheckTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _updateUnreadCounts();
    });
  }

  @override
  void dispose() {
    _unreadCheckTimer?.cancel();
    super.dispose();
  }

  Future<void> _updateUnreadCounts() async {
    if (_messagesController != null) {
      final unreadCount = _messagesController!.getTotalUnreadCount();
      if (mounted) {
        setState(() {
          _unreadMessageCount = unreadCount;
        });
      }
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });

    // If navigating to messages tab, update unread count after a short delay
    if (index == 1) {
      Future.delayed(const Duration(seconds: 1), () {
        _updateUnreadCounts();
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
