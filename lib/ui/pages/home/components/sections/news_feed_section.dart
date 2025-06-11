import 'package:flutter/material.dart';
import 'package:flutter_application_2/constants/theme_constants.dart';
import 'package:flutter_application_2/constants/category_utils.dart';
import 'package:flutter_application_2/models/post.dart';
import 'package:flutter_application_2/providers/posts_provider.dart';
import 'package:flutter_application_2/ui/pages/home/components/all_news_page.dart';
import 'package:flutter_application_2/ui/pages/home/components/post_detail/post_detail_page.dart';
import 'package:flutter_application_2/ui/pages/media/gallery_preview_page.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_application_2/services/api/account/api_urls.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

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

  // Recommended posts state
  List<Post> _recommendedPosts = [];
  bool _isLoadingRecommended = false;
  Map<String, dynamic> _recommendationMetadata = {};
  String _recommendationMessage = '';

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
        _fetchRecommendedPosts(); // Fetch recommendations
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
        _fetchRecommendedPosts(); // Fetch recommendations on update
      }
    });
  }

  // Fetch recommended posts based on user location and preferences
  Future<void> _fetchRecommendedPosts() async {
    if (!mounted) return;

    setState(() {
      _isLoadingRecommended = true;
    });

    try {
      final provider = Provider.of<PostsProvider>(context, listen: false);

      // Format date as YYYY-MM-DD for API (same as regular posts)
      final formattedDate =
          widget.selectedDate.toIso8601String().split('T').first;

      debugPrint(
          '🎯 NewsFeedSection: Fetching recommendations for date: $formattedDate');

      final result = await provider.fetchRecommendedPosts(
        radiusKm: 50, // 50km radius
        limit: 10, // Get 10 recommendations
        date: formattedDate,
      );

      if (mounted) {
        setState(() {
          _recommendedPosts = List<Post>.from(result['posts'] ?? []);
          _recommendationMetadata =
              Map<String, dynamic>.from(result['metadata'] ?? {});
          _recommendationMessage = result['message'] ?? '';
          _isLoadingRecommended = false;
        });

        debugPrint(
            '🎯 NewsFeedSection: Loaded ${_recommendedPosts.length} recommended posts');
        debugPrint(
            '🎯 NewsFeedSection: Recommendation message: $_recommendationMessage');
      }
    } catch (e) {
      debugPrint('❌ NewsFeedSection: Error fetching recommendations: $e');
      if (mounted) {
        setState(() {
          _recommendedPosts = [];
          _recommendationMetadata = {};
          // Show more helpful error message based on the error type
          if (e.toString().toLowerCase().contains('location')) {
            _recommendationMessage =
                'Using default location (Tulkarm) for recommendations. Enable location for personalized content.';
          } else if (e.toString().toLowerCase().contains('network') ||
              e.toString().toLowerCase().contains('connection')) {
            _recommendationMessage =
                'Network error - please check your internet connection';
          } else {
            _recommendationMessage =
                'Loading recommendations with default location...';
          }
          _isLoadingRecommended = false;
        });
      }
    }
  }

  Future<void> _fetchPosts({bool refresh = false}) async {
    if (!mounted) return;

    debugPrint(
        '🎯🎯🎯 NewsFeedSection._fetchPosts: Starting RECOMMENDED posts fetch with refresh=$refresh 🎯🎯🎯');

    try {
      // Show loading state immediately
      debugPrint(
          '🎯 _fetchPosts: BEFORE setState _isLoading=true (current: $_isLoading)');
      setState(() {
        _isLoading = true;
      });
      debugPrint(
          '🎯 _fetchPosts: AFTER setState _isLoading=true (current: $_isLoading)');

      // Format date as YYYY-MM-DD for API
      final formattedDate =
          widget.selectedDate.toIso8601String().split('T').first;
      debugPrint(
          '🎯 NewsFeedSection._fetchPosts: Formatted date: $formattedDate');

      final provider = Provider.of<PostsProvider>(context, listen: false);
      debugPrint('🎯 _fetchPosts: BEFORE provider.fetchRecommendedPosts');

      // Use recommended posts instead of regular posts
      final result = await provider.fetchRecommendedPosts(
        radiusKm: 50, // 50km radius for local content
        limit: 20, // Get 20 recommendations
        date: formattedDate,
      );

      debugPrint(
          '🎯 _fetchPosts: AFTER provider.fetchRecommendedPosts, result: ${result.keys}');

      if (mounted) {
        debugPrint(
            '🎯 _fetchPosts: BEFORE setState _isLoading=false (current: $_isLoading)');

        // Extract posts from recommendation result
        final List<Post> recommendedPosts =
            List<Post>.from(result['posts'] ?? []);

        setState(() {
          _isLoading = false;
          // Store recommended posts for display
          _recommendedPosts = recommendedPosts;
          _recommendationMetadata =
              Map<String, dynamic>.from(result['metadata'] ?? {});
          _recommendationMessage =
              result['message'] ?? 'Recommendations loaded';
        });

        debugPrint(
            '🎯 _fetchPosts: AFTER setState _isLoading=false, loaded ${recommendedPosts.length} recommended posts');
        debugPrint(
            '🎯 _fetchPosts: Recommendation metadata: $_recommendationMetadata');
      }

      // Show success message if we have recommendations
      if (mounted && _recommendedPosts.isNotEmpty) {
        debugPrint(
            '🎯 _fetchPosts: Successfully loaded ${_recommendedPosts.length} recommended posts');
      }
      // No snackbar for empty recommendations - handled by empty state UI
    } catch (e) {
      debugPrint('❌ NewsFeedSection._fetchPosts: Exception occurred: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _recommendedPosts = [];
          _recommendationMetadata = {};
          _recommendationMessage = 'Failed to load recommendations';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
      debugPrint('Error fetching recommended posts: $e');
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

  // Open media preview (gallery with video support)
  void _openMediaPreview(Post post) {
    // Get all media URLs from the post
    List<String> allMediaUrls = [];

    if (post.hasMedia && post.mediaUrls.isNotEmpty) {
      allMediaUrls =
          post.mediaUrls.map((url) => _getFixedImageUrl(url)).toList();
    } else if (post.imageUrl.isNotEmpty) {
      allMediaUrls = [_getFixedImageUrl(post.imageUrl)];
    }

    if (allMediaUrls.isNotEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => GalleryPreviewPage(
            mediaUrls: allMediaUrls,
            title: post.title,
            initialIndex: 0,
          ),
        ),
      );
    }
  }

  // Build recommended posts section
  Widget _buildRecommendedSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Recommended Posts Header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Row(
            children: [
              Icon(
                Icons.recommend,
                color: ThemeConstants.primaryColor,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Recommended for You',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: ThemeConstants.primaryColor,
                    ),
              ),
              const Spacer(),
              if (_recommendationMetadata.isNotEmpty)
                Tooltip(
                  message: _recommendationMessage,
                  child: Icon(
                    Icons.info_outline,
                    size: 16,
                    color: ThemeConstants.grey,
                  ),
                ),
            ],
          ),
        ),

        // Recommended Posts List
        if (_isLoadingRecommended)
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Center(child: CircularProgressIndicator()),
          )
        else
          SizedBox(
            height: 200,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              itemCount: _recommendedPosts.length,
              itemBuilder: (context, index) {
                return SizedBox(
                  width: 200,
                  child: _buildRecommendedPostCard(_recommendedPosts[index]),
                );
              },
            ),
          ),
      ],
    );
  }

  // Build recommended post card (compact version)
  Widget _buildRecommendedPostCard(Post post) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: InkWell(
          onTap: () => _navigateToPostDetail(post),
          borderRadius: BorderRadius.circular(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image section with category badge overlay
              Stack(
                children: [
                  ClipRRect(
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(12)),
                    child: Container(
                      height: 100,
                      width: double.infinity,
                      child: _buildPostImage(post, height: 100),
                    ),
                  ),

                  // Category badge positioned in top-left corner of image
                  Positioned(
                    top: 6,
                    left: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 2),
                      decoration: BoxDecoration(
                        color: CategoryUtils.getCategoryColor(post.category),
                        borderRadius: BorderRadius.circular(6),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 2,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            CategoryUtils.getCategoryIcon(post.category),
                            color: Colors.white,
                            size: 8,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            CategoryUtils.getCategoryDisplayName(post.category),
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
                ],
              ),

              // Content section
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title
                      Text(
                        post.title,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),

                      // Location
                      Row(
                        children: [
                          Icon(
                            Icons.location_on,
                            size: 10,
                            color: ThemeConstants.grey,
                          ),
                          const SizedBox(width: 2),
                          Expanded(
                            child: Text(
                              post.location.address ?? 'Unknown location',
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontSize: 10,
                                color: ThemeConstants.grey,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
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
              Row(
                children: [
                  Icon(
                    Icons.recommend,
                    color: ThemeConstants.primaryColor,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Recommended for You',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: ThemeConstants.primaryColor,
                        ),
                  ),
                ],
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

        // Recommended Posts content
        _buildRecommendedPostsContent(),
      ],
    );
  }

  Widget _buildPostsList(List<Post> posts) {
    // Preserve the backend's recommendation order - don't sort by honesty score
    // The backend already provides posts in the optimal recommendation order

    // Extract featured and regular posts while preserving order
    final featuredPost = posts.isNotEmpty ? posts.first : null;
    final regularPosts = posts.length > 1 ? posts.sublist(1) : <Post>[];

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
              color: Colors.black.withAlpha(51), // 0.2 * 255 = 51
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
              child: GestureDetector(
                onTap: () => _openMediaPreview(post),
                child: _buildImage(_getBestImageUrl(post)),
              ),
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
                    Colors.black.withAlpha(51), // 0.2 * 255 = 51
                    Colors.black.withAlpha(179), // 0.7 * 255 = 179
                  ],
                  stops: const [0.5, 0.75, 0.95],
                ),
              ),
            ),

            // Category badge positioned in top-left corner
            Positioned(
              top: 16,
              left: 16,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: CategoryUtils.getCategoryColor(post.category),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(51),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      CategoryUtils.getCategoryIcon(post.category),
                      color: Colors.white,
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      CategoryUtils.getCategoryDisplayName(post.category),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
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
                            color: Colors.white.withAlpha(51), // 0.2 * 255 = 51
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
                                color: Colors.black
                                    .withAlpha(51), // 0.2 * 255 = 51
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
                        color: Colors.black.withAlpha(51), // 0.2 * 255 = 51
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
              // Image section with category badge overlay
              Stack(
                children: [
                  SizedBox(
                    height: 126, // Fixed height for image
                    width: double.infinity,
                    child: GestureDetector(
                      onTap: () => _openMediaPreview(post),
                      child: _buildImage(_getBestImageUrl(post)),
                    ),
                  ),

                  // Category badge positioned in top-left corner of image
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: CategoryUtils.getCategoryColor(post.category),
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 2,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            CategoryUtils.getCategoryIcon(post.category),
                            color: Colors.white,
                            size: 10,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            CategoryUtils.getCategoryDisplayName(post.category),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
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

  // Helper method to format category name for display
  String _formatCategoryName(String category) {
    switch (category.toLowerCase()) {
      case 'news':
        return 'News';
      case 'event':
        return 'Event';
      case 'alert':
        return 'Alert';
      case 'community':
        return 'Community';
      case 'emergency':
        return 'Emergency';
      case 'sports':
        return 'Sports';
      case 'culture':
        return 'Culture';
      case 'business':
        return 'Business';
      case 'politics':
        return 'Politics';
      case 'health':
        return 'Health';
      case 'education':
        return 'Education';
      case 'technology':
        return 'Technology';
      case 'entertainment':
        return 'Entertainment';
      case 'food':
        return 'Food';
      case 'travel':
        return 'Travel';
      case 'weather':
        return 'Weather';
      case 'traffic':
        return 'Traffic';
      case 'construction':
        return 'Construction';
      case 'security':
        return 'Security';
      case 'other':
        return 'Other';
      default:
        return category.isNotEmpty
            ? category[0].toUpperCase() + category.substring(1)
            : 'Other';
    }
  }

  // Helper method to get category color
  Color _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'news':
        return Colors.blue;
      case 'event':
        return Colors.purple;
      case 'alert':
        return Colors.orange;
      case 'emergency':
        return Colors.red;
      case 'community':
        return Colors.green;
      case 'sports':
        return Colors.teal;
      case 'culture':
        return Colors.indigo;
      case 'business':
        return Colors.brown;
      case 'politics':
        return Colors.deepPurple;
      case 'health':
        return Colors.pink;
      case 'education':
        return Colors.cyan;
      case 'technology':
        return Colors.blueGrey;
      case 'entertainment':
        return Colors.amber;
      case 'food':
        return Colors.deepOrange;
      case 'travel':
        return Colors.lightBlue;
      case 'weather':
        return Colors.lightGreen;
      case 'traffic':
        return Colors.yellow[700] ?? Colors.yellow;
      case 'construction':
        return Colors.grey[600] ?? Colors.grey;
      case 'security':
        return Colors.red[800] ?? Colors.red;
      default:
        return Colors.grey;
    }
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
    // Handle null or empty image URL
    if (imageUrl == null || imageUrl.isEmpty) {
      return _buildPlaceholderImage();
    }

    // Check if it's a video file
    if (_isVideoFile(imageUrl)) {
      return _buildVideoThumbnail(imageUrl, fit: fit);
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

  // Extract thumbnail URL from video URL or post data - Direct server approach
  String? _extractThumbnailUrl(String videoUrl) {
    // This method constructs the thumbnail URL using the server's base URL + path pattern
    try {
      // Extract the relative path from the video URL
      String relativePath = '';

      if (videoUrl.contains('attachments/video/')) {
        // Extract path after domain (e.g., /media/attachments/video/filename.mp4)
        int pathIndex = videoUrl.indexOf('attachments/video/');
        relativePath = videoUrl.substring(pathIndex);

        // Convert to thumbnail path
        relativePath = relativePath.replaceAll(
            'attachments/video/', 'media/attachments/thumbnails/');
        relativePath = relativePath.replaceAll('.mp4', '_thumb.jpg');

        // Construct full URL using ApiUrls.baseUrl without extra /media/
        String thumbnailUrl = '${ApiUrls.baseUrl}/$relativePath';
        print('🎥 Constructed server thumbnail URL: $thumbnailUrl');
        return thumbnailUrl;
      } else if (videoUrl.contains('attachments/image/') &&
          videoUrl.endsWith('.mp4')) {
        // Handle videos that were incorrectly placed in image directory
        int pathIndex = videoUrl.indexOf('attachments/image/');
        relativePath = videoUrl.substring(pathIndex);

        // Convert to thumbnail path
        relativePath = relativePath.replaceAll(
            'attachments/image/', 'attachments/thumbnails/');
        relativePath = relativePath.replaceAll('.mp4', '_thumb.jpg');

        // Construct full URL using ApiUrls.baseUrl without extra /media/
        String thumbnailUrl = '${ApiUrls.baseUrl}/$relativePath';
        print(
            '🎥 Constructed server thumbnail URL for misplaced video: $thumbnailUrl');
        return thumbnailUrl;
      }
    } catch (e) {
      print('🎥 Error extracting thumbnail URL: $e');
    }
    return null;
  }

  // Build video thumbnail with play overlay - Server-first approach
  Widget _buildVideoThumbnail(String videoUrl, {BoxFit fit = BoxFit.cover}) {
    // Try to get server-generated thumbnail first
    String? thumbnailUrl = _extractThumbnailUrl(videoUrl);

    return Container(
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
              loadingBuilder: (context, child, progress) {
                if (progress == null) return child;
                return _buildVideoLoading();
              },
              errorBuilder: (context, error, stackTrace) {
                print(
                    '🎥 Server thumbnail failed, trying client generation: $error, URL: $thumbnailUrl');
                // Fallback to client-side thumbnail generation
                return FutureBuilder<Widget>(
                  future: _buildVideoThumbnailWidget(videoUrl, fit),
                  builder: (context, snapshot) {
                    if (snapshot.hasData) {
                      return snapshot.data!;
                    } else if (snapshot.hasError) {
                      print(
                          '🎥 Client thumbnail also failed: ${snapshot.error}');
                      return _buildVideoPattern();
                    } else {
                      return _buildVideoLoading();
                    }
                  },
                );
              },
            )
          else
            // No server thumbnail available, try client-side generation
            FutureBuilder<Widget>(
              future: _buildVideoThumbnailWidget(videoUrl, fit),
              builder: (context, snapshot) {
                if (snapshot.hasData) {
                  return snapshot.data!;
                } else if (snapshot.hasError) {
                  print(
                      '🎥 Video thumbnail generation failed: ${snapshot.error}');
                  return _buildVideoPattern();
                } else {
                  return _buildVideoLoading();
                }
              },
            ),

          // Play button overlay
          Center(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.8),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 8,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: const Icon(
                Icons.play_arrow,
                color: Colors.white,
                size: 36,
              ),
            ),
          ),

          // Video indicator badge
          Positioned(
            top: 12,
            right: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.9),
                borderRadius: BorderRadius.circular(6),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.videocam,
                    color: Colors.white,
                    size: 14,
                  ),
                  SizedBox(width: 4),
                  Text(
                    'VIDEO',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
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
      // Strategy 1: Try video_thumbnail package
      final thumbnailData = await _generateVideoThumbnail(videoUrl);
      if (thumbnailData != null && thumbnailData.isNotEmpty) {
        print('🎥 Successfully generated video thumbnail');
        return Image.memory(
          thumbnailData,
          fit: fit,
          errorBuilder: (context, error, stackTrace) {
            print('🎥 Error displaying thumbnail: $error');
            return _buildVideoPattern();
          },
        );
      }
    } catch (e) {
      print('🎥 Video thumbnail generation failed: $e');
    }

    // Strategy 2: Return a nice video pattern fallback
    return _buildVideoPattern();
  }

  // Generate video thumbnail with improved error handling
  Future<Uint8List?> _generateVideoThumbnail(String videoUrl) async {
    try {
      String processedVideoUrl = _getFixedImageUrl(videoUrl);
      print('🎥 Processing video URL: $processedVideoUrl');

      // Multiple attempts with different parameters
      List<Map<String, dynamic>> attempts = [
        {'timeMs': 1000, 'quality': 75},
        {'timeMs': 2000, 'quality': 85},
        {'timeMs': 500, 'quality': 65},
        {'timeMs': 0, 'quality': 75}, // Try at the very beginning
      ];

      for (var attempt in attempts) {
        try {
          print(
              '🎥 Attempting thumbnail generation with timeMs: ${attempt['timeMs']}, quality: ${attempt['quality']}');

          final uint8list = await VideoThumbnail.thumbnailData(
            video: processedVideoUrl,
            imageFormat: ImageFormat.JPEG,
            maxWidth: 400,
            maxHeight: 300,
            timeMs: attempt['timeMs'],
            quality: attempt['quality'],
          );

          if (uint8list != null && uint8list.isNotEmpty) {
            print(
                '🎥 Success! Generated thumbnail with ${uint8list.length} bytes');
            return uint8list;
          }
        } catch (e) {
          print('🎥 Attempt failed: $e');
          continue;
        }
      }

      print('🎥 All thumbnail generation attempts failed');
      return null;
    } catch (e) {
      print('🎥 Critical error in thumbnail generation: $e');
      return null;
    }
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
              size: 64,
              color: Colors.white.withOpacity(0.7),
            ),
            const SizedBox(height: 8),
            Text(
              'Video Preview',
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontSize: 14,
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
      color: Colors.grey[300],
      child: const Center(
        child: CircularProgressIndicator(),
      ),
    );
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

  // Build content for recommended posts instead of using Consumer
  Widget _buildRecommendedPostsContent() {
    debugPrint(
        '🎯🎯🎯 NewsFeedSection _buildRecommendedPostsContent BUILD START 🎯🎯🎯');
    debugPrint('🎯 Local _isLoading=$_isLoading');
    debugPrint('🎯 Local _isLoadingRecommended=$_isLoadingRecommended');
    debugPrint('🎯 Recommended posts.length=${_recommendedPosts.length}');
    debugPrint('🎯 Recommendation message: $_recommendationMessage');

    // Show local loading state first
    if (_isLoading || _isLoadingRecommended) {
      debugPrint(
          '🎯 CONDITION: _isLoading or _isLoadingRecommended is true -> Showing loading indicator');
      return const Center(child: CircularProgressIndicator());
    }

    // Show no news message if we have no posts and aren't loading
    if (_recommendedPosts.isEmpty) {
      debugPrint(
          '🎯 CONDITION: _recommendedPosts.isEmpty -> Showing no recommendations message');
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.recommend_outlined,
                size: 48, color: ThemeConstants.grey),
            const SizedBox(height: 16),
            Text(
              'No posts available for ${widget.selectedDate.toLocal().toString().split(' ')[0]}',
              style: const TextStyle(color: ThemeConstants.grey),
              textAlign: TextAlign.center,
            ),
            if (_recommendationMessage.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                _recommendationMessage,
                style:
                    const TextStyle(color: ThemeConstants.grey, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ],
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
        '🎯 CONDITION: DEFAULT -> Showing recommended posts list with ${_recommendedPosts.length} posts');
    debugPrint(
        '🎯🎯🎯 NewsFeedSection _buildRecommendedPostsContent BUILD END 🎯🎯🎯');
    return _buildPostsList(_recommendedPosts);
  }

  // Build post image widget - handles different media types
  Widget _buildPostImage(Post post, {double? height}) {
    final String imageUrl = _getBestImageUrl(post);

    // Check if it's a video file
    if (_isVideoFile(imageUrl)) {
      return _buildVideoThumbnail(imageUrl, fit: BoxFit.cover);
    }

    // Otherwise build regular image
    return _buildImage(imageUrl, fit: BoxFit.cover);
  }
}
