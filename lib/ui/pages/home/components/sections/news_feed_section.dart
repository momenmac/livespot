import 'package:flutter/material.dart';
import 'package:flutter_application_2/constants/theme_constants.dart';
import 'package:flutter_application_2/models/post.dart';
import 'package:flutter_application_2/providers/posts_provider.dart';
import 'package:flutter_application_2/ui/pages/home/components/all_news_page.dart';
import 'package:flutter_application_2/ui/pages/home/components/post_detail/post_detail_page.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;
import 'dart:io';

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
        _fetchPosts();
      }
    });
  }

  @override
  void didUpdateWidget(NewsFeedSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reload posts if the selected date changes, but use post-frame callback
    if (oldWidget.selectedDate != widget.selectedDate) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _fetchPosts();
        }
      });
    }
  }

  Future<void> _fetchPosts() async {
    try {
      // Format date as YYYY-MM-DD for API
      final formattedDate =
          widget.selectedDate.toIso8601String().split('T').first;

      await Provider.of<PostsProvider>(context, listen: false)
          .fetchPosts(date: formattedDate);
    } catch (e) {
      // Handle any errors, but don't rethrow
      debugPrint('Error fetching posts: $e');
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
    return Consumer<PostsProvider>(
      builder: (context, postsProvider, child) {
        if (postsProvider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (postsProvider.posts.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline,
                    size: 48, color: ThemeConstants.grey),
                const SizedBox(height: 16),
                Text(
                  'No news available for ${widget.selectedDate.toLocal().toString().split(' ')[0]}',
                  style: const TextStyle(color: ThemeConstants.grey),
                ),
                const SizedBox(height: 24),
                TextButton.icon(
                  onPressed: _fetchPosts,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refresh'),
                ),
              ],
            ),
          );
        }

        // Get a list of posts, sorted by honesty score
        final posts = List.of(postsProvider.posts)
          ..sort((a, b) => b.honestyScore.compareTo(a.honestyScore));

        // Extract the featured post (highest honesty score)
        final featuredPost = posts.isNotEmpty ? posts.first : null;
        // Rest of the posts for the horizontal scroll
        final regularPosts = posts.length > 1 ? posts.sublist(1) : [];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Unified News Feed Section Header
            Padding(
              padding: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
              child: Row(
                children: [
                  const Text(
                    'News Feed',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: _navigateToAllNews,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'View All',
                          style: TextStyle(
                            color: ThemeConstants.primaryColor,
                            fontWeight: FontWeight.bold,
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

            // Featured post
            if (featuredPost != null) _buildFeaturedPostCard(featuredPost),

            // Regular posts in horizontal scroll
            if (regularPosts.isNotEmpty) ...[
              SizedBox(
                height: 240,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  itemCount: regularPosts.length,
                  itemBuilder: (context, index) {
                    final post = regularPosts[index];
                    return SizedBox(
                      width: 240, // Fixed width for each card
                      child: _buildRegularPostCard(post),
                    );
                  },
                ),
              ),
            ],
          ],
        );
      },
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
        elevation: 3, // Add more elevation for better shadow
        color: isDarkMode ? theme.cardColor : Colors.white,
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
      // Handle URL path - check if it needs a base URL prefix
      String processedUrl = imageUrl;
      if (imageUrl.startsWith('/')) {
        // Add domain for relative paths (like /media/images/file.jpg)
        processedUrl = 'http://localhost:8000$imageUrl';
      }

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
