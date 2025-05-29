import 'package:flutter/material.dart';
import 'package:flutter_application_2/constants/theme_constants.dart';
import 'package:flutter_application_2/models/post.dart';
import 'package:flutter_application_2/providers/posts_provider.dart';
import 'package:flutter_application_2/ui/pages/home/components/post_detail/post_detail_page.dart';
import 'package:flutter_application_2/ui/pages/home/components/news_search_page.dart';
import 'package:provider/provider.dart';
import 'package:flutter_application_2/constants/category_utils.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_application_2/services/api/account/api_urls.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:flutter_application_2/utils/time_formatter.dart';

class AllNewsPage extends StatefulWidget {
  const AllNewsPage({super.key});

  @override
  State<AllNewsPage> createState() => _AllNewsPageState();
}

class _AllNewsPageState extends State<AllNewsPage> {
  String _selectedFilter = 'Popular';
  String _selectedCategory = 'All';
  DateTime _selectedDate = DateTime.now();

  bool _isLoadingMore = false;

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  final List<String> _filterOptions = [
    'Popular',
    'Latest',
    'Most Upvoted',
    'Verified Only',
  ];

  // Category options including 'All' and categories from CategoryUtils
  List<String> get _categoryOptions => ['All', ...CategoryUtils.allCategories];

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
      // Format date for API call
      final formattedDate = _selectedDate.toIso8601String().split('T').first;
      await postsProvider.fetchPosts(date: formattedDate, refresh: refresh);
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
        final formattedDate = _selectedDate.toIso8601String().split('T').first;
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

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
      // Fetch posts for the new date
      _fetchAllPosts(refresh: true);
    }
  }

  List<Post> _getFilteredPosts(List<Post> posts) {
    // First filter by category
    List<Post> categoryFiltered = posts;
    if (_selectedCategory != 'All') {
      categoryFiltered = posts
          .where((post) =>
              post.category.toLowerCase() == _selectedCategory.toLowerCase())
          .toList();
    }

    // Then apply sorting filter
    switch (_selectedFilter) {
      case 'Popular':
        // For now, return as-is (server order), can be enhanced later with ML recommendations
        return categoryFiltered;
      case 'Latest':
        return List.from(categoryFiltered)
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      case 'Most Upvoted':
        return List.from(categoryFiltered)
          ..sort((a, b) => b.upvotes.compareTo(a.upvotes));
      case 'Verified Only':
        return categoryFiltered.where((post) => post.author.isVerified).toList()
          ..sort((a, b) => b.createdAt
              .compareTo(a.createdAt)); // Sort verified posts by latest
      default:
        return categoryFiltered;
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
          // Date Picker and Sort Filter Section
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
            child: Row(
              children: [
                // Date Picker
                Icon(Icons.calendar_today,
                    size: 20, color: ThemeConstants.primaryColor),
                const SizedBox(width: 8),
                Text(
                  'Date:',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: GestureDetector(
                    onTap: _selectDate,
                    child: Container(
                      height: 32, // Fixed height to match sort dropdown
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 0),
                      decoration: BoxDecoration(
                        color: theme.cardColor,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: ThemeConstants.primaryColor.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}",
                            style: TextStyle(
                              color: ThemeConstants.primaryColor,
                              fontWeight: FontWeight.w500,
                              fontSize: 11, // Match dropdown font size
                            ),
                          ),
                          Icon(Icons.arrow_drop_down,
                              color: ThemeConstants.primaryColor,
                              size: 14), // Match dropdown icon size
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                // Sort Filter Dropdown
                Icon(Icons.sort, size: 20, color: ThemeConstants.primaryColor),
                const SizedBox(width: 8),
                Text(
                  'Sort:',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: Container(
                    height: 32, // Fixed height to match date picker
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                    decoration: BoxDecoration(
                      color: theme.cardColor,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: ThemeConstants.primaryColor.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedFilter,
                        isExpanded: true,
                        isDense: true, // Makes dropdown more compact
                        icon: Icon(Icons.arrow_drop_down,
                            color: ThemeConstants.primaryColor, size: 14),
                        style: TextStyle(
                          color: ThemeConstants.primaryColor,
                          fontWeight: FontWeight.w500,
                          fontSize: 11, // Smaller font size
                        ),
                        dropdownColor: theme.cardColor,
                        items: _filterOptions.map((String filter) {
                          return DropdownMenuItem<String>(
                            value: filter,
                            child: Text(
                              filter,
                              style: TextStyle(
                                color: theme.textTheme.bodyMedium?.color,
                                fontSize: 11, // Smaller font size
                              ),
                            ),
                          );
                        }).toList(),
                        onChanged: (String? newValue) {
                          if (newValue != null) {
                            setState(() {
                              _selectedFilter = newValue;
                            });
                          }
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Category Filter Section
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'Categories',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 34,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _categoryOptions.length,
                    itemBuilder: (context, index) {
                      final category = _categoryOptions[index];
                      final isSelected = category == _selectedCategory;

                      if (category == 'All') {
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            label: Text(
                              'All',
                              style: TextStyle(
                                fontSize: 12,
                                color: isSelected
                                    ? Colors.white
                                    : ThemeConstants.primaryColor,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                            selected: isSelected,
                            onSelected: (_) {
                              setState(() {
                                _selectedCategory = 'All';
                              });
                            },
                            backgroundColor:
                                ThemeConstants.primaryColor.withOpacity(0.1),
                            selectedColor: ThemeConstants.primaryColor,
                            labelPadding:
                                const EdgeInsets.symmetric(horizontal: 6),
                            padding: EdgeInsets.zero,
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                            checkmarkColor: Colors.white,
                            visualDensity: VisualDensity.compact,
                          ),
                        );
                      }

                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedCategory = category;
                            });
                          },
                          child: CategoryUtils.buildCategoryChip(
                            category: category,
                            isSelected: isSelected,
                            height: 32,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
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

                        // Date/Time
                        Row(
                          children: [
                            Icon(
                              Icons.access_time,
                              size: 14,
                              color: ThemeConstants.grey,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              TimeFormatter.getFormattedTime(post.createdAt),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: ThemeConstants.grey,
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

  // Enhanced image handling for various path formats with video support
  Widget _buildPostImage(Post post, {BoxFit fit = BoxFit.cover}) {
    final imageUrl = _getFixedImageUrl(_getPostImageUrl(post));

    if (imageUrl.isEmpty) {
      return _buildImagePlaceholder();
    }

    // Check if it's a video file
    if (_isVideoFile(imageUrl)) {
      return _buildVideoThumbnail(imageUrl, fit: fit);
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
              padding: const EdgeInsets.all(12),
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
                size: 24,
              ),
            ),
          ),

          // Video indicator badge
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.9),
                borderRadius: BorderRadius.circular(4),
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
                    size: 12,
                  ),
                  SizedBox(width: 3),
                  Text(
                    'VIDEO',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 9,
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
              size: 32,
              color: Colors.white.withOpacity(0.7),
            ),
            const SizedBox(height: 4),
            Text(
              'Video Preview',
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontSize: 10,
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
