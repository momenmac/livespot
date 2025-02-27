// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'package:flutter/material.dart';

import 'package:flutter_application_2/core/constants/theme_constants.dart';

import '../../core/utils/navigation_service.dart';
import '../../routes/app_routes.dart';

class AnimatedIconButton extends StatefulWidget {
  final IconData selectedIcon;
  final IconData unselectedIcon;
  final bool isSelected;
  final VoidCallback onPressed;
  final Color color;
  final double size;

  const AnimatedIconButton({
    super.key,
    required this.selectedIcon,
    required this.unselectedIcon,
    required this.isSelected,
    required this.onPressed,
    required this.color,
    required this.size,
  });

  @override
  State<AnimatedIconButton> createState() => _AnimatedIconButtonState();
}

class _AnimatedIconButtonState extends State<AnimatedIconButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _animation = Tween<double>(begin: 1, end: 1.1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      padding: EdgeInsets.zero,
      onPressed: () {
        _controller.forward().then((_) => _controller.reverse());
        widget.onPressed();
      },
      icon: AnimatedBuilder(
        animation: _animation,
        builder: (context, child) => Transform.scale(
          scale: _animation.value,
          child: Icon(
            widget.isSelected ? widget.selectedIcon : widget.unselectedIcon,
            size: widget.size,
            color: widget.color,
          ),
        ),
      ),
    );
  }
}

class TopNavigationBar extends StatelessWidget implements PreferredSizeWidget {
  final int currentIndex;
  final Function(int) onTap;
  final bool rounded;

  const TopNavigationBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.rounded,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppBar(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.zero,
      ),
      backgroundColor: theme.scaffoldBackgroundColor, // You can change this
      elevation: 1, // Add shadow
      centerTitle: true, // Center the navigation items
      title: Container(
        constraints: const BoxConstraints(maxWidth: 500), // Constrain max width
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: <Widget>[
            // You can wrap each AnimatedIconButton with additional styling
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(25),
                color: currentIndex == 0
                    ? theme.primaryColor.withOpacity(0.1)
                    : Colors.transparent,
              ),
              child: AnimatedIconButton(
                selectedIcon: Icons.home,
                unselectedIcon: Icons.home_outlined,
                isSelected: currentIndex == 0,
                color: currentIndex == 0
                    ? ThemeConstants.primaryColor
                    : theme.iconTheme.color!,
                size: 28, // Customize icon size
                onPressed: () => onTap(0),
              ),
            ),
            // Repeat similar Container wrapper for other buttons
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(25),
                color: currentIndex == 1
                    ? theme.primaryColor.withOpacity(0.1)
                    : Colors.transparent,
              ),
              child: AnimatedIconButton(
                selectedIcon: Icons.message,
                unselectedIcon: Icons.message_outlined,
                isSelected: currentIndex == 1,
                color: currentIndex == 1
                    ? ThemeConstants.primaryColor
                    : theme.iconTheme.color!,
                size: 28, // Customize icon size
                onPressed: () => onTap(1),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(25),
                color: currentIndex == 3
                    ? theme.primaryColor.withOpacity(0.1)
                    : Colors.transparent,
              ),
              child: AnimatedIconButton(
                selectedIcon: Icons.notifications,
                unselectedIcon: Icons.notifications_outlined,
                isSelected: currentIndex == 3,
                color: currentIndex == 3
                    ? ThemeConstants.primaryColor
                    : theme.iconTheme.color!,
                size: 28, // Customize icon size
                onPressed: () => onTap(3),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(25),
                color: currentIndex == 4
                    ? theme.primaryColor.withOpacity(0.1)
                    : Colors.transparent,
              ),
              child: AnimatedIconButton(
                selectedIcon: Icons.person,
                unselectedIcon: Icons.person_outline,
                isSelected: currentIndex == 4,
                color: currentIndex == 4
                    ? ThemeConstants.primaryColor
                    : theme.iconTheme.color!,
                size: 28, // Customize icon size
                onPressed: () => onTap(4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

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
    final theme = Theme.of(context);

    return BottomAppBar(
      height: 65,
      notchMargin: 8.0,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(5, 10, 5, 0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            AnimatedIconButton(
              selectedIcon: Icons.home,
              unselectedIcon: Icons.home_outlined,
              isSelected: currentIndex == 0,
              color: currentIndex == 0
                  ? ThemeConstants.primaryColor
                  : theme.iconTheme.color!,
              size: theme.iconTheme.size!,
              onPressed: () => onTap(0),
            ),
            AnimatedIconButton(
              selectedIcon: Icons.chat,
              unselectedIcon: Icons.chat_outlined,
              isSelected: currentIndex == 1,
              color: currentIndex == 1
                  ? ThemeConstants.primaryColor
                  : theme.iconTheme.color!,
              size: 28,
              onPressed: () => onTap(1),
            ),
            const SizedBox(width: 40),
            AnimatedIconButton(
              selectedIcon: Icons.notifications,
              unselectedIcon: Icons.notifications_outlined,
              isSelected: currentIndex == 3,
              color: currentIndex == 3
                  ? ThemeConstants.primaryColor
                  : theme.iconTheme.color!,
              size: theme.iconTheme.size!,
              onPressed: () => onTap(3),
              // Colors.grey.shade500
            ),
            AnimatedIconButton(
              selectedIcon: Icons.person,
              unselectedIcon: Icons.person_outline,
              isSelected: currentIndex == 4,
              color: currentIndex == 4
                  ? ThemeConstants.primaryColor
                  : theme.iconTheme.color!,
              size: theme.iconTheme.size!,
              onPressed: () => onTap(4),
            ),
          ],
        ),
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
    final isLargeScreen = MediaQuery.of(context).size.width > 900;

    return Scaffold(
      appBar: isLargeScreen
          ? TopNavigationBar(
              currentIndex: currentIndex,
              onTap: onTap,
              rounded: true,
            )
          : null,
      bottomNavigationBar: isLargeScreen
          ? null
          : CustomNavigationBar(
              currentIndex: currentIndex,
              onTap: onTap,
            ),
      floatingActionButton: isLargeScreen
          ? null
          : SizedBox(
              width: 65,
              height: 65,
              child: FloatingActionButton(
                onPressed: () =>
                    NavigationService().navigateTo(AppRoutes.camera),
                tooltip: 'Camera',
                shape: const CircleBorder(),
                child: const Icon(Icons.camera_alt_outlined, size: 35),
              ),
            ),
      floatingActionButtonLocation:
          isLargeScreen ? null : FloatingActionButtonLocation.centerDocked,
      body: body,
    );
  }
}
