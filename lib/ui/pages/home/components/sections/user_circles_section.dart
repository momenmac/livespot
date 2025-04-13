import 'package:flutter/material.dart';
import 'package:flutter_application_2/constants/theme_constants.dart';
import 'package:flutter_application_2/ui/pages/home/components/post_detail/post_detail_page.dart';
import 'dart:math' as math;

class UserCirclesSection extends StatefulWidget {
  // Callback function for toggling map view
  final VoidCallback? onMapToggle;

  const UserCirclesSection({super.key, this.onMapToggle});

  @override
  State<UserCirclesSection> createState() => _UserCirclesSectionState();
}

class _UserCirclesSectionState extends State<UserCirclesSection> {
  // Sample user data with multiple posts per user
  final List<Map<String, dynamic>> _users = [
    {
      'id': '1',
      'name': 'Sarah',
      'profileImage': 'https://picsum.photos/seed/user1/100/100',
      'hasUpdate': true,
      'location': 'Boston, MA',
      'posts': [
        {
          'title': 'Storm Update 1',
          'description':
              'Wind speeds increasing rapidly, waves starting to rise at the harbor.',
          'imageUrl': 'https://picsum.photos/seed/news11/800/600',
          'time': '10 min ago',
          'honesty': 94,
          'upvotes': 57,
          'comments': 12,
          'isVerified': true,
        },
        {
          'title': 'Storm Update 2',
          'description':
              'Evacuations beginning in coastal areas, emergency services on standby.',
          'imageUrl': 'https://picsum.photos/seed/news12/800/600',
          'time': '7 min ago',
          'honesty': 96,
          'upvotes': 82,
          'comments': 18,
          'isVerified': true,
        },
        {
          'title': 'Storm Update 3',
          'description':
              'Power outages reported in eastern neighborhoods. Backup generators activated.',
          'imageUrl': 'https://picsum.photos/seed/news13/800/600',
          'time': '3 min ago',
          'honesty': 92,
          'upvotes': 41,
          'comments': 9,
          'isVerified': true,
        }
      ]
    },
    {
      'id': '2',
      'name': 'Mike',
      'profileImage': 'https://picsum.photos/seed/user2/100/100',
      'hasUpdate': true,
      'location': 'Chicago, IL',
      'posts': [
        {
          'title': 'Festival Preparations',
          'description':
              'Setting up for tomorrow\'s big event. Perfect weather forecasted!',
          'imageUrl': 'https://picsum.photos/seed/news2/800/600',
          'time': '25 min ago',
          'honesty': 87,
          'upvotes': 42,
          'comments': 8,
          'isVerified': false,
        },
        {
          'title': 'Crowd Starting to Arrive',
          'description':
              'Early birds are already lining up for the festival. Great energy!',
          'imageUrl': 'https://picsum.photos/seed/news22/800/600',
          'time': '15 min ago',
          'honesty': 90,
          'upvotes': 36,
          'comments': 5,
          'isVerified': false,
        }
      ]
    },
    {
      'id': '3',
      'name': 'Jessica',
      'profileImage': 'https://picsum.photos/seed/user3/100/100',
      'hasUpdate': true,
      'location': 'Seattle, WA',
      'posts': [
        {
          'title': 'Tech Conference Highlights',
          'description':
              'Amazing innovations being showcased at the annual tech expo.',
          'imageUrl': 'https://picsum.photos/seed/news3/800/600',
          'time': '1 hour ago',
          'honesty': 91,
          'upvotes': 103,
          'comments': 27,
          'isVerified': true,
        }
      ]
    },
    {
      'id': '4',
      'name': 'Carlos',
      'profileImage': 'https://picsum.photos/seed/user4/100/100',
      'hasUpdate': false,
      'location': 'Miami, FL',
      'posts': []
    },
    {
      'id': '5',
      'name': 'Alex',
      'profileImage': 'https://picsum.photos/seed/user5/100/100',
      'hasUpdate': true,
      'location': 'Denver, CO',
      'posts': [
        {
          'title': 'Mountain Rescue Operation',
          'description':
              'Emergency services coordinating a rescue after heavy snowfall.',
          'imageUrl': 'https://picsum.photos/seed/news5/800/600',
          'time': '5 hours ago',
          'honesty': 95,
          'upvotes': 142,
          'comments': 31,
          'isVerified': true,
        },
        {
          'title': 'Rescue Complete',
          'description':
              'All hikers have been safely rescued and are receiving medical attention.',
          'imageUrl': 'https://picsum.photos/seed/news52/800/600',
          'time': '2 hours ago',
          'honesty': 97,
          'upvotes': 189,
          'comments': 42,
          'isVerified': true,
        }
      ]
    },
    {
      'id': '6',
      'name': 'Taylor',
      'profileImage': 'https://picsum.photos/seed/user6/100/100',
      'hasUpdate': true,
      'location': 'Austin, TX',
      'posts': [
        {
          'title': 'New City Park Opening',
          'description':
              'The long-awaited central park has finally opened to the public.',
          'imageUrl': 'https://picsum.photos/seed/news6/800/600',
          'time': '2 hours ago',
          'honesty': 88,
          'upvotes': 67,
          'comments': 14,
          'isVerified': false,
        }
      ]
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(
          top: 12), // Add top margin to make it more prominent
      padding: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? Colors.black.withOpacity(0.3)
            : Colors.grey.shade50,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Recent Updates',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    // View all following
                  },
                  style: TextButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: Text(
                    'See All',
                    style: TextStyle(
                      color: ThemeConstants.primaryColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 106, // Increased height to accommodate segments
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: _users.length,
              itemBuilder: (context, index) {
                final user = _users[index];
                final posts = user['posts'] as List<dynamic>;
                final hasUpdate = user['hasUpdate'] as bool && posts.isNotEmpty;

                return _buildUserCircle(context, user, posts.length);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserCircle(
      BuildContext context, Map<String, dynamic> user, int postCount) {
    final bool hasUpdate = user['hasUpdate'] as bool && postCount > 0;
    final posts = user['posts'] as List<dynamic>;

    return GestureDetector(
      onTap: () {
        if (posts.isNotEmpty) {
          _showUserPostsModal(context, user);
        }
      },
      onLongPress: () {
        // Option to toggle map on long press
        if (widget.onMapToggle != null) {
          widget.onMapToggle!();
        }
      },
      child: Container(
        width: 75,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                // Segmented circle for multiple posts
                if (postCount > 1 && hasUpdate)
                  _buildSegmentedCircle(postCount),

                // Single gradient border for single post
                if (postCount <= 1 && hasUpdate)
                  Container(
                    width: 68,
                    height: 68,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [
                          ThemeConstants.primaryColor,
                          ThemeConstants.primaryColor.withOpacity(0.7),
                          ThemeConstants.orange,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                  ),

                // No border for users without updates
                if (!hasUpdate)
                  Container(
                    width: 68,
                    height: 68,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: ThemeConstants.greyLight.withOpacity(0.5),
                    ),
                  ),

                // Profile image
                Container(
                  width: hasUpdate ? 62 : 64,
                  height: hasUpdate ? 62 : 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Theme.of(context).scaffoldBackgroundColor,
                      width: 3,
                    ),
                  ),
                  child: ClipOval(
                    child: Image.network(
                      user['profileImage'] as String,
                      fit: BoxFit.cover,
                      errorBuilder: (context, _, __) => Container(
                        color: ThemeConstants.grey.withOpacity(0.3),
                        child: const Icon(Icons.person,
                            size: 30, color: Colors.white),
                      ),
                    ),
                  ),
                ),

                // Post count indicator
                if (postCount > 1)
                  Positioned(
                    right: 3,
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: ThemeConstants.primaryColor,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Theme.of(context).scaffoldBackgroundColor,
                          width: 1.5,
                        ),
                      ),
                      child: Text(
                        postCount.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 4),
            // Username
            Text(
              user['name'] as String,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: hasUpdate ? ThemeConstants.primaryColor : null,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // Build segmented circle like Telegram's stories UI
  Widget _buildSegmentedCircle(int segments) {
    return CustomPaint(
      size: const Size(68, 68),
      painter: SegmentedCirclePainter(
        segments: segments,
        gapSize: 4, // Size of gaps between segments
        strokeWidth: 3, // Width of the segments
        colors: [
          ThemeConstants.primaryColor,
          ThemeConstants.orange,
          ThemeConstants.pink.withOpacity(0.7),
        ],
      ),
    );
  }

  // Show bottom sheet with user's multiple posts
  void _showUserPostsModal(BuildContext context, Map<String, dynamic> user) {
    final posts = user['posts'] as List<dynamic>;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => DraggableScrollableSheet(
          initialChildSize: 0.9,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (context, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
              ),
              child: Column(
                children: [
                  // Handle bar
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 10),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),

                  // User info
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundImage: NetworkImage(
                            user['profileImage'] as String,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user['name'] as String,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              user['location'] as String,
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                  ),

                  const Divider(height: 16),

                  // Posts list
                  Expanded(
                    child: PageView.builder(
                      itemCount: posts.length,
                      itemBuilder: (context, index) {
                        final post = posts[index];
                        return SingleChildScrollView(
                          controller: scrollController,
                          child: Column(
                            children: [
                              // Image
                              Image.network(
                                post['imageUrl'] as String,
                                height: 240,
                                width: double.infinity,
                                fit: BoxFit.cover,
                              ),

                              // Post content
                              Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Post counter
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        for (int i = 0; i < posts.length; i++)
                                          Container(
                                            margin: const EdgeInsets.symmetric(
                                                horizontal: 2),
                                            width: i == index ? 18 : 8,
                                            height: 4,
                                            decoration: BoxDecoration(
                                              color: i == index
                                                  ? ThemeConstants.primaryColor
                                                  : Colors.grey.shade300,
                                              borderRadius:
                                                  BorderRadius.circular(2),
                                            ),
                                          ),
                                      ],
                                    ),

                                    const SizedBox(height: 16),

                                    Text(
                                      post['title'] as String,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                      ),
                                    ),

                                    const SizedBox(height: 8),

                                    Text(
                                      post['description'] as String,
                                      style: const TextStyle(fontSize: 14),
                                    ),

                                    const SizedBox(height: 12),

                                    // Post metadata
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.access_time,
                                          size: 14,
                                          color: Colors.grey.shade600,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          post['time'] as String,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Icon(
                                          Icons.verified_user,
                                          size: 14,
                                          color: ThemeConstants.green,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          '${post['honesty']}% honest',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: ThemeConstants.green,
                                          ),
                                        ),
                                      ],
                                    ),

                                    const SizedBox(height: 16),

                                    // Action buttons
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceAround,
                                      children: [
                                        _buildActionButton(
                                          icon: Icons.arrow_upward,
                                          label: '${post['upvotes']}',
                                        ),
                                        _buildActionButton(
                                          icon: Icons.forum_outlined,
                                          label: '${post['comments']}',
                                        ),
                                        _buildActionButton(
                                          icon: Icons.share_outlined,
                                          label: 'Share',
                                        ),
                                        _buildActionButton(
                                          icon: Icons.map_outlined,
                                          label: 'Map',
                                          onTap: () {
                                            Navigator.pop(context);
                                            if (widget.onMapToggle != null) {
                                              widget.onMapToggle!();
                                            }
                                          },
                                        ),
                                      ],
                                    ),

                                    const SizedBox(height: 16),

                                    // View full post button
                                    Center(
                                      child: ElevatedButton(
                                        onPressed: () {
                                          Navigator.pop(context);
                                          _navigateToPostDetail(
                                            context,
                                            post['title'] as String,
                                            post['description'] as String,
                                            post['imageUrl'] as String,
                                            user['location'] as String,
                                            post['time'] as String,
                                            post['honesty'] as int,
                                            post['upvotes'] as int,
                                            post['comments'] as int,
                                            post['isVerified'] as bool,
                                          );
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor:
                                              ThemeConstants.primaryColor,
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(20),
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 24,
                                            vertical: 10,
                                          ),
                                        ),
                                        child: const Text('View Full Post'),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
        child: Row(
          children: [
            Icon(icon, size: 16, color: ThemeConstants.grey),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: ThemeConstants.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
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
}

// Custom painter for drawing segmented circles like Telegram's stories UI
class SegmentedCirclePainter extends CustomPainter {
  final int segments;
  final double gapSize;
  final double strokeWidth;
  final List<Color> colors;

  SegmentedCirclePainter({
    required this.segments,
    required this.gapSize,
    required this.strokeWidth,
    required this.colors,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    // Calculate angle per segment including gaps
    final totalGapAngle = segments * gapSize * math.pi / 180;
    final segmentAngle = (2 * math.pi - totalGapAngle) / segments;

    // Current angle position
    double startAngle = -math.pi / 2; // Start from top

    for (int i = 0; i < segments; i++) {
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..shader = LinearGradient(
          colors: colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(Rect.fromCircle(center: center, radius: radius));

      // Draw segment
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        segmentAngle,
        false,
        paint,
      );

      // Move to next segment start position
      startAngle += segmentAngle + (gapSize * math.pi / 180);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
