import 'package:flutter/material.dart';
import 'package:flutter_application_2/constants/theme_constants.dart';
import 'package:flutter_application_2/models/post.dart';
import 'package:flutter_application_2/providers/posts_provider.dart';
import 'package:flutter_application_2/ui/pages/home/components/post_detail/post_detail_page.dart';
import 'package:flutter_application_2/ui/pages/home/components/news_search_page.dart';
import 'package:provider/provider.dart';
import 'package:flutter_application_2/constants/category_utils.dart';
import 'dart:io';
import 'package:flutter_application_2/services/api/account/api_urls.dart';

class AllNewsPage extends StatefulWidget {
  const AllNewsPage({super.key});

  @override
  State<AllNewsPage> createState() => _AllNewsPageState();
}

class _AllNewsPageState extends State<AllNewsPage> {
  String _selectedFilter = 'Latest';
  String _searchQuery = '';
  bool _isSearching = false;
  List<Post> _searchResults = [];
  bool _isLoadingMore = false;

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  final List<String> _filterOptions = [
    'Latest',
    'Trending',
    'Most Upvoted',
    'Verified Only',
  ];

  // Track voted posts
  final Map<int, bool?> _userVotes =
      {}; // true for upvote, false for downvote, null for no vote

  @override
  void initState() {
    super.initState();
    // Schedule fetch after the widget is built to avoid setState during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchAllPosts(refresh: true);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _fetchAllPosts({bool refresh = false}) async {
    try {
      final postsProvider = Provider.of<PostsProvider>(context, listen: false);
      await postsProvider.fetchPosts(refresh: refresh);
    } catch (e) {
      debugPrint('Error fetching all posts: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load posts: $e')),
        );
      }
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
      final postsProvider = Provider.of<PostsProvider>(context, listen: false);
      if (postsProvider.hasMore && !postsProvider.isFetchingMore) {
        await postsProvider.loadMorePosts();
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

  Future<void> _searchPosts() async {
    if (_searchQuery.trim().isEmpty) {
      setState(() {
        _isSearching = false;
        _searchResults.clear();
      });
      return;
    }

    setState(() {
      _isSearching = true;
    });

    try {
      final results = await Provider.of<PostsProvider>(context, listen: false)
          .searchPosts(_searchQuery);
      setState(() {
        _searchResults = results;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Search failed: $e')),
      );
    } finally {
      setState(() {
        _isSearching = false;
      });
    }
  }

  void _navigateToPostDetail(Post post) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PostDetailPage(
          title: post.title,
          description: post.content,
          imageUrl: post.hasMedia && post.mediaUrls.isNotEmpty
              ? post.mediaUrls.first
              : 'https://picsum.photos/seed/news${post.id}/800/600',
          location: post.location.address ?? "Unknown location",
          time: post.createdAt.toString(),
          honesty: post.honestyScore,
          upvotes: post.upvotes,
          comments: 0,
          isVerified: post.author.isVerified,
          post: post, // Pass the complete Post object
          authorName: post.author.name,
          distance: post.distance > 0
              ? '${post.distance.toStringAsFixed(1)} mi'
              : null,
        ),
      ),
    );
  }

  void _handleVote(Post post, bool isUpvote) {
    // Save the current state before optimistic update
    final previousVote = _userVotes[post.id];
    final previousUpvotes = post.upvotes;

    // Apply optimistic UI update
    setState(() {
      // If already voted the same way, remove the vote
      if (_userVotes[post.id] == isUpvote) {
        _userVotes[post.id] = null; // Clear the vote
      } else {
        _userVotes[post.id] = isUpvote; // Set new vote
      }
    });

    // Try to update the post vote in provider
    Provider.of<PostsProvider>(context, listen: false)
        .voteOnPost(post, isUpvote)
        .then((result) {
      // Success case handled by the provider
      return result;
    }).catchError((error) {
      // If the API call fails, revert to previous state
      if (mounted) {
        setState(() {
          _userVotes[post.id] = previousVote;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to register vote: Please try again later'),
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      debugPrint('Error voting on post: $error');

      // Return an empty map to match the Future's type
      return <String, dynamic>{};
    });
  }

  List<Post> _getFilteredPosts(List<Post> posts) {
    switch (_selectedFilter) {
      case 'Latest':
        return List.from(posts)
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      case 'Trending':
        return List.from(posts)
          ..sort((a, b) => b.honestyScore.compareTo(a.honestyScore));
      case 'Most Upvoted':
        return List.from(posts)..sort((a, b) => b.upvotes.compareTo(a.upvotes));
      case 'Verified Only':
        return posts.where((post) => post.author.isVerified).toList();
      default:
        return posts;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('News Feed'),
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              final postsProvider =
                  Provider.of<PostsProvider>(context, listen: false);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => NewsSearchPage(
                    postsProvider: postsProvider,
                  ),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _fetchAllPosts(refresh: true),
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter chips
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: theme.scaffoldBackgroundColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 3,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: SizedBox(
              height: 34,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _filterOptions.length,
                itemBuilder: (context, index) {
                  final filter = _filterOptions[index];
                  final isSelected = filter == _selectedFilter;

                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(
                        filter,
                        style: TextStyle(
                          fontSize: 12,
                          color: isSelected
                              ? ThemeConstants.primaryColor
                              : theme.textTheme.bodyMedium?.color,
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      selected: isSelected,
                      onSelected: (_) {
                        setState(() {
                          _selectedFilter = filter;
                          _searchResults.clear();
                          _isSearching = false;
                          _searchQuery = '';
                          _searchController.clear();
                        });
                      },
                      backgroundColor: theme.cardColor,
                      selectedColor:
                          ThemeConstants.primaryColor.withOpacity(0.2),
                      labelPadding: const EdgeInsets.symmetric(horizontal: 6),
                      padding: EdgeInsets.zero,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      checkmarkColor: ThemeConstants.primaryColor,
                      visualDensity: VisualDensity.compact,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          // Main content
          Expanded(
            child: Consumer<PostsProvider>(
              builder: (context, postsProvider, child) {
                if (postsProvider.isLoading && postsProvider.posts.isEmpty) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                if (postsProvider.errorMessage != null &&
                    postsProvider.posts.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 64,
                          color: ThemeConstants.grey.withOpacity(0.5),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Error: ${postsProvider.errorMessage}',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: ThemeConstants.grey,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        TextButton.icon(
                          onPressed: () => _fetchAllPosts(refresh: true),
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry'),
                        ),
                      ],
                    ),
                  );
                }

                if (postsProvider.posts.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.article_outlined,
                          size: 64,
                          color: ThemeConstants.grey.withOpacity(0.5),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No news available',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: ThemeConstants.grey,
                          ),
                        ),
                        const SizedBox(height: 24),
                        TextButton.icon(
                          onPressed: () => _fetchAllPosts(refresh: true),
                          icon: const Icon(Icons.refresh),
                          label: const Text('Refresh'),
                        ),
                      ],
                    ),
                  );
                }

                final filteredPosts = _getFilteredPosts(postsProvider.posts);

                return RefreshIndicator(
                  onRefresh: () => _fetchAllPosts(refresh: true),
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
                      padding: const EdgeInsets.all(16),
                      itemCount: filteredPosts.length +
                          (postsProvider.hasMore ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == filteredPosts.length) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16.0),
                            child: Center(
                              child: SizedBox(
                                height: 32,
                                width: 32,
                                child: _isLoadingMore
                                    ? const CircularProgressIndicator()
                                    : const Text('No more posts'),
                              ),
                            ),
                          );
                        }

                        final post = filteredPosts[index];
                        return _buildNewsListItem(post);
                      },
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNewsListItem(Post post) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    // Check if this post has been voted on
    final userVote = _userVotes[post.id];
    final hasUpvoted = userVote == true;
    final hasDownvoted = userVote == false;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: GestureDetector(
        onTap: () => _navigateToPostDetail(post),
        child: Container(
          decoration: BoxDecoration(
            color: isDarkMode ? theme.cardColor : Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Image with category badge overlay
                Stack(
                  children: [
                    // Image
                    SizedBox(
                      width: 120,
                      child: _buildPostImage(post),
                    ),

                    // Category badge
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: CategoryUtils.getCategoryColor(post.category),
                          borderRadius: BorderRadius.circular(10),
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
                            Icon(
                              CategoryUtils.getCategoryIcon(post.category),
                              color: Colors.white,
                              size: 12,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              CategoryUtils.getCategoryDisplayName(
                                  post.category),
                              style: const TextStyle(
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

                // Content
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title
                        Text(
                          post.title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),

                        const SizedBox(height: 8),

                        // Preview content
                        Text(
                          post.content,
                          style: theme.textTheme.bodyMedium,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),

                        const SizedBox(height: 12),

                        // Location
                        if (post.location.address != null)
                          Row(
                            children: [
                              Icon(
                                Icons.location_on,
                                size: 14,
                                color: ThemeConstants.grey,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  post.location.address!,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: ThemeConstants.grey,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),

                        const SizedBox(height: 8),

                        // Footer with voting and badges (voting disabled)
                        Row(
                          children: [
                            // Upvote (non-clickable)
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Icon(
                                Icons.arrow_upward_rounded,
                                color: Colors.green.withOpacity(0.7),
                                size: 20,
                              ),
                            ),

                            const SizedBox(width: 4),

                            Text(
                              '${post.upvotes}',
                              style: theme.textTheme.bodyMedium,
                            ),

                            const SizedBox(width: 8),

                            // Downvote (non-clickable)
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Icon(
                                Icons.arrow_downward_rounded,
                                color: Colors.red.withOpacity(0.7),
                                size: 20,
                              ),
                            ),

                            const Spacer(),

                            // Honesty score
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: _getHonestyColor(post.honestyScore),
                                borderRadius: BorderRadius.circular(10),
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
                                  Icon(Icons.verified_user,
                                      color: Colors.white, size: 10),
                                  const SizedBox(width: 2),
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

                            const SizedBox(width: 8),

                            // Verified badge
                            if (post.author.isVerified)
                              Container(
                                padding: const EdgeInsets.all(3),
                                decoration: const BoxDecoration(
                                  color: Colors.blue,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.verified,
                                  color: Colors.white,
                                  size: 14,
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

  // Enhanced image handling for various path formats
  Widget _buildPostImage(Post post, {BoxFit fit = BoxFit.cover}) {
    final imageUrl = _getFixedImageUrl(_getPostImageUrl(post));

    if (imageUrl.isEmpty) {
      return _buildImagePlaceholder();
    }

    if (_isFilePath(imageUrl)) {
      // Handle local file paths
      return Image.file(
        File(imageUrl),
        fit: fit,
        errorBuilder: (context, error, stackTrace) {
          debugPrint('Error loading file image: $error');
          return _buildImagePlaceholder();
        },
      );
    } else {
      // Always fix the image URL
      return Image.network(
        imageUrl,
        fit: fit,
        errorBuilder: (context, error, stackTrace) {
          debugPrint('Error loading network image: $error');
          return _buildImagePlaceholder();
        },
      );
    }
  }

  // Consistent placeholder for missing images
  Widget _buildImagePlaceholder() {
    return Container(
      color: ThemeConstants.greyLight,
      child: Center(
        child: Icon(
          Icons.image,
          size: 40,
          color: ThemeConstants.grey.withOpacity(0.5),
        ),
      ),
    );
  }

  // Check if a path is a file path rather than a URL
  bool _isFilePath(String path) {
    return path.startsWith('/') ||
        path.startsWith('file:/') ||
        !path.contains('://');
  }

  // Get the best available image URL for a post
  String? _getPostImageUrl(Post post) {
    // Try to get media URLs first
    if (post.hasMedia && post.mediaUrls.isNotEmpty) {
      return post.mediaUrls.first;
    }

    // Then try direct imageUrl property
    if (post.imageUrl.isNotEmpty) {
      return post.imageUrl;
    }

    // Fallback to a generated placeholder
    return 'https://picsum.photos/seed/news${post.id}/800/600';
  }
}
