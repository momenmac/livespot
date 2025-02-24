import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

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
    this.iconSize = 40,
    this.circleSize = 50,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        final timeAgo = DateTime.now().difference(timestamp);
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Marker Info'),
            content: Text(
              'Description: $description\n'
              'Created: ${timeAgo.inMinutes} minutes ago',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      },
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (withCircle)
            Container(
              width: circleSize,
              height: circleSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                // ignore: deprecated_member_use
                color: Colors.blue.withOpacity(0.5),
              ),
            ),
          Icon(
            icon,
            color: Colors.red,
            size: iconSize,
          ),
        ],
      ),
    );
  }
}
