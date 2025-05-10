import 'package:flutter/material.dart';
import 'package:flutter_application_2/constants/theme_constants.dart';

class ThreadItem extends StatelessWidget {
  final String authorName;
  final String text;
  final String time;
  final int likes;
  final int replies;
  final bool isVerified;
  final String distance;
  final String? profilePic;

  const ThreadItem({
    super.key,
    required this.authorName,
    required this.text,
    required this.time,
    required this.likes,
    required this.replies,
    required this.isVerified,
    required this.distance,
    this.profilePic,
  });

  // Format distance string to use km/m instead of miles
  String _formatDistance(String distanceString) {
    // Check if the distance is in the format "X.X mi away"
    if (distanceString.contains("mi away")) {
      // Extract the numeric part
      final RegExp regex = RegExp(r'(\d+\.?\d*)');
      final match = regex.firstMatch(distanceString);
      if (match != null) {
        try {
          final double miles = double.parse(match.group(1)!);
          // Convert miles to meters (1 mile ≈ 1609.34 meters)
          final double meters = miles * 1609.34;

          if (meters < 1000) {
            // Less than 1km, show in meters
            return '${meters.toInt()} m';
          } else {
            // More than 1km, show in kilometers with one decimal place
            return '${(meters / 1000).toStringAsFixed(1)} km';
          }
        } catch (e) {
          // If parsing fails, just return "Nearby"
          return 'Nearby';
        }
      }
    }

    // For any other format or if parsing fails, return "Nearby" instead of the original
    return distanceString.isEmpty ? 'Nearby' : distanceString;
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Author info row
            Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundImage: profilePic != null && profilePic!.isNotEmpty
                      ? NetworkImage(profilePic!)
                      : null,
                  child: profilePic == null || profilePic!.isEmpty
                      ? const Icon(Icons.person, size: 16)
                      : null,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            authorName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          if (isVerified)
                            Padding(
                              padding: const EdgeInsets.only(left: 4),
                              child: Icon(Icons.verified,
                                  size: 14, color: ThemeConstants.primaryColor),
                            ),
                        ],
                      ),
                      Row(
                        children: [
                          Text(
                            time,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _formatDistance(distance),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            // Thread content
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12.0),
              child: Text(text),
            ),
            // Actions row
            Row(
              children: [
                // Like button
                Row(
                  children: [
                    Icon(
                      Icons.thumb_up_outlined,
                      size: 16,
                      color: Colors.grey[600],
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$likes',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 16),
                // Reply button
                Row(
                  children: [
                    Icon(
                      Icons.chat_bubble_outline,
                      size: 16,
                      color: Colors.grey[600],
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$replies',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                // Share button
                Icon(
                  Icons.share_outlined,
                  size: 16,
                  color: Colors.grey[600],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
