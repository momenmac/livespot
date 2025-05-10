import 'package:flutter/material.dart';
import 'package:flutter_application_2/constants/theme_constants.dart';

/// A utility class that centralizes all category-related styles and functions
class CategoryUtils {
  /// List of all supported category types
  static const List<String> allCategories = [
    'news',
    'event',
    'alert',
    'military', // New category
    'casualties', // Military subcategory
    'explosion', // Military subcategory
    'politics', // New category
    'sports', // New category
    'health', // New category
    'traffic',
    'weather',
    'crime',
    'community',
    'disaster', // New category
    'environment', // New category
    'education', // New category
    'fire', // Disaster subcategory
    'other',
  ];

  /// Get the appropriate color for a category
  static Color getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'news':
        return ThemeConstants.primaryColor;
      case 'event':
        return ThemeConstants.purple;
      case 'alert':
        return ThemeConstants.red;
      case 'military':
        return const Color(0xFF546E7A); // Military blue-grey
      case 'casualties':
        return const Color(0xFF212121); // Dark grey for casualties
      case 'explosion':
        return const Color(0xFFBF360C); // Deep orange for explosions
      case 'politics':
        return const Color(0xFF6A1B9A); // Deep purple
      case 'sports':
        return const Color(0xFF00897B); // Teal
      case 'health':
        return const Color(0xFFE91E63); // Pink
      case 'traffic':
        return ThemeConstants.orange;
      case 'weather':
        return const Color(0xFF4FC3F7); // Light blue
      case 'crime':
        return ThemeConstants.red.withOpacity(0.8);
      case 'community':
        return ThemeConstants.green;
      case 'disaster':
        return const Color(0xFFB71C1C); // Deep red
      case 'fire':
        return const Color(0xFFFF6F00); // Amber for fires
      case 'environment':
        return const Color(0xFF558B2F); // Light green
      case 'education':
        return const Color(0xFFFFA000); // Amber
      case 'other':
      default:
        return ThemeConstants.grey;
    }
  }

  /// Get the appropriate icon for a category
  static IconData getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'news':
        return Icons.article;
      case 'event':
        return Icons.event;
      case 'alert':
        return Icons.warning_amber;
      case 'military':
        return Icons.security; // Military shield icon
      case 'casualties':
        return Icons.dangerous; // Replace with a dangerous icon instead of non-existent skull icon
      case 'explosion':
        return Icons.flashlight_on; // Explosion icon
      case 'politics':
        return Icons.account_balance; // Government building icon
      case 'sports':
        return Icons.sports_soccer; // Sports icon
      case 'health':
        return Icons.local_hospital; // Hospital icon
      case 'traffic':
        return Icons.traffic;
      case 'weather':
        return Icons.cloud;
      case 'crime':
        return Icons.local_police;
      case 'community':
        return Icons.people;
      case 'disaster':
        return Icons.emergency; // Emergency icon
      case 'fire':
        return Icons.local_fire_department; // Fire icon
      case 'environment':
        return Icons.park; // Nature icon
      case 'education':
        return Icons.school; // School icon
      case 'other':
      default:
        return Icons.category;
    }
  }

  /// Get a human-readable display name for a category
  static String getCategoryDisplayName(String category) {
    switch (category.toLowerCase()) {
      case 'news':
        return 'News';
      case 'event':
        return 'Event';
      case 'alert':
        return 'Alert';
      case 'military':
        return 'Military';
      case 'casualties':
        return 'Casualties';
      case 'explosion':
        return 'Explosion';
      case 'politics':
        return 'Politics';
      case 'sports':
        return 'Sports';
      case 'health':
        return 'Health';
      case 'traffic':
        return 'Traffic';
      case 'weather':
        return 'Weather';
      case 'crime':
        return 'Crime';
      case 'community':
        return 'Community';
      case 'disaster':
        return 'Disaster';
      case 'fire':
        return 'Fire';
      case 'environment':
        return 'Environment';
      case 'education':
        return 'Education';
      case 'other':
      default:
        return 'Other';
    }
  }

  /// Build a category chip widget for display in lists and filters
  static Widget buildCategoryChip({
    required String category,
    bool includeIcon = true,
    bool isSelected = false,
    double height = 32.0,
  }) {
    final color = getCategoryColor(category);
    final icon = getCategoryIcon(category);
    final label = getCategoryDisplayName(category);

    return Container(
      height: height,
      padding:
          EdgeInsets.symmetric(horizontal: includeIcon ? 12 : 16, vertical: 4),
      decoration: BoxDecoration(
        color: isSelected ? color : color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected ? color : color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (includeIcon) ...[
            Icon(
              icon,
              size: 16,
              color: isSelected ? Colors.white : color,
            ),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : color,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  /// Build a category icon for maps and badges
  static Widget buildCategoryIcon(
    String category, {
    double size = 24.0,
    Color? backgroundColor,
    Color? iconColor,
    double padding = 8.0,
  }) {
    final color = backgroundColor ?? getCategoryColor(category);
    final icon = getCategoryIcon(category);

    return Container(
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Icon(
        icon,
        size: size,
        color: iconColor ?? Colors.white,
      ),
    );
  }

  /// Build a map marker for the given category
  static Widget buildCategoryMapMarker(
    String category, {
    bool isSelected = false,
    String? label,
  }) {
    // Wrap in ClipRect to prevent any overflow from showing
    return ClipRect(
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minWidth: 30,
          maxWidth: 200, // Allow wider content when needed
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              decoration: BoxDecoration(
                color: getCategoryColor(category),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 5), // Reduced vertical padding from 6 to 5
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon(
                    getCategoryIcon(category),
                    color: Colors.white,
                    size: isSelected ? 18 : 14,
                  ),
                  if (label != null) ...[
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        label,
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: isSelected ? 12 : 10,
                          overflow: TextOverflow.ellipsis,
                        ),
                        maxLines: 1,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            // Use a smaller pointer (4px instead of 5px)
            SizedBox(
              width: 10,
              height: 4,
              child: CustomPaint(
                painter: TrianglePainter(
                  color: getCategoryColor(category),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build a map marker with LiveUAMap-style design
  static Widget buildLiveUAMapMarker(
    String category, {
    bool isSelected = false,
    String? label,
    bool showShadow = true,
  }) {
    final color = getCategoryColor(category);
    final icon = getCategoryIcon(category);
    
    // Calculate marker size based on selection state
    final markerSize = isSelected ? 38.0 : 32.0; // Reduced from 42.0/36.0

    // Special custom icons based on category
    Widget? customIcon;

    // Check for specialized icons
    switch (category.toLowerCase()) {
      case 'casualties':
        customIcon = _buildSkullIcon();
        break;
      case 'explosion':
        customIcon = _buildExplosionIcon();
        break;
      case 'military':
        customIcon = _buildTankIcon();
        break;
      case 'fire':
        customIcon = _buildFireIcon();
        break;
    }

    // Just return the marker circle without any Column wrapper to avoid overflow
    return Container(
      width: markerSize,
      height: markerSize,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: showShadow
            ? [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 6,
                  offset: const Offset(0, 3),
                ),
              ]
            : null,
      ),
      child: Center(
        child: customIcon ??
            Icon(
              icon,
              color: Colors.white,
              size: isSelected ? 22.0 : 18.0, // Reduced from 24.0/20.0
            ),
      ),
    );
  }

  // Custom icon builders for specialized markers

  /// Build a skull icon for casualties marker
  static Widget _buildSkullIcon() {
    return const CustomPaint(
      size: Size(20, 20), // Increased from 16x16
      painter: SkullIconPainter(color: Colors.white),
    );
  }

  /// Build an explosion icon
  static Widget _buildExplosionIcon() {
    return Stack(
      alignment: Alignment.center,
      children: [
        Icon(Icons.flash_on, color: Colors.yellow, size: 20), // Increased from 16
        Icon(Icons.circle, color: Colors.white.withOpacity(0.7), size: 10), // Increased from 8
      ],
    );
  }

  /// Build a tank icon for military
  static Widget _buildTankIcon() {
    return const CustomPaint(
      size: Size(22, 18), // Increased from 18x14
      painter: TankIconPainter(color: Colors.white),
    );
  }

  /// Build a fire icon
  static Widget _buildFireIcon() {
    return Stack(
      alignment: Alignment.center,
      children: [
        Icon(Icons.local_fire_department,
            color: Colors.orange.shade300, size: 22), // Increased from 18
        Icon(Icons.local_fire_department, color: Colors.red, size: 18), // Increased from 14
      ],
    );
  }

  /// Build an animated pulsing marker for important/highlighted events
  static Widget buildPulsingMarker(
    String category, {
    Color? pulseColor,
    double size = 36.0, // Increased from 30.0
  }) {
    final baseColor = getCategoryColor(category);
    final icon = getCategoryIcon(category);
    final pulse = pulseColor ?? baseColor.withOpacity(0.4);

    return Stack(
      children: [
        // Animated pulse effect
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: const Duration(seconds: 2),
          builder: (context, value, child) {
            return Opacity(
              opacity: (1.0 - value) * 0.7,
              child: Transform.scale(
                scale: 1.0 + (value * 0.5),
                child: Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    color: pulse,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          },
          // Loop the animation
          onEnd: () => TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(seconds: 2),
            builder: (context, value, child) {
              return Opacity(
                opacity: (1.0 - value) * 0.7,
                child: Transform.scale(
                  scale: 1.0 + (value * 0.5),
                  child: Container(
                    width: size,
                    height: size,
                    decoration: BoxDecoration(
                      color: pulse,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              );
            },
          ),
        ),

        // Actual marker
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: baseColor,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Icon(
              icon,
              color: Colors.white,
              size: size * 0.5,
            ),
          ),
        ),
      ],
    );
  }
}

/// Custom painter for drawing the triangle pointer below the marker
class TrianglePainter extends CustomPainter {
  final Color color;

  TrianglePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final Path path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(TrianglePainter oldDelegate) => color != oldDelegate.color;
}

/// Custom painter for drawing a skull icon
class SkullIconPainter extends CustomPainter {
  final Color color;

  const SkullIconPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final width = size.width;
    final height = size.height;

    // Draw skull shape
    final skullPath = Path()
      ..moveTo(width * 0.3, height * 0.5)
      ..cubicTo(width * 0.3, height * 0.3, width * 0.7, height * 0.3,
          width * 0.7, height * 0.5)
      ..lineTo(width * 0.6, height * 0.8)
      ..lineTo(width * 0.4, height * 0.8)
      ..close();

    // Draw eyes
    final leftEye = Path()
      ..addOval(Rect.fromCenter(
        center: Offset(width * 0.35, height * 0.45),
        width: width * 0.15,
        height: height * 0.2,
      ));

    final rightEye = Path()
      ..addOval(Rect.fromCenter(
        center: Offset(width * 0.65, height * 0.45),
        width: width * 0.15,
        height: height * 0.2,
      ));

    canvas.drawPath(skullPath, paint);

    // Cutout eyes with XOR operation
    paint.blendMode = BlendMode.clear;
    canvas.drawPath(leftEye, paint);
    canvas.drawPath(rightEye, paint);

    // Draw teeth
    paint.blendMode = BlendMode.srcOver;
    paint.style = PaintingStyle.stroke;
    paint.strokeWidth = 1;

    canvas.drawLine(Offset(width * 0.45, height * 0.65),
        Offset(width * 0.45, height * 0.75), paint);
    canvas.drawLine(Offset(width * 0.55, height * 0.65),
        Offset(width * 0.55, height * 0.75), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Custom painter for drawing a tank icon
class TankIconPainter extends CustomPainter {
  final Color color;

  const TankIconPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final width = size.width;
    final height = size.height;

    // Draw tank body
    final bodyPath = Path()
      ..moveTo(width * 0.2, height * 0.7)
      ..lineTo(width * 0.8, height * 0.7)
      ..lineTo(width * 0.9, height * 0.5)
      ..lineTo(width * 0.7, height * 0.5)
      ..lineTo(width * 0.7, height * 0.3)
      ..lineTo(width * 0.3, height * 0.3)
      ..lineTo(width * 0.3, height * 0.5)
      ..lineTo(width * 0.1, height * 0.5)
      ..close();

    // Draw tank barrel
    final barrelPath = Path()
      ..moveTo(width * 0.5, height * 0.4)
      ..lineTo(width, height * 0.4);

    // Draw tank tracks
    final leftTrackPath = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromPoints(
          Offset(width * 0.15, height * 0.7),
          Offset(width * 0.35, height * 0.9),
        ),
        const Radius.circular(2),
      ));

    final rightTrackPath = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromPoints(
          Offset(width * 0.65, height * 0.7),
          Offset(width * 0.85, height * 0.9),
        ),
        const Radius.circular(2),
      ));

    // Fill style for body
    paint.style = PaintingStyle.fill;
    canvas.drawPath(bodyPath, paint);

    // Stroke style for barrel
    paint.style = PaintingStyle.stroke;
    canvas.drawPath(barrelPath, paint);

    // Fill style for tracks
    paint.style = PaintingStyle.fill;
    canvas.drawPath(leftTrackPath, paint);
    canvas.drawPath(rightTrackPath, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
