import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_application_2/constants/theme_constants.dart';

/// A reliable network avatar widget that handles loading states and errors gracefully
class NetworkAvatar extends StatelessWidget {
  final String imageUrl;
  final String? fallbackText;
  final double radius;
  final Color? backgroundColor;
  final Widget? errorWidget;

  const NetworkAvatar({
    super.key,
    required this.imageUrl,
    this.fallbackText,
    this.radius = 20,
    this.backgroundColor,
    this.errorWidget,
  });

  /// Create a network avatar from a user name
  factory NetworkAvatar.fromName(String name,
      {double radius = 20, Color? backgroundColor}) {
    // Generate a safe URL with just initials
    final initials = name
        .trim()
        .split(' ')
        .take(2)
        .map((e) => e.isNotEmpty ? e[0].toUpperCase() : '')
        .join('');
    final safeName = Uri.encodeComponent(initials);
    final url =
        'https://ui-avatars.com/api/?name=$safeName&size=256&background=random';

    return NetworkAvatar(
      imageUrl: url,
      fallbackText: initials,
      radius: radius,
      backgroundColor: backgroundColor,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return CircleAvatar(
      radius: radius,
      backgroundColor: backgroundColor ??
          (isDarkMode
              ? ThemeConstants.primaryColor.withOpacity(0.4)
              : ThemeConstants.primaryColor.withOpacity(0.2)),
      child: ClipOval(
        child: CachedNetworkImage(
          imageUrl: imageUrl,
          width: radius * 2,
          height: radius * 2,
          fit: BoxFit.cover,
          placeholder: (context, url) => Center(
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: ThemeConstants.primaryColor,
            ),
          ),
          errorWidget: (context, url, error) {
            if (errorWidget != null) return errorWidget!;

            return Center(
              child: Text(
                fallbackText ?? '?',
                style: TextStyle(
                  color: isDarkMode ? Colors.white : Colors.black87,
                  fontWeight: FontWeight.bold,
                  fontSize: radius * 0.8,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
