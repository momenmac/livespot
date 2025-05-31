import 'package:flutter/material.dart';
import 'package:flutter_application_2/constants/theme_constants.dart';
import 'package:flutter_application_2/constants/text_strings.dart';
import 'package:flutter_application_2/constants/category_utils.dart';
import 'package:flutter_application_2/ui/pages/home/components/post_detail/post_detail_page.dart';
import 'package:flutter_application_2/services/api/account/api_urls.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'package:provider/provider.dart';
import 'package:flutter_application_2/providers/posts_provider.dart';
// Add video player support
import 'dart:io';
import 'dart:typed_data';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:video_player/video_player.dart';

class StoryViewerPage extends StatefulWidget {
  final List<Map<String, dynamic>> stories;
  final String username;
  final String userImageUrl;
  final bool isUserAdmin;

  const StoryViewerPage({
    super.key,
    required this.stories,
    required this.username,
    required this.userImageUrl,
    this.isUserAdmin = false,
  });

  @override
  State<StoryViewerPage> createState() => _StoryViewerPageState();
}

class _StoryViewerPageState extends State<StoryViewerPage>
    with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  late PageController _pageController;
  late AnimationController _progressController;
  Timer? _storyTimer;
  bool _isPaused = false;

  // Video player controllers
  final Map<int, VideoPlayerController?> _videoControllers = {};
  bool _isVideoInitializing = false;

  // Story display duration in seconds
  final int _storyDuration = 5;

  // Helper method to format time strings
  String _formatTimeString(String timeString) {
    if (timeString.isEmpty) {
      return '';
    }

    try {
      final dateTime = DateTime.parse(timeString);
      // Format to a more readable format (e.g., "May 13, 2:30 PM")
      return DateFormat('MMM d, h:mm a').format(dateTime);
    } catch (e) {
      // If we can't parse the date, return the original string or a default
      return timeString.length > 20 ? timeString.substring(0, 20) : timeString;
    }
  }

  // Helper to fix story image URLs that use localhost
  String _getFixedStoryImageUrl(String? url) {
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

  @override
  void initState() {
    super.initState();
    _pageController = PageController();

    // Initialize progress animation controller
    _progressController = AnimationController(
      vsync: this,
      duration: Duration(seconds: _storyDuration),
    )..addListener(() {
        setState(() {});
      });

    _progressController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _nextStory();
      }
    });

    // Start the progress for the first story and initialize video if needed
    _initializeCurrentStory();
  }

  Future<void> _initializeCurrentStory() async {
    await _initializeVideoIfNeeded(_currentIndex);
    _startStoryTimer();
  }

  Future<void> _initializeVideoIfNeeded(int index) async {
    if (index >= widget.stories.length) return;

    final story = widget.stories[index];
    final String? mediaUrl = story['imageUrl'];

    if (mediaUrl != null && _isVideoFile(mediaUrl)) {
      if (_videoControllers[index] == null) {
        setState(() {
          _isVideoInitializing = true;
        });

        try {
          final fixedUrl = _getFixedStoryImageUrl(mediaUrl);
          final controller = VideoPlayerController.network(fixedUrl);

          await controller.initialize();

          // Set up video controller
          controller.setLooping(true);
          controller.setVolume(0.8); // Slightly lower volume for stories

          _videoControllers[index] = controller;

          // Start playing immediately
          await controller.play();

          debugPrint('🎥 Story Video initialized and playing: $fixedUrl');
        } catch (e) {
          debugPrint('🎥 Story Video initialization failed: $e');
          _videoControllers[index] = null;
        } finally {
          setState(() {
            _isVideoInitializing = false;
          });
        }
      } else {
        // Video already initialized, just play it
        _videoControllers[index]?.play();
      }
    }
  }

  void _pauseCurrentVideo() {
    final controller = _videoControllers[_currentIndex];
    if (controller != null && controller.value.isInitialized) {
      controller.pause();
    }
  }

  void _resumeCurrentVideo() {
    final controller = _videoControllers[_currentIndex];
    if (controller != null && controller.value.isInitialized) {
      controller.play();
    }
  }

  void _disposeVideoController(int index) {
    final controller = _videoControllers[index];
    if (controller != null) {
      controller.pause();
      controller.dispose();
      _videoControllers.remove(index);
    }
  }

  void _startStoryTimer() {
    final story = widget.stories[_currentIndex];
    final String? mediaUrl = story['imageUrl'];

    // For videos, use video duration if available, otherwise default duration
    if (mediaUrl != null && _isVideoFile(mediaUrl)) {
      final controller = _videoControllers[_currentIndex];
      if (controller != null && controller.value.isInitialized) {
        final videoDuration = controller.value.duration;
        if (videoDuration.inSeconds > 0) {
          _progressController.duration = videoDuration;
        }
      }
    } else {
      _progressController.duration = Duration(seconds: _storyDuration);
    }

    _progressController.forward(from: 0.0);
  }

  void _pauseStoryTimer() {
    if (!_isPaused) {
      _progressController.stop();
      _pauseCurrentVideo();
      _isPaused = true;
    }
  }

  void _resumeStoryTimer() {
    if (_isPaused) {
      _progressController.forward();
      _resumeCurrentVideo();
      _isPaused = false;
    }
  }

  void _resetStoryTimer() {
    _progressController.reset();
    _isPaused = false;
    _startStoryTimer();
  }

  void _nextStory() async {
    // Dispose current video
    _disposeVideoController(_currentIndex);

    if (_currentIndex < widget.stories.length - 1) {
      setState(() {
        _currentIndex++;
        _pageController.animateToPage(
          _currentIndex,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      });
      await _initializeVideoIfNeeded(_currentIndex);
      _resetStoryTimer();
    } else {
      // Last story completed, pop back to previous screen
      Navigator.of(context).pop();
    }
  }

  void _previousStory() async {
    // Dispose current video
    _disposeVideoController(_currentIndex);

    if (_currentIndex > 0) {
      setState(() {
        _currentIndex--;
        _pageController.animateToPage(
          _currentIndex,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      });
      await _initializeVideoIfNeeded(_currentIndex);
      _resetStoryTimer();
    }
  }

  void _navigateToFullPost() async {
    // Pause the timer when navigating away
    _pauseStoryTimer();

    final story = widget.stories[_currentIndex];
    final postsProvider = Provider.of<PostsProvider>(context, listen: false);

    // Try to get postId from story
    int? postId;
    if (story.containsKey('id')) {
      postId = story['id'] is int
          ? story['id']
          : int.tryParse(story['id'].toString());
    }

    if (postId == null) {
      // If no postId, show error and return
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to load post details.')),
      );
      _resumeStoryTimer();
      return;
    }

    // Show loading indicator while fetching
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final post = await postsProvider.fetchPostDetails(postId);
      if (!mounted) return; // Add mounted check
      Navigator.of(context).pop(); // Remove loading dialog
      if (post == null) {
        if (!mounted) return; // Add mounted check
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to load post details.')),
        );
        _resumeStoryTimer();
        return;
      }

      // Format the time string before passing to the detail page
      final formattedTime =
          _formatTimeString(post.timePosted.toIso8601String());

      if (!mounted) return; // Add mounted check
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PostDetailPage(
            title: post.title,
            description: post.content,
            imageUrl: post.mediaUrls.isNotEmpty ? post.mediaUrls.first : '',
            location: post.location.address ?? '',
            time: formattedTime,
            honesty: post.honestyScore,
            upvotes: post.upvotes,
            comments: 0, // No commentsCount in Post, fallback to 0
            isVerified: post.isVerifiedLocation,
            post: post,
            distance: post.distance.toString(),
            authorName: post.authorName,
          ),
        ),
      ).then((_) {
        // Resume the timer when coming back
        _resumeStoryTimer();
      });
    } catch (e) {
      if (!mounted) return; // Add mounted check
      Navigator.of(context).pop(); // Remove loading dialog
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading post details: $e')),
      );
      _resumeStoryTimer();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTapDown: (details) {
          // Determine tap position for navigation
          final screenWidth = MediaQuery.of(context).size.width;
          final tapPosition = details.globalPosition.dx;

          // Left third of screen goes to previous story
          if (tapPosition < screenWidth / 3) {
            _previousStory();
          }
          // Right two-thirds goes to next story
          else {
            _nextStory();
          }
        },
        onLongPressStart: (_) {
          // Pause progress when user long presses
          _pauseStoryTimer();
        },
        onLongPressEnd: (_) {
          // Resume progress when user releases long press
          _resumeStoryTimer();
        },
        child: Stack(
          children: [
            // Page view for multiple stories
            PageView.builder(
              controller: _pageController,
              physics:
                  const NeverScrollableScrollPhysics(), // Disable swiping, use taps instead
              itemCount: widget.stories.length,
              onPageChanged: (index) {
                setState(() {
                  _currentIndex = index;
                });
                _resetStoryTimer();
              },
              itemBuilder: (context, index) {
                final story = widget.stories[index];
                return _buildStoryContent(story);
              },
            ),

            // Progress indicators
            SafeArea(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
                child: Row(
                  children: List.generate(
                    widget.stories.length,
                    (index) => Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2.0),
                        child: LinearProgressIndicator(
                          value: index < _currentIndex
                              ? 1.0
                              : (index == _currentIndex
                                  ? _progressController.value
                                  : 0.0),
                          backgroundColor: Colors.white.withOpacity(0.3),
                          valueColor:
                              const AlwaysStoppedAnimation<Color>(Colors.white),
                          minHeight: 2.5,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // User info at top
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    // User avatar with improved error handling and debugging
                    Stack(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: ThemeConstants.primaryColor,
                            border: Border.all(color: Colors.white, width: 1.5),
                          ),
                          child: ClipOval(
                            child: widget.userImageUrl.isNotEmpty
                                ? FadeInImage.assetNetwork(
                                    placeholder:
                                        'assets/images/placeholder_avatar.png', // Add this placeholder asset or use a transparent one
                                    image: _getFixedProfileUrl(
                                        widget.userImageUrl),
                                    fit: BoxFit.cover,
                                    fadeInDuration:
                                        const Duration(milliseconds: 200),
                                    imageErrorBuilder:
                                        (context, error, stackTrace) {
                                      // Enhanced error logging for debugging
                                      print('\n⚠️ PROFILE IMAGE ERROR ⚠️');
                                      print('❌ Error type: $error');
                                      print(
                                          '📸 Attempted URL: ${_getFixedProfileUrl(widget.userImageUrl)}');
                                      print('👤 User: ${widget.username}');

                                      // Special handling for Layla to help debug her profile picture issues
                                      if (widget.username
                                          .toLowerCase()
                                          .contains('layla')) {
                                        print('⚡ LAYLA PROFILE DEBUG:');
                                        print(
                                            '1. Original URL: ${widget.userImageUrl}');
                                        print(
                                            '2. Base URL being used: ${ApiUrls.baseUrl}');
                                        print(
                                            '3. Expected correct path: ${ApiUrls.baseUrl}/media/profile_pics/13/${widget.userImageUrl.split('/').last}');
                                        print('4. Stack trace: $stackTrace');
                                      }

                                      // Get initials for the avatar
                                      String initials = '';
                                      if (widget.username.isNotEmpty) {
                                        initials = widget.username
                                            .trim()
                                            .split(' ')
                                            .map((part) => part.isNotEmpty
                                                ? part[0].toUpperCase()
                                                : '')
                                            .join('')
                                            .substring(
                                                0,
                                                widget.username
                                                            .trim()
                                                            .split(' ')
                                                            .length >
                                                        1
                                                    ? 2
                                                    : 1);
                                      }

                                      return Container(
                                        color: ThemeConstants.primaryColor,
                                        alignment: Alignment.center,
                                        child: initials.isNotEmpty
                                            ? Text(
                                                initials,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16,
                                                ),
                                              )
                                            : const Icon(Icons.person,
                                                color: Colors.white),
                                      );
                                    },
                                  )
                                : Container(
                                    color: ThemeConstants.primaryColor,
                                    alignment: Alignment.center,
                                    child: _buildInitialsAvatar(),
                                  ),
                          ),
                        ),
                        // Show admin badge directly on the avatar if user is an admin
                        if (widget.isUserAdmin == true)
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(1),
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.verified_user,
                                color: Colors.blue,
                                size: 12,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(width: 10),
                    // Username
                    Row(
                      children: [
                        Text(
                          widget.username,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        // Only show admin badge if user is actually an admin
                        if (widget.isUserAdmin ==
                            true) // Explicit check for true value
                          Padding(
                            padding: const EdgeInsets.only(left: 4.0),
                            child: Icon(
                              Icons.verified_user,
                              color: Colors.blue,
                              size: 14,
                            ),
                          ),
                      ],
                    ),
                    // Time
                    const SizedBox(width: 8),
                    Builder(builder: (context) {
                      // Format the time to be more user-friendly
                      String formattedTime = '';
                      try {
                        final timeString =
                            widget.stories[_currentIndex]['time'] ?? '';
                        formattedTime = _formatTimeString(timeString);
                      } catch (e) {
                        formattedTime = '';
                      }

                      return Text(
                        formattedTime,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 12,
                        ),
                      );
                    }),
                    const Spacer(),
                    // Close button
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
            ),

            // Action buttons at bottom
            SafeArea(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(
                      bottom: 36.0), // Restored to original padding
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // View full post button
                      _buildActionButton(
                        icon: Icons.article_outlined,
                        label: 'Full Post',
                        onTap: _navigateToFullPost,
                      ),

                      // Location button
                      _buildActionButton(
                        icon: Icons.location_on_outlined,
                        label: 'Location',
                        onTap: () {
                          // Show location sheet without map controller
                          _pauseStoryTimer();
                          _showLocationSheet(
                              context, widget.stories[_currentIndex]);
                        },
                      ),

                      // React button
                      _buildActionButton(
                        icon: Icons.thumb_up_alt_outlined,
                        label: 'React',
                        onTap: () {
                          _showReactionOptions(context);
                        },
                      ),

                      // Share button
                      _buildActionButton(
                        icon: Icons.share_outlined,
                        label: 'Share',
                        onTap: () {
                          // Share functionality
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Location indicator in the corner
            _buildLocationIndicator(),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 45,
            height: 45,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.6),
              borderRadius: BorderRadius.circular(22.5),
              border:
                  Border.all(color: Colors.white.withOpacity(0.5), width: 1.5),
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w500,
              shadows: [
                Shadow(
                  color: Colors.black54,
                  offset: Offset(0, 1),
                  blurRadius: 2,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationIndicator() {
    final story = widget.stories[_currentIndex];
    // Try to get location from different possible fields
    String location = '';

    // Check if the post has direct location
    if (story.containsKey('location') && story['location'] != null) {
      if (story['location'] is String) {
        location = story['location'];
      } else if (story['location'] is Map) {
        final locationMap = story['location'] as Map;
        // Try to extract address from location object
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
            location =
                'Near (${coords['latitude']?.toStringAsFixed(4)}, ${coords['longitude']?.toStringAsFixed(4)})';
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
        // If parsing fails, try to use the raw values
        location = 'Near (${story['latitude']}, ${story['longitude']})';
      }
    }

    // Process and validate category
    String category = '';
    if (story.containsKey('category') &&
        story['category'] != null &&
        story['category'].toString() != 'null' &&
        story['category'].toString().isNotEmpty) {
      category = story['category'].toString().toLowerCase();

      // Check if this category exists in our list, if not use 'other'
      if (!CategoryUtils.allCategories.contains(category)) {
        debugPrint(
            'Warning: Unknown category in story: $category. Using "other" as fallback.');
        category = 'other';
      }
    }

    bool hasCategory = category.isNotEmpty;
    bool hasLocation = location.isNotEmpty;

    // If neither location nor category is available, return empty widget
    if (!hasLocation && !hasCategory) {
      return const SizedBox();
    }

    // Create the widgets to show
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(top: 70, right: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Place location and category in a row when both exist
            if (hasLocation && hasCategory)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Category indicator (left) - no action on tap
                  Container(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: CategoryUtils.getCategoryColor(
                                category.toLowerCase())
                            .withOpacity(0.8),
                        borderRadius: const BorderRadius.horizontal(
                          left: Radius.circular(12),
                          right: Radius.zero,
                        ),
                        border: Border.all(
                            color: Colors.white.withOpacity(0.2), width: 0.8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            CategoryUtils.getCategoryIcon(
                                category.toLowerCase()),
                            color: Colors.white,
                            size: 12,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            CategoryUtils.getCategoryDisplayName(
                                category.toLowerCase()),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Location indicator (right)
                  GestureDetector(
                    onTap: () {
                      _pauseStoryTimer();
                      _showLocationSheet(context, story);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        borderRadius: const BorderRadius.horizontal(
                          left: Radius.zero,
                          right: Radius.circular(12),
                        ),
                        border: Border.all(
                            color: Colors.white.withOpacity(0.2), width: 0.8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.place,
                            color: Colors.white,
                            size: 12,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            location.length > 15
                                ? '${location.substring(0, 12)}...'
                                : location,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              )
            // If only one exists, show it individually
            else if (hasLocation)
              GestureDetector(
                onTap: () {
                  _pauseStoryTimer();
                  _showLocationSheet(context, story);
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: Colors.white.withOpacity(0.2), width: 1),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.place,
                        color: ThemeConstants.primaryColor,
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          location.length > 25
                              ? '${location.substring(0, 22)}...'
                              : location,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else if (hasCategory)
              Container(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color:
                        CategoryUtils.getCategoryColor(category.toLowerCase())
                            .withOpacity(0.8),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: Colors.white.withOpacity(0.2), width: 0.8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        CategoryUtils.getCategoryIcon(category.toLowerCase()),
                        color: Colors.white,
                        size: 12,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        CategoryUtils.getCategoryDisplayName(
                            category.toLowerCase()),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
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

  void _showLocationSheet(BuildContext context, Map<String, dynamic> story) {
    // Try to get location from different possible fields
    String location = 'Unknown location';
    double? latitude;
    double? longitude;
    String category = story['category']?.toString().toLowerCase() ?? 'other';

    // Validate category
    if (!CategoryUtils.allCategories.contains(category)) {
      category = 'other';
    }

    // Check if the post has direct location
    if (story.containsKey('location') && story['location'] != null) {
      if (story['location'] is String) {
        location = story['location'];
      } else if (story['location'] is Map) {
        final locationMap = story['location'] as Map;
        // Try to extract address from location object
        if (locationMap.containsKey('address') &&
            locationMap['address'] != null &&
            locationMap['address'] != 'null') {
          location = locationMap['address'].toString();
        } else if (locationMap.containsKey('name') &&
            locationMap['name'] != null &&
            locationMap['name'] != 'null') {
          location = locationMap['name'].toString();
        }

        // Try to extract coordinates
        if (locationMap.containsKey('coordinates')) {
          var coords = locationMap['coordinates'];
          if (coords is Map) {
            if (coords.containsKey('latitude') &&
                coords.containsKey('longitude')) {
              try {
                latitude = double.parse(coords['latitude'].toString());
                longitude = double.parse(coords['longitude'].toString());
              } catch (e) {
                debugPrint('Error parsing coordinates: $e');
              }
            }
          }
        }
      }
    }

    // Try direct latitude and longitude fields if location is still unknown
    // or if we couldn't extract coordinates from the location object
    if ((location == 'Unknown location' ||
            latitude == null ||
            longitude == null) &&
        story.containsKey('latitude') &&
        story.containsKey('longitude') &&
        story['latitude'] != null &&
        story['longitude'] != null) {
      try {
        latitude = double.parse(story['latitude'].toString());
        longitude = double.parse(story['longitude'].toString());

        // Only update location string if it was unknown
        if (location == 'Unknown location') {
          location =
              'Near (${latitude.toStringAsFixed(4)}, ${longitude.toStringAsFixed(4)})';
        }
      } catch (e) {
        debugPrint('Error parsing direct lat/lng: $e');
      }
    }

    // If still unknown and we have a title, use it as a fallback
    if (location == 'Unknown location' &&
        story.containsKey('title') &&
        story['title'] != null &&
        story['title'].toString().isNotEmpty) {
      location = "Near: ${story['title']}";
    }

    // Format for display
    String iconToShow;
    if (location.toLowerCase().contains('unknown')) {
      iconToShow = 'location_searching';
      location = 'Location information unavailable';
    } else if (location.toLowerCase().contains('near')) {
      iconToShow = 'place_outlined';
    } else {
      iconToShow = 'location_on';
    }

    _pauseStoryTimer(); // Ensure timer is paused

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.4,
        minChildSize: 0.3,
        maxChildSize: 0.6,
        builder: (context, scrollController) {
          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                // Handle
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(top: 8),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),

                // Header
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Icon(
                        iconToShow == 'location_searching'
                            ? Icons.location_searching
                            : iconToShow == 'place_outlined'
                                ? Icons.place_outlined
                                : Icons.location_on,
                        color: CategoryUtils.getCategoryColor(category),
                        size: 24,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          location,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          Navigator.pop(context);
                          _resumeStoryTimer();
                        },
                      ),
                    ],
                  ),
                ),

                const Divider(),

                // Map preview with category-specific marker
                Expanded(
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      image: latitude != null && longitude != null
                          ? DecorationImage(
                              image: NetworkImage(
                                  'https://maps.googleapis.com/maps/api/staticmap?center=$latitude,$longitude&zoom=14&size=600x300&maptype=roadmap&markers=color:red%7C$latitude,$longitude&key=AIzaSyBVNzKL6mC5K9cIV8ex1t0jWoHnqTc5zY8'),
                              fit: BoxFit.cover,
                              opacity: 0.7,
                            )
                          : null,
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Use CategoryUtils to build a proper category marker
                          latitude != null && longitude != null
                              ? CategoryUtils.buildLiveUAMapMarker(category,
                                  isSelected: true)
                              : Icon(
                                  iconToShow == 'location_searching'
                                      ? Icons.location_searching
                                      : iconToShow == 'place_outlined'
                                          ? Icons.place_outlined
                                          : Icons.location_on,
                                  size: 64,
                                  color:
                                      CategoryUtils.getCategoryColor(category),
                                ),

                          if (latitude != null && longitude != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(
                                'Coordinates: (${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)})',
                                style: TextStyle(
                                  color: Colors.grey.shade700,
                                  fontSize: 12,
                                ),
                              ),
                            ),

                          const SizedBox(height: 20),
                          Text(
                            location,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              fontSize: 16,
                              color: Colors.black87,
                              shadows: [
                                Shadow(
                                  color: Colors.white.withOpacity(0.8),
                                  blurRadius: 3,
                                  offset: const Offset(0, 0),
                                )
                              ],
                            ),
                          ),

                          const SizedBox(height: 20),
                          ElevatedButton.icon(
                            onPressed: () {
                              Navigator.pop(context);
                              _navigateToFullPost();
                            },
                            icon: Icon(CategoryUtils.getCategoryIcon(category)),
                            label: const Text("View Full Post"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  CategoryUtils.getCategoryColor(category),
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    ).then((_) {
      _resumeStoryTimer();
    });
  }

  void _showReactionOptions(BuildContext context) {
    _pauseStoryTimer();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        contentPadding:
            const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "React to this post",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildReactionButton(
                    Icons.thumb_up, "Useful", ThemeConstants.primaryColor),
                _buildReactionButton(Icons.favorite, "Like", Colors.red),
                _buildReactionButton(
                    Icons.visibility, "Seen", ThemeConstants.green),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildReactionButton(
                    Icons.help_outline, "Question", Colors.amber),
                _buildReactionButton(
                    Icons.warning_amber, "Warning", Colors.orange),
                _buildReactionButton(Icons.block, "Not Useful", Colors.grey),
              ],
            ),
          ],
        ),
      ),
    ).then((_) {
      _resumeStoryTimer();
    });
  }

  Widget _buildReactionButton(IconData icon, String label, Color color) {
    return InkWell(
      onTap: () {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Reacted with: $label'),
            duration: const Duration(seconds: 1),
          ),
        );
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: color,
              size: 28,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
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

  // Check if the path is a file path rather than URL
  bool _isFilePath(String path) {
    return path.startsWith('/') ||
        path.startsWith('file:/') ||
        !path.contains('://');
  }

  // Extract thumbnail URL from video URL or post data - Direct server approach
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
        debugPrint('🎥 Story: Constructed server thumbnail URL: $thumbnailUrl');
        return thumbnailUrl;
      } else if (videoUrl.contains('attachments/image/') &&
          videoUrl.endsWith('.mp4')) {
        int pathIndex = videoUrl.indexOf('attachments/image/');
        relativePath = videoUrl.substring(pathIndex);
        relativePath = relativePath.replaceAll(
            'attachments/image/', 'attachments/thumbnails/');
        relativePath = relativePath.replaceAll('.mp4', '_thumb.jpg');
        String thumbnailUrl = '${ApiUrls.baseUrl}/$relativePath';
        debugPrint(
            '🎥 Story: Constructed server thumbnail URL for misplaced video: $thumbnailUrl');
        return thumbnailUrl;
      }
    } catch (e) {
      debugPrint('🎥 Story: Error extracting thumbnail URL: $e');
    }
    return null;
  }

  // Build video thumbnail with play overlay - Server-first approach
  Widget _buildVideoThumbnail(String videoUrl, {BoxFit fit = BoxFit.contain}) {
    String? thumbnailUrl = _extractThumbnailUrl(videoUrl);

    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.grey[800]!,
            Colors.grey[900]!,
          ],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Server thumbnail first, then client-side generation as fallback
          if (thumbnailUrl != null && thumbnailUrl.isNotEmpty)
            Image.network(
              thumbnailUrl,
              fit: fit,
              width: double.infinity,
              height: double.infinity,
              loadingBuilder: (context, child, progress) {
                if (progress == null) return child;
                return _buildVideoLoading();
              },
              errorBuilder: (context, error, stackTrace) {
                debugPrint(
                    '🎥 Story: Server thumbnail failed, trying client generation: $error, URL: $thumbnailUrl');
                return FutureBuilder<Widget>(
                  future: _buildVideoThumbnailWidget(videoUrl, fit),
                  builder: (context, snapshot) {
                    if (snapshot.hasData) {
                      return snapshot.data!;
                    } else if (snapshot.hasError) {
                      debugPrint(
                          '🎥 Story: Client thumbnail also failed: ${snapshot.error}');
                      return _buildVideoPattern();
                    } else {
                      return _buildVideoLoading();
                    }
                  },
                );
              },
            )
          else
            FutureBuilder<Widget>(
              future: _buildVideoThumbnailWidget(videoUrl, fit),
              builder: (context, snapshot) {
                if (snapshot.hasData) {
                  return snapshot.data!;
                } else if (snapshot.hasError) {
                  debugPrint(
                      '🎥 Story: Video thumbnail generation failed: ${snapshot.error}');
                  return _buildVideoPattern();
                } else {
                  return _buildVideoLoading();
                }
              },
            ),

          // Play button overlay
          Center(
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.8),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.4),
                    blurRadius: 12,
                    spreadRadius: 3,
                  ),
                ],
              ),
              child: const Icon(
                Icons.play_arrow,
                color: Colors.white,
                size: 56,
              ),
            ),
          ),

          // Video indicator badge
          Positioned(
            top: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.9),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 6,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.videocam,
                    color: Colors.white,
                    size: 18,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'VIDEO',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Build video thumbnail widget with multiple fallback strategies
  Future<Widget> _buildVideoThumbnailWidget(String videoUrl, BoxFit fit) async {
    try {
      final thumbnailData = await _generateVideoThumbnail(videoUrl);
      if (thumbnailData != null && thumbnailData.isNotEmpty) {
        debugPrint('🎥 Story: Successfully generated video thumbnail');
        return SizedBox(
          width: double.infinity,
          height: double.infinity,
          child: Image.memory(
            thumbnailData,
            fit: fit,
            width: double.infinity,
            height: double.infinity,
            errorBuilder: (context, error, stackTrace) {
              debugPrint('🎥 Story: Error displaying thumbnail: $error');
              return _buildVideoPattern();
            },
          ),
        );
      }
    } catch (e) {
      debugPrint('🎥 Story: Video thumbnail generation failed: $e');
    }
    return _buildVideoPattern();
  }

  // Generate video thumbnail with improved error handling
  Future<Uint8List?> _generateVideoThumbnail(String videoUrl) async {
    try {
      String processedVideoUrl = _getFixedStoryImageUrl(videoUrl);
      debugPrint('🎥 Story: Processing video URL: $processedVideoUrl');

      List<Map<String, dynamic>> attempts = [
        {'timeMs': 1000, 'quality': 85},
        {'timeMs': 2000, 'quality': 90},
        {'timeMs': 500, 'quality': 80},
        {'timeMs': 0, 'quality': 85},
      ];

      for (var attempt in attempts) {
        try {
          debugPrint(
              '🎥 Story: Attempting thumbnail generation with timeMs: ${attempt['timeMs']}, quality: ${attempt['quality']}');

          final uint8list = await VideoThumbnail.thumbnailData(
            video: processedVideoUrl,
            imageFormat: ImageFormat.JPEG,
            maxWidth: 800,
            maxHeight: 600,
            timeMs: attempt['timeMs'],
            quality: attempt['quality'],
          );

          if (uint8list != null && uint8list.isNotEmpty) {
            debugPrint(
                '🎥 Story: Success! Generated thumbnail with ${uint8list.length} bytes');
            return uint8list;
          }
        } catch (e) {
          debugPrint('🎥 Story: Attempt failed: $e');
          continue;
        }
      }

      debugPrint('🎥 Story: All thumbnail generation attempts failed');
      return null;
    } catch (e) {
      debugPrint('🎥 Story: Critical error in thumbnail generation: $e');
      return null;
    }
  }

  // Enhanced media building with video playback support
  Widget _buildStoryMedia(String? mediaUrl, {BoxFit fit = BoxFit.contain}) {
    if (mediaUrl == null || mediaUrl.isEmpty) {
      return _buildPlaceholderImage();
    }

    // Check if it's a video file
    if (_isVideoFile(mediaUrl)) {
      return _buildVideoPlayer(mediaUrl, fit: fit);
    }

    // Check if it's a file path or network URL
    if (_isFilePath(mediaUrl)) {
      return SizedBox(
        width: double.infinity,
        height: double.infinity,
        child: Image.file(
          File(mediaUrl),
          fit: fit,
          width: double.infinity,
          height: double.infinity,
          errorBuilder: (context, error, stackTrace) {
            debugPrint('🎥 Story: Error loading file image: $error');
            return _buildPlaceholderImage();
          },
        ),
      );
    } else {
      String processedUrl = _getFixedStoryImageUrl(mediaUrl);
      return SizedBox(
        width: double.infinity,
        height: double.infinity,
        child: Image.network(
          processedUrl,
          fit: fit,
          width: double.infinity,
          height: double.infinity,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Center(
              child: CircularProgressIndicator(
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded /
                        loadingProgress.expectedTotalBytes!
                    : null,
                color: ThemeConstants.primaryColor,
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) {
            debugPrint('🎥 Story: Error loading network image: $error');
            return _buildPlaceholderImage();
          },
        ),
      );
    }
  }

  // Build actual video player for stories
  Widget _buildVideoPlayer(String videoUrl, {BoxFit fit = BoxFit.contain}) {
    final controller = _videoControllers[_currentIndex];

    if (_isVideoInitializing) {
      return Container(
        width: double.infinity,
        height: double.infinity,
        color: Colors.black,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                color: Colors.white,
              ),
              const SizedBox(height: 16),
              Text(
                'Loading video...',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (controller == null || !controller.value.isInitialized) {
      // Fallback to thumbnail if video fails to load
      return _buildVideoThumbnail(videoUrl, fit: fit);
    }

    return Container(
      width: double.infinity,
      height: double.infinity,
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Video player
          Center(
            child: AspectRatio(
              aspectRatio: controller.value.aspectRatio,
              child: VideoPlayer(controller),
            ),
          ),

          // Video indicator badge
          Positioned(
            top: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.8),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 6,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.videocam,
                    color: Colors.white,
                    size: 16,
                  ),
                  SizedBox(width: 6),
                  Text(
                    'VIDEO',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Video controls overlay (shows play/pause state)
          if (!controller.value.isPlaying && _isPaused)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.8),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.pause,
                    color: Colors.white,
                    size: 48,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // Helper to build consistent placeholder for missing images
  Widget _buildPlaceholderImage() {
    return Container(
      color: Colors.grey[800],
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.image_not_supported,
              size: 64,
              color: Colors.white.withOpacity(0.5),
            ),
            const SizedBox(height: 12),
            Text(
              "Media unavailable",
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStoryContent(Map<String, dynamic> story) {
    return Container(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Story media (image or video)
          Center(
            child: _buildStoryMedia(story['imageUrl']),
          ),

          // Story content overlay
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withOpacity(0.3),
                    Colors.black.withOpacity(0.8),
                  ],
                  stops: const [0.0, 0.4, 0.8],
                ),
              ),
              padding: const EdgeInsets.fromLTRB(24.0, 48.0, 24.0, 120.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Honesty rating at top
                  Row(
                    children: [
                      _buildHonestyPill(
                          story['honesty_score'] ?? story['honesty'] ?? 0),
                      const Spacer(),
                      if ((story['upvotes'] ?? 0) > 0)
                        _buildUpvotesPill(story['upvotes'] ?? 0),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Title
                  Text(
                    story['title'] ?? '',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      shadows: [
                        Shadow(
                          color: Colors.black54,
                          offset: Offset(0, 1),
                          blurRadius: 3,
                        ),
                      ],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  // Description - only show 1 line
                  Text(
                    story['description'] ?? '',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 14,
                      shadows: const [
                        Shadow(
                          color: Colors.black54,
                          offset: Offset(0, 1),
                          blurRadius: 2,
                        ),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUpvotesPill(int upvotes) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.arrow_upward,
            size: 12,
            color: Colors.white,
          ),
          const SizedBox(width: 4),
          Text(
            '$upvotes',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHonestyPill(dynamic rating) {
    // Ensure rating is an integer
    int honestyRating = 0;

    if (rating is int) {
      honestyRating = rating;
    } else if (rating is double) {
      honestyRating = rating.toInt();
    } else if (rating is String) {
      try {
        honestyRating = int.parse(rating);
      } catch (e) {
        honestyRating = 0;
      }
    }

    // Ensure rating is between 0 and 100
    honestyRating = honestyRating.clamp(0, 100);

    Color color;
    if (honestyRating >= 80) {
      color = ThemeConstants.green;
    } else if (honestyRating >= 60) {
      color = ThemeConstants.orange;
    } else {
      color = ThemeConstants.red;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.verified_user,
            size: 12,
            color: Colors.white,
          ),
          const SizedBox(width: 4),
          Text(
            '$honestyRating% ${TextStrings.honestyRating}',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  // Ensures profile image URLs are valid and complete, and logs the result
  String _getFixedProfileUrl(String url) {
    if (url.isEmpty) return '';
    String finalUrl = url;
    if (url.startsWith('http://') || url.startsWith('https://')) {
      finalUrl = url;
    } else if (url.startsWith('/')) {
      // Use ApiUrls.baseUrl for relative URLs
      finalUrl = ApiUrls.baseUrl + url;
    }
    // Remove any double slashes after the protocol (except for '://')
    finalUrl = finalUrl.replaceFirstMapped(
      RegExp(r'^(https?:\/\/)(.+)'),
      (match) =>
          match.group(1)! + match.group(2)!.replaceAll(RegExp(r'\/\/'), '/'),
    );
    // Debug log
    debugPrint('[StoryViewer] Profile image URL: $finalUrl');
    return finalUrl;
  }

  // Build an avatar with the user's initials for when there's no profile picture
  Widget _buildInitialsAvatar() {
    String initials = '';
    if (widget.username.isNotEmpty) {
      final parts = widget.username.trim().split(' ');
      initials = parts
          .map((part) => part.isNotEmpty ? part[0].toUpperCase() : '')
          .join();
      if (initials.length > 2) {
        initials = initials.substring(0, 2);
      }
    }
    return Text(
      initials.isNotEmpty ? initials : '?',
      style: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.bold,
        fontSize: 16,
      ),
    );
  }

  @override
  void dispose() {
    // Dispose all video controllers
    for (var controller in _videoControllers.values) {
      controller?.dispose();
    }
    _videoControllers.clear();

    _pageController.dispose();
    _progressController.dispose();
    _storyTimer?.cancel();
    super.dispose();
  }

  // Create a nice video pattern background
  Widget _buildVideoPattern() {
    return Container(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.center,
          radius: 1.0,
          colors: [
            Colors.grey[700]!,
            Colors.grey[900]!,
          ],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.movie_creation_outlined,
              size: 80,
              color: Colors.white.withOpacity(0.7),
            ),
            const SizedBox(height: 12),
            Text(
              'Video Story',
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Fallback widget for video thumbnail loading
  Widget _buildVideoLoading() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: Colors.grey[800],
      child: const Center(
        child: CircularProgressIndicator(
          color: Colors.white,
        ),
      ),
    );
  }
}
