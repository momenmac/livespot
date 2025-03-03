import 'package:flutter/material.dart';
import 'package:flutter_application_2/constants/theme_constants.dart';

/// A ListTile that shows a subtle hover effect when the mouse is over it
class HoverListTile extends StatefulWidget {
  /// The leading widget, typically an icon or avatar
  final Widget? leading;

  /// The primary content of the list tile
  final Widget title;

  /// Additional content displayed below the title
  final Widget? subtitle;

  /// Called when the user taps this list tile
  final VoidCallback? onTap;

  /// Optional trailing widget that appears after the title
  final Widget? trailing;

  /// Hover color for light theme
  final Color? lightHoverColor;

  /// Hover color for dark theme
  final Color? darkHoverColor;

  /// Whether to use the default hover color
  final bool useDefaultHoverColor;

  /// Creates a ListTile with hover effect
  const HoverListTile({
    super.key,
    this.leading,
    required this.title,
    this.subtitle,
    this.onTap,
    this.trailing,
    this.lightHoverColor,
    this.darkHoverColor,
    this.useDefaultHoverColor = true,
  });

  @override
  State<HoverListTile> createState() => _HoverListTileState();
}

class _HoverListTileState extends State<HoverListTile> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    // Default hover colors
    final defaultLightHover = ThemeConstants.primaryColor.withOpacity(0.05);
    final defaultDarkHover = ThemeConstants.primaryColor.withOpacity(0.1);

    // Determine which hover color to use
    Color? hoverColor;
    if (widget.useDefaultHoverColor) {
      hoverColor = isDarkMode ? defaultDarkHover : defaultLightHover;
    } else {
      hoverColor = isDarkMode ? widget.darkHoverColor : widget.lightHoverColor;
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      cursor: widget.onTap != null
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      child: Container(
        color: _isHovering ? hoverColor : Colors.transparent,
        child: ListTile(
          leading: widget.leading,
          title: widget.title,
          subtitle: widget.subtitle,
          trailing: widget.trailing,
          onTap: widget.onTap,
        ),
      ),
    );
  }
}
