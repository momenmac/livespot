import 'package:flutter/material.dart';
import 'package:flutter_application_2/constants/theme_constants.dart';
import 'package:flutter_application_2/services/api/account/api_urls.dart';
import 'package:flutter_application_2/ui/pages/home/components/story/story_viewer_page.dart';
import 'package:flutter_application_2/providers/posts_provider.dart';
import 'package:provider/provider.dart';
import 'dart:developer' as developer;

class AllUpdatesPage extends StatefulWidget {
  const AllUpdatesPage({super.key});

  @override
  State<AllUpdatesPage> createState() => _AllUpdatesPageState();
}

class _AllUpdatesPageState extends State<AllUpdatesPage> {
  bool _dataLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadStories();
  }

  Future<void> _loadStories() async {
    if (!mounted) return;

    try {
      // Initially mark as not loaded and clear stories
      setState(() {
        _dataLoaded = false;
      });

      final postsProvider = Provider.of<PostsProvider>(context, listen: false);
      postsProvider.clearStories();

      // Use addPostFrameCallback to ensure state is updated before fetching
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;

        try {
          // Always send current date for all updates (you can modify this to show all dates)
          final String dateStr = DateTime.now().toIso8601String().split('T')[0];
          developer.log('Fetching all stories for date: $dateStr',
              name: 'AllUpdatesPage');

          // Wait a frame to ensure the UI has updated after clearing stories
          await Future.microtask(() {});

          // Fetch stories with explicit date - same as story_section.dart
          final stories =
              await postsProvider.fetchFollowingStories(date: dateStr);

          // Ensure we clear stories again if none were found
          if (stories.isEmpty) {
            postsProvider.clearStories();
            developer.log('No stories found for date: $dateStr',
                name: 'AllUpdatesPage');
          } else {
            developer.log('Loaded ${stories.length} stories for date: $dateStr',
                name: 'AllUpdatesPage');
          }

          if (mounted) {
            setState(() {
              _dataLoaded = true;
            });
          }
        } catch (e) {
          if (mounted) {
            developer.log('Error loading stories: $e', name: 'AllUpdatesPage');
            // Ensure stories are cleared on error
            Provider.of<PostsProvider>(context, listen: false).clearStories();
            setState(() {
              _dataLoaded = true;
            });
          }
        }
      });
    } catch (e) {
      if (mounted) {
        developer.log('Error in _loadStories: $e', name: 'AllUpdatesPage');
      }
    }
  }

  Future<void> _refreshStories() async {
    await _loadStories();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recent Updates'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              // Implement search
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshStories,
          ),
        ],
      ),
      body: Consumer<PostsProvider>(
        builder: (context, postsProvider, _) {
          final userStories = postsProvider.userStories;
          final isLoading = postsProvider.isLoading;

          if (isLoading && !_dataLoaded) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (userStories.isEmpty) {
            return const Center(
              child: Text('No stories available'),
            );
          }

          return ListView(
            children: [
              // Stats header
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    _buildStatCard(
                      context,
                      'Users',
                      userStories.length.toString(),
                      Icons.people,
                      ThemeConstants.primaryColor,
                    ),
                    const SizedBox(width: 12),
                    _buildStatCard(
                      context,
                      'Updates',
                      _countAllStories(userStories).toString(),
                      Icons.update,
                      ThemeConstants.green,
                    ),
                  ],
                ),
              ),

              // Grid of user updates
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                childAspectRatio: 0.75, // Adjusted for better proportions
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                children: userStories.entries.map((entry) {
                  final String username = entry.key;
                  final List<Map<String, dynamic>> stories = entry.value;

                  return _buildUserUpdatesCard(
                    context,
                    username: username,
                    stories: stories,
                    imageUrl: _getProfilePictureUrl(stories.first),
                    isLive: username == 'Emily J.' || username == 'David',
                    hasMultipleStories: stories.length > 1,
                    storiesCount: stories.length,
                  );
                }).toList(),
              ),

              const SizedBox(height: 20),

              // Latest updates header
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Text(
                  'Latest Updates',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              // List of all updates, ordered by time
              _buildAllUpdatesList(context, userStories),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatCard(
    BuildContext context,
    String label,
    String count,
    IconData icon,
    Color color,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 8),
            Text(
              count,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).textTheme.bodyLarge?.color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper to fix image/video URLs
  String _getFixedUrl(String? url) {
    if (url == null || url.isEmpty) return '';

    // Handle relative URLs
    if (url.startsWith('http://localhost:8000')) {
      return ApiUrls.baseUrl + url.substring('http://localhost:8000'.length);
    }
    if (url.startsWith('http://127.0.0.1:8000')) {
      return ApiUrls.baseUrl + url.substring('http://127.0.0.1:8000'.length);
    }
    if (url.startsWith('/')) {
      return ApiUrls.baseUrl + url;
    }

    // Return as is if it's already a complete URL
    if (url.startsWith('http://') || url.startsWith('https://')) {
      return url;
    }

    return url;
  }

  // Helper to create consistent avatar widgets
  Widget _buildAvatar({
    required String imageUrl,
    required double radius,
    String username = '',
    Widget? child,
    Color? backgroundColor,
    BoxBorder? border,
  }) {
    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: border,
        color: backgroundColor ?? Colors.grey[200],
      ),
      child: ClipOval(
        child: child ??
            (imageUrl.isEmpty
                ? Container(
                    width: radius * 2,
                    height: radius * 2,
                    color: ThemeConstants.primaryColor.withOpacity(0.1),
                    child: _buildInitialsWidget(username, radius),
                  )
                : Image.network(
                    _getFixedUrl(imageUrl),
                    width: radius * 2,
                    height: radius * 2,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Container(
                        width: radius * 2,
                        height: radius * 2,
                        color: Colors.grey[200],
                        child: Center(
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            value: loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded /
                                    loadingProgress.expectedTotalBytes!
                                : null,
                          ),
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      developer.log('Error loading avatar image: $error');
                      return Container(
                        width: radius * 2,
                        height: radius * 2,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: ThemeConstants.primaryColor.withOpacity(0.1),
                        ),
                        child: _buildInitialsWidget(username, radius),
                      );
                    },
                  )),
      ),
    );
  }

  // Helper to build user initials widget
  Widget _buildInitialsWidget(String username, double radius) {
    if (username.isEmpty) {
      return Icon(
        Icons.person,
        color: Colors.grey[600],
        size: radius * 0.8,
      );
    }

    // Generate initials from username
    String initials = '';
    try {
      final parts = username.trim().split(' ');
      if (parts.isNotEmpty) {
        initials = parts.first.isNotEmpty ? parts.first[0].toUpperCase() : '';
        if (parts.length > 1 && parts.last.isNotEmpty) {
          initials += parts.last[0].toUpperCase();
        }
      }
    } catch (e) {
      developer.log('Error generating initials for username: $username');
    }

    if (initials.isEmpty) {
      return Icon(
        Icons.person,
        color: Colors.grey[600],
        size: radius * 0.8,
      );
    }

    return Center(
      child: Text(
        initials,
        style: TextStyle(
          color: ThemeConstants.primaryColor,
          fontSize: radius * 0.6,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  // Helper to create consistent thumbnail widgets
  Widget _buildThumbnail({
    required String imageUrl,
    required double width,
    required double height,
    double borderRadius = 8,
  }) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        color: Colors.grey[200],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: imageUrl.isEmpty
            ? Container(
                width: width,
                height: height,
                color: Colors.grey[300],
                child: Icon(
                  Icons.image_not_supported,
                  color: Colors.grey[600],
                  size: (width * 0.4).clamp(16.0, 48.0),
                ),
              )
            : Image.network(
                _getFixedUrl(imageUrl),
                width: width,
                height: height,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Container(
                    width: width,
                    height: height,
                    color: Colors.grey[200],
                    child: Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        value: loadingProgress.expectedTotalBytes != null
                            ? loadingProgress.cumulativeBytesLoaded /
                                loadingProgress.expectedTotalBytes!
                            : null,
                      ),
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  developer.log('Error loading thumbnail image: $error');
                  return Container(
                    width: width,
                    height: height,
                    color: Colors.grey[300],
                    child: Icon(
                      Icons.image_not_supported,
                      color: Colors.grey[600],
                      size: (width * 0.4).clamp(16.0, 48.0),
                    ),
                  );
                },
              ),
      ),
    );
  }

  // Helper to safely get string value from dynamic
  String _safeGetString(dynamic value, String fallback) {
    if (value == null) return fallback;
    if (value is String) return value;
    if (value is Map) return fallback; // Handle map case
    return value.toString();
  }

  // Helper to safely get int value from dynamic
  int _safeGetInt(dynamic value, int fallback) {
    if (value == null) return fallback;
    if (value is int) return value;
    if (value is String) {
      return int.tryParse(value) ?? fallback;
    }
    return fallback;
  }

  Widget _buildUserUpdatesCard(
    BuildContext context, {
    required String username,
    required List<Map<String, dynamic>> stories,
    required String imageUrl,
    required bool isLive,
    required bool hasMultipleStories,
    required int storiesCount,
  }) {
    return GestureDetector(
      onTap: () {
        _navigateToUserStories(
          context,
          username,
          stories,
          imageUrl,
          isLive,
        );
      },
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Main card
          Card(
            margin: const EdgeInsets.all(8),
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Cover image section - slightly reduced height
                Expanded(
                  flex: 2, // Reduced from 3 to make image shorter
                  child: Stack(
                    clipBehavior: Clip.hardEdge,
                    children: [
                      // Cover image
                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(12),
                          ),
                          color: Colors.grey[200],
                        ),
                        child: ClipRRect(
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(12),
                          ),
                          child: _buildThumbnail(
                            imageUrl: _getStoryImageUrl(stories.first),
                            width: double.infinity,
                            height: double.infinity,
                            borderRadius:
                                0, // Remove inner borderRadius to prevent double rounding
                          ),
                        ),
                      ),

                      // Live indicator
                      if (isLive)
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.circle,
                                  color: Colors.white,
                                  size: 8,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'LIVE',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                // User info section - adjusted for new avatar position
                Expanded(
                  flex: 3, // Increased to balance shorter image
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                        16, 32, 16, 12), // More top padding for avatar
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            username,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatTimeAgo(_safeGetString(stories.first['time'],
                              DateTime.now().toIso8601String())),
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Flexible(
                          child: Text(
                            _safeGetString(
                                stories.first['description'], 'Story update'),
                            style: const TextStyle(
                              fontSize: 13,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // User profile image - positioned lower to be more in the text section
          Positioned(
            top: 80, // Moved down to sit more in the text section
            left: 24,
            child: Material(
              elevation: 6, // Increased elevation for better shadow
              shape: const CircleBorder(),
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white,
                    width: 3,
                  ),
                  gradient: hasMultipleStories
                      ? LinearGradient(
                          colors: [
                            ThemeConstants.primaryColor,
                            ThemeConstants.primaryColor.withOpacity(0.7),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : null,
                ),
                child: _buildAvatar(
                  imageUrl: _getProfilePictureUrl(stories.first),
                  username: username,
                  radius: 22, // Slightly larger avatar
                ),
              ),
            ),
          ),

          // Story count indicator - adjusted to match new avatar position
          if (hasMultipleStories)
            Positioned(
              top: 90, // Adjusted to align with new avatar position
              left: 72, // Adjusted to align with larger avatar
              child: Material(
                elevation: 6, // Increased to match avatar
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: ThemeConstants.primaryColor,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    '$storiesCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // Add time formatting helper
  String _formatTimeAgo(String dateString) {
    developer.log('⏰ Formatting time for dateString: $dateString');

    try {
      // Check for fake timestamps first
      if (dateString.contains('2024-01-01T00:00:00')) {
        developer.log('⚠️ Detected fake timestamp, returning fallback');
        return 'Recently';
      }

      // Handle various date string formats
      DateTime dateTime;

      if (dateString.contains('T')) {
        // ISO 8601 format
        dateTime = DateTime.parse(dateString);
      } else if (dateString.contains('-')) {
        // Try parsing as date only
        dateTime = DateTime.parse(dateString + 'T00:00:00Z');
      } else {
        // Fallback for other formats
        dateTime = DateTime.parse(dateString);
      }

      developer.log('⏰ Parsed dateTime: $dateTime');

      final DateTime now = DateTime.now();
      final Duration difference = now.difference(dateTime);

      developer.log('⏰ Current time: $now');
      developer.log(
          '⏰ Difference: ${difference.inDays} days, ${difference.inHours} hours, ${difference.inMinutes} minutes');

      // Ensure we don't get negative or extremely large values
      if (difference.isNegative) {
        developer.log('⏰ Negative difference, returning "Just now"');
        return 'Just now';
      }

      // Detect unrealistic time differences (more than 2 years ago)
      if (difference.inDays > 730) {
        developer.log(
            '⚠️ Unrealistic time difference (${difference.inDays} days), returning fallback');
        return 'Recently';
      }

      String result;
      if (difference.inDays > 365) {
        final years = (difference.inDays / 365).floor();
        result = '${years}y ago';
      } else if (difference.inDays > 30) {
        final months = (difference.inDays / 30).floor();
        result = '${months}mo ago';
      } else if (difference.inDays > 0) {
        result = '${difference.inDays}d ago';
      } else if (difference.inHours > 0) {
        result = '${difference.inHours}h ago';
      } else if (difference.inMinutes > 0) {
        result = '${difference.inMinutes}m ago';
      } else {
        result = 'Just now';
      }

      developer.log('⏰ Final result: $result');
      return result;
    } catch (e) {
      developer.log('⏰ Error parsing date: $dateString, error: $e');
      return 'Recently';
    }
  }

  Widget _buildAllUpdatesList(
    BuildContext context,
    Map<String, List<Map<String, dynamic>>> userStories,
  ) {
    // Flatten all stories into a single list and sort by time
    final List<Map<String, dynamic>> allStories = [];

    userStories.forEach((username, stories) {
      developer
          .log('📚 Processing user: $username with ${stories.length} stories');
      for (final story in stories) {
        developer.log('📖 Story data: $story');
        final Map<String, dynamic> storyWithUser = Map.from(story);
        storyWithUser['username'] = username;
        // Use proper profile picture extraction method
        storyWithUser['userImage'] = _getProfilePictureUrl(story);
        // Use proper image URL extraction for thumbnail
        storyWithUser['imageUrl'] = _getStoryImageUrl(story);
        allStories.add(storyWithUser);
      }
    });

    // Sort by created_at timestamp (most recent first)
    allStories.sort((a, b) {
      try {
        final String timeA =
            _safeGetString(a['time'], DateTime.now().toIso8601String());
        final String timeB =
            _safeGetString(b['time'], DateTime.now().toIso8601String());
        final DateTime dateA = DateTime.parse(timeA);
        final DateTime dateB = DateTime.parse(timeB);
        return dateB.compareTo(dateA); // Most recent first
      } catch (e) {
        return 0;
      }
    });

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: allStories.length,
      itemBuilder: (context, index) {
        final story = allStories[index];
        return _buildUpdateListItem(context, story);
      },
    );
  }

  Widget _buildUpdateListItem(
      BuildContext context, Map<String, dynamic> story) {
    return InkWell(
      onTap: () {
        _navigateToSingleStory(context, story);
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User avatar with better error handling
            _buildAvatar(
              imageUrl: _safeGetString(story['userImage'], ''),
              username: _safeGetString(story['username'], ''),
              radius: 24,
            ),
            const SizedBox(width: 12),
            // Story info - Properly constrained
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _safeGetString(story['username'], 'Unknown User'),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _formatTimeAgo(_safeGetString(
                            story['time'], DateTime.now().toIso8601String())),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _safeGetString(story['description'], 'Story update'),
                    style: const TextStyle(fontSize: 14),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        Icons.place,
                        size: 12,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          _getLocationText(story),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _buildMiniHonestyPill(
                          _safeGetInt(story['honesty_rating'], 85)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Story thumbnail - Better constrained and error handling
            _buildThumbnail(
              imageUrl: _safeGetString(story['imageUrl'], ''),
              width: 60,
              height: 60,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniHonestyPill(int rating) {
    Color color;
    if (rating >= 80) {
      color = ThemeConstants.green;
    } else if (rating >= 60) {
      color = ThemeConstants.orange;
    } else {
      color = ThemeConstants.red;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.verified_user,
            size: 10,
            color: color,
          ),
          const SizedBox(width: 2),
          Text(
            '$rating%',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // Helper methods
  int _countAllStories(Map<String, List<Map<String, dynamic>>> userStories) {
    int count = 0;
    userStories.forEach((_, stories) {
      count += stories.length;
    });
    return count;
  }

  // Helper method to get profile picture URL from various possible field names
  String _getProfilePictureUrl(Map<String, dynamic> story) {
    developer
        .log('🖼️ Getting profile picture for story: ${story.keys.toList()}');

    // According to working files, stories often don't contain profile picture data
    // In that case, we need to return empty string and let the avatar widget handle it
    // by showing user initials instead

    // Try different possible field names for profile picture
    // Note: profile_picture_url is now included in the server response
    final possibleFields = [
      'profile_picture_url', // New field added to server response
      'user_profile_picture',
      'profile_picture',
      'profileImage',
      'userImage',
      'avatar_url',
      'author.profile_picture',
      'author.profileImage',
      'user.profile_picture',
    ];

    for (final field in possibleFields) {
      if (field.contains('.')) {
        // Handle nested fields like 'author.profile_picture'
        final parts = field.split('.');
        dynamic value = story;

        for (final part in parts) {
          if (value is Map && value.containsKey(part)) {
            value = value[part];
          } else {
            value = null;
            break;
          }
        }

        if (value != null && value is String && value.isNotEmpty) {
          developer.log('🖼️ Found profile picture at $field: $value');
          return _getFixedUrl(value);
        }
      } else {
        // Handle direct fields
        if (story.containsKey(field) &&
            story[field] != null &&
            story[field] is String &&
            story[field].toString().isNotEmpty) {
          final url = story[field].toString();
          developer.log('🖼️ Found profile picture at $field: $url');
          return _getFixedUrl(url);
        }
      }
    }

    developer
        .log('🖼️ No profile picture found in story, returning empty string');
    // Return empty string to let avatar widget show user initials
    return '';
  }

  // Helper method to get story image URL from various possible field names
  String _getStoryImageUrl(Map<String, dynamic> story) {
    developer.log('📸 Getting story image for story: ${story.keys.toList()}');

    // Try different possible field names for story image
    final possibleImageFields = [
      'imageUrl',
      'image_url',
      'image',
      'media_url',
      'thumbnail_url',
      'file_path',
      'attachment_url',
      'media_urls', // This might be an array
    ];

    for (final field in possibleImageFields) {
      if (story.containsKey(field) && story[field] != null) {
        if (field == 'media_urls' && story[field] is List) {
          // Handle array of media URLs
          final List<dynamic> mediaUrls = story[field] as List<dynamic>;
          if (mediaUrls.isNotEmpty) {
            final firstUrl = mediaUrls.first.toString();
            developer
                .log('📸 Found story image in media_urls array: $firstUrl');
            return _getFixedUrl(_generateThumbnailUrl(firstUrl));
          }
        } else if (story[field] is String &&
            story[field].toString().isNotEmpty) {
          final url = story[field].toString();
          developer.log('📸 Found story image at $field: $url');

          // For video files, try to get thumbnail URL first
          if (_isVideoFile(url)) {
            final thumbnailUrl = _generateThumbnailUrl(url);
            if (thumbnailUrl.isNotEmpty) {
              developer
                  .log('📸 Generated thumbnail URL for video: $thumbnailUrl');
              return _getFixedUrl(thumbnailUrl);
            }
          }

          return _getFixedUrl(url);
        }
      }
    }

    developer.log('📸 No story image found');
    // Return empty string if no image found
    return '';
  }

  // Helper to check if URL is a video file
  bool _isVideoFile(String url) {
    final String lowerUrl = url.toLowerCase();
    return lowerUrl.contains('.mp4') ||
        lowerUrl.contains('.mov') ||
        lowerUrl.contains('.avi') ||
        lowerUrl.contains('.mkv') ||
        lowerUrl.contains('video/');
  }

  // Helper to generate thumbnail URL for video files
  String _generateThumbnailUrl(String videoUrl) {
    try {
      // Extract the video filename and create thumbnail URL
      // Example: video/15c994de-3db1-4f8b-b6bf-5d5ba1813817.mp4
      // -> thumbnails/15c994de-3db1-4f8b-b6bf-5d5ba1813817_thumb.jpg

      if (videoUrl.contains('attachments/video/')) {
        final videoPath = videoUrl.substring(
            videoUrl.indexOf('attachments/video/') +
                'attachments/video/'.length);
        final videoName = videoPath.split('/').last;
        final nameWithoutExt = videoName
            .replaceAll('.mp4', '')
            .replaceAll('.mov', '')
            .replaceAll('.avi', '')
            .replaceAll('.mkv', '');
        final thumbnailPath =
            '/media/attachments/thumbnails/${nameWithoutExt}_thumb.jpg';
        developer.log('📸 Generated thumbnail path: $thumbnailPath');
        return thumbnailPath;
      } else if (videoUrl.contains('attachments/image/') &&
          videoUrl.contains('.mp4')) {
        // Handle cases where video is in image folder
        final videoPath = videoUrl.substring(
            videoUrl.indexOf('attachments/image/') +
                'attachments/image/'.length);
        final videoName = videoPath.split('/').last;
        final nameWithoutExt = videoName
            .replaceAll('.mp4', '')
            .replaceAll('.mov', '')
            .replaceAll('.avi', '')
            .replaceAll('.mkv', '');
        final thumbnailPath =
            '/media/attachments/thumbnails/${nameWithoutExt}_thumb.jpg';
        developer.log(
            '📸 Generated thumbnail path for image folder video: $thumbnailPath');
        return thumbnailPath;
      }
    } catch (e) {
      developer.log('📸 Error generating thumbnail URL: $e');
    }

    return '';
  }

  // Helper method to get location text from story data structure
  String _getLocationText(Map<String, dynamic> story) {
    String location = '';

    // Check if the story has direct location
    if (story.containsKey('location') && story['location'] != null) {
      if (story['location'] is String) {
        location = story['location'];
      } else if (story['location'] is Map) {
        final locationMap = story['location'] as Map;

        // Try to extract address from location object (prioritize address over name)
        if (locationMap.containsKey('address') &&
            locationMap['address'] != null &&
            locationMap['address'] != 'null') {
          location = locationMap['address'].toString();
        } else if (locationMap.containsKey('name') &&
            locationMap['name'] != null &&
            locationMap['name'] != 'null') {
          location = locationMap['name'].toString();
        } else if (locationMap.containsKey('coordinates')) {
          // Try to get a readable format from coordinates
          var coords = locationMap['coordinates'];
          if (coords is Map &&
              coords.containsKey('latitude') &&
              coords.containsKey('longitude')) {
            try {
              final lat = double.parse(coords['latitude'].toString());
              final lng = double.parse(coords['longitude'].toString());
              location =
                  'Near (${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)})';
            } catch (e) {
              developer.log('Error parsing coordinates: $e');
            }
          }
        }
      }
    }

    // If no location found in location field, try direct latitude/longitude fields
    if (location.isEmpty &&
        story.containsKey('latitude') &&
        story.containsKey('longitude') &&
        story['latitude'] != null &&
        story['longitude'] != null) {
      try {
        final lat = double.parse(story['latitude'].toString());
        final lng = double.parse(story['longitude'].toString());
        location =
            'Near (${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)})';
      } catch (e) {
        developer.log('Error parsing direct lat/lng: $e');
      }
    }

    // If still no location, try using title as fallback
    if (location.isEmpty &&
        story.containsKey('title') &&
        story['title'] != null &&
        story['title'].toString().isNotEmpty) {
      location = "Near: ${story['title']}";
    }

    // Return location or fallback text
    return location.isNotEmpty ? location : 'Unknown location';
  }

  void _navigateToUserStories(
    BuildContext context,
    String username,
    List<Map<String, dynamic>> stories,
    String userImageUrl,
    bool isVerified,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => StoryViewerPage(
          stories: stories,
          username: username,
          userImageUrl: userImageUrl,
          isUserAdmin: isVerified,
        ),
      ),
    );
  }

  void _navigateToSingleStory(
    BuildContext context,
    Map<String, dynamic> story,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => StoryViewerPage(
          stories: [story],
          username: story['username'] ?? '',
          userImageUrl: story['userImage'] ?? '',
          isUserAdmin: story['isVerified'] ?? false,
        ),
      ),
    );
  }
}
