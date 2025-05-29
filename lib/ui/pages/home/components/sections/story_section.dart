import 'package:flutter/material.dart';
import 'package:flutter_application_2/constants/theme_constants.dart';
import 'package:flutter_application_2/services/api/account/api_urls.dart';
import 'package:flutter_application_2/ui/pages/home/components/story/story_viewer_page.dart';
import 'package:flutter_application_2/ui/pages/home/components/story/all_updates_page.dart';
import 'package:flutter_application_2/ui/pages/posts/admin_create_post_page.dart';
import 'package:flutter_application_2/ui/pages/camera/unified_camera_page.dart';
import 'package:flutter_application_2/providers/user_profile_provider.dart';
import 'package:flutter_application_2/providers/posts_provider.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;
import 'dart:developer' as developer;

// Add video thumbnail support
import 'dart:typed_data';
import 'package:video_thumbnail/video_thumbnail.dart';

class StorySection extends StatefulWidget {
  final DateTime selectedDate;

  const StorySection({
    super.key,
    required this.selectedDate,
  });

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

  // Add caching for user posts to prevent excessive API calls
  Map<String, Future<List<dynamic>>> _userPostsCache = {};
  Map<String, List<dynamic>> _userPostsData = {};

  @override
  void initState() {
    super.initState();
    _loadStories();
  }

  @override
  void didUpdateWidget(StorySection oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reload stories when selected date changes
    if (!DateUtils.isSameDay(oldWidget.selectedDate, widget.selectedDate)) {
      // Clear cache when date changes
      _userPostsCache.clear();
      _userPostsData.clear();

      // Also clear provider cache
      final postsProvider = Provider.of<PostsProvider>(context, listen: false);
      postsProvider.clearUserPostsByDateCache();

      _loadStories();
    }
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
          final now = DateTime.now();
          final normalizedToday = DateTime(now.year, now.month, now.day);
          final normalizedSelected = DateTime(widget.selectedDate.year,
              widget.selectedDate.month, widget.selectedDate.day);

          // Don't fetch stories for future dates
          if (normalizedSelected.isAfter(normalizedToday)) {
            if (mounted) {
              setState(() {
                _dataLoaded = true;
              });
            }
            return;
          }

          // Always send date parameter
          final String dateStr =
              widget.selectedDate.toIso8601String().split('T')[0];
          developer.log('Fetching stories for date: $dateStr',
              name: 'StorySection');

          // Wait a frame to ensure the UI has updated after clearing stories
          await Future.microtask(() {});

          // Fetch stories with explicit date
          final stories =
              await postsProvider.fetchFollowingStories(date: dateStr);

          // Ensure we clear stories again if none were found
          if (stories.isEmpty) {
            postsProvider.clearStories();
            developer.log(
                'No stories found for date: $dateStr, clearing stories',
                name: 'StorySection');
          } else {
            developer.log('Loaded ${stories.length} stories for date: $dateStr',
                name: 'StorySection');
          }

          if (mounted) {
            setState(() {
              _dataLoaded = true;
            });
          }
        } catch (e) {
          if (mounted) {
            developer.log('Error loading stories: $e', name: 'StorySection');
            // Ensure stories are cleared on error
            Provider.of<PostsProvider>(context, listen: false).clearStories();
          }
        }
      });
    } catch (e) {
      if (mounted) {
        developer.log('Error in _loadStories: $e', name: 'StorySection');
      }
    }
  }

  // Check if a URL/path points to a video file
  bool _isVideoFile(String url) {
    final String lowerUrl = url.toLowerCase();
    return lowerUrl.contains('.mp4') ||
        lowerUrl.contains('.mov') ||
        lowerUrl.contains('.avi') ||
        lowerUrl.contains('.mkv') ||
        lowerUrl.contains('.webm') ||
        lowerUrl.contains('.m4v') ||
        lowerUrl.contains('.3gp');
  }

  // Helper to fix image/video URLs
  String _getFixedUrl(String? url) {
    if (url == null || url.isEmpty) return '';
    if (url.startsWith('http://localhost:8000')) {
      return ApiUrls.baseUrl + url.substring('http://localhost:8000'.length);
    }
    if (url.startsWith('http://127.0.0.1:8000')) {
      return ApiUrls.baseUrl + url.substring('http://127.0.0.1:8000'.length);
    }
    if (url.startsWith('/')) {
      return ApiUrls.baseUrl + url;
    }
    return url;
  }

  // Extract thumbnail URL from video URL for story thumbnails
  String? _extractThumbnailUrl(String videoUrl) {
    try {
      String relativePath = '';

      if (videoUrl.contains('attachments/video/')) {
        int pathIndex = videoUrl.indexOf('attachments/video/');
        relativePath = videoUrl.substring(pathIndex);
        relativePath = relativePath.replaceAll(
            'attachments/video/', 'media/attachments/thumbnails/');
        relativePath = relativePath.replaceAll('.mp4', '_thumb.jpg');
        String thumbnailUrl = '${ApiUrls.baseUrl}/$relativePath';
        return thumbnailUrl;
      } else if (videoUrl.contains('attachments/image/') &&
          videoUrl.endsWith('.mp4')) {
        int pathIndex = videoUrl.indexOf('attachments/image/');
        relativePath = videoUrl.substring(pathIndex);
        relativePath = relativePath.replaceAll(
            'attachments/image/', 'attachments/thumbnails/');
        relativePath = relativePath.replaceAll('.mp4', '_thumb.jpg');
        String thumbnailUrl = '${ApiUrls.baseUrl}/$relativePath';
        return thumbnailUrl;
      }
    } catch (e) {
      developer.log('Error extracting story thumbnail URL: $e',
          name: 'StorySection');
    }
    return null;
  }

  // Build story avatar with video support and proper circle fitting
  Widget _buildStoryAvatar(String imageUrl) {
    // Check if it's a video
    if (_isVideoFile(imageUrl)) {
      // Try to get server thumbnail first
      String? thumbnailUrl = _extractThumbnailUrl(imageUrl);

      return Stack(
        children: [
          Container(
            width: 62, // Fixed size for proper circle fitting
            height: 62,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.grey[300],
            ),
            child: ClipOval(
              child: thumbnailUrl != null && thumbnailUrl.isNotEmpty
                  ? Image.network(
                      thumbnailUrl,
                      width: 62,
                      height: 62,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        // Fallback to client-side generation
                        return FutureBuilder<Uint8List?>(
                          future: _generateVideoThumbnail(imageUrl),
                          builder: (context, snapshot) {
                            if (snapshot.hasData && snapshot.data != null) {
                              return Image.memory(
                                snapshot.data!,
                                width: 62,
                                height: 62,
                                fit: BoxFit.cover,
                              );
                            }
                            return Container(
                              width: 62,
                              height: 62,
                              decoration: BoxDecoration(
                                gradient: RadialGradient(
                                  colors: [
                                    Colors.grey[600]!,
                                    Colors.grey[800]!
                                  ],
                                ),
                              ),
                              child: Icon(
                                Icons.videocam,
                                size: 24,
                                color: Colors.white.withOpacity(0.8),
                              ),
                            );
                          },
                        );
                      },
                    )
                  : FutureBuilder<Uint8List?>(
                      future: _generateVideoThumbnail(imageUrl),
                      builder: (context, snapshot) {
                        if (snapshot.hasData && snapshot.data != null) {
                          return Image.memory(
                            snapshot.data!,
                            width: 62,
                            height: 62,
                            fit: BoxFit.cover,
                          );
                        }
                        return Container(
                          width: 62,
                          height: 62,
                          decoration: BoxDecoration(
                            gradient: RadialGradient(
                              colors: [Colors.grey[600]!, Colors.grey[800]!],
                            ),
                          ),
                          child: Icon(
                            Icons.videocam,
                            size: 24,
                            color: Colors.white.withOpacity(0.8),
                          ),
                        );
                      },
                    ),
            ),
          ),
          // Video indicator
          Positioned(
            bottom: 2,
            right: 2,
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: const BoxDecoration(
                color: Colors.black87,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.play_arrow,
                color: Colors.white,
                size: 10,
              ),
            ),
          ),
        ],
      );
    } else {
      // Regular image handling with proper circle fitting
      return Container(
        width: 62,
        height: 62,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: ThemeConstants.greyLight.withOpacity(0.3),
        ),
        child: ClipOval(
          child: Image.network(
            _getFixedUrl(imageUrl),
            width: 62,
            height: 62,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                width: 62,
                height: 62,
                color: ThemeConstants.greyLight.withOpacity(0.3),
                child: const Icon(
                  Icons.image_not_supported,
                  size: 24,
                  color: Colors.grey,
                ),
              );
            },
          ),
        ),
      );
    }
  }

  // Generate video thumbnail with better error handling
  Future<Uint8List?> _generateVideoThumbnail(String videoUrl) async {
    try {
      String processedVideoUrl = _getFixedUrl(videoUrl);
      developer.log('🎥 Processing video URL for thumbnail: $processedVideoUrl',
          name: 'StorySection');

      List<Map<String, dynamic>> attempts = [
        {'timeMs': 1000, 'quality': 85},
        {'timeMs': 2000, 'quality': 75},
        {'timeMs': 500, 'quality': 85},
        {'timeMs': 0, 'quality': 75},
      ];

      for (var attempt in attempts) {
        try {
          final uint8list = await VideoThumbnail.thumbnailData(
            video: processedVideoUrl,
            imageFormat: ImageFormat.JPEG,
            maxWidth: 200,
            maxHeight: 200,
            timeMs: attempt['timeMs'],
            quality: attempt['quality'],
          );

          if (uint8list != null && uint8list.isNotEmpty) {
            developer.log('🎥 Successfully generated story thumbnail',
                name: 'StorySection');
            return uint8list;
          }
        } catch (e) {
          developer.log('🎥 Thumbnail attempt failed: $e',
              name: 'StorySection');
          continue;
        }
      }

      developer.log('🎥 All story thumbnail generation attempts failed',
          name: 'StorySection');
      return null;
    } catch (e) {
      developer.log('🎥 Critical error in story thumbnail generation: $e',
          name: 'StorySection');
      return null;
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
    final postsProvider = Provider.of<PostsProvider>(context, listen: false);
    final userProfile = userProfileProvider.currentUserProfile;

    // If no user profile, show the add story button
    if (userProfile == null) {
      return _buildSimpleAddStoryItem();
    }

    final currentUserId = userProfile.account.id;
    final formattedDate = widget.selectedDate.toIso8601String().split('T')[0];
    final cacheKey = '${currentUserId}_$formattedDate';

    // Check if we already have cached data
    if (_userPostsData.containsKey(cacheKey)) {
      final cachedData = _userPostsData[cacheKey]!;
      if (cachedData.isEmpty) {
        return _buildSimpleAddStoryItem();
      }
      return _buildUserStoryWidget(cachedData, userProfile);
    }

    // Check if we have an ongoing request
    if (!_userPostsCache.containsKey(cacheKey)) {
      _userPostsCache[cacheKey] =
          postsProvider.getUserPostsByDate(currentUserId, formattedDate);
    }

    return FutureBuilder<List<dynamic>>(
      future: _userPostsCache[cacheKey],
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingStoryItem();
        }

        if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
          // Cache the empty result
          _userPostsData[cacheKey] = [];
          // No posts for this date, show add story button
          return _buildSimpleAddStoryItem();
        }

        // Cache the successful result
        final userPosts = snapshot.data!;
        _userPostsData[cacheKey] = userPosts;

        return _buildUserStoryWidget(userPosts, userProfile);
      },
    );
  }

  Widget _buildUserStoryWidget(List<dynamic> userPosts, dynamic userProfile) {
    final firstPost = userPosts.first;

    // Get the first media URL if available
    String? imageUrl;
    if (firstPost.mediaUrls != null && firstPost.mediaUrls!.isNotEmpty) {
      imageUrl = _getFixedUrl(firstPost.mediaUrls!.first);
    }

    return GestureDetector(
      onTap: () => _navigateToUserStory(userPosts),
      child: Container(
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
                      color: ThemeConstants.primaryColor,
                      width: 2.5,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(3),
                    child: ClipOval(
                      child: imageUrl != null && imageUrl.isNotEmpty
                          ? _buildStoryMediaPreview(imageUrl)
                          : _buildDefaultUserStoryContent(userProfile),
                    ),
                  ),
                ),
                // Story count indicator if multiple posts
                if (userPosts.length > 1)
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: ThemeConstants.primaryColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: Center(
                      child: Text(
                        userPosts.length.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 5),
            Text(
              'My Story',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white
                    : Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSimpleAddStoryItem() {
    final userProfileProvider = Provider.of<UserProfileProvider>(context);
    final userProfile = userProfileProvider.currentUserProfile;

    return GestureDetector(
      onTap: () => _handleAddStoryTap(userProfile),
      child: Container(
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
                    child: Container(
                      width: 65,
                      height: 65,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: ThemeConstants.greyLight.withOpacity(0.3),
                      ),
                      child: ClipOval(
                        child: userProfile?.profilePictureUrl != null &&
                                userProfile!.profilePictureUrl.isNotEmpty
                            ? Image.network(
                                userProfile.profilePictureUrl,
                                width: 65,
                                height: 65,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    Icon(
                                  Icons.person,
                                  size: 32,
                                  color: ThemeConstants.grey,
                                ),
                              )
                            : Icon(
                                Icons.person,
                                size: 32,
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
            Text(
              'Your story',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white
                    : Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Handle add story tap - navigate to different pages based on admin status
  void _handleAddStoryTap(dynamic userProfile) {
    // Check if user is admin
    final bool isAdmin = userProfile?.account?.isAdmin ?? false;
    
    if (isAdmin) {
      // Navigate to admin create post page
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const AdminCreatePostPage(),
        ),
      );
    } else {
      // Navigate to camera page for regular users
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const UnifiedCameraPage(),
        ),
      );
    }
  }

  Widget _buildLoadingStoryItem() {
    return Container(
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
            ),
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: ThemeConstants.primaryColor,
                ),
              ),
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'Loading...',
            style: TextStyle(
              fontSize: 12,
              color: ThemeConstants.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStoryMediaPreview(String mediaUrl) {
    if (_isVideoFile(mediaUrl)) {
      // For videos, try to show thumbnail
      String? thumbnailUrl = _extractThumbnailUrl(mediaUrl);

      return Stack(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: Colors.grey[300],
            ),
            child: thumbnailUrl != null && thumbnailUrl.isNotEmpty
                ? Image.network(
                    thumbnailUrl,
                    width: 64,
                    height: 64,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return FutureBuilder<Uint8List?>(
                        future: _generateVideoThumbnail(mediaUrl),
                        builder: (context, snapshot) {
                          if (snapshot.hasData && snapshot.data != null) {
                            return Image.memory(
                              snapshot.data!,
                              width: 64,
                              height: 64,
                              fit: BoxFit.cover,
                            );
                          }
                          return Container(
                            decoration: BoxDecoration(
                              gradient: RadialGradient(
                                colors: [Colors.grey[600]!, Colors.grey[800]!],
                              ),
                            ),
                            child: Icon(
                              Icons.videocam,
                              size: 20,
                              color: Colors.white.withOpacity(0.8),
                            ),
                          );
                        },
                      );
                    },
                  )
                : FutureBuilder<Uint8List?>(
                    future: _generateVideoThumbnail(mediaUrl),
                    builder: (context, snapshot) {
                      if (snapshot.hasData && snapshot.data != null) {
                        return Image.memory(
                          snapshot.data!,
                          width: 64,
                          height: 64,
                          fit: BoxFit.cover,
                        );
                      }
                      return Container(
                        decoration: BoxDecoration(
                          gradient: RadialGradient(
                            colors: [Colors.grey[600]!, Colors.grey[800]!],
                          ),
                        ),
                        child: Icon(
                          Icons.videocam,
                          size: 20,
                          color: Colors.white.withOpacity(0.8),
                        ),
                      );
                    },
                  ),
          ),
          // Small video indicator
          Positioned(
            bottom: 2,
            right: 2,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: const BoxDecoration(
                color: Colors.black87,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.play_arrow,
                color: Colors.white,
                size: 8,
              ),
            ),
          ),
        ],
      );
    } else {
      // For images
      return Image.network(
        mediaUrl,
        width: 64,
        height: 64,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              colors: [Colors.grey[400]!, Colors.grey[600]!],
            ),
          ),
          child: Icon(
            Icons.image,
            size: 20,
            color: Colors.white.withOpacity(0.8),
          ),
        ),
      );
    }
  }

  Widget _buildDefaultUserStoryContent(dynamic userProfile) {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            ThemeConstants.primaryColor.withOpacity(0.8),
            ThemeConstants.primaryColor,
          ],
        ),
      ),
      child: userProfile?.profilePictureUrl != null &&
              userProfile!.profilePictureUrl.isNotEmpty
          ? Image.network(
              userProfile.profilePictureUrl,
              width: 64,
              height: 64,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Icon(
                Icons.person,
                size: 24,
                color: Colors.white,
              ),
            )
          : Icon(
              Icons.person,
              size: 24,
              color: Colors.white,
            ),
    );
  }

  void _navigateToUserStory(List<dynamic> userPosts) {
    final userProfileProvider =
        Provider.of<UserProfileProvider>(context, listen: false);
    final userProfile = userProfileProvider.currentUserProfile;

    if (userProfile == null) return;

    // Convert posts to story format
    final stories = userPosts.map((post) {
      return {
        'id': post.id,
        'title': post.title,
        'content': post.content,
        'category': post.category,
        'time': post.createdAt.toIso8601String(),
        'imageUrl': post.mediaUrls != null && post.mediaUrls!.isNotEmpty
            ? _getFixedUrl(post.mediaUrls!.first)
            : '',
        'upvotes': post.upvotes ?? 0,
        'honesty_score': post.honestyScore ?? 0,
        'comments': 0,
        'isVerified': post.isVerifiedLocation,
        'is_admin': userProfile.account.isAdmin,
        'profile_picture_url': userProfile.profilePictureUrl,
        'location': 'Location available',
        'author_id': userProfile.account.id,
      };
    }).toList();

    final username =
        '${userProfile.account.firstName} ${userProfile.account.lastName}'
            .trim();
    final displayName = username.isNotEmpty ? username : userProfile.username;

    // Navigate to story viewer
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => StoryViewerPage(
          username: displayName,
          userImageUrl: userProfile.profilePictureUrl,
          stories: stories,
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
      return const SizedBox.shrink();
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
                    child: _buildStoryAvatar(imageUrl),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 5),
            SizedBox(
              width: 70,
              child: Text(
                username,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white
                      : Colors.black,
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
