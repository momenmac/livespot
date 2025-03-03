import 'package:flutter/material.dart';
import 'package:flutter_application_2/constants/theme_constants.dart';
import 'package:latlong2/latlong.dart';
import 'package:intl/intl.dart';

class CustomMarker extends StatelessWidget {
  final LatLng location;
  final IconData icon;
  final String description;
  final DateTime timestamp;
  final bool withCircle;
  final double iconSize;
  final double circleSize;

  const CustomMarker({
    super.key,
    required this.location,
    required this.icon,
    required this.description,
    required this.timestamp,
    this.withCircle = false,
    this.iconSize = 24,
    this.circleSize = 40,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        _showMarkerInfo(context);
      },
      child: withCircle
          ? Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: circleSize,
                  height: circleSize,
                  decoration: BoxDecoration(
                    color: ThemeConstants.primaryColor,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 6,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Icon(
                    icon,
                    color: Colors.white,
                    size: iconSize,
                  ),
                ),
              ],
            )
          : Icon(
              icon,
              color: ThemeConstants.primaryColor,
              size: iconSize,
            ),
    );
  }

  void _showMarkerInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(description),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Coordinates: ${location.latitude.toStringAsFixed(6)}, ${location.longitude.toStringAsFixed(6)}',
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 8),
            Text(
              'Timestamp: ${DateFormat('yyyy-MM-dd HH:mm').format(timestamp)}',
              style: const TextStyle(fontSize: 14),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
