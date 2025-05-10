import 'package:flutter_application_2/constants/category_utils.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

class CustomEventMarker extends StatelessWidget {
  final LatLng location;
  final String eventType;
  final bool selected;
  final VoidCallback onTap;

  const CustomEventMarker({
    super.key,
    required this.location,
    required this.eventType,
    this.selected = false,
    required this.onTap,
  });

  // Factory constructor to create a marker for a specific event type
  factory CustomEventMarker.forEvent({
    required LatLng location,
    required String eventType,
    bool selected = false,
    required VoidCallback onTap,
  }) {
    return CustomEventMarker(
      location: location,
      eventType: eventType.toLowerCase(),
      selected: selected,
      onTap: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Using the correct method name buildCategoryMapMarker instead of buildMapMarker
    return GestureDetector(
      onTap: onTap,
      child: CategoryUtils.buildCategoryMapMarker(
        eventType,
        isSelected: selected,
        label: null, // You can add a label if needed
      ),
    );
  }
}
