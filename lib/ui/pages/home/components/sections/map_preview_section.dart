import 'package:flutter/material.dart';
import 'package:flutter_application_2/constants/text_strings.dart';
import 'package:flutter_application_2/constants/theme_constants.dart';
import 'package:flutter_application_2/ui/pages/map/map_controller.dart';
import 'package:flutter_application_2/ui/pages/map/widgets/map_view.dart';
import 'package:flutter_application_2/ui/pages/home/components/home_content.dart';

class MapPreviewSection extends StatefulWidget {
  const MapPreviewSection({super.key});

  @override
  State<MapPreviewSection> createState() => _MapPreviewSectionState();
}

class _MapPreviewSectionState extends State<MapPreviewSection> {
  late MapPageController _mapController;
  bool _isMapReady = false;

  @override
  void initState() {
    super.initState();
    _mapController = MapPageController();

    // Initialize map after widget is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeMap();
    });
  }

  Future<void> _initializeMap() async {
    try {
      _mapController.setContext(context);
      await _mapController.initializeLocation();

      // Allow a moment for the map to initialize
      await Future.delayed(const Duration(milliseconds: 800));

      if (mounted) {
        setState(() {
          _isMapReady = true;
        });
      }
    } catch (e) {
      debugPrint('Error initializing map: $e');
      // Set map ready even on error, to show a fallback view
      if (mounted) {
        setState(() {
          _isMapReady = true;
        });
      }
    }
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    // Background color based on theme
    final containerColor = isDarkMode
        ? ThemeConstants.primaryColor.withOpacity(0.2)
        : ThemeConstants.primaryColorVeryLight;

    // Shadow color based on theme
    final shadowColor = isDarkMode
        ? Colors.black.withOpacity(0.15)
        : Colors.black.withOpacity(0.05);

    // Gradient colors for overlay
    final gradientColors = [
      Colors.transparent,
      isDarkMode
          ? theme.scaffoldBackgroundColor.withOpacity(0.9)
          : Colors.white.withOpacity(0.9),
    ];

    return Container(
      margin: const EdgeInsets.all(12),
      height: 180,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: containerColor,
        boxShadow: [
          BoxShadow(
            color: shadowColor,
            spreadRadius: 1,
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            // Real map view instead of placeholder
            GestureDetector(
              onTap: () => _openFullMap(context),
              child: _isMapReady
                  ? MapView(
                      controller: _mapController,
                      onTap: () => _openFullMap(context),
                    )
                  : Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(
                            color: ThemeConstants.primaryColor,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "Loading map...",
                            style: TextStyle(
                              color:
                                  Theme.of(context).textTheme.bodyMedium?.color,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
            ),

            // Overlay with text and actions
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                height: 50,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: gradientColors,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      TextStrings.newsNearby,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextButton(
                      onPressed: () => _openFullMap(context),
                      child: Row(
                        children: [
                          Text(
                            TextStrings.viewAll,
                            style: TextStyle(
                              color: ThemeConstants.primaryColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.arrow_forward,
                            size: 16,
                            color: ThemeConstants.primaryColor,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // New method to open the full map
  void _openFullMap(BuildContext context) {
    // Find the HomeContent widget directly to access its onMapToggle callback
    final homeContent = context.findAncestorWidgetOfExactType<HomeContent>();

    if (homeContent != null && homeContent.onMapToggle != null) {
      homeContent.onMapToggle!();
    } else {
      // Try to use Navigator to open the map page directly if we can't find HomeContent
      debugPrint('Could not find HomeContent parent with onMapToggle');
    }
  }
}
