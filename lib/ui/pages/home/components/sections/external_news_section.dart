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
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    // TODO: Implement proper dark mode theming for this section

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
                    style: theme.textTheme.titleMedium?.copyWith(
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

        // Horizontal scrolling news cards
        SizedBox(
          height: 200,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              _buildExternalNewsCard(
                context,
                "Global Markets Report: Tech Stocks Surge",
                "Major tech companies see significant gains amid positive quarterly earnings reports.",
                "Financial Times",
                "3 hours ago",
                _getRandomImageUrl(),
                ThemeConstants.primaryColor,
              ),
              _buildExternalNewsCard(
                context,
                "New Health Study Reveals Benefits of Mediterranean Diet",
                "Research shows significant health improvements for participants following the diet for six months.",
                "Health Journal",
                "5 hours ago",
                _getRandomImageUrl(),
                ThemeConstants.green,
              ),
              _buildExternalNewsCard(
                context,
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
    BuildContext context,
    String title,
    String description,
    String source,
    String time,
    String imageUrl,
    Color accentColor,
  ) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    // Card background color based on theme
    final cardBackgroundColor = isDarkMode ? theme.cardColor : Colors.white;

    // Shadow color based on theme
    final shadowColor = isDarkMode
        ? Colors.black.withOpacity(0.15)
        : Colors.black.withOpacity(0.08);

    // Text colors based on theme
    final titleTextColor = isDarkMode
        ? theme.textTheme.bodyLarge?.color
        : null; // Use default for light mode

    final descriptionTextColor = isDarkMode
        ? theme.textTheme.bodyMedium?.color
        : ThemeConstants.black.withOpacity(0.8);

    final secondaryTextColor =
        isDarkMode ? theme.textTheme.bodySmall?.color : ThemeConstants.grey;

    return Container(
      width: 280,
      margin: const EdgeInsets.only(right: 16, bottom: 0),
      decoration: BoxDecoration(
        color: cardBackgroundColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: shadowColor,
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
                height: 105,
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
                      color: isDarkMode
                          ? theme.canvasColor
                          : ThemeConstants.greyLight,
                      child: Center(
                        child: Icon(
                          Icons.image,
                          size: 48,
                          color: isDarkMode
                              ? theme.disabledColor
                              : ThemeConstants.grey.withOpacity(0.5),
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
            padding: const EdgeInsets.all(6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    height: 1.1,
                    color: titleTextColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),

                const SizedBox(height: 2),

                // Description
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.2,
                    color: descriptionTextColor,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),

                const SizedBox(height: 3),

                // Time info and read more button
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Time
                    Row(
                      children: [
                        Icon(
                          Icons.access_time,
                          size: 14,
                          color: secondaryTextColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          time,
                          style: TextStyle(
                            fontSize: 12,
                            color: secondaryTextColor,
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
