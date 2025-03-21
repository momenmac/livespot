import 'package:flutter/material.dart';
import 'package:flutter_application_2/constants/text_strings.dart';
import 'package:flutter_application_2/constants/theme_constants.dart';
import 'dart:math' as math;

class ExternalNewsSection extends StatelessWidget {
  final DateTime selectedDate;

  const ExternalNewsSection({
    super.key,
    required this.selectedDate,
  });

  // Sample image URLs for external news
  final List<String> _newsImageUrls = const [
    'https://picsum.photos/seed/news1/800/450',
    'https://picsum.photos/seed/news2/800/450',
    'https://picsum.photos/seed/news3/800/450',
    'https://picsum.photos/seed/news4/800/450',
    'https://picsum.photos/seed/news5/800/450',
  ];

  String _getRandomImageUrl() {
    final random = math.Random();
    return _newsImageUrls[random.nextInt(_newsImageUrls.length)];
  }

  @override
  Widget build(BuildContext context) {
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
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: ThemeConstants.primaryColorLight,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.public,
                      size: 16,
                      color: ThemeConstants.primaryColor,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    TextStrings.externalNews,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              TextButton(
                onPressed: () {
                  // View all external news
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

        // Horizontal scrolling news cards - FIXED: further reduced height
        SizedBox(
          height: 200, // Further reduced from 215px to 200px
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              _buildExternalNewsCard(
                "Global Markets Report: Tech Stocks Surge",
                "Major tech companies see significant gains amid positive quarterly earnings reports.",
                "Financial Times",
                "3 hours ago",
                _getRandomImageUrl(),
                ThemeConstants.primaryColor,
              ),
              _buildExternalNewsCard(
                "New Health Study Reveals Benefits of Mediterranean Diet",
                "Research shows significant health improvements for participants following the diet for six months.",
                "Health Journal",
                "5 hours ago",
                _getRandomImageUrl(),
                ThemeConstants.green,
              ),
              _buildExternalNewsCard(
                "Climate Summit Announces New Global Initiatives",
                "World leaders agree on ambitious carbon reduction targets at international conference.",
                "Reuters",
                "Yesterday",
                _getRandomImageUrl(),
                ThemeConstants.orange,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildExternalNewsCard(
    String title,
    String description,
    String source,
    String time,
    String imageUrl,
    Color accentColor,
  ) {
    return Container(
      width: 280,
      margin: const EdgeInsets.only(
          right: 16, bottom: 0), // Eliminated bottom margin completely
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Image section with reduced height
          Stack(
            children: [
              SizedBox(
                height: 105, // Further reduced from 115px to 105px
                width: double.infinity,
                child: Image.network(
                  imageUrl,
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
                          Icons.image,
                          size: 48,
                          color: ThemeConstants.grey.withOpacity(0.5),
                        ),
                      ),
                    );
                  },
                ),
              ),

              // Source badge
              Positioned(
                top: 12,
                left: 12,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: accentColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    source,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),

          // Content with further reduced padding
          Padding(
            padding: const EdgeInsets.all(6), // Further reduced from 8px to 6px
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14, // Reduced from 15px to 14px
                    height: 1.1, // Added tight line height
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),

                const SizedBox(height: 2), // Reduced from 4px to 2px

                // Description
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12, // Reduced from 13px to 12px
                    height: 1.2, // Added tight line height
                    color: ThemeConstants.black.withOpacity(0.8),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),

                const SizedBox(height: 3), // Reduced from 5px to 3px

                // Time info and read more button - same as before
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Time
                    Row(
                      children: [
                        Icon(
                          Icons.access_time,
                          size: 14,
                          color: ThemeConstants.grey,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          time,
                          style: TextStyle(
                            fontSize: 12,
                            color: ThemeConstants.grey,
                          ),
                        ),
                      ],
                    ),

                    // Read more button
                    TextButton(
                      onPressed: () {},
                      style: TextButton.styleFrom(
                        foregroundColor: accentColor,
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(60, 24),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Row(
                        children: [
                          Text(
                            TextStrings.readMore,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 2),
                          Icon(
                            Icons.arrow_forward,
                            size: 12,
                          ),
                        ],
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
