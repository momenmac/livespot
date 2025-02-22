import 'package:flutter/material.dart';
import '../widgets/navigation_bar.dart';
import 'map_page.dart';
import 'camera_page.dart';
import 'notifications_page.dart';
import 'profile_page.dart';

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  int _selectedIndex = 0;
  bool _showMap = false;
  double? dragStartX;

  static const List<Widget> _pages = <Widget>[
    HomeContent(),
    MapPage(),
    CameraPage(),
    NotificationsPage(),
    ProfilePage(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  void _toggleMap() {
    setState(() {
      _showMap = !_showMap;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isLargeScreen = MediaQuery.of(context).size.width > 700;

    if (isLargeScreen) {
      return Row(
        children: [
          const Expanded(
            flex: 1,
            child: MapPage(showBackButton: false),
          ),
          Container(
            constraints: const BoxConstraints(maxWidth: 450),
            child: CustomScaffold(
              currentIndex: _selectedIndex,
              onTap: _onItemTapped,
              body: _pages[_selectedIndex],
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

class HomeContent extends StatelessWidget {
  const HomeContent({super.key});

  @override
  Widget build(BuildContext context) {
    final isLargeScreen = MediaQuery.of(context).size.width > 700;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        leading: isLargeScreen
            ? null
            : IconButton(
                onPressed: () {
                  final homeState =
                      context.findAncestorStateOfType<_HomeState>();
                  homeState?._toggleMap();
                },
                icon: const Icon(Icons.location_on_outlined),
              ),
      ),
      body: const Center(
        child: Text('Home Page'),
      ),
    );
  }
}
