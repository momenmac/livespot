import 'package:flutter/material.dart';
import '../theme/navigation_theme.dart';
import '../pages/home.dart';
import '../pages/map_page.dart';
import '../pages/camera_page.dart';
import '../pages/notifications_page.dart';
import '../pages/profile_page.dart';

class CustomNavigationBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const CustomNavigationBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return BottomAppBar(
      shape: CircularNotchedRectangle(),
      notchMargin: 8.0,
      color: NavigationTheme.navigationBarTheme.color,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          IconButton(
            icon: Icon(Icons.home),
            color: currentIndex == 0
                ? NavigationTheme.navigationBarItemTheme.color
                : Colors.grey,
            onPressed: () => onTap(0),
          ),
          IconButton(
            icon: Icon(Icons.map),
            color: currentIndex == 1
                ? NavigationTheme.navigationBarItemTheme.color
                : Colors.grey,
            onPressed: () => onTap(1),
          ),
          SizedBox(width: 40), // The dummy child for the notch
          IconButton(
            icon: Icon(Icons.notifications),
            color: currentIndex == 3
                ? NavigationTheme.navigationBarItemTheme.color
                : Colors.grey,
            onPressed: () => onTap(3),
          ),
          IconButton(
            icon: Icon(Icons.person),
            color: currentIndex == 4
                ? NavigationTheme.navigationBarItemTheme.color
                : Colors.grey,
            onPressed: () => onTap(4),
          ),
        ],
      ),
    );
  }
}

class CustomScaffold extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;
  final Widget body;

  const CustomScaffold({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: CustomNavigationBar(
        currentIndex: currentIndex,
        onTap: onTap,
      ),
      floatingActionButton: SizedBox(
        width: 70,
        height: 70,
        child: FloatingActionButton(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => CameraPage()),
          ),
          tooltip: 'Camera',
          shape: CircleBorder(),
          backgroundColor: NavigationTheme.cameraButtonTheme.backgroundColor,
          elevation: NavigationTheme.cameraButtonTheme.elevation,
          hoverColor: NavigationTheme.cameraButtonTheme.hoverColor,
          focusColor: NavigationTheme.cameraButtonTheme.focusColor,
          child: Icon(Icons.camera_alt, size: 35),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      body: body,
    );
  }
}
