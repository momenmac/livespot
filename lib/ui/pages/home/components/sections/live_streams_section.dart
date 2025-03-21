import 'package:flutter/material.dart';
import 'package:flutter_application_2/constants/text_strings.dart';
import 'package:flutter_application_2/constants/theme_constants.dart';
import 'dart:math' as math;

class LiveStreamsSection extends StatelessWidget {
  const LiveStreamsSection({super.key});

  // Random image URLs for live streams
  final List<String> _liveImageUrls = const [
    'https://picsum.photos/seed/live1/800/600',
    'https://picsum.photos/seed/live2/800/600',
    'https://picsum.photos/seed/live3/800/600',
    'https://picsum.photos/seed/live4/800/600',
    'https://picsum.photos/seed/live5/800/600',
  ];

  @override
  Widget build(BuildContext context) {
    // Check if there are any live streams - for now, we'll assume there are
    final hasLiveStreams = true;

    if (!hasLiveStreams) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: ThemeConstants.red,
                    ),
                    child: const Icon(
                      Icons.fiber_manual_record,
                      color: Colors.white,
                      size: 12,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    TextStrings.liveStreams,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              TextButton(
                onPressed: () {
                  // View all live streams
                },
                child: Row(
                  children: [
                    Text(
                      TextStrings.viewAll,
                      style: TextStyle(
                        color: ThemeConstants.primaryColor,
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
        SizedBox(
          height: 250, // Increased height to fully accommodate content
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            children: [
              _buildLiveStreamCard(
                "Breaking: Protest Downtown",
                "Reporter on the scene",
                _getRandomImageUrl(),
                "Central Square",
                1243,
              ),
              _buildLiveStreamCard(
                "City Council Meeting",
                "Live coverage of today's session",
                _getRandomImageUrl(),
                "City Hall",
                578,
              ),
              _buildLiveStreamCard(
                "Traffic Update: Major Accident",
                "Live from the highway",
                _getRandomImageUrl(),
                "Highway 101",
                892,
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _getRandomImageUrl() {
    final random = math.Random();
    return _liveImageUrls[random.nextInt(_liveImageUrls.length)];
  }

  Widget _buildLiveStreamCard(
    String title,
    String description,
    String imageUrl,
    String location,
    int viewerCount,
  ) {
    return Container(
      width: 280,
      height: 200, // Reduced height to avoid overflow
      margin: const EdgeInsets.symmetric(
          horizontal: 8, vertical: 2), // Reduced vertical margin
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Thumbnail with LIVE indicator
          Stack(
            children: [
              ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(16)),
                child: SizedBox(
                  height: 130, // Reduced height
                  width: double.infinity,
                  child: Image.network(
                    _getRandomImageUrl(),
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Center(
                        child: CircularProgressIndicator(
                          value: loadingProgress.expectedTotalBytes != null
                              ? loadingProgress.cumulativeBytesLoaded /
                                  loadingProgress.expectedTotalBytes!
                              : null,
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: ThemeConstants.greyLight,
                        child: Center(
                          child: Icon(
                            Icons.videocam,
                            size: 48,
                            color: ThemeConstants.grey,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              Positioned(
                top: 8,
                left: 8,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: ThemeConstants.red,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.fiber_manual_record,
                        color: Colors.white,
                        size: 12,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'LIVE',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                bottom: 8,
                right: 8,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.visibility,
                        color: Colors.white,
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '$viewerCount ${TextStrings.watching}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // Content
          Padding(
            padding: const EdgeInsets.all(8), // Reduced padding
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min, // Use minimum space needed
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14, // Reduced font size
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2), // Smaller gap
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12,
                    color: ThemeConstants.grey,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4), // Smaller gap
                Row(
                  mainAxisAlignment: MainAxisAlignment
                      .spaceBetween, // FIXED: Use proper MainAxisAlignment
                  mainAxisSize:
                      MainAxisSize.max, // Use max to fill container width
                  children: [
                    // Fixed: Replace the Row + Flexible with a simple Row that has bounded width
                    SizedBox(
                      width: 140, // Fixed width for location section
                      child: Row(
                        mainAxisSize:
                            MainAxisSize.min, // Use minimum required width
                        children: [
                          Icon(Icons.location_on,
                              size: 14, color: ThemeConstants.grey),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              location,
                              style: TextStyle(
                                fontSize: 12,
                                color: ThemeConstants.grey,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () {},
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ThemeConstants.primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4),
                        minimumSize: const Size(60, 24),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        TextStrings.joinStream,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
