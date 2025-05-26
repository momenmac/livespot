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
import 'package:flutter_application_2/ui/profile/other_user_profile_page.dart';
import 'package:flutter_application_2/ui/profile/profile_page.dart';
import 'package:flutter_application_2/services/api/account/account_provider.dart';

class TikTokStyleReelsPage extends StatefulWidget {
  final Post post;
  final int initialIndex;

  const TikTokStyleReelsPage({
    super.key,
    required this.post,
    this.initialIndex = 0,
  });

  @override
  State<TikTokStyleReelsPage> createState() => _TikTokStyleReelsPageState();
}

class _TikTokStyleReelsPageState extends State<TikTokStyleReelsPage> {
  late PageController _pageController;
  List<String> _mediaUrls = [];
  List<Post> _threadPosts = [];
  Map<String, Post> _mediaToPostMap = {};
  int _currentPage = 0;
  bool _isLoading = true;

  // Getter for thread posts count
  int get threadPostsCount => _threadPosts.length;

  @override
  void initState() {
    super.initState();
    _loadThreadPosts();
    _currentPage = widget.initialIndex;
    _pageController = PageController(
      initialPage: _currentPage,
      viewportFraction: 1.0,
      keepPage: true,
    );

    // Enable immersive mode for better viewing experience
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
  }

  @override
  void dispose() {
    _pageController.dispose();
    // Restore system UI when leaving the page
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  Future<void> _loadThreadPosts() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final postsProvider = Provider.of<PostsProvider>(context, listen: false);

      // Get all posts in the thread (related posts + main post)
      List<Post> allThreadPosts =
          await postsProvider.getRelatedPosts(widget.post.id);

      // Add the current post if it's not already in the list
      bool currentPostInList =
          allThreadPosts.any((p) => p.id == widget.post.id);
      if (!currentPostInList) {
        allThreadPosts.insert(0, widget.post);
      }

      // Sort posts by creation date to maintain thread order
      allThreadPosts.sort((a, b) => a.createdAt.compareTo(b.createdAt));

      // Extract all media URLs from all posts in the thread
      List<String> allMediaUrls = [];
      Map<String, Post> tempMediaToPostMap = {};

      for (Post post in allThreadPosts) {
        List<String> postMediaUrls = [];

        // Get media URLs from the post
        if (post.mediaUrls.isNotEmpty) {
          postMediaUrls = List.from(post.mediaUrls);
        } else if (post.imageUrl.isNotEmpty) {
          postMediaUrls = [post.imageUrl];
        }

        // Fix and filter media URLs
        postMediaUrls = postMediaUrls
            .map((url) => _getFixedMediaUrl(url))
            .where((url) => url.isNotEmpty)
            .toList();

        // Map each media URL to its corresponding post
        for (String mediaUrl in postMediaUrls) {
          tempMediaToPostMap[mediaUrl] = post;
          allMediaUrls.add(mediaUrl);
        }
      }

      setState(() {
        _threadPosts = allThreadPosts;
        _mediaUrls = allMediaUrls;
        _mediaToPostMap = tempMediaToPostMap;
        _isLoading = false;
      });

      // Update current page if needed
      if (widget.initialIndex < _mediaUrls.length) {
        _currentPage = widget.initialIndex;
        if (_pageController.hasClients) {
          _pageController.animateToPage(
            _currentPage,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        }
      }
    } catch (e) {
      debugPrint('Error loading thread posts: $e');

      // Fallback to single post media
      _initSinglePostMedia();

      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        ResponsiveSnackBar.showError(
          context: context,
          message: 'Could not load full thread. Showing current post only.',
        );
      }
    }
  }

  void _initSinglePostMedia() {
    // Fallback method for single post (original logic)
    List<String> mediaUrls = [];

    if (widget.post.mediaUrls.isEmpty && widget.post.imageUrl.isNotEmpty) {
      mediaUrls = [widget.post.imageUrl];
    } else {
      mediaUrls = List.from(widget.post.mediaUrls);
    }

    // Make sure all URLs are properly formatted
    mediaUrls = mediaUrls.map((url) => _getFixedMediaUrl(url)).toList();

    // Remove any empty URLs
    mediaUrls.removeWhere((url) => url.isEmpty);

    // Create mapping for single post
    Map<String, Post> singlePostMap = {};
    for (String url in mediaUrls) {
      singlePostMap[url] = widget.post;
    }

    setState(() {
      _mediaUrls = mediaUrls;
      _threadPosts = [widget.post];
      _mediaToPostMap = singlePostMap;
    });

    if (_mediaUrls.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ResponsiveSnackBar.showInfo(
          context: context,
          message: 'No media found for this post',
        );
      });
    }
  }

  String _getFixedMediaUrl(String? url) {
    if (url == null || url.isEmpty) return '';

    // Already absolute URL
    if (url.startsWith('http://') || url.startsWith('https://')) {
      // Fix localhost URLs
      if (url.contains('localhost') || url.contains('127.0.0.1')) {
        return url.replaceFirst(
            RegExp(r'http://localhost:[0-9]+|http://127.0.0.1:[0-9]+'),
            ApiUrls.baseUrl);
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

  // Get the post associated with the current media item
  Post _getCurrentPost() {
    if (_currentPage < _mediaUrls.length) {
      String currentMediaUrl = _mediaUrls[_currentPage];
      return _mediaToPostMap[currentMediaUrl] ?? widget.post;
    }
    return widget.post;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.black.withValues(alpha: 0.3),
          ),
          child: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.black.withValues(alpha: 0.3),
            ),
            child: IconButton(
              icon: const Icon(Icons.more_vert, color: Colors.white),
              onPressed: () {
                // Show additional options (share, report, etc.)
                _showOptionsBottomSheet(context);
              },
            ),
          ),
        ],
      ),
      body: _isLoading
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
                          _buildUpvoteButton(),
                          _buildDownvoteButton(),
                          _buildInteractionButton(
                            icon: Icons.comment,
                            label:
                                '${threadPostsCount}', // Show related posts count
                            onTap: () => _navigateToPostDetail(),
                          ),
                          _buildHonestyButton(),
                          _buildInteractionButton(
                            icon: Icons.share,
                            label: 'Share',
                            onTap: () => _handleShare(),
                          ),
                        ],
                      ),
                    ),

                    // Media pagination indicator (if multiple media) - vertical on the right side
                    if (_mediaUrls.length > 1)
                      Positioned(
                        right: 10.0,
                        top: 0,
                        bottom: 0,
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                vertical: 6.0, horizontal: 2.0),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: List.generate(
                                _mediaUrls.length,
                                (index) => Container(
                                  width: 5.0,
                                  height: _currentPage == index ? 20.0 : 5.0,
                                  margin:
                                      const EdgeInsets.symmetric(vertical: 3.0),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(5),
                                    color: _currentPage == index
                                        ? ThemeConstants.primaryColor
                                        : Colors.white.withOpacity(0.5),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
    );
  }

  Widget _buildReelItem(String mediaUrl, int index) {
    return GestureDetector(
      // Allow vertical scrolling to pass through to PageView
      onVerticalDragUpdate: null,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Media content
          _isVideoFile(mediaUrl)
              ? _VideoPlayer(
                  videoUrl: mediaUrl, autoPlay: index == _currentPage)
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
                  // Author row with profile pic - clickable for profile navigation
                  GestureDetector(
                    onTap: () => _navigateToUserProfile(),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundImage: _getCurrentPost().authorProfilePic !=
                                      null &&
                                  _getCurrentPost().authorProfilePic!.isNotEmpty
                              ? NetworkImage(_getFixedMediaUrl(
                                  _getCurrentPost().authorProfilePic))
                              : null,
                          backgroundColor: ThemeConstants.primaryColor,
                          child: _getCurrentPost().authorProfilePic == null ||
                                  _getCurrentPost().authorProfilePic!.isEmpty
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
                                  _getCurrentPost().getDisplayName(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                if (_getCurrentPost().isAuthorVerified)
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
                              '${DateTime.now().difference(_getCurrentPost().timePosted).inDays} days ago',
                              style: const TextStyle(color: Colors.white70),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Post title
                  Text(
                    _getCurrentPost().title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Post description
                  Text(
                    _getCurrentPost().description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white70),
                  ),
                  // Tags row
                  if (_getCurrentPost().tags.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Wrap(
                        spacing: 8,
                        children: _getCurrentPost().tags.map((tag) {
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
                  const SizedBox(height: 16),
                  // Media pagination indicator removed from here (moved to main Stack)
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

  Widget _buildUpvoteButton() {
    final currentPost = _getCurrentPost();
    final bool isUpvoted = currentPost.userVote == 1;

    debugPrint(
        '🎨 Building upvote button - Post ID: ${currentPost.id}, userVote: ${currentPost.userVote}, isUpvoted: $isUpvoted');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        children: [
          InkWell(
            onTap: () => _handleUpvote(),
            borderRadius: BorderRadius.circular(25),
            child: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black.withValues(alpha: 0.3),
              ),
              child: Icon(
                isUpvoted ? Icons.arrow_upward : Icons.arrow_upward_outlined,
                color: isUpvoted ? ThemeConstants.primaryColor : Colors.white,
                size: 28,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${currentPost.upvotes}',
            style: TextStyle(
              color: isUpvoted ? ThemeConstants.primaryColor : Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDownvoteButton() {
    final currentPost = _getCurrentPost();
    final bool isDownvoted = currentPost.userVote == -1;

    debugPrint(
        '🎨 Building downvote button - Post ID: ${currentPost.id}, userVote: ${currentPost.userVote}, isDownvoted: $isDownvoted');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        children: [
          InkWell(
            onTap: () => _handleDownvote(),
            borderRadius: BorderRadius.circular(25),
            child: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black.withValues(alpha: 0.3),
              ),
              child: Icon(
                isDownvoted
                    ? Icons.arrow_downward
                    : Icons.arrow_downward_outlined,
                color: isDownvoted ? Colors.redAccent : Colors.white,
                size: 28,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${currentPost.downvotes}',
            style: TextStyle(
              color: isDownvoted ? Colors.redAccent : Colors.white,
            ),
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

  // Handle upvote functionality
  void _handleUpvote() async {
    final currentPost = _getCurrentPost();
    final postsProvider = Provider.of<PostsProvider>(context, listen: false);

    debugPrint(
        '🎯 Before upvote - Post ID: ${currentPost.id}, userVote: ${currentPost.userVote}, upvotes: ${currentPost.upvotes}');

    // Store previous state for rollback
    final int previousVote = currentPost.userVote;
    final int previousUpvotes = currentPost.upvotes;
    final int previousDownvotes = currentPost.downvotes;

    try {
      // Optimistically update UI - if already upvoted, remove upvote, otherwise add upvote
      if (currentPost.userVote == 1) {
        // Remove upvote
        debugPrint('🔄 Removing upvote...');
        currentPost.upvotes--;
        currentPost.userVote = 0;
      } else {
        // Add upvote, remove downvote if present
        debugPrint('🔄 Adding upvote...');
        if (currentPost.userVote == -1) {
          currentPost.downvotes--;
        }
        currentPost.upvotes++;
        currentPost.userVote = 1;
      }

      debugPrint(
          '🎯 After optimistic update - userVote: ${currentPost.userVote}, upvotes: ${currentPost.upvotes}');

      // Update the post in the media map to ensure consistency
      if (_currentPage < _mediaUrls.length) {
        String currentMediaUrl = _mediaUrls[_currentPage];
        _mediaToPostMap[currentMediaUrl] = currentPost;
      }

      setState(() {}); // Refresh UI with optimistic update

      // Make the API call
      final result = await postsProvider.voteOnPost(currentPost, true);

      // Update with real values from server
      if (result.isNotEmpty) {
        debugPrint('🔄 API Response: $result');
        setState(() {
          currentPost.upvotes = result['upvotes'] ?? currentPost.upvotes;
          currentPost.downvotes = result['downvotes'] ?? currentPost.downvotes;
          currentPost.honestyScore =
              result['honesty_score'] ?? currentPost.honestyScore;

          // Handle user_vote more intelligently
          final serverUserVote = result['user_vote'];
          final voteRemoved = result['vote_removed'] ?? false;

          if (voteRemoved) {
            // Vote was successfully removed
            currentPost.userVote = 0;
            debugPrint('✅ Vote removed successfully');
          } else if (serverUserVote != null && serverUserVote != 0) {
            // Server returned a valid vote state
            currentPost.userVote = serverUserVote;
            debugPrint('✅ Server returned userVote: $serverUserVote');
          } else {
            // Server returned 0 or null for user_vote, but vote wasn't removed
            // This indicates a server-side issue - maintain our optimistic state
            debugPrint(
                '⚠️ Server returned userVote: $serverUserVote but vote not removed. Maintaining optimistic state.');
            // Keep the current optimistic userVote value
          }

          // Update the post in the media map again after API response
          if (_currentPage < _mediaUrls.length) {
            String currentMediaUrl = _mediaUrls[_currentPage];
            _mediaToPostMap[currentMediaUrl] = currentPost;
          }
        });
        debugPrint(
            '✅ Post updated - userVote: ${currentPost.userVote}, upvotes: ${currentPost.upvotes}');
        debugPrint(
            '🔗 Post object after API update - hashCode: ${currentPost.hashCode}');
      } else {
        debugPrint('⚠️ API returned empty result');
      }
    } catch (e) {
      debugPrint('❌ Upvote failed: $e');
      // Revert to previous state if API call failed
      setState(() {
        currentPost.userVote = previousVote;
        currentPost.upvotes = previousUpvotes;
        currentPost.downvotes = previousDownvotes;
      });

      if (mounted) {
        ResponsiveSnackBar.showError(
          context: context,
          message: 'Failed to upvote post',
        );
      }
    }
  }

  // Handle downvote functionality
  void _handleDownvote() async {
    final currentPost = _getCurrentPost();
    final postsProvider = Provider.of<PostsProvider>(context, listen: false);

    debugPrint(
        '🎯 Before downvote - Post ID: ${currentPost.id}, userVote: ${currentPost.userVote}, downvotes: ${currentPost.downvotes}');

    // Store previous state for rollback
    final int previousVote = currentPost.userVote;
    final int previousUpvotes = currentPost.upvotes;
    final int previousDownvotes = currentPost.downvotes;

    try {
      // Optimistically update UI - if already downvoted, remove downvote, otherwise add downvote
      if (currentPost.userVote == -1) {
        // Remove downvote
        debugPrint('🔄 Removing downvote...');
        currentPost.downvotes--;
        currentPost.userVote = 0;
      } else {
        // Add downvote, remove upvote if present
        debugPrint('🔄 Adding downvote...');
        if (currentPost.userVote == 1) {
          currentPost.upvotes--;
        }
        currentPost.downvotes++;
        currentPost.userVote = -1;
      }

      debugPrint(
          '🎯 After optimistic update - userVote: ${currentPost.userVote}, downvotes: ${currentPost.downvotes}');

      // Update the post in the media map to ensure consistency
      if (_currentPage < _mediaUrls.length) {
        String currentMediaUrl = _mediaUrls[_currentPage];
        _mediaToPostMap[currentMediaUrl] = currentPost;
      }

      setState(() {}); // Refresh UI with optimistic update

      // Make the API call
      final result = await postsProvider.voteOnPost(currentPost, false);

      // Update with real values from server
      if (result.isNotEmpty) {
        debugPrint('🔄 API Response: $result');
        setState(() {
          currentPost.upvotes = result['upvotes'] ?? currentPost.upvotes;
          currentPost.downvotes = result['downvotes'] ?? currentPost.downvotes;
          currentPost.honestyScore =
              result['honesty_score'] ?? currentPost.honestyScore;

          // Handle user_vote more intelligently
          final serverUserVote = result['user_vote'];
          final voteRemoved = result['vote_removed'] ?? false;

          if (voteRemoved) {
            // Vote was successfully removed
            currentPost.userVote = 0;
            debugPrint('✅ Vote removed successfully');
          } else if (serverUserVote != null && serverUserVote != 0) {
            // Server returned a valid vote state
            currentPost.userVote = serverUserVote;
            debugPrint('✅ Server returned userVote: $serverUserVote');
          } else {
            // Server returned 0 or null for user_vote, but vote wasn't removed
            // This indicates a server-side issue - maintain our optimistic state
            debugPrint(
                '⚠️ Server returned userVote: $serverUserVote but vote not removed. Maintaining optimistic state.');
            // Keep the current optimistic userVote value
          }

          // Update the post in the media map again after API response
          if (_currentPage < _mediaUrls.length) {
            String currentMediaUrl = _mediaUrls[_currentPage];
            _mediaToPostMap[currentMediaUrl] = currentPost;
          }
        });
        debugPrint(
            '✅ Post updated - userVote: ${currentPost.userVote}, downvotes: ${currentPost.downvotes}');
        debugPrint(
            '🔗 Post object after API update - hashCode: ${currentPost.hashCode}');
      } else {
        debugPrint('⚠️ API returned empty result');
      }
    } catch (e) {
      debugPrint('❌ Downvote failed: $e');
      // Revert to previous state if API call failed
      setState(() {
        currentPost.userVote = previousVote;
        currentPost.upvotes = previousUpvotes;
        currentPost.downvotes = previousDownvotes;
      });

      if (mounted) {
        ResponsiveSnackBar.showError(
          context: context,
          message: 'Failed to downvote post',
        );
      }
    }
  }

  // Navigate to post detail page
  void _navigateToPostDetail() {
    final currentPost = _getCurrentPost();
    debugPrint('🚀 Navigating to post detail - Post ID: ${currentPost.id}');
    debugPrint(
        '🚀 Current post state - userVote: ${currentPost.userVote}, upvotes: ${currentPost.upvotes}, downvotes: ${currentPost.downvotes}');
    debugPrint('🚀 Post object hashCode: ${currentPost.hashCode}');
    debugPrint('🚀 Is this post upvoted? ${currentPost.userVote == 1}');
    debugPrint(
        '🚀 Has Upvoted (for post detail): ${currentPost.userVote == 1}');

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

  // Navigate to user profile page based on whether this is an anonymous post
  void _navigateToUserProfile() {
    final currentPost = _getCurrentPost();

    // Don't navigate for anonymous users
    if (currentPost.isAnonymous) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Cannot view anonymous user's profile"),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    // Check if the post author is the currently logged in user
    final accountProvider =
        Provider.of<AccountProvider>(context, listen: false);
    final bool isCurrentUser = accountProvider.currentUser != null &&
        accountProvider.currentUser!.id == currentPost.author.id;

    // Create the user data map required by OtherUserProfilePage
    Map<String, dynamic> userData = {
      'id': currentPost.author.id,
      'username': currentPost.authorName,
      'profile_pic': currentPost.authorProfilePic ?? '', // Ensure not null
      'is_verified': currentPost.isAuthorVerified,
    };

    // Add extra fields if they are available
    if (currentPost.author.fullName != null) {
      userData['full_name'] = currentPost
          .author.fullName; // Using 'full_name' to match expected format
    }

    if (isCurrentUser) {
      // Navigate to the current user's profile page by replacing the current screen
      debugPrint(
          '🧑 Navigating to current user profile - User ID: ${currentPost.author.id}');
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const ProfilePage(),
        ),
      );
      return;
    }

    // Navigate to other user's profile
    debugPrint(
        '🧑‍🤝‍🧑 Navigating to other user profile - User ID: ${currentPost.author.id}');

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => OtherUserProfilePage(userData: userData),
      ),
    );
  }

  // Cool honesty button with smaller design
  Widget _buildHonestyButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: GestureDetector(
        onTap: () {}, // Removed popup dialog
        child: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                _getHonestyColor().withValues(alpha: 0.8),
                _getHonestyColor().withValues(alpha: 0.6),
              ],
            ),
            border: Border.all(
              color: _getHonestyColor().withValues(alpha: 0.9),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: _getHonestyColor().withValues(alpha: 0.3),
                blurRadius: 8,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.verified_user,
                color: Colors.white,
                size: 20,
              ),
              Text(
                '${_getCurrentPost().honestyScore}%',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Get color based on honesty score
  Color _getHonestyColor() {
    final score = _getCurrentPost().honestyScore;
    if (score >= 80) return Colors.green;
    if (score >= 60) return Colors.orange;
    if (score >= 40) return Colors.yellow;
    return Colors.red;
  }

  // Display honesty score info methods moved to icon tooltip

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
                title:
                    const Text('Share', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  _handleShare();
                },
              ),
              ListTile(
                leading: const Icon(Icons.comment, color: Colors.white),
                title: const Text('View related posts',
                    style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  _navigateToPostDetail();
                },
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                margin: const EdgeInsets.symmetric(horizontal: 16.0),
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.grey.withOpacity(0.2),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
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

class _VideoPlayerState extends State<_VideoPlayer>
    with WidgetsBindingObserver {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _isPlaying = false;
  bool _isBuffering = false;
  bool _isVisible = true; // Track visibility state

  @override
  void initState() {
    super.initState();
    _isVisible =
        widget.autoPlay; // Set initial visibility based on autoPlay parameter
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
      if (widget.autoPlay &&
          _controller != null &&
          _isInitialized &&
          !_isPlaying) {
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
      if (widget.videoUrl.startsWith('/') ||
          widget.videoUrl.startsWith('file:')) {
        _controller = VideoPlayerController.file(File(widget.videoUrl));
      } else {
        _controller =
            VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));
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
