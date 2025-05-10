import 'package:flutter/material.dart';
import 'package:flutter_application_2/constants/theme_constants.dart';
import 'package:flutter_application_2/models/post.dart';
import 'package:flutter_application_2/models/user.dart';
import 'package:flutter_application_2/models/coordinates.dart';
import 'package:flutter_application_2/providers/posts_provider.dart';
import 'package:flutter_application_2/ui/pages/home/components/post_detail/post_detail_page.dart';
import 'package:flutter_application_2/ui/widgets/responsive_snackbar.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:developer' as developer;

class NewsSearchPage extends StatefulWidget {
  final PostsProvider postsProvider;

  const NewsSearchPage({
    super.key,
    required this.postsProvider,
  });

  @override
  State<NewsSearchPage> createState() => _NewsSearchPageState();
}

class _NewsSearchPageState extends State<NewsSearchPage> {
  final TextEditingController _searchController = TextEditingController();
  List<Post> _searchResults = [];
  List<Map<String, dynamic>> _recentSearches = [];
  bool _isSearching = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadRecentSearches();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadRecentSearches() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final recentSearchesJson = prefs.getString('recent_news_searches');

      if (recentSearchesJson != null) {
        final List<dynamic> searches = json.decode(recentSearchesJson);
        setState(() {
          _recentSearches = List<Map<String, dynamic>>.from(searches);
        });
      }
    } catch (e) {
      debugPrint('Error loading recent searches: $e');
    }
  }

  Future<void> _saveRecentSearch(Post post) async {
    try {
      // Create a map with minimal post data for recent searches
      final searchData = {
        'id': post.id,
        'title': post.title,
        'content': post.content.length > 100
            ? '${post.content.substring(0, 100)}...'
            : post.content,
        'imageUrl': post.hasMedia && post.mediaUrls.isNotEmpty
            ? post.mediaUrls.first
            : '',
        'honestyScore': post.honestyScore,
        'address': post.location.address,
        'category': post.category,
        'createdAt': post.createdAt.toIso8601String(),
      };

      // Add to the start of the list and remove duplicates
      _recentSearches.removeWhere((item) => item['id'] == post.id);
      _recentSearches.insert(0, searchData);

      // Limit to 10 recent searches
      if (_recentSearches.length > 10) {
        _recentSearches = _recentSearches.sublist(0, 10);
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          'recent_news_searches', json.encode(_recentSearches));

      setState(() {});
    } catch (e) {
      debugPrint('Error saving recent search: $e');
    }
  }

  Future<void> _clearRecentSearches() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('recent_news_searches');
      setState(() {
        _recentSearches = [];
      });
    } catch (e) {
      debugPrint('Error clearing recent searches: $e');
    }
  }

  void _delayedSearch() {
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        _performSearch();
      }
    });
  }

  Future<void> _onSearchChanged() async {
    final query = _searchController.text.trim();

    setState(() {
      _isSearching = query.isNotEmpty;
    });

    if (!_isSearching) {
      setState(() {
        _searchResults = [];
      });
      return;
    }

    // Only search if query has at least 2 characters
    if (query.length >= 2) {
      // Use debounce technique to avoid too many API calls
      _delayedSearch();
    } else {
      setState(() {
        _searchResults = [];
      });
    }
  }

  Future<void> _performSearch() async {
    final query = _searchController.text.trim();

    if (query.length < 2) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final results = await widget.postsProvider.searchPosts(query);

      setState(() {
        _searchResults = results;
        _isLoading = false;
      });
      developer.log('Found ${results.length} news results for "$query"',
          name: 'NewsSearchPage');
    } catch (e) {
      setState(() {
        _searchResults = [];
        _isLoading = false;
      });
      debugPrint('Error searching for news: $e');

      if (mounted) {
        ResponsiveSnackBar.showError(
          context: context,
          message: 'Failed to search: ${e.toString()}',
        );
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        backgroundColor: isDark
            ? ThemeConstants.darkCardColor
            : ThemeConstants.primaryColorVeryLight,
        leading: IconButton(
          icon: Icon(Icons.arrow_back,
              color: isDark ? Colors.white : ThemeConstants.primaryColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'Search news...',
            border: InputBorder.none,
            hintStyle: TextStyle(
                color: isDark
                    ? Colors.white70
                    : ThemeConstants.primaryColor.withOpacity(0.6)),
            suffixIcon: _isSearching
                ? IconButton(
                    icon: Icon(Icons.close,
                        color: isDark
                            ? Colors.white
                            : ThemeConstants.primaryColor),
                    onPressed: () {
                      _searchController.clear();
                      setState(() {
                        _isSearching = false;
                        _searchResults = [];
                      });
                    },
                  )
                : null,
          ),
          style: TextStyle(
            color: isDark ? Colors.white : ThemeConstants.black,
          ),
          autofocus: true,
          onSubmitted: (_) => _performSearch(),
        ),
      ),
      body: _isSearching ? _buildSearchResults() : _buildRecentSearches(),
    );
  }

  Widget _buildRecentSearches() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16.0),
          decoration: BoxDecoration(
            color: isDark
                ? ThemeConstants.darkCardColor
                : ThemeConstants.primaryColorVeryLight,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 3,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recent Searches',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : ThemeConstants.primaryColor,
                ),
              ),
              if (_recentSearches.isNotEmpty)
                TextButton.icon(
                  icon: Icon(Icons.delete_outline,
                      size: 20, color: ThemeConstants.red.withOpacity(0.8)),
                  label: Text('Clear',
                      style: TextStyle(
                          color: ThemeConstants.red.withOpacity(0.8))),
                  onPressed: _clearRecentSearches,
                ),
            ],
          ),
        ),
        Expanded(
          child: _recentSearches.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.search,
                        size: 64,
                        color: ThemeConstants.primaryColor.withOpacity(0.3),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No recent searches',
                        style: TextStyle(
                          fontSize: 16,
                          color: isDark
                              ? Colors.white70
                              : ThemeConstants.primaryColor,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _recentSearches.length,
                  itemBuilder: (context, index) {
                    final search = _recentSearches[index];
                    final formattedDate = _formatDate(search['createdAt']);

                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 1,
                      color:
                          isDark ? ThemeConstants.darkCardColor : Colors.white,
                      child: ListTile(
                        leading: Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            color: isDark
                                ? ThemeConstants.darkBackgroundColor
                                : ThemeConstants.primaryColorLight,
                            borderRadius: BorderRadius.circular(8),
                            image: search['imageUrl'] != null &&
                                    search['imageUrl'].isNotEmpty
                                ? DecorationImage(
                                    image: NetworkImage(search['imageUrl']),
                                    fit: BoxFit.cover,
                                  )
                                : null,
                          ),
                          child: search['imageUrl'] == null ||
                                  search['imageUrl'].isEmpty
                              ? Icon(Icons.article,
                                  color: ThemeConstants.primaryColor)
                              : null,
                        ),
                        title: Text(
                          search['title'] ?? 'Unknown',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : ThemeConstants.black,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              search['content'] ?? '',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark
                                    ? Colors.white70
                                    : ThemeConstants.black.withOpacity(0.6),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(
                                  Icons.calendar_today,
                                  size: 12,
                                  color: ThemeConstants.primaryColor
                                      .withOpacity(0.7),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  formattedDate,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: ThemeConstants.primaryColor
                                        .withOpacity(0.7),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Icon(
                                  Icons.category,
                                  size: 12,
                                  color: _getCategoryColor(
                                          search['category'] ?? 'general')
                                      .withOpacity(0.7),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _capitalizeFirstLetter(
                                      search['category'] ?? 'general'),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: _getCategoryColor(
                                            search['category'] ?? 'general')
                                        .withOpacity(0.7),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        onTap: () {
                          // Convert back to Post object for navigation
                          final post = Post(
                            id: search['id'],
                            title: search['title'],
                            content: search['content'],
                            mediaUrls: search['imageUrl'] != null &&
                                    search['imageUrl'].isNotEmpty
                                ? [search['imageUrl']]
                                : [],
                            category: search['category'] ?? 'general',
                            location: PostCoordinates(
                              latitude: 0,
                              longitude: 0,
                              address: search['address'],
                            ),
                            author: User(
                              id: 0,
                              username: 'user',
                              fullName: '',
                              profileImage: null,
                              isVerified: false,
                            ),
                            createdAt: DateTime.parse(search['createdAt']),
                            upvotes: 0,
                            downvotes: 0,
                            honestyScore: search['honestyScore'] ?? 0,
                            status: 'published',
                            isVerifiedLocation: true,
                            takenWithinApp: true,
                            tags: [],
                          );
                          _navigateToPostDetail(post);
                        },
                        trailing: Icon(Icons.arrow_forward_ios,
                            size: 16, color: ThemeConstants.primaryColor),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildSearchResults() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(
          color: ThemeConstants.primaryColor,
        ),
      );
    }

    if (_searchController.text.length < 2) {
      return Center(
        child: Text(
          'Type at least 2 characters to search',
          style: TextStyle(
            color: isDark ? Colors.white70 : ThemeConstants.primaryColor,
          ),
        ),
      );
    }

    if (_searchResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: ThemeConstants.primaryColor.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'No results found for "${_searchController.text}"',
              style: TextStyle(
                fontSize: 16,
                color: isDark ? Colors.white70 : ThemeConstants.primaryColor,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final post = _searchResults[index];
        final formattedDate = _formatDate(post.createdAt.toString());

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: _getCategoryColor(post.category).withOpacity(0.3),
              width: 1,
            ),
          ),
          elevation: 3,
          shadowColor: _getCategoryColor(post.category).withOpacity(0.2),
          color: isDark ? ThemeConstants.darkCardColor : Colors.white,
          child: InkWell(
            onTap: () => _navigateToPostDetail(post),
            borderRadius: BorderRadius.circular(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Image if available
                if (post.hasMedia && post.mediaUrls.isNotEmpty)
                  ClipRRect(
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(12)),
                    child: Stack(
                      children: [
                        Image.network(
                          post.mediaUrls.first,
                          height: 150,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              height: 100,
                              color: isDark
                                  ? ThemeConstants.darkBackgroundColor
                                  : ThemeConstants.primaryColorLight,
                              child: Center(
                                child: Icon(
                                  Icons.image,
                                  size: 40,
                                  color: ThemeConstants.primaryColor
                                      .withOpacity(0.5),
                                ),
                              ),
                            );
                          },
                        ),
                        // Category badge overlay
                        Positioned(
                          top: 12,
                          left: 12,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: _getCategoryColor(post.category),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              _capitalizeFirstLetter(post.category),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title
                      Text(
                        post.title,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: isDark ? Colors.white : ThemeConstants.black,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),

                      const SizedBox(height: 8),

                      // Content preview
                      Text(
                        post.content,
                        style: TextStyle(
                          color: isDark
                              ? Colors.white70
                              : ThemeConstants.black.withOpacity(0.7),
                          fontSize: 14,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),

                      const SizedBox(height: 16),

                      // Bottom row
                      Row(
                        children: [
                          // If no image, show category badge here
                          if (!post.hasMedia || post.mediaUrls.isEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: _getCategoryColor(post.category),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                _capitalizeFirstLetter(post.category),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                ),
                              ),
                            ),

                          if (!post.hasMedia || post.mediaUrls.isEmpty)
                            const SizedBox(width: 8),

                          // Honesty score
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: _getHonestyColor(post.honestyScore),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.verified_user,
                                  color: Colors.white,
                                  size: 12,
                                ),
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

                          const Spacer(),

                          // Date
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? ThemeConstants.darkBackgroundColor
                                      .withOpacity(0.5)
                                  : ThemeConstants.primaryColorLight
                                      .withOpacity(0.7),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.access_time,
                                  size: 12,
                                  color: isDark
                                      ? Colors.white70
                                      : ThemeConstants.primaryColor,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  formattedDate,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark
                                        ? Colors.white70
                                        : ThemeConstants.primaryColor,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Verified badge if applicable
                          if (post.author.isVerified)
                            Padding(
                              padding: const EdgeInsets.only(left: 8),
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: ThemeConstants.primaryColor,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.verified,
                                  size: 12,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                        ],
                      ),

                      // Location if available
                      if (post.location.address != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? ThemeConstants.darkBackgroundColor
                                      .withOpacity(0.5)
                                  : ThemeConstants.primaryColorVeryLight,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isDark
                                    ? Colors.white24
                                    : ThemeConstants.primaryColorLight,
                                width: 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.location_on,
                                  size: 14,
                                  color: ThemeConstants.orange,
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    post.location.address!,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDark
                                          ? Colors.white70
                                          : ThemeConstants.black
                                              .withOpacity(0.7),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inDays == 0) {
        if (difference.inHours == 0) {
          return '${difference.inMinutes} min ago';
        }
        return '${difference.inHours} hr ago';
      } else if (difference.inDays < 7) {
        return '${difference.inDays} days ago';
      } else {
        return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      }
    } catch (e) {
      return 'Unknown date';
    }
  }

  String _capitalizeFirstLetter(String text) {
    if (text.isEmpty) return '';
    return text[0].toUpperCase() + text.substring(1);
  }

  Color _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'news':
        return Colors.blue;
      case 'event':
        return Colors.purple;
      case 'alert':
        return Colors.red;
      case 'traffic':
        return Colors.orange;
      case 'weather':
        return Colors.teal;
      case 'crime':
        return Colors.deepPurple;
      case 'community':
        return Colors.green;
      default:
        return ThemeConstants.primaryColor;
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
}
