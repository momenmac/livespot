import 'package:flutter/material.dart';
import 'package:flutter_application_2/constants/theme_constants.dart';
import 'package:flutter_application_2/models/post.dart';
import 'package:flutter_application_2/providers/posts_provider.dart';
import 'package:flutter_application_2/ui/pages/home/components/all_news_page.dart';
import 'package:flutter_application_2/ui/pages/home/components/post_detail/post_detail_page.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;
import 'dart:io';
import 'package:flutter_application_2/services/api/account/api_urls.dart';

class NewsFeedSection extends StatefulWidget {
  final DateTime selectedDate;
  final VoidCallback? onMapToggle;

  const NewsFeedSection({
    super.key,
    required this.selectedDate,
    this.onMapToggle,
  });

  @override
  State<NewsFeedSection> createState() => _NewsFeedSectionState();
}

class _NewsFeedSectionState extends State<NewsFeedSection> {
  // Keep some image URLs for fallback and placeholders
  final List<String> _imageUrls = const [
    'https://picsum.photos/seed/news1/800/600',
    'https://picsum.photos/seed/news2/800/600',
    'https://picsum.photos/seed/news3/800/600',
    'https://picsum.photos/seed/news4/800/600',
    'https://picsum.photos/seed/news5/800/600',
  ];

  bool _isLoadingMore = false;
  bool _isLoading = false;

  String _getRandomImageUrl() {
    final random = math.Random();
    return _imageUrls[random.nextInt(_imageUrls.length)];
  }

  @override
  void initState() {
    super.initState();
    // Use a post-frame callback to avoid setState during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _fetchPosts(refresh: true);
      }
    });
  }

  @override
  void didUpdateWidget(NewsFeedSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Always fetch posts when widget updates (date or parent rebuild)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _fetchPosts(refresh: true);
      }
    });
  }

  Future<void> _fetchPosts({bool refresh = false}) async {
    if (!mounted) return;

    debugPrint(
        '🔥🔥🔥 NewsFeedSection._fetchPosts: Starting with refresh=$refresh 🔥🔥🔥');

    try {
      // Show loading state immediately
      debugPrint(
          '🔥 _fetchPosts: BEFORE setState _isLoading=true (current: $_isLoading)');
      setState(() {
        _isLoading = true;
      });
      debugPrint(
          '🔥 _fetchPosts: AFTER setState _isLoading=true (current: $_isLoading)');

      // Format date as YYYY-MM-DD for API
      final formattedDate =
          widget.selectedDate.toIso8601String().split('T').first;
      debugPrint(
          '🔥 NewsFeedSection._fetchPosts: Formatted date: $formattedDate');

      final provider = Provider.of<PostsProvider>(context, listen: false);
      debugPrint(
          '🔥 _fetchPosts: BEFORE provider.fetchPosts, provider.isLoading=${provider.isLoading}, provider.posts.length=${provider.posts.length}');

      // Wait for fetch to complete and ensure we have data
      final success =
          await provider.fetchPosts(date: formattedDate, refresh: refresh);
      debugPrint(
          '🔥 _fetchPosts: AFTER provider.fetchPosts, success=$success, provider.isLoading=${provider.isLoading}, provider.posts.length=${provider.posts.length}');

      if (mounted) {
        debugPrint(
            '🔥 _fetchPosts: BEFORE setState _isLoading=false (current: $_isLoading)');
        setState(() {
          _isLoading = false;
        });
        debugPrint(
            '🔥 _fetchPosts: AFTER setState _isLoading=false (current: $_isLoading)');
      }

      if (!success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Failed to load news. Please try again.')),
        );
      }
    } catch (e) {
      debugPrint('❌ NewsFeedSection._fetchPosts: Exception occurred: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
      debugPrint('Error fetching posts: $e');
    }
  }

  Future<void> _loadMorePosts() async {
    if (_isLoadingMore) {
      return;
    }

    setState(() {
      _isLoadingMore = true;
    });

    try {
      final formattedDate =
          widget.selectedDate.toIso8601String().split('T').first;
      final postsProvider = Provider.of<PostsProvider>(context, listen: false);

      if (postsProvider.hasMore && !postsProvider.isFetchingMore) {
        await postsProvider.loadMorePosts(date: formattedDate);
      }
    } catch (e) {
      debugPrint('Error loading more posts: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
        });
      }
    }
  }

  void _handleVote(Post post, bool isUpvote) {
    try {
      Provider.of<PostsProvider>(context, listen: false)
          .voteOnPost(post, isUpvote);
    } catch (e) {
      debugPrint('Error voting on post: $e');
      // Show a snackbar or other error notification
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to register your vote: $e')),
      );
    }
  }

  void _navigateToPostDetail(Post post) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PostDetailPage(
          title: post.title,
          description: post.content,
          imageUrl: _getBestImageUrl(post),
          location: post.location.address ?? "Unknown location",
          time: post.createdAt.toString(),
          honesty: post.honestyScore,
          upvotes: post.upvotes,
          comments: 0,
          isVerified: post.author.isVerified,
          post: post, // Pass the post object
        ),
      ),
    );
  }

  void _navigateToAllNews() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AllNewsPage(),
      ),
    );
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
                'News Feed',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              TextButton(
                onPressed: _navigateToAllNews,
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
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.arrow_forward,
                      size: 16,
                      color: ThemeConstants.primaryColor,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Posts content
        Consumer<PostsProvider>(
          builder: (context, postsProvider, child) {
            // Debug print provider state with more details
            debugPrint('🎯🎯🎯 NewsFeedSection Consumer BUILD START 🎯🎯🎯');
            debugPrint('🎯 Local _isLoading=$_isLoading');
            debugPrint('🎯 Provider isLoading=${postsProvider.isLoading}');
            debugPrint(
                '🎯 Provider posts.length=${postsProvider.posts.length}');
            debugPrint(
                '🎯 Provider errorMessage=${postsProvider.errorMessage}');
            debugPrint('🎯 Provider hasMore=${postsProvider.hasMore}');

            final posts = postsProvider.posts;
            final hasError = postsProvider.errorMessage != null;

            debugPrint('🎯 posts.isEmpty=${posts.isEmpty}');
            debugPrint('🎯 hasError=$hasError');

            // Show local loading state first
            if (_isLoading) {
              debugPrint(
                  '🎯 CONDITION: _isLoading is true -> Showing local loading indicator');
              return const Center(child: CircularProgressIndicator());
            }

            // Show loading indicator for initial load or refresh
            if (postsProvider.isLoading && posts.isNotEmpty) {
              debugPrint(
                  '🎯 CONDITION: provider.isLoading && posts.isNotEmpty -> Showing stack with loading overlay');
              // Show loading indicator over existing content if we have posts
              return Stack(
                children: [
                  // Existing posts with overlay
                  Opacity(
                    opacity: 0.6,
                    child: _buildPostsList(posts),
                  ),
                  // Loading indicator
                  const Center(child: CircularProgressIndicator()),
                ],
              );
            }

            // Show error if we have one and no posts
            if (hasError && posts.isEmpty) {
              debugPrint(
                  '🎯 CONDITION: hasError && posts.isEmpty -> Showing error message');
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline,
                        size: 48, color: ThemeConstants.grey),
                    const SizedBox(height: 16),
                    Text(
                      'Error loading news: ${postsProvider.errorMessage}',
                      style: const TextStyle(color: ThemeConstants.grey),
                    ),
                    const SizedBox(height: 24),
                    TextButton.icon(
                      onPressed: () => _fetchPosts(refresh: true),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                    ),
                  ],
                ),
              );
            }

            // Show no news message if we have no posts and aren't loading
            if (posts.isEmpty) {
              debugPrint(
                  '🎯 CONDITION: posts.isEmpty -> Showing no news message');
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.article_outlined,
                        size: 48, color: ThemeConstants.grey),
                    const SizedBox(height: 16),
                    Text(
                      'No news available for ${widget.selectedDate.toLocal().toString().split(' ')[0]}',
                      style: const TextStyle(color: ThemeConstants.grey),
                    ),
                    const SizedBox(height: 24),
                    TextButton.icon(
                      onPressed: () => _fetchPosts(refresh: true),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Refresh'),
                    ),
                  ],
                ),
              );
            }

            debugPrint(
                '🎯 CONDITION: DEFAULT -> Showing posts list with ${posts.length} posts');
            debugPrint('🎯🎯🎯 NewsFeedSection Consumer BUILD END 🎯🎯🎯');
            return _buildPostsList(posts);
          },
        ),
      ],
    );
  }

  Widget _buildPostsList(List<Post> posts) {
    // Sort posts by honesty score
    final sortedPosts = List<Post>.from(posts)
      ..sort((a, b) => b.honestyScore.compareTo(a.honestyScore));

    // Extract featured and regular posts
    final featuredPost = sortedPosts.isNotEmpty ? sortedPosts.first : null;
    final regularPosts =
        sortedPosts.length > 1 ? sortedPosts.sublist(1) : <Post>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (featuredPost != null) _buildFeaturedPostCard(featuredPost),
        if (regularPosts.isNotEmpty) _buildRegularPostsList(regularPosts),
      ],
    );
  }

  Widget _buildRegularPostsList(List<Post> regularPosts) {
    final postsProvider = Provider.of<PostsProvider>(context);
    return SizedBox(
      height: 240,
      child: NotificationListener<ScrollNotification>(
        onNotification: (ScrollNotification scrollInfo) {
          if (!_isLoadingMore &&
              postsProvider.hasMore &&
              !postsProvider.isFetchingMore &&
              scrollInfo.metrics.pixels >=
                  scrollInfo.metrics.maxScrollExtent * 0.9) {
            _loadMorePosts();
          }
          return true;
        },
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          itemCount: regularPosts.length +
              (Provider.of<PostsProvider>(context).hasMore ? 1 : 0),
          itemBuilder: (context, index) {
            if (index == regularPosts.length) {
              return Padding(
                padding: const EdgeInsets.all(8.0),
                child: Center(
                  child: _isLoadingMore
                      ? const CircularProgressIndicator()
                      : const SizedBox.shrink(),
                ),
              );
            }
            return SizedBox(
              width: 240,
              child: _buildRegularPostCard(regularPosts[index]),
            );
          },
        ),
      ),
    );
  }

  Widget _buildFeaturedPostCard(Post post) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return GestureDetector(
      onTap: () => _navigateToPostDetail(post),
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            // Background image
            Container(
              height: 350,
              width: double.infinity,
              decoration: BoxDecoration(
                color: isDarkMode ? Colors.grey[800] : ThemeConstants.greyLight,
              ),
              child: _buildImage(_getBestImageUrl(post)),
            ),

            // Content overlay with gradient
            Container(
              height: 350,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withOpacity(0.2),
                    Colors.black.withOpacity(0.7),
                  ],
                  stops: const [0.5, 0.75, 0.95],
                ),
              ),
            ),

            // Featured badge
            Positioned(
              top: 16,
              left: 16,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: ThemeConstants.primaryColor,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.star,
                      color: Colors.white,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      'FEATURED',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Content
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    Text(
                      post.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        shadows: [
                          Shadow(
                            blurRadius: 3.0,
                            color: Colors.black54,
                            offset: Offset(1, 1),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 8),

                    // Description
                    Text(
                      post.content,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        shadows: [
                          Shadow(
                            blurRadius: 3.0,
                            color: Colors.black54,
                            offset: Offset(1, 1),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Bottom info row
                    Row(
                      children: [
                        // Location
                        if (post.location.address != null)
                          Expanded(
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.location_on,
                                  size: 14,
                                  color: Colors.white70,
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    post.location.address!,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.white70,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                        // Upvote button with count (non-clickable)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.arrow_upward_rounded,
                                size: 16,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${post.upvotes}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(width: 8),

                        // Honesty score badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: _getHonestyColor(post.honestyScore),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 2,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.verified_user,
                                color: Colors.white,
                                size: 12,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${post.honestyScore}%',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Verified badge if applicable
            if (post.author.isVerified)
              Positioned(
                top: 16,
                right: 16,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.verified,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRegularPostCard(Post post) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return GestureDetector(
      onTap: () => _navigateToPostDetail(post),
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        clipBehavior: Clip.antiAlias,
        elevation: isDarkMode ? 2 : 3, // Slightly less elevation in dark mode
        color: theme.cardColor,
        child: SizedBox(
          height: 232, // Set explicit height to match parent container
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image - fixed height with better error handling
              SizedBox(
                height: 126, // Fixed height for image
                width: double.infinity,
                child: _buildImage(_getBestImageUrl(post)),
              ),

              // Content - use Expanded to avoid overflow
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title with improved styling
                      Text(
                        post.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          height: 1.2, // Tighter line height
                        ),
                      ),

                      const SizedBox(height: 4),

                      // Location
                      if (post.location.address != null)
                        Row(
                          children: [
                            Icon(Icons.location_on,
                                size: 12, color: ThemeConstants.grey),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                post.location.address!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: ThemeConstants.grey,
                                ),
                              ),
                            ),
                          ],
                        ),

                      const Spacer(), // Push the action row to the bottom

                      // Voting and honesty score with better styling
                      Row(
                        children: [
                          // Upvote button (non-clickable)
                          Icon(
                            Icons.arrow_upward_rounded,
                            size: 18,
                            color: Colors.green,
                          ),

                          const SizedBox(width: 4),
                          Text('${post.upvotes}',
                              style: const TextStyle(fontSize: 12)),

                          const SizedBox(width: 12),

                          // Downvote button (non-clickable)
                          Icon(
                            Icons.arrow_downward_rounded,
                            size: 18,
                            color: Colors.red,
                          ),

                          const Spacer(),

                          // Honesty score with improved badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: _getHonestyColor(post.honestyScore),
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 2,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.verified_user,
                                  color: Colors.white,
                                  size: 10,
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  '${post.honestyScore}%',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Verified badge
                          if (post.author.isVerified)
                            Padding(
                              padding: const EdgeInsets.only(left: 4),
                              child: Icon(
                                Icons.verified,
                                size: 16,
                                color: Colors.blue,
                              ),
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
      ),
    );
  }

  Color _getHonestyColor(int score) {
    if (score >= 80) {
      return Colors.green;
    } else if (score >= 60) {
      return Colors.orange;
    } else {
      return Colors.red;
    }
  }

  // Helper to fix image URLs that use localhost, 127.0.0.1, or are relative
  String _getFixedImageUrl(String? url) {
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

  // Enhanced image URL handling with support for different path types
  Widget _buildImage(String? imageUrl, {BoxFit fit = BoxFit.cover}) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    // Handle null or empty image URL
    if (imageUrl == null || imageUrl.isEmpty) {
      return _buildPlaceholderImage();
    }

    // Check if it's a file path or network URL
    if (_isFilePath(imageUrl)) {
      return Image.file(
        File(imageUrl),
        fit: fit,
        errorBuilder: (context, error, stackTrace) {
          debugPrint('Error loading file image: $error');
          return _buildPlaceholderImage();
        },
      );
    } else {
      // Always fix the image URL
      String processedUrl = _getFixedImageUrl(imageUrl);
      return Image.network(
        processedUrl,
        fit: fit,
        errorBuilder: (context, error, stackTrace) {
          debugPrint('Error loading network image: $error');
          return _buildPlaceholderImage();
        },
      );
    }
  }

  // Helper to build consistent placeholder for missing images
  Widget _buildPlaceholderImage() {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return Container(
      color: isDarkMode ? Colors.grey[800] : ThemeConstants.greyLight,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.image_not_supported,
              size: 48,
              color: isDarkMode ? Colors.grey[600] : ThemeConstants.grey,
            ),
            const SizedBox(height: 8),
            Text(
              "Image unavailable",
              style: TextStyle(
                color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Check if the path is a file path rather than URL
  bool _isFilePath(String path) {
    return path.startsWith('/') ||
        path.startsWith('file:/') ||
        !path.contains('://');
  }

  // Get the best available image URL from a post
  String _getBestImageUrl(Post post) {
    // Try to get media URL first
    if (post.hasMedia && post.mediaUrls.isNotEmpty) {
      return post.mediaUrls.first;
    }

    // Then try for direct imageUrl property
    if (post.imageUrl.isNotEmpty) {
      return post.imageUrl;
    }

    // Return random placeholder as fallback - never return null
    return _getRandomImageUrl();
  }
}
