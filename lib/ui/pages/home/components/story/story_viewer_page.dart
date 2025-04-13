import 'package:flutter/material.dart';
import 'package:flutter_application_2/constants/theme_constants.dart';
import 'package:flutter_application_2/constants/text_strings.dart';
import 'package:flutter_application_2/ui/pages/home/components/post_detail/post_detail_page.dart';
import 'dart:async';

class StoryViewerPage extends StatefulWidget {
  final List<Map<String, dynamic>> stories;
  final String username;
  final String userImageUrl;
  final bool isUserVerified;

  const StoryViewerPage({
    super.key,
    required this.stories,
    required this.username,
    required this.userImageUrl,
    this.isUserVerified = false,
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

  // Story display duration in seconds
  final int _storyDuration = 5;

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

    // Start the progress for the first story
    _startStoryTimer();
  }

  void _startStoryTimer() {
    _progressController.forward(from: 0.0);
  }

  void _pauseStoryTimer() {
    if (!_isPaused) {
      _progressController.stop();
      _isPaused = true;
    }
  }

  void _resumeStoryTimer() {
    if (_isPaused) {
      _progressController.forward();
      _isPaused = false;
    }
  }

  void _resetStoryTimer() {
    _progressController.reset();
    _progressController.forward();
    _isPaused = false;
  }

  void _nextStory() {
    if (_currentIndex < widget.stories.length - 1) {
      setState(() {
        _currentIndex++;
        _pageController.animateToPage(
          _currentIndex,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      });
      _resetStoryTimer();
    } else {
      // Last story completed, pop back to previous screen
      Navigator.of(context).pop();
    }
  }

  void _previousStory() {
    if (_currentIndex > 0) {
      setState(() {
        _currentIndex--;
        _pageController.animateToPage(
          _currentIndex,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      });
      _resetStoryTimer();
    }
  }

  void _navigateToFullPost() {
    // Pause the timer when navigating away
    _pauseStoryTimer();

    final story = widget.stories[_currentIndex];
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PostDetailPage(
          title: story['title'] ?? '',
          description: story['description'] ?? '',
          imageUrl: story['imageUrl'] ?? '',
          location: story['location'] ?? '',
          time: story['time'] ?? '',
          honesty: story['honesty'] ?? 0,
          upvotes: story['upvotes'] ?? 0,
          comments: story['comments'] ?? 0,
          isVerified: story['isVerified'] ?? false,
        ),
      ),
    ).then((_) {
      // Resume the timer when coming back
      _resumeStoryTimer();
    });
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
                    // User avatar
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: ThemeConstants.primaryColor,
                      backgroundImage: NetworkImage(widget.userImageUrl),
                      onBackgroundImageError: (exception, stackTrace) {},
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
                        if (widget.isUserVerified)
                          Padding(
                            padding: const EdgeInsets.only(left: 4.0),
                            child: Icon(
                              Icons.verified,
                              color: ThemeConstants.primaryColor,
                              size: 14,
                            ),
                          ),
                      ],
                    ),
                    // Time
                    const SizedBox(width: 8),
                    Text(
                      widget.stories[_currentIndex]['time'] ?? '',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 12,
                      ),
                    ),
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

            // Action buttons at bottom - Increased bottom padding
            SafeArea(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 36.0),
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
                          _showLocationSheet(context, widget.stories[_currentIndex]);
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
    final location = story['location'] ?? '';

    return SafeArea(
      child: Align(
        alignment: Alignment.topRight,
        child: GestureDetector(
          onTap: () {
            _pauseStoryTimer();
            _showLocationSheet(context, story);
          },
          child: Container(
            margin: const EdgeInsets.only(top: 64, right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.6),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.place,
                  color: Colors.white,
                  size: 14,
                ),
                const SizedBox(width: 4),
                Text(
                  location,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showLocationSheet(BuildContext context, Map<String, dynamic> story) {
    final location = story['location'] ?? 'Unknown location';

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        builder: (context, scrollController) {
          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                // Handle
                Container(
                  margin: const EdgeInsets.only(top: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                // Header
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      const Icon(Icons.location_on,
                          color: ThemeConstants.primaryColor),
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

                // Static map preview instead of interactive map
                Expanded(
                  child: Container(
                    width: double.infinity,
                    color: Colors.grey.shade200,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.map,
                            size: 64,
                            color: ThemeConstants.primaryColor,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            "Map preview for $location",
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton.icon(
                            onPressed: () {
                              Navigator.pop(context);
                              _navigateToFullPost();
                            },
                            icon: const Icon(Icons.article_outlined),
                            label: const Text("View Full Post"),
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
        contentPadding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
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

  Widget _buildStoryContent(Map<String, dynamic> story) {
    return Container(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Story image
          Center(
            child: Image.network(
              story['imageUrl'] ?? '',
              fit: BoxFit.contain,
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
              errorBuilder: (context, error, stackTrace) => Center(
                child: Icon(
                  Icons.broken_image,
                  size: 64,
                  color: Colors.white.withOpacity(0.5),
                ),
              ),
            ),
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
              padding: const EdgeInsets.fromLTRB(24.0, 48.0, 24.0, 160.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Honesty rating at top
                  Row(
                    children: [
                      _buildHonestyPill(story['honesty'] ?? 0),
                      const Spacer(),
                      // Added upvotes indicator for additional context
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

  Widget _buildHonestyPill(int rating) {
    Color color;
    if (rating >= 80) {
      color = ThemeConstants.green;
    } else if (rating >= 60) {
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
            '$rating% ${TextStrings.honestyRating}',
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

  @override
  void dispose() {
    _pageController.dispose();
    _progressController.dispose();
    _storyTimer?.cancel();
    super.dispose();
  }
}