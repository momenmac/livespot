import 'package:flutter/material.dart';
import 'package:flutter_application_2/constants/text_strings.dart';
import 'package:flutter_application_2/constants/theme_constants.dart';
import 'package:flutter_application_2/ui/pages/map/map_controller.dart';
import 'package:flutter_application_2/ui/pages/map/widgets/map_view.dart';
import 'package:flutter_application_2/ui/pages/home/components/home_content.dart'; // Added import

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
      await Future.delayed(const Duration(milliseconds: 500));

      if (mounted) {
        setState(() {
          _isMapReady = true;
        });
      }
    } catch (e) {
      debugPrint('Error initializing map: $e');
    }
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(12),
      height: 180,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: ThemeConstants.primaryColorVeryLight,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
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
                      child: CircularProgressIndicator(
                        color: ThemeConstants.primaryColor,
                      ),
                    ),
            ),

            // REMOVED: Static map markers that were previously here

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
                    colors: [
                      Colors.white.withOpacity(0.0),
                      Colors.white.withOpacity(0.9),
                    ],
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      TextStrings.newsNearby,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
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

  // New method to open the full map - FIXED syntax errors
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
