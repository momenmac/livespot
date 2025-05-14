import 'package:flutter/material.dart';
import 'package:flutter_application_2/constants/theme_constants.dart';
import 'package:flutter_application_2/ui/pages/home/components/story/story_viewer_page.dart';
import 'package:flutter_application_2/ui/pages/home/components/story/all_updates_page.dart';
import 'package:flutter_application_2/providers/user_profile_provider.dart';
import 'package:flutter_application_2/providers/posts_provider.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;
import 'dart:developer' as developer;

class StorySection extends StatefulWidget {
  const StorySection({super.key});

  // Method to get stories from the provider
  static Map<String, List<Map<String, dynamic>>> getUserStories(
      BuildContext context) {
    return Provider.of<PostsProvider>(context, listen: false).userStories;
  }

  @override
  State<StorySection> createState() => _StorySectionState();
}

class _StorySectionState extends State<StorySection> {
  bool _dataLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadStories();
  }

  Future<void> _loadStories() async {
    // Ensure this method won't proceed if the widget is not mounted
    if (!mounted) return;

    try {
      // Schedule the provider call for the next frame to avoid build issues
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        
        try {
          // Call the API to fetch stories
          await Provider.of<PostsProvider>(context, listen: false)
              .fetchFollowingStories();

          // Check mounted state before updating the UI
          if (mounted) {
            setState(() {
              _dataLoaded = true;
            });
            developer.log('Loaded stories from API', name: 'StorySection');
          }
        } catch (e) {
          // Only log the error if the widget is still mounted
          if (mounted) {
            developer.log('Error loading stories: $e', name: 'StorySection');
          }
        }
      });
    } catch (e) {
      // Only log the error if the widget is still mounted
      if (mounted) {
        developer.log('Error in _loadStories: $e', name: 'StorySection');
      }
    }
  }

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
          child: Consumer<PostsProvider>(builder: (context, postsProvider, _) {
            final isLoading = postsProvider.isLoading;
            final userStories = postsProvider.userStories;

            if (isLoading && !_dataLoaded) {
              return Center(
                child: CircularProgressIndicator(
                  color: ThemeConstants.primaryColor,
                ),
              );
            }

            // Check if we have valid stories data
            final List<Widget> storyWidgets = [];
            if (userStories.isNotEmpty) {
              try {
                for (var entry in userStories.entries) {
                  if (entry.key.isNotEmpty && entry.value.isNotEmpty) {
                    storyWidgets.add(_buildUserStory(entry.key, entry.value));
                  }
                }
              } catch (e) {
                developer.log('Error building story widgets: $e',
                    name: 'StorySection');
              }
            }

            return ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                // Add story button (for the current user)
                _buildAddStoryItem(),

                // All stories/updates button
                _buildAllUpdatesItem(),

                // Show stories from API
                if (storyWidgets.isEmpty && _dataLoaded)
                  _buildEmptyStoriesWidget()
                else
                  ...storyWidgets,
              ],
            );
          }),
        ),
      ],
    );
  }

  Widget _buildAddStoryItem() {
    // Get current user profile from provider
    final userProfileProvider = Provider.of<UserProfileProvider>(context);
    final userProfile = userProfileProvider.currentUserProfile;

    return Container(
      margin: const EdgeInsets.only(right: 12),
      child: Column(
        children: [
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: ThemeConstants.grey.withOpacity(0.2),
                    width: 2,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(2.5),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(35),
                    child: userProfile?.profilePictureUrl != null &&
                            userProfile!.profilePictureUrl.isNotEmpty
                        ? Image.network(
                            userProfile.profilePictureUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Icon(
                              Icons.person,
                              size: 40,
                              color: ThemeConstants.grey,
                            ),
                          )
                        : Container(
                            color: ThemeConstants.greyLight.withOpacity(0.3),
                            child: Icon(
                              Icons.person,
                              size: 40,
                              color: ThemeConstants.grey,
                            ),
                          ),
                  ),
                ),
              ),
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: ThemeConstants.primaryColor,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.add,
                  color: Colors.white,
                  size: 18,
                ),
              )
            ],
          ),
          const SizedBox(height: 5),
          const Text(
            'Your story',
            style: TextStyle(
              fontSize: 12,
              color: Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAllUpdatesItem() {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const AllUpdatesPage(),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(right: 12),
        child: Column(
          children: [
            Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: ThemeConstants.grey.withOpacity(0.2),
                  width: 2,
                ),
                color: ThemeConstants.greyLight.withOpacity(0.3),
              ),
              child: const Icon(
                Icons.notifications_outlined,
                size: 30,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 5),
            const Text(
              'Updates',
              style: TextStyle(
                fontSize: 12,
                color: Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyStoriesWidget() {
    return Container(
      width: 100,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.people_outline,
            size: 32,
            color: ThemeConstants.grey.withOpacity(0.7),
          ),
          const SizedBox(height: 8),
          Text(
            'No stories available',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              color: ThemeConstants.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserStory(String username, List<Map<String, dynamic>> stories) {
    if (stories.isEmpty) {
      developer.log('Warning: Empty stories list for user: $username',
          name: 'StorySection');
      return const SizedBox.shrink(); // Return empty widget for empty stories
    }

    final bool hasMultipleStories = stories.length > 1;
    String imageUrl = 'https://picsum.photos/seed/fallback/200';

    try {
      if (stories.isNotEmpty && stories.first.containsKey('imageUrl')) {
        final dynamic urlValue = stories.first['imageUrl'];
        if (urlValue != null && urlValue is String && urlValue.isNotEmpty) {
          imageUrl = urlValue;
        }
      }
    } catch (e) {
      developer.log('Error getting image URL: $e', name: 'StorySection');
    }

    bool isAdmin = false;
    try {
      if (stories.isNotEmpty && stories.first.containsKey('is_admin')) {
        final dynamic adminValue = stories.first['is_admin'];
        if (adminValue != null && adminValue is bool) {
          isAdmin = adminValue;
        }
      }
    } catch (e) {
      developer.log('Error getting admin status: $e', name: 'StorySection');
    }

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => StoryViewerPage(
              stories: stories,
              username: username,
              userImageUrl: imageUrl,
              isUserAdmin: isAdmin,
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(right: 12),
        child: Column(
          children: [
            SizedBox(
              width: 70,
              height: 70,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  hasMultipleStories
                      ? CustomPaint(
                          painter: SegmentedCirclePainter(
                            segments: stories.length,
                            color: ThemeConstants.primaryColor,
                          ),
                        )
                      : Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: ThemeConstants.primaryColor,
                              width: 2,
                            ),
                          ),
                        ),
                  Padding(
                    padding: const EdgeInsets.all(4),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(35),
                      child: Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: ThemeConstants.greyLight.withOpacity(0.3),
                            child: const Icon(
                              Icons.image_not_supported,
                              size: 30,
                              color: Colors.grey,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 5),
            SizedBox(
              width: 70,
              child: Text(
                username,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.black,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Custom painter for segmented circle (like Telegram stories)
class SegmentedCirclePainter extends CustomPainter {
  final int segments;
  final Color color;
  final double strokeWidth;
  final double gapWidth;

  SegmentedCirclePainter({
    required this.segments,
    required this.color,
    this.strokeWidth = 2.5,
    this.gapWidth = 3,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    if (segments <= 1) {
      canvas.drawCircle(center, radius, paint);
      return;
    }

    final segmentAngle = 2 * math.pi / segments;
    final gapAngle = gapWidth / radius;

    for (int i = 0; i < segments; i++) {
      final startAngle = i * segmentAngle + gapAngle / 2;
      final endAngle = (i + 1) * segmentAngle - gapAngle / 2;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle - math.pi / 2, // Start from top
        endAngle - startAngle,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(SegmentedCirclePainter oldDelegate) =>
      segments != oldDelegate.segments ||
      color != oldDelegate.color ||
      strokeWidth != oldDelegate.strokeWidth ||
      gapWidth != oldDelegate.gapWidth;
}
