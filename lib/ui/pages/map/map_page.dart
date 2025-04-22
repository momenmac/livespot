import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart'; // Import SchedulerBinding
import 'package:flutter_application_2/constants/text_strings.dart';
import 'package:flutter_application_2/constants/theme_constants.dart';
import 'package:flutter_application_2/ui/pages/map/map_controller.dart';
import 'package:flutter_application_2/ui/pages/map/widgets/map_search_bar.dart';
import 'package:flutter_application_2/ui/pages/map/widgets/map_controls.dart';
import 'package:flutter_application_2/ui/pages/map/widgets/map_view.dart';
import 'package:flutter_application_2/ui/pages/map/widgets/map_date_picker.dart';
import 'package:flutter_application_2/ui/pages/map/widgets/map_categories.dart';

class MapPage extends StatefulWidget {
  final VoidCallback? onBackPress;
  final bool showBackButton;

  const MapPage({
    super.key,
    this.onBackPress,
    this.showBackButton = true,
  });

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  late final MapPageController _controller;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller = MapPageController();
    // Delay initialization to ensure context is available
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _controller.setContext(context);
    });
    // Defer map initialization until after the first frame is rendered
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _controller.initializeLocation();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final isLargeScreen = MediaQuery.of(context).size.width > 900;

    return GestureDetector(
      onTap: () {
        // Hide keyboard when tapping anywhere on the screen
        FocusScope.of(context).unfocus();
      },
      child: Scaffold(
        appBar: widget.showBackButton && !isLargeScreen
            ? AppBar(
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () {
                    // First hide keyboard when back button is pressed
                    FocusScope.of(context).unfocus();

                    // Then perform navigation
                    if (widget.onBackPress != null) {
                      widget.onBackPress!();
                    } else {
                      Navigator.of(context).pop();
                    }
                  },
                ),
                title: Text(TextStrings.map,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                actions: [
                  Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: MapDatePicker(
                      selectedDate: _controller.selectedDate,
                      onDateChanged: _controller.handleDateChanged,
                    ),
                  ),
                ],
              )
            : null,
        body: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            return Stack(
              children: [
                // Map view
                MapView(
                  controller: _controller,
                  onTap: () {
                    // Dismiss keyboard when map is tapped
                    FocusScope.of(context).unfocus();
                  },
                ),

                // Categories
                Positioned(
                  top: 70,
                  left: 0,
                  right: 0,
                  child: MapCategories(
                    onCategorySelected: _controller.handleCategorySelected,
                  ),
                ),

                // Search bar
                Positioned(
                  top: 10,
                  left: 10,
                  right: 10,
                  child: MapSearchBar(
                    controller: _controller,
                    focusNode: _focusNode,
                  ),
                ),

                // Left side controls
                Positioned(
                  bottom: MediaQuery.of(context).padding.bottom + 20,
                  left: 10,
                  child: MapControls(
                    controller: _controller,
                    isDarkMode: isDarkMode,
                  ),
                ),

                // Date picker for large screens
                if (!widget.showBackButton || isLargeScreen)
                  Positioned(
                    left: 60,
                    bottom: 20,
                    child: Container(
                      decoration: BoxDecoration(
                        color: isDarkMode
                            ? ThemeConstants.darkCardColor
                            : ThemeConstants.lightBackgroundColor,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: MapDatePicker(
                        selectedDate: _controller.selectedDate,
                        onDateChanged: _controller.handleDateChanged,
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
        floatingActionButton: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            return Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                FloatingActionButton(
                  heroTag: 'location_button',
                  elevation: 0,
                  onPressed: _controller.centerOnUserLocation,
                  child: const Icon(
                    Icons.my_location,
                    size: 30,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 10),
                FloatingActionButton(
                  heroTag: 'route_button',
                  elevation: 0,
                  onPressed: _controller.toggleRoute,
                  backgroundColor: _controller.showRoute
                      ? ThemeConstants.primaryColor
                      : null,
                  child: const Icon(
                    Icons.route,
                    size: 30,
                    color: Colors.white,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
