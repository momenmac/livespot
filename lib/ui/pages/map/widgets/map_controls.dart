import 'package:flutter/material.dart';
import 'package:flutter_application_2/constants/theme_constants.dart';
import 'package:flutter_application_2/ui/pages/map/map_controller.dart';
import 'package:flutter_application_2/ui/theme/floating_action_button_theme.dart';

class MapControls extends StatelessWidget {
  final MapPageController controller;
  final bool isDarkMode;

  const MapControls({
    super.key,
    required this.controller,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return Column(
          children: [
            _buildControlButton(
              context: context,
              icon: controller.showMarkersAndRoute
                  ? Icons.visibility
                  : Icons.visibility_off,
              heroTag: 'visibility_button',
              onPressed: controller.toggleMarkersAndRoute,
            ),
            const SizedBox(height: 10),
            _buildControlButton(
              context: context,
              icon: Icons.add,
              heroTag: 'zoom_in_button',
              onPressed: controller.zoomIn,
            ),
            const SizedBox(height: 10),
            _buildControlButton(
              context: context,
              icon: Icons.remove,
              heroTag: 'zoom_out_button',
              onPressed: controller.zoomOut,
            ),
          ],
        );
      },
    );
  }

  Widget _buildControlButton({
    required BuildContext context,
    required IconData icon,
    required String heroTag,
    required VoidCallback onPressed,
  }) {
    return Theme(
      data: Theme.of(context).copyWith(
        floatingActionButtonTheme: FloatingActionButtonTheme.zoomButtonTheme,
      ),
      child: SizedBox(
        width: 40,
        height: 40,
        child: FloatingActionButton(
          heroTag: heroTag,
          backgroundColor: isDarkMode
              ? ThemeConstants.darkCardColor
              : ThemeConstants.lightBackgroundColor,
          onPressed: onPressed,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 20,
            color: !isDarkMode
                ? ThemeConstants.darkCardColor
                : ThemeConstants.lightBackgroundColor,
          ),
        ),
      ),
    );
  }
}
