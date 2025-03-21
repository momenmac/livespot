import 'package:flutter/material.dart';
import 'package:flutter_application_2/constants/text_strings.dart';
import 'package:flutter_application_2/constants/theme_constants.dart';
import 'dart:math' as math;
import 'package:flutter_application_2/ui/pages/post_detail/post_detail_page.dart';

class NewsFeedSection extends StatelessWidget {
  final DateTime selectedDate;

  // Updated image URLs with reliable placeholders
  final List<String> _imageUrls = const [
    'https://picsum.photos/seed/news1/800/600',
    'https://picsum.photos/seed/news2/800/600',
    'https://picsum.photos/seed/news3/800/600',
    'https://picsum.photos/seed/news4/800/600',
    'https://picsum.photos/seed/news5/800/600',
  ];

  const NewsFeedSection({
    super.key,
    required this.selectedDate,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          ThemeConstants.primaryColor,
                          ThemeConstants.primaryColor.withOpacity(0.7),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.trending_up_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    TextStrings.happening,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
              TextButton(
                onPressed: () {
                  // View all news
                },
                style: TextButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
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
                      Icons.arrow_forward_rounded,
                      size: 16,
                      color: ThemeConstants.primaryColor,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Main feature story
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _buildFeatureStory(
            context, // Pass context here
            title: "Major Storm Approaching Eastern Coast",
            description:
                "Residents advised to prepare for high winds and flooding as category 3 hurricane approaches.",
            imageUrl: "https://example.com/storm.jpg",
            location: "Boston, MA",
            time: "2 hours ago",
            honesty: 92,
            upvotes: 345,
            comments: 78,
            isVerified: true,
          ),
        ),

        const SizedBox(height: 16),

        // Secondary stories in horizontal layout
        SizedBox(
          height: 280, // Increased from 270 to 280 to give more space
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(left: 16),
            children: [
              _buildSecondaryStory(
                context, // Pass context here
                title: "New Technology Center Opens Downtown",
                description:
                    "The innovation hub will create over 500 jobs and provide resources for tech startups.",
                imageUrl: "https://example.com/tech.jpg",
                location: "Austin, TX",
                time: "5 hours ago",
                honesty: 88,
                upvotes: 210,
                comments: 42,
                isVerified: false,
                color: ThemeConstants.green,
              ),
              _buildSecondaryStory(
                context, // Pass context here
                title: "Local Festival Draws Record Crowds",
                description:
                    "Annual cultural celebration sees highest attendance in its 15-year history.",
                imageUrl: "https://example.com/festival.jpg",
                location: "Portland, OR",
                time: "Yesterday",
                honesty: 95,
                upvotes: 432,
                comments: 63,
                isVerified: false,
                color: ThemeConstants.orange,
              ),
              _buildSecondaryStory(
                context, // Pass context here
                title: "City Council Approves New Housing Development",
                description:
                    "The project will include affordable housing units and community spaces.",
                imageUrl: "https://example.com/housing.jpg",
                location: "Denver, CO",
                time: "Yesterday",
                honesty: 90,
                upvotes: 187,
                comments: 35,
                isVerified: true,
                color: ThemeConstants.pink,
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _getRandomImageUrl() {
    final random = math.Random();
    return _imageUrls[random.nextInt(_imageUrls.length)];
  }

  Widget _buildFeatureStory(
    BuildContext context, // Add context parameter
    {
    required String title,
    required String description,
    required String imageUrl,
    required String location,
    required String time,
    required int honesty,
    required int upvotes,
    required int comments,
    required bool isVerified,
  }) {
    return InkWell(
      // Fix: Remove context parameter from onTap callback
      onTap: () => _navigateToPostDetail(context, title, description, imageUrl,
          location, time, honesty, upvotes, comments, isVerified),
      borderRadius: BorderRadius.circular(24),
      child: Container(
        height: 360,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 20,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            // Image background with gradient overlay
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: ThemeConstants.greyLight,
                ),
                child: Stack(
                  children: [
                    // Use a more reliable image loading method with error handling
                    Image.network(
                      _getRandomImageUrl(),
                      width: double.infinity,
                      height: double.infinity,
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
                              size: 100,
                              color: ThemeConstants.grey.withOpacity(0.3),
                            ),
                          ),
                        );
                      },
                    ),
                    // Gradient overlay
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withOpacity(0.1),
                              Colors.black.withOpacity(0.6),
                            ],
                            stops: const [0.6, 0.75, 1.0],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Content overlaid on image
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Verified badge if needed
                    if (isVerified)
                      Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: ThemeConstants.primaryColor,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.verified_rounded,
                              color: Colors.white,
                              size: 12,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              TextStrings.verified,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Title
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        shadows: [
                          Shadow(
                            color: Colors.black26,
                            blurRadius: 2,
                            offset: Offset(0, 1),
                          ),
                        ],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),

                    const SizedBox(height: 8),

                    // Description
                    Text(
                      description,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.white,
                        shadows: [
                          Shadow(
                            color: Colors.black26,
                            blurRadius: 2,
                            offset: Offset(0, 1),
                          ),
                        ],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),

                    const SizedBox(height: 16),

                    // Location, time, and rating row
                    Row(
                      children: [
                        Icon(Icons.location_on,
                            size: 14, color: Colors.white.withOpacity(0.9)),
                        const SizedBox(width: 4),
                        Text(
                          location,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withOpacity(0.9),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Icon(Icons.access_time,
                            size: 14, color: Colors.white.withOpacity(0.9)),
                        const SizedBox(width: 4),
                        Text(
                          time,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withOpacity(0.9),
                          ),
                        ),
                        const Spacer(),
                        _buildHonestyPill(honesty),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Action buttons - FIXED: not inside a Positioned widget
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildVoteButton(
                          icon: Icons.arrow_upward,
                          label: '$upvotes',
                          color: Colors.white,
                          isUpvote: true,
                        ),
                        _buildActionButton(
                          icon: Icons.forum_outlined,
                          label: '$comments',
                          color: Colors.white,
                        ),
                        _buildActionButton(
                          icon: Icons.share_outlined,
                          label: TextStrings.share,
                          color: Colors.white,
                        ),
                      ],
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

  Widget _buildSecondaryStory(
    BuildContext context, // Add context parameter
    {
    required String title,
    required String description,
    required String imageUrl,
    required String location,
    required String time,
    required int honesty,
    required int upvotes,
    required int comments,
    required bool isVerified,
    required Color color,
  }) {
    return InkWell(
      // Fix: Remove context parameter from onTap callback
      onTap: () => _navigateToPostDetail(context, title, description, imageUrl,
          location, time, honesty, upvotes, comments, isVerified),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 250,
        // Explicitly set height to match parent constraint
        height: 260,
        margin: const EdgeInsets.only(
            right: 16, bottom: 4), // Reduced bottom margin
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min, // Use minimum required vertical space
          children: [
            // Image with category indicator
            Stack(
              children: [
                // Improved image loading with error handling
                SizedBox(
                  height: 140,
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
                            Icons.image,
                            size: 50,
                            color: ThemeConstants.grey.withOpacity(0.3),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                Positioned(
                  top: 12,
                  left: 12,
                  child: Transform.rotate(
                    angle: -math.pi / 50, // Slight tilt
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(4),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        _getCategoryFromTitle(title),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
                if (isVerified)
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.verified_rounded,
                        color: ThemeConstants.primaryColor,
                        size: 14,
                      ),
                    ),
                  ),
              ],
            ),

            // Content
            Padding(
              padding: const EdgeInsets.all(12), // Reduced from 16 to 12
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      height: 1.2,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),

                  const SizedBox(height: 6), // Reduced from 8 to 6

                  // Location and time
                  Row(
                    children: [
                      Icon(Icons.location_on,
                          size: 12, color: ThemeConstants.grey),
                      const SizedBox(width: 2),
                      Text(
                        location,
                        style: TextStyle(
                          fontSize: 10,
                          color: ThemeConstants.grey,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(Icons.access_time,
                          size: 12, color: ThemeConstants.grey),
                      const SizedBox(width: 2),
                      Text(
                        time,
                        style: TextStyle(
                          fontSize: 10,
                          color: ThemeConstants.grey,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 3), // Reduced from 4 to 3

                  // Honesty rating
                  _buildHonestyPill(honesty, isSmall: true),

                  const SizedBox(height: 3), // Reduced from 4 to 3

                  // Stats row
                  Row(
                    children: [
                      _buildStatisticPill(
                        icon: Icons.arrow_upward,
                        count: upvotes,
                        isUpvote: true,
                      ),
                      const SizedBox(width: 8),
                      _buildStatisticPill(
                        icon: Icons.forum_outlined,
                        count: comments,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHonestyPill(int rating, {bool isSmall = false}) {
    Color color;
    if (rating >= 80)
      color = ThemeConstants.green;
    else if (rating >= 60)
      color = ThemeConstants.orange;
    else
      color = ThemeConstants.red;

    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: isSmall ? 6 : 8, vertical: isSmall ? 2 : 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color,
            color.withOpacity(0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.verified_user_rounded,
            size: isSmall ? 10 : 12,
            color: Colors.white,
          ),
          const SizedBox(width: 3),
          Text(
            '$rating%',
            style: TextStyle(
              fontSize: isSmall ? 9 : 11,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatisticPill({
    required IconData icon,
    required int count,
    bool isUpvote = false,
  }) {
    return GestureDetector(
      onTap: isUpvote
          ? () {
              // Handle upvote action
            }
          : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: ThemeConstants.greyLight,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 12,
              color: ThemeConstants.grey,
            ),
            const SizedBox(width: 4),
            Text(
              count.toString(),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: ThemeConstants.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVoteButton({
    required IconData icon,
    required String label,
    required Color color,
    bool isUpvote = false,
  }) {
    return GestureDetector(
      onTap: () {
        // Handle upvote/downvote action
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 18,
            color: color,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 18,
          color: color,
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: color,
          ),
        ),
      ],
    );
  }

  // Helper to navigate to post detail page
  void _navigateToPostDetail(
    BuildContext context,
    String title,
    String description,
    String imageUrl,
    String location,
    String time,
    int honesty,
    int upvotes,
    int comments,
    bool isVerified,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PostDetailPage(
          title: title,
          description: description,
          imageUrl: imageUrl,
          location: location,
          time: time,
          honesty: honesty,
          upvotes: upvotes,
          comments: comments,
          isVerified: isVerified,
        ),
      ),
    );
  }

  // Helper to get a category from the title
  String _getCategoryFromTitle(String title) {
    if (title.contains("Storm") || title.contains("Weather"))
      return TextStrings.weather;
    if (title.contains("Tech")) return TextStrings.technology;
    if (title.contains("Festival") || title.contains("Concert"))
      return TextStrings.entertainment;
    if (title.contains("Council") || title.contains("Mayor"))
      return TextStrings.politics;
    if (title.contains("Arrest") || title.contains("Police"))
      return TextStrings.crime;
    return TextStrings.localNews;
  }
}
