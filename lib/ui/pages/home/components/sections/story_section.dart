import 'package:flutter/material.dart';
import 'package:flutter_application_2/constants/theme_constants.dart';
import 'package:flutter_application_2/constants/text_strings.dart';
import 'package:flutter_application_2/ui/pages/home/components/post_detail/post_detail_page.dart';
import 'package:flutter_application_2/ui/pages/home/components/story/story_viewer_page.dart';
import 'package:flutter_application_2/ui/pages/home/components/story/all_updates_page.dart';
import 'dart:math' as math;

class StorySection extends StatelessWidget {
  const StorySection({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recent Updates',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              TextButton(
                onPressed: () {
                  // Navigate to view all updates page
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AllUpdatesPage(),
                    ),
                  );
                },
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(50, 30),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Row(
                  children: [
                    Text(
                      'View all',
                      style: TextStyle(
                        color: ThemeConstants.primaryColor,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.arrow_forward_ios,
                      size: 12,
                      color: ThemeConstants.primaryColor,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Story list
        SizedBox(
          height: 110,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              // Add story button
              _buildAddStoryItem(),
              // User stories
              _buildStoryItem(
                username: 'Emily J.',
                imageUrl: 'https://picsum.photos/seed/user1/100/100',
                hasMultipleStories: true,
                storiesCount: 3,
                isLive: true,
                storyData: _mockStoryDataByUser['Emily J.']?.first ?? {},
                context: context,
              ),
              _buildStoryItem(
                username: 'Michael',
                imageUrl: 'https://picsum.photos/seed/user2/100/100',
                hasMultipleStories: true,
                storiesCount: 2,
                isLive: false,
                storyData: _mockStoryDataByUser['Michael']?.first ?? {},
                context: context,
              ),
              _buildStoryItem(
                username: 'Sarah',
                imageUrl: 'https://picsum.photos/seed/user3/100/100',
                hasMultipleStories: false,
                storiesCount: 1,
                isLive: false,
                storyData: _mockStoryDataByUser['Sarah']?.first ?? {},
                context: context,
              ),
              _buildStoryItem(
                username: 'David',
                imageUrl: 'https://picsum.photos/seed/user4/100/100',
                hasMultipleStories: true,
                storiesCount: 4,
                isLive: true,
                storyData: _mockStoryDataByUser['David']?.first ?? {},
                context: context,
              ),
              _buildStoryItem(
                username: 'Alex',
                imageUrl: 'https://picsum.photos/seed/user5/100/100',
                hasMultipleStories: false,
                storiesCount: 1,
                isLive: false,
                storyData: _mockStoryDataByUser['Alex']?.first ?? {},
                context: context,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAddStoryItem() {
    return Container(
      margin: const EdgeInsets.only(right: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              color: ThemeConstants.greyLight,
              shape: BoxShape.circle,
            ),
            child: Stack(
              children: [
                Center(
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: ThemeConstants.greyLight,
                        width: 2,
                      ),
                    ),
                    child: Icon(
                      Icons.add,
                      size: 30,
                      color: ThemeConstants.grey,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Add Story',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildStoryItem({
    required String username,
    required String imageUrl,
    required bool hasMultipleStories,
    required int storiesCount,
    required bool isLive,
    required Map<String, dynamic> storyData,
    required BuildContext context,
  }) {
    // Find all stories for this user
    final List<Map<String, dynamic>> userStories =
        _mockStoryDataByUser[username] ?? [];

    return GestureDetector(
      onTap: () {
        _navigateToStoryViewer(
          context,
          userStories,
          username,
          imageUrl,
          isLive,
        );
      },
      child: Container(
        margin: const EdgeInsets.only(right: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 68,
              height: 68,
              child: Stack(
                children: [
                  // Segmented circle for multiple stories
                  if (hasMultipleStories) _buildSegmentedCircle(storiesCount),
                  // Single circle for one story
                  if (!hasMultipleStories)
                    Container(
                      width: 68,
                      height: 68,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            ThemeConstants.primaryColor,
                            ThemeConstants.primaryColor.withOpacity(0.7),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                      ),
                    ),
                  // Profile image
                  Center(
                    child: Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: ClipOval(
                        child: Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Icon(
                            Icons.person,
                            size: 36,
                            color: ThemeConstants.grey.withOpacity(0.7),
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Live indicator
                  if (isLive)
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                        child: const Text(
                          'LIVE',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Text(
              username,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isLive ? FontWeight.bold : FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSegmentedCircle(int segments) {
    return SizedBox(
      width: 68,
      height: 68,
      child: CustomPaint(
        painter: SegmentedCirclePainter(
          segments: segments,
          colors: [
            ThemeConstants.primaryColor,
            ThemeConstants.primaryColor.withOpacity(0.7),
          ],
        ),
      ),
    );
  }

  // Mock data for stories by user
  static final Map<String, List<Map<String, dynamic>>> _mockStoryDataByUser = {
    'Emily J.': [
      {
        'title': 'Flash Flooding on Main Street',
        'description':
            'Heavy rain has caused significant flooding downtown. Several roads are now closed.',
        'imageUrl': 'https://picsum.photos/seed/story1/800/600',
        'location': 'Main St, Boston, MA',
        'time': '15 minutes ago',
        'honesty': 95,
        'upvotes': 78,
        'comments': 12,
        'isVerified': true,
      },
      {
        'title': 'Traffic Backed Up on Highway 95',
        'description':
            'Expect delays of up to 30 minutes due to construction and flooding.',
        'imageUrl': 'https://picsum.photos/seed/story1b/800/600',
        'location': 'Highway 95, Boston, MA',
        'time': '25 minutes ago',
        'honesty': 90,
        'upvotes': 45,
        'comments': 8,
        'isVerified': true,
      },
      {
        'title': 'Emergency Shelters Opening',
        'description':
            'City officials are opening emergency shelters at local schools for those affected by flooding.',
        'imageUrl': 'https://picsum.photos/seed/story1c/800/600',
        'location': 'City Hall, Boston, MA',
        'time': '40 minutes ago',
        'honesty': 98,
        'upvotes': 112,
        'comments': 24,
        'isVerified': true,
      },
    ],
    'Michael': [
      {
        'title': 'New Tech Conference Announced',
        'description':
            'The annual tech summit will be held downtown next month featuring speakers from major companies.',
        'imageUrl': 'https://picsum.photos/seed/story2/800/600',
        'location': 'Convention Center, Austin, TX',
        'time': '1 hour ago',
        'honesty': 88,
        'upvotes': 45,
        'comments': 8,
        'isVerified': true,
      },
      {
        'title': 'Tech Startup Workshop',
        'description':
            'Join our free workshop on funding opportunities for tech startups this weekend.',
        'imageUrl': 'https://picsum.photos/seed/story2b/800/600',
        'location': 'Innovation Hub, Austin, TX',
        'time': '2 hours ago',
        'honesty': 92,
        'upvotes': 38,
        'comments': 6,
        'isVerified': true,
      },
    ],
    'Sarah': [
      {
        'title': 'Local Restaurant Grand Opening',
        'description':
            'Chef Mario\'s new Italian bistro opens this weekend with special promotions.',
        'imageUrl': 'https://picsum.photos/seed/story3/800/600',
        'location': 'Oak St, Portland, OR',
        'time': '3 hours ago',
        'honesty': 85,
        'upvotes': 32,
        'comments': 5,
        'isVerified': false,
      },
    ],
    'David': [
      {
        'title': 'Traffic Accident on Highway 101',
        'description':
            'Multi-car collision causing major delays. Police and emergency services on scene.',
        'imageUrl': 'https://picsum.photos/seed/story4/800/600',
        'location': 'Highway 101, San Francisco, CA',
        'time': '30 minutes ago',
        'honesty': 97,
        'upvotes': 112,
        'comments': 28,
        'isVerified': true,
      },
      {
        'title': 'Alternate Routes Available',
        'description':
            'Police recommend using these alternate routes to avoid the accident on Highway 101.',
        'imageUrl': 'https://picsum.photos/seed/story4b/800/600',
        'location': 'San Francisco, CA',
        'time': '45 minutes ago',
        'honesty': 96,
        'upvotes': 87,
        'comments': 15,
        'isVerified': true,
      },
      {
        'title': 'Accident Cleared',
        'description':
            'The accident on Highway 101 has been cleared. Traffic is still heavy but moving.',
        'imageUrl': 'https://picsum.photos/seed/story4c/800/600',
        'location': 'Highway 101, San Francisco, CA',
        'time': '1 hour ago',
        'honesty': 98,
        'upvotes': 65,
        'comments': 10,
        'isVerified': true,
      },
      {
        'title': 'Traffic Update',
        'description':
            'Traffic flow has returned to normal on Highway 101 following earlier accident.',
        'imageUrl': 'https://picsum.photos/seed/story4d/800/600',
        'location': 'Highway 101, San Francisco, CA',
        'time': '2 hours ago',
        'honesty': 95,
        'upvotes': 42,
        'comments': 7,
        'isVerified': true,
      },
    ],
    'Alex': [
      {
        'title': 'Community Cleanup Event',
        'description':
            'Volunteers needed this Saturday for beach cleanup. Equipment will be provided.',
        'imageUrl': 'https://picsum.photos/seed/story5/800/600',
        'location': 'Sunset Beach, Miami, FL',
        'time': '4 hours ago',
        'honesty': 91,
        'upvotes': 64,
        'comments': 7,
        'isVerified': false,
      },
    ],
  };

  // Keep compatibility with existing code
  static List<Map<String, dynamic>> get _mockStoryData {
    List<Map<String, dynamic>> allStories = [];
    _mockStoryDataByUser.forEach((user, stories) {
      allStories.addAll(stories);
    });
    return allStories;
  }

  // Make the mock data accessible to other classes
  static Map<String, List<Map<String, dynamic>>> getUserStories() {
    return _mockStoryDataByUser;
  }

  void _navigateToStory(BuildContext context, Map<String, dynamic> storyData) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PostDetailPage(
          title: storyData['title'],
          description: storyData['description'],
          imageUrl: storyData['imageUrl'],
          location: storyData['location'],
          time: storyData['time'],
          honesty: storyData['honesty'],
          upvotes: storyData['upvotes'],
          comments: storyData['comments'],
          isVerified: storyData['isVerified'],
        ),
      ),
    );
  }

  // New method to navigate to StoryViewer for multiple stories
  void _navigateToStoryViewer(
    BuildContext context,
    List<Map<String, dynamic>> stories,
    String username,
    String userImageUrl,
    bool isVerified,
  ) {
    if (stories.isEmpty) return;

    // Use the new StoryViewerPage for all stories
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => StoryViewerPage(
          stories: stories,
          username: username,
          userImageUrl: userImageUrl,
          isUserVerified: isVerified,
        ),
      ),
    );
  }
}

// Custom painter for segmented circle (like Telegram stories)
class SegmentedCirclePainter extends CustomPainter {
  final int segments;
  final List<Color> colors;
  final double strokeWidth;
  final double gapWidth;

  SegmentedCirclePainter({
    required this.segments,
    required this.colors,
    this.strokeWidth = 4.0,
    this.gapWidth = 4.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Rect rect = Offset.zero & size;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(center.dx, center.dy) - strokeWidth / 2;

    // Fix: Simplify the logic for drawing segments
    if (segments <= 1) {
      // Just draw a complete circle if only one segment
      final Paint paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..shader = LinearGradient(
          colors: colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(rect);

      canvas.drawCircle(center, radius, paint);
      return;
    }

    // For multiple segments
    final double segmentAngle = 2 * math.pi / segments;
    final double gapAngle = 0.05; // Fixed small gap between segments

    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..shader = LinearGradient(
        colors: colors,
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(rect);

    for (int i = 0; i < segments; i++) {
      final double startAngle = i * segmentAngle - math.pi / 2;
      final double sweepAngle = segmentAngle - gapAngle;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}
