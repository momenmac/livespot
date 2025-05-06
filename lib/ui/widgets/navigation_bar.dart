// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'package:flutter/material.dart';

import 'package:flutter_application_2/constants/theme_constants.dart';

import '../../services/utils/navigation_service.dart';
import '../../routes/app_routes.dart';

class AnimatedIconButton extends StatefulWidget {
  final IconData selectedIcon;
  final IconData unselectedIcon;
  final bool isSelected;
  final VoidCallback onPressed;
  final Color color;
  final double size;
  final int? badgeCount;

  const AnimatedIconButton({
    super.key,
    required this.selectedIcon,
    required this.unselectedIcon,
    required this.isSelected,
    required this.onPressed,
    required this.color,
    required this.size,
    this.badgeCount,
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
    // Check if we need to show badge
    final showBadge = widget.badgeCount != null && widget.badgeCount! > 0;

    // Get the platform-independent constraints to ensure consistency
    const double badgeSize = 16.0;
    const double badgeFontSize = 10.0;
    const double badgePadding = 4.0;

    return IconButton(
      padding: EdgeInsets.zero,
      onPressed: () {
        _controller.forward().then((_) => _controller.reverse());
        widget.onPressed();
      },
      icon: Stack(
        clipBehavior: Clip.none, // Allow badge to overflow
        children: [
          AnimatedBuilder(
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
          if (showBadge)
            Positioned(
              right: -4,
              top: -2,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: badgePadding, vertical: 1),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(badgeSize / 2),
                  border: Border.all(color: Colors.white, width: 1),
                ),
                constraints: const BoxConstraints(
                  minWidth: badgeSize,
                  minHeight: badgeSize,
                ),
                child: Center(
                  child: Text(
                    widget.badgeCount! > 99
                        ? "99+"
                        : widget.badgeCount.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: badgeFontSize,
                      fontWeight: FontWeight.bold,
                      height: 1.0, // Removes extra vertical space in text
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class TopNavigationBar extends StatelessWidget implements PreferredSizeWidget {
  final int currentIndex;
  final Function(int) onTap;
  final bool rounded;
  final int? unreadMessageCount;
  final int? unreadNotificationCount;

  const TopNavigationBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.rounded,
    this.unreadMessageCount,
    this.unreadNotificationCount,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Only show badge counts when they are actually greater than zero
    final showMessageBadge =
        unreadMessageCount != null && unreadMessageCount! > 0;
    final showNotificationBadge =
        unreadNotificationCount != null && unreadNotificationCount! > 0;

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
                    // ignore: deprecated_member_use
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
                    // ignore: deprecated_member_use
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
                badgeCount: showMessageBadge ? unreadMessageCount : null,
              ),
            ),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(25),
                color: currentIndex == 3
                    // ignore: deprecated_member_use
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
                badgeCount:
                    showNotificationBadge ? unreadNotificationCount : null,
              ),
            ),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(25),
                color: currentIndex == 4
                    // ignore: deprecated_member_use
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
  final int? unreadNotificationCount;
  final int? unreadMessageCount;

  const CustomNavigationBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.unreadNotificationCount,
    this.unreadMessageCount,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Only show badge counts when they are actually greater than zero
    final showMessageBadge =
        unreadMessageCount != null && unreadMessageCount! > 0;
    final showNotificationBadge =
        unreadNotificationCount != null && unreadNotificationCount! > 0;

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
              size: theme.iconTheme.size ?? 28,
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
              badgeCount: showMessageBadge ? unreadMessageCount : null,
            ),
            const SizedBox(width: 40),
            AnimatedIconButton(
              selectedIcon: Icons.notifications,
              unselectedIcon: Icons.notifications_outlined,
              isSelected: currentIndex == 3,
              color: currentIndex == 3
                  ? ThemeConstants.primaryColor
                  : theme.iconTheme.color!,
              size: theme.iconTheme.size ?? 28,
              onPressed: () => onTap(3),
              badgeCount:
                  showNotificationBadge ? unreadNotificationCount : null,
            ),
            AnimatedIconButton(
              selectedIcon: Icons.person,
              unselectedIcon: Icons.person_outline,
              isSelected: currentIndex == 4,
              color: currentIndex == 4
                  ? ThemeConstants.primaryColor
                  : theme.iconTheme.color!,
              size: theme.iconTheme.size ?? 28,
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
  final int? unreadNotificationCount;
  final int? unreadMessageCount;

  const CustomScaffold({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.body,
    this.unreadNotificationCount,
    this.unreadMessageCount,
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
              unreadMessageCount: unreadMessageCount,
              unreadNotificationCount: unreadNotificationCount,
            )
          : null,
      bottomNavigationBar: isLargeScreen
          ? null
          : CustomNavigationBar(
              currentIndex: currentIndex,
              onTap: onTap,
              unreadNotificationCount: unreadNotificationCount,
              unreadMessageCount: unreadMessageCount,
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
