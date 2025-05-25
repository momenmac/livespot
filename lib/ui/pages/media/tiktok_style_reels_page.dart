import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_player/video_player.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';

import 'package:flutter_application_2/constants/theme_constants.dart';
import 'package:flutter_application_2/models/post.dart';
import 'package:flutter_application_2/providers/posts_provider.dart';
import 'package:flutter_application_2/services/api/account/api_urls.dart';
import 'package:flutter_application_2/ui/widgets/responsive_snackbar.dart';
import 'package:flutter_application_2/ui/pages/home/components/post_detail/post_detail_page.dart';
import 'package:flutter_application_2/utils/time_formatter.dart';

class TikTokStyleReelsPage extends StatefulWidget {
  final Post post;
  final int initialIndex;

  const TikTokStyleReelsPage({
    Key? key,
    required this.post,
    this.initialIndex = 0,
  }) : super(key: key);

  @override
  State<TikTokStyleReelsPage> createState() => _TikTokStyleReelsPageState();
}

class _TikTokStyleReelsPageState extends State<TikTokStyleReelsPage> {
  late PageController _pageController;
  List<String> _mediaUrls = [];
  List<Post> _threadPosts = [];
  Map<int, Post> _mediaIndexToPost = {}; // Map media index to its corresponding post
  bool _isLoadingThread = true;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _currentPage = widget.initialIndex;
    _pageController = PageController(
      initialPage: _currentPage,
      viewportFraction: 1.0,
      keepPage: true,
    );
    
    // Enable immersive mode for better viewing experience
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
    
    // Load thread data and media URLs
    _loadThreadData();
  }

  @override
  void dispose() {
    _pageController.dispose();
    // Restore system UI when leaving the page
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _initMediaUrls() {
    _mediaUrls = [];
    _mediaIndexToPost = {};
    int mediaIndex = 0;
    
    // Collect media URLs from all posts in the thread
    for (final post in _threadPosts) {
      List<String> postMediaUrls = [];
      
      if (post.mediaUrls.isEmpty && post.imageUrl.isNotEmpty) {
        // If no media URLs but has an image URL, use that
        postMediaUrls = [post.imageUrl];
      } else {
        // Otherwise use the media URLs list
        postMediaUrls = List.from(post.mediaUrls);
      }
      
      // Make sure all URLs are properly formatted
      postMediaUrls = postMediaUrls.map((url) => _getFixedMediaUrl(url)).toList();
      
      // Remove any empty URLs
      postMediaUrls.removeWhere((url) => url.isEmpty);
      
      // Add this post's media to the complete list and map each media index to its post
      for (final mediaUrl in postMediaUrls) {
        _mediaUrls.add(mediaUrl);
        _mediaIndexToPost[mediaIndex] = post;
        mediaIndex++;
      }
    }
    
    if (_mediaUrls.isEmpty) {
      // Add a placeholder if no valid media is found
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ResponsiveSnackBar.showInfo(
            context: context,
            message: 'No media found in this thread',
          );
        }
      });
    }
  }

  String _getFixedMediaUrl(String? url) {
    if (url == null || url.isEmpty) return '';
    
    // Already absolute URL
    if (url.startsWith('http://') || url.startsWith('https://')) {
      // Fix localhost URLs
      if (url.contains('localhost') || url.contains('127.0.0.1')) {
        return url.replaceFirst(RegExp(r'http://localhost:[0-9]+|http://127.0.0.1:[0-9]+'), ApiUrls.baseUrl);
      }
      return url;
    }
    
    // Relative path
    if (url.startsWith('/')) {
      return '${ApiUrls.baseUrl}$url';
    }
    
    return url;
  }

  bool _isVideoFile(String url) {
    final String lowerUrl = url.toLowerCase();
    return lowerUrl.contains('.mp4') ||
        lowerUrl.contains('.mov') ||
        lowerUrl.contains('.avi') ||
        lowerUrl.contains('.mkv') ||
        lowerUrl.contains('.webm');
  }

  bool _isFilePath(String path) {
    return path.startsWith('/') ||
        path.startsWith('file:/') ||
        !path.contains('://');
  }

  void _onPageChanged(int page) {
    setState(() {
      _currentPage = page;
    });
  }

  Future<void> _loadThreadData() async {
    setState(() {
      _isLoadingThread = true;
    });

    try {
      final postsProvider = Provider.of<PostsProvider>(context, listen: false);
      
      // Get all related posts for this thread
      final relatedPosts = await postsProvider.getRelatedPosts(widget.post.id);
      
      // Create the complete thread list: current post + related posts
      _threadPosts = [widget.post, ...relatedPosts];
      
      // Remove duplicates by ID (in case the current post is included in related posts)
      final Map<int, Post> uniquePosts = {};
      for (final post in _threadPosts) {
        uniquePosts[post.id] = post;
      }
      _threadPosts = uniquePosts.values.toList();
      
      // Sort posts by creation date (oldest first for chronological order)
      _threadPosts.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      
      // Now collect media URLs from all posts in the thread
      _initMediaUrls();
      
      // Find the initial index for the current post's first media item
      _updateInitialIndex();
      
    } catch (e) {
      debugPrint('Error loading thread data: $e');
      // Fallback: just use the current post
      _threadPosts = [widget.post];
      _initMediaUrls();
      
      if (mounted) {
        ResponsiveSnackBar.showError(
          context: context,
          message: 'Could not load all thread media. Showing current post only.',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingThread = false;
        });
      }
    }
  }

  void _updateInitialIndex() {
    // Find the index where the current post's media starts in the combined media list
    int mediaIndex = 0;
    for (final post in _threadPosts) {
      if (post.id == widget.post.id) {
        // Found the current post, now add the initialIndex offset
        _currentPage = mediaIndex + widget.initialIndex;
        // Recreate the page controller with the correct initial page
        _pageController.dispose();
        _pageController = PageController(
          initialPage: _currentPage,
          viewportFraction: 1.0,
          keepPage: true,
        );
        break;
      }
      
      // Count media items from this post
      List<String> postMediaUrls = [];
      if (post.mediaUrls.isEmpty && post.imageUrl.isNotEmpty) {
        postMediaUrls = [post.imageUrl];
      } else {
        postMediaUrls = List.from(post.mediaUrls);
      }
      postMediaUrls = postMediaUrls.where((url) => url.isNotEmpty).toList();
      mediaIndex += postMediaUrls.length;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onPressed: () {
              // Show additional options (share, report, etc.)
              _showOptionsBottomSheet(context);
            },
          ),
        ],
      ),
      body: _isLoadingThread
          ? const Center(
              child: CircularProgressIndicator(
                color: Colors.white,
              ),
            )
          : _mediaUrls.isEmpty
              ? const Center(
                  child: Text(
                    'No media available',
                    style: TextStyle(color: Colors.white),
                  ),
                )
              : Stack(
              children: [
                // Vertical PageView for TikTok-style scrolling
                PageView.builder(
                  scrollDirection: Axis.vertical,
                  controller: _pageController,
                  itemCount: _mediaUrls.length,
                  onPageChanged: _onPageChanged,
                  physics: const ClampingScrollPhysics(),
                  pageSnapping: true,
                  allowImplicitScrolling: false,
                  itemBuilder: (context, index) {
                    final mediaUrl = _mediaUrls[index];
                    return _buildReelItem(mediaUrl, index);
                  },
                ),
                
                // Right side interaction buttons
                Positioned(
                  right: 16,
                  bottom: 100,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildInteractionButton(
                        icon: Icons.north,
                        label: '${_getCurrentPost().upvotes}',
                        onTap: () => _handleUpvote(),
                      ),
                      _buildInteractionButton(
                        icon: Icons.comment,
                        label: '${_getCurrentPost().relatedPostsCount}',
                        onTap: () => _navigateToPostDetail(),
                      ),
                      _buildInteractionButton(
                        icon: Icons.verified_user,
                        label: '${_getCurrentPost().honestyScore}%',
                        onTap: () => _showHonestyInfo(),
                      ),
                      _buildInteractionButton(
                        icon: Icons.share,
                        label: 'Share',
                        onTap: () => _handleShare(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildReelItem(String mediaUrl, int index) {
    // Get the post that corresponds to this media item
    final currentPost = _mediaIndexToPost[index] ?? widget.post;
    
    return GestureDetector(
      // Allow vertical scrolling to pass through to PageView
      onVerticalDragUpdate: null,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Media content
          _isVideoFile(mediaUrl) 
              ? _VideoPlayer(videoUrl: mediaUrl, autoPlay: index == _currentPage)
              : _buildImageWidget(mediaUrl),

          // Content info overlay (bottom gradient)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.7),
                  ],
                ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Author row with profile pic
                Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundImage: currentPost.authorProfilePic != null && currentPost.authorProfilePic!.isNotEmpty
                          ? NetworkImage(_getFixedMediaUrl(currentPost.authorProfilePic))
                          : null,
                      backgroundColor: ThemeConstants.primaryColor,
                      child: currentPost.authorProfilePic == null || currentPost.authorProfilePic!.isEmpty
                          ? const Icon(Icons.person, color: Colors.white)
                          : null,
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              currentPost.getDisplayName(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            if (currentPost.isAuthorVerified)
                              Padding(
                                padding: const EdgeInsets.only(left: 4.0),
                                child: Icon(
                                  Icons.verified,
                                  color: ThemeConstants.primaryColor,
                                  size: 16,
                                ),
                              ),
                          ],
                        ),
                        Text(
                          '${DateTime.now().difference(currentPost.timePosted).inDays} days ago',
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Post title
                Text(
                  currentPost.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 8),
                // Post description 
                Text(
                  currentPost.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white70),
                ),
                // Tags row
                if (currentPost.tags.isNotEmpty) 
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Wrap(
                      spacing: 8,
                      children: currentPost.tags.map((tag) {
                        return Text(
                          "#$tag",
                          style: TextStyle(
                            color: ThemeConstants.primaryColor,
                            fontWeight: FontWeight.w500,
                          ),
                        );
                      }).toList(),
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

  Widget _buildInteractionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        children: [
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(25),
            child: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black.withValues(alpha: 0.3),
              ),
              child: Icon(
                icon,
                color: Colors.white,
                size: 28,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildImageWidget(String mediaUrl) {
    if (_isFilePath(mediaUrl)) {
      return Image.file(
        File(mediaUrl),
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return _buildErrorPlaceholder();
        },
      );
    } else {
      return CachedNetworkImage(
        imageUrl: mediaUrl,
        fit: BoxFit.cover,
        placeholder: (context, url) => const Center(
          child: CircularProgressIndicator(
            color: Colors.white,
          ),
        ),
        errorWidget: (context, url, error) {
          return _buildErrorPlaceholder();
        },
      );
    }
  }

  Widget _buildErrorPlaceholder() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.broken_image, color: Colors.white70, size: 64),
        const SizedBox(height: 16),
        Text(
          'Unable to load media',
          style: TextStyle(color: Colors.white70),
        ),
      ],
    );
  }

  // Helper method to get the current post for the currently visible media
  Post _getCurrentPost() {
    return _mediaIndexToPost[_currentPage] ?? widget.post;
  }

  // Handle upvote functionality
  void _handleUpvote() async {
    try {
      final postsProvider = Provider.of<PostsProvider>(context, listen: false);
      final currentPost = _getCurrentPost();
      
      await postsProvider.voteOnPost(currentPost, true);
      
      // Update the thread posts list with new vote count
      final updatedPostIndex = _threadPosts.indexWhere((p) => p.id == currentPost.id);
      if (updatedPostIndex != -1) {
        setState(() {
          // The provider should have updated the post already
        });
      }
    } catch (e) {
      if (mounted) {
        ResponsiveSnackBar.showError(
          context: context,
          message: 'Failed to upvote post',
        );
      }
    }
  }

  // Navigate to post detail page
  void _navigateToPostDetail() {
    final currentPost = _getCurrentPost();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PostDetailPage(
          post: currentPost,
          title: currentPost.title,
          description: currentPost.description,
          imageUrl: currentPost.imageUrl,
          location: currentPost.location.address ?? 'Unknown location',
          time: TimeFormatter.getTimeAgo(currentPost.timePosted),
          honesty: currentPost.honestyScore,
          upvotes: currentPost.upvotes,
          comments: currentPost.relatedPostsCount,
          isVerified: currentPost.isAuthorVerified,
          authorName: currentPost.getDisplayName(),
        ),
      ),
    );
  }

  // Handle share functionality
  void _handleShare() {
    final currentPost = _getCurrentPost();
    final shareUrl = '${ApiUrls.baseUrl}/posts/${currentPost.id}';
    final shareText = '${currentPost.title}\n\nCheck out this post: $shareUrl';
    
    Share.share(shareText, subject: currentPost.title);
  }

  // Show options bottom sheet with TikTok-like interactions
  void _showOptionsBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black.withValues(alpha: 0.8),
      builder: (BuildContext context) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.share, color: Colors.white),
                title: const Text('Share', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  // Implement share functionality
                },
              ),
              ListTile(
                leading: const Icon(Icons.flag, color: Colors.white),
                title: const Text('Report', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  // Implement report functionality
                },
              ),
              ListTile(
                leading: const Icon(Icons.info_outline, color: Colors.white),
                title: const Text('Post details', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  // Show more post details
                },
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
      },
    );
  }

  // Show honesty score information
  void _showHonestyInfo() {
    final currentPost = _getCurrentPost();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black.withValues(alpha: 0.9),
      builder: (BuildContext context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.verified_user,
                color: ThemeConstants.primaryColor,
                size: 48,
              ),
              const SizedBox(height: 16),
              Text(
                'Honesty Score',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${currentPost.honestyScore}%',
                style: TextStyle(
                  color: ThemeConstants.primaryColor,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'This score represents the community\'s assessment of how truthful and accurate this post is.',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Got it',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _VideoPlayer extends StatefulWidget {
  final String videoUrl;
  final bool autoPlay;

  const _VideoPlayer({
    required this.videoUrl,
    this.autoPlay = false,
  });

  @override
  State<_VideoPlayer> createState() => _VideoPlayerState();
}

class _VideoPlayerState extends State<_VideoPlayer> with WidgetsBindingObserver {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _isPlaying = false;
  bool _isBuffering = false;
  bool _isVisible = true; // Track visibility state

  @override
  void initState() {
    super.initState();
    _isVisible = widget.autoPlay; // Set initial visibility based on autoPlay parameter
    _initializeVideo();
    // Add observer to detect app lifecycle changes
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didUpdateWidget(covariant _VideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If autoPlay changes, update playback state and visibility
    if (widget.autoPlay != oldWidget.autoPlay) {
      _isVisible = widget.autoPlay;
      if (widget.autoPlay && _controller != null && _isInitialized && !_isPlaying) {
        _play();
      } else if (!widget.autoPlay && _isPlaying) {
        _pause();
      }
    }
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Pause video when app is in background
    if (state == AppLifecycleState.paused) {
      _pause();
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _initializeVideo() async {
    try {
      if (widget.videoUrl.startsWith('/') || widget.videoUrl.startsWith('file:')) {
        _controller = VideoPlayerController.file(File(widget.videoUrl));
      } else {
        _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));
      }

      _controller!.addListener(_videoListener);
      
      await _controller!.initialize();
      
      // Automatically start playing if autoPlay is true
      if (widget.autoPlay && mounted) {
        _play();
      }
      
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    } catch (e) {
      debugPrint('Error initializing video: $e');
    }
  }

  void _videoListener() {
    if (_controller == null || !mounted) return;
    
    final isBuffering = _controller!.value.isBuffering;
    
    if (isBuffering != _isBuffering) {
      setState(() {
        _isBuffering = isBuffering;
      });
    }
    
    // Loop the video when it ends
    if (_controller!.value.position >= _controller!.value.duration) {
      _controller!.seekTo(Duration.zero);
      _controller!.play();
    }
  }

  void _play() {
    if (_isVisible && _controller != null) {
      _controller?.play();
      setState(() {
        _isPlaying = true;
      });
    }
  }

  void _pause() {
    _controller?.pause();
    setState(() {
      _isPlaying = false;
    });
  }

  void _togglePlayPause() {
    if (_controller != null && _isInitialized) {
      if (_isPlaying) {
        _pause();
      } else {
        _play();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized || _controller == null) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    return GestureDetector(
      onTap: _togglePlayPause,
      child: Stack(
        alignment: Alignment.center,
        fit: StackFit.expand,
        children: [
          AspectRatio(
            aspectRatio: _controller!.value.aspectRatio,
            child: VideoPlayer(_controller!),
          ),
          
          // Show spinner when buffering
          if (_isBuffering)
            Container(
              color: Colors.black26,
              child: const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ),
            
          // Show play icon when paused  
          if (!_isPlaying && !_isBuffering)
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.5),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.play_arrow,
                color: Colors.white,
                size: 40,
              ),
            ),
        ],
      ),
    );
  }
}
