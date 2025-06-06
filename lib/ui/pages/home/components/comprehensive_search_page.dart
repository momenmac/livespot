import 'package:flutter/material.dart';
import 'package:flutter_application_2/constants/theme_constants.dart';
import 'package:flutter_application_2/constants/category_utils.dart';
import 'package:flutter_application_2/services/api/account/api_urls.dart';
import 'package:flutter_application_2/models/post.dart';
import 'package:flutter_application_2/models/user.dart';
import 'package:flutter_application_2/models/coordinates.dart';
import 'package:flutter_application_2/providers/posts_provider.dart';
import 'package:flutter_application_2/providers/user_profile_provider.dart';
import 'package:flutter_application_2/ui/pages/home/components/post_detail/post_detail_page.dart';
import 'package:flutter_application_2/ui/profile/other_user_profile_page.dart';
import 'package:flutter_application_2/ui/widgets/responsive_snackbar.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:async';

class ComprehensiveSearchPage extends StatefulWidget {
  final PostsProvider postsProvider;
  final UserProfileProvider userProfileProvider;

  const ComprehensiveSearchPage({
    super.key,
    required this.postsProvider,
    required this.userProfileProvider,
  });

  @override
  State<ComprehensiveSearchPage> createState() =>
      _ComprehensiveSearchPageState();
}

class _ComprehensiveSearchPageState extends State<ComprehensiveSearchPage> {
  final TextEditingController _searchController = TextEditingController();

  // User search results
  List<Map<String, dynamic>> _userSearchResults = [];
  final Map<int, bool> _isFollowingMap = {};
  final Map<int, bool> _isLoadingFollowMap = {};

  // Post search results
  List<Post> _postSearchResults = [];

  // Recent searches
  List<Map<String, dynamic>> _recentUserSearches = [];
  List<Map<String, dynamic>> _recentPostSearches = [];

  // Loading states
  bool _isSearching = false;
  bool _isLoadingUsers = false;
  bool _isLoadingPosts = false;

  // Display limits
  final int _maxDisplayedUsers = 8;
  final int _maxDisplayedPosts = 5;
  bool _showAllUsers = false;
  bool _showAllPosts = false;

  // Debounce timer
  String _lastQuery = '';
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _loadRecentSearches();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadRecentSearches() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Load recent user searches
      final recentUserSearchesJson = prefs.getString('recent_user_searches');
      if (recentUserSearchesJson != null) {
        final List<dynamic> searches = json.decode(recentUserSearchesJson);
        setState(() {
          _recentUserSearches = List<Map<String, dynamic>>.from(searches);
        });
      }

      // Load recent post searches
      final recentPostSearchesJson = prefs.getString('recent_post_searches');
      if (recentPostSearchesJson != null) {
        final List<dynamic> searches = json.decode(recentPostSearchesJson);
        setState(() {
          _recentPostSearches = List<Map<String, dynamic>>.from(searches);
        });
      }
    } catch (e) {
      debugPrint('Error loading recent searches: $e');
    }
  }

  Future<void> _saveRecentUserSearch(Map<String, dynamic> profile) async {
    try {
      final searchData = {
        'id': profile['id'],
        'name': profile['name'],
        'username': profile['username'],
        'profileImage': profile['profileImage'],
      };

      _recentUserSearches.removeWhere((item) => item['id'] == profile['id']);
      _recentUserSearches.insert(0, searchData);

      if (_recentUserSearches.length > 10) {
        _recentUserSearches = _recentUserSearches.sublist(0, 10);
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          'recent_user_searches', json.encode(_recentUserSearches));

      setState(() {});
    } catch (e) {
      debugPrint('Error saving recent user search: $e');
    }
  }

  Future<void> _saveRecentPostSearch(Post post) async {
    try {
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

      _recentPostSearches.removeWhere((item) => item['id'] == post.id);
      _recentPostSearches.insert(0, searchData);

      if (_recentPostSearches.length > 10) {
        _recentPostSearches = _recentPostSearches.sublist(0, 10);
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          'recent_post_searches', json.encode(_recentPostSearches));

      setState(() {});
    } catch (e) {
      debugPrint('Error saving recent post search: $e');
    }
  }

  Future<void> _clearRecentSearches() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('recent_user_searches');
      await prefs.remove('recent_post_searches');
      setState(() {
        _recentUserSearches = [];
        _recentPostSearches = [];
      });
    } catch (e) {
      debugPrint('Error clearing recent searches: $e');
    }
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim();

    // Cancel previous debounce timer
    _debounceTimer?.cancel();

    setState(() {
      _isSearching = query.isNotEmpty;
    });

    if (!_isSearching) {
      setState(() {
        _userSearchResults = [];
        _postSearchResults = [];
        _showAllUsers = false;
        _showAllPosts = false;
        _isLoadingUsers = false;
        _isLoadingPosts = false;
      });
      return;
    }

    // Only search if query has at least 2 characters and is different from last query
    if (query.length >= 2 && query != _lastQuery) {
      _lastQuery = query;

      // Set up debounce timer
      _debounceTimer = Timer(const Duration(milliseconds: 500), () {
        if (_searchController.text.trim() == query && mounted) {
          _performUserSearch();
          _performPostSearch();
        }
      });
    } else if (query.length < 2) {
      setState(() {
        _userSearchResults = [];
        _postSearchResults = [];
        _isLoadingUsers = false;
        _isLoadingPosts = false;
      });
    }
  }

  Future<void> _performUserSearch() async {
    final query = _searchController.text.trim();
    if (query.length < 2) return;

    setState(() {
      _isLoadingUsers = true;
    });

    try {
      final results = await widget.userProfileProvider.searchUsers(query);

      // Remove duplicates based on user ID
      final uniqueResults = <Map<String, dynamic>>[];
      final seenIds = <int>{};

      for (var user in results) {
        final userId = user['id'] as int;
        if (!seenIds.contains(userId)) {
          seenIds.add(userId);
          uniqueResults.add(user);
        }
      }

      // Initialize following status for new results
      for (var user in uniqueResults) {
        final userId = user['id'] as int;
        if (!_isFollowingMap.containsKey(userId)) {
          _isLoadingFollowMap[userId] = true;

          try {
            final isFollowing =
                await widget.userProfileProvider.checkFollowing(userId);
            if (mounted) {
              setState(() {
                _isFollowingMap[userId] = isFollowing;
                _isLoadingFollowMap[userId] = false;
              });
            }
          } catch (e) {
            if (mounted) {
              setState(() {
                _isFollowingMap[userId] = false;
                _isLoadingFollowMap[userId] = false;
              });
            }
          }
        }
      }

      if (mounted) {
        setState(() {
          _userSearchResults = uniqueResults;
          _isLoadingUsers = false;
        });
      }

      developer.log(
          'Found ${uniqueResults.length} unique user results for "$query"',
          name: 'ComprehensiveSearchPage');
    } catch (e) {
      if (mounted) {
        setState(() {
          _userSearchResults = [];
          _isLoadingUsers = false;
        });
      }
      debugPrint('Error searching for users: $e');
    }
  }

  Future<void> _performPostSearch() async {
    final query = _searchController.text.trim();
    if (query.length < 2) return;

    setState(() {
      _isLoadingPosts = true;
    });

    try {
      final results = await widget.postsProvider.searchPosts(query);

      // Remove duplicates based on post ID
      final uniqueResults = <Post>[];
      final seenIds = <int>{};

      for (var post in results) {
        if (!seenIds.contains(post.id)) {
          seenIds.add(post.id);
          uniqueResults.add(post);
        }
      }

      if (mounted) {
        setState(() {
          _postSearchResults = uniqueResults;
          _isLoadingPosts = false;
        });
      }

      developer.log(
          'Found ${uniqueResults.length} unique post results for "$query"',
          name: 'ComprehensiveSearchPage');
    } catch (e) {
      if (mounted) {
        setState(() {
          _postSearchResults = [];
          _isLoadingPosts = false;
        });
      }
      debugPrint('Error searching for posts: $e');

      if (mounted) {
        ResponsiveSnackBar.showError(
          context: context,
          message: 'Failed to search posts: ${e.toString()}',
        );
      }
    }
  }

  Future<void> _toggleFollow(BuildContext context, int userId) async {
    if (_isLoadingFollowMap[userId] == true) return;

    setState(() {
      _isLoadingFollowMap[userId] = true;
    });

    try {
      bool success;
      if (_isFollowingMap[userId] == true) {
        success = await widget.userProfileProvider.unfollowUser(userId);
        if (success) {
          setState(() {
            _isFollowingMap[userId] = false;

            // Update followers count in search results
            for (int i = 0; i < _userSearchResults.length; i++) {
              if (_userSearchResults[i]['id'] == userId) {
                _userSearchResults[i]['followers'] =
                    (_userSearchResults[i]['followers'] ?? 1) - 1;
                break;
              }
            }
          });
        }
      } else {
        success = await widget.userProfileProvider.followUser(userId);
        if (success) {
          setState(() {
            _isFollowingMap[userId] = true;

            // Update followers count in search results
            for (int i = 0; i < _userSearchResults.length; i++) {
              if (_userSearchResults[i]['id'] == userId) {
                _userSearchResults[i]['followers'] =
                    (_userSearchResults[i]['followers'] ?? 0) + 1;
                break;
              }
            }
          });
        }
      }

      if (!success && mounted) {
        ResponsiveSnackBar.showError(
          context: context,
          message:
              'Failed to ${_isFollowingMap[userId] == true ? 'unfollow' : 'follow'} user',
        );
      }
    } catch (e) {
      if (mounted) {
        ResponsiveSnackBar.showError(
          context: context,
          message: 'Error: ${e.toString()}',
        );
      }
    } finally {
      setState(() {
        _isLoadingFollowMap[userId] = false;
      });
    }
  }

  void _navigateToUserProfile(Map<String, dynamic> profile) {
    _saveRecentUserSearch(profile);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => OtherUserProfilePage(
          userData: profile,
        ),
      ),
    );
  }

  void _navigateToPostDetail(Post post) {
    _saveRecentPostSearch(post);

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
          post: post,
          authorName: post.author.name,
          distance: post.distance > 0
              ? '${post.distance.toStringAsFixed(1)} mi'
              : null,
        ),
      ),
    );
  }

  @override
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Search'),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor ??
            Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        foregroundColor: Theme.of(context).appBarTheme.foregroundColor ??
            Theme.of(context).textTheme.titleLarge?.color,
      ),
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Column(
        children: [
          // Search bar
          Container(
            color: Theme.of(context).scaffoldBackgroundColor,
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Search for people and posts...',
                hintStyle: TextStyle(
                  color: Theme.of(context).hintColor.withOpacity(0.6),
                ),
                prefixIcon:
                    Icon(Icons.search, color: Theme.of(context).hintColor),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear,
                            color: Theme.of(context).hintColor),
                        onPressed: () {
                          _searchController.clear();
                        },
                      )
                    : null,
                filled: true,
                fillColor: Theme.of(context).inputDecorationTheme.fillColor ??
                    Theme.of(context).colorScheme.surface.withOpacity(0.95),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: Theme.of(context).dividerColor.withOpacity(0.2),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: ThemeConstants.primaryColor,
                    width: 2,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),

          // Search results or recent searches
          Expanded(
            child:
                _isSearching ? _buildSearchResults() : _buildRecentSearches(),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),

          // Users section
          if (_isLoadingUsers || _userSearchResults.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 4.0, left: 2, right: 2),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'People',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  if (_isLoadingUsers)
                    Container(
                      width: 24,
                      height: 24,
                      padding: const EdgeInsets.all(2),
                      child: const CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(
                            ThemeConstants.primaryColor),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Divider(
                color: Theme.of(context).dividerColor.withOpacity(0.3),
                thickness: 1,
                height: 1,
              ),
            ),
            if (_isLoadingUsers && _userSearchResults.isEmpty)
              SizedBox(
                height: 120,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 30,
                        height: 30,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          valueColor: AlwaysStoppedAnimation<Color>(
                              ThemeConstants.primaryColor),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Searching for people...',
                        style: TextStyle(
                          fontSize: 14,
                          color: ThemeConstants.grey.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              _buildUserResults(),
            if (_userSearchResults.isNotEmpty || _postSearchResults.isNotEmpty)
              const SizedBox(height: 32),
          ],

          // Posts section
          if (_isLoadingPosts || _postSearchResults.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 4.0, left: 2, right: 2),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Posts',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  if (_isLoadingPosts)
                    Container(
                      width: 24,
                      height: 24,
                      padding: const EdgeInsets.all(2),
                      child: const CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(
                            ThemeConstants.primaryColor),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Divider(
                color: Theme.of(context).dividerColor.withOpacity(0.3),
                thickness: 1,
                height: 1,
              ),
            ),
            if (_isLoadingPosts && _postSearchResults.isEmpty)
              SizedBox(
                height: 100,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 30,
                        height: 30,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          valueColor: AlwaysStoppedAnimation<Color>(
                              ThemeConstants.primaryColor),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Searching for posts...',
                        style: TextStyle(
                          fontSize: 14,
                          color: ThemeConstants.grey.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              _buildPostResults(),
            const SizedBox(height: 24),
          ],

          // No results message
          if (!_isLoadingUsers &&
              !_isLoadingPosts &&
              _userSearchResults.isEmpty &&
              _postSearchResults.isEmpty &&
              _searchController.text.trim().length >= 2) ...[
            Center(
              child: Column(
                children: [
                  const SizedBox(height: 60),
                  Icon(
                    Icons.search_off,
                    size: 64,
                    color: ThemeConstants.grey.withOpacity(0.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No results found',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: ThemeConstants.grey,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Try searching with different keywords',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: ThemeConstants.grey.withOpacity(0.7),
                        ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildUserResults() {
    if (_userSearchResults.isEmpty) {
      return const SizedBox.shrink();
    }

    final displayedUsers = _showAllUsers
        ? _userSearchResults
        : _userSearchResults.take(_maxDisplayedUsers).toList();

    return Column(
      children: [
        // Horizontal scrolling user circles
        SizedBox(
          height: 120,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: displayedUsers.length,
            itemBuilder: (context, index) {
              final user = displayedUsers[index];
              return _buildUserCircle(user);
            },
          ),
        ),

        // Show more accounts button
        if (_userSearchResults.length > _maxDisplayedUsers && !_showAllUsers)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: TextButton.icon(
              onPressed: () {
                setState(() {
                  _showAllUsers = true;
                });
              },
              icon: const Icon(Icons.expand_more,
                  color: ThemeConstants.primaryColor),
              label: Text(
                'Show ${_userSearchResults.length - _maxDisplayedUsers} more accounts',
                style: const TextStyle(
                  color: ThemeConstants.primaryColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),

        // Show less button
        if (_showAllUsers && _userSearchResults.length > _maxDisplayedUsers)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: TextButton.icon(
              onPressed: () {
                setState(() {
                  _showAllUsers = false;
                });
              },
              icon: const Icon(Icons.expand_less,
                  color: ThemeConstants.primaryColor),
              label: const Text(
                'Show less',
                style: TextStyle(
                  color: ThemeConstants.primaryColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildUserCircle(Map<String, dynamic> user) {
    final userId = user['id'] as int;
    final isFollowing = _isFollowingMap[userId] ?? false;
    final isLoadingFollow = _isLoadingFollowMap[userId] ?? false;

    return Container(
      width: 90,
      margin: const EdgeInsets.only(right: 16),
      child: Column(
        children: [
          // Profile picture with follow button
          Stack(
            children: [
              GestureDetector(
                onTap: () => _navigateToUserProfile(user),
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: ThemeConstants.primaryColor.withOpacity(0.3),
                      width: 2,
                    ),
                  ),
                  child: CircleAvatar(
                    radius: 30,
                    backgroundImage: user['profileImage'] != null &&
                            user['profileImage'].toString().isNotEmpty
                        ? NetworkImage(user['profileImage'])
                        : null,
                    backgroundColor:
                        ThemeConstants.primaryColor.withOpacity(0.1),
                    child: user['profileImage'] == null ||
                            user['profileImage'].toString().isEmpty
                        ? Text(
                            (user['name'] ?? user['username'] ?? 'U')
                                .toString()
                                .substring(0, 1)
                                .toUpperCase(),
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: ThemeConstants.primaryColor,
                            ),
                          )
                        : null,
                  ),
                ),
              ),

              // Follow/Unfollow button
              Positioned(
                bottom: 0,
                right: 0,
                child: GestureDetector(
                  onTap: () => _toggleFollow(context, userId),
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: isFollowing
                          ? Colors.green
                          : ThemeConstants.primaryColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: isLoadingFollow
                        ? const SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(
                              strokeWidth: 1.5,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : Icon(
                            isFollowing ? Icons.check : Icons.add,
                            size: 14,
                            color: Colors.white,
                          ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // User name
          GestureDetector(
            onTap: () => _navigateToUserProfile(user),
            child: Text(
              user['name'] ?? user['username'] ?? 'Unknown',
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).textTheme.bodyMedium?.color ??
                    (Theme.of(context).brightness == Brightness.dark
                        ? Colors.white
                        : ThemeConstants.black),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPostResults() {
    if (_postSearchResults.isEmpty) {
      return const SizedBox.shrink();
    }

    final displayedPosts = _showAllPosts
        ? _postSearchResults
        : _postSearchResults.take(_maxDisplayedPosts).toList();

    return Column(
      children: [
        // Post list
        ...displayedPosts.map((post) => _buildPostCard(post)),

        // Show more posts button
        if (_postSearchResults.length > _maxDisplayedPosts && !_showAllPosts)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  setState(() {
                    _showAllPosts = true;
                  });
                },
                icon: const Icon(Icons.expand_more,
                    color: ThemeConstants.primaryColor),
                label: Text(
                  'Show ${_postSearchResults.length - _maxDisplayedPosts} more posts',
                  style: const TextStyle(
                    color: ThemeConstants.primaryColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: ThemeConstants.primaryColor),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ),

        // Show less button
        if (_showAllPosts && _postSearchResults.length > _maxDisplayedPosts)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  setState(() {
                    _showAllPosts = false;
                  });
                },
                icon: const Icon(Icons.expand_less,
                    color: ThemeConstants.primaryColor),
                label: const Text(
                  'Show less',
                  style: TextStyle(
                    color: ThemeConstants.primaryColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: ThemeConstants.primaryColor),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildPostCard(Post post) {
    debugPrint(
        '🖼️ Post ${post.id}: hasMedia=${post.hasMedia}, mediaUrls=${post.mediaUrls}');
    if (post.hasMedia && post.mediaUrls.isNotEmpty) {
      final mediaUrl = _getMediaUrl(post.mediaUrls.first);
      debugPrint('🎬 Post ${post.id}: Original URL: ${post.mediaUrls.first}');
      debugPrint('🖼️ Post ${post.id}: Using thumbnail URL: $mediaUrl');
    }

    return Container(
        width: double.infinity,
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        constraints: const BoxConstraints(
          maxWidth: 400,
        ),
        child: Card(
          elevation: 2,
          shadowColor: Theme.of(context).shadowColor.withOpacity(0.12),
          color: Theme.of(context).cardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(
              color: Theme.of(context).dividerColor.withOpacity(0.15),
              width: 1,
            ),
          ),
          child: InkWell(
            onTap: () => _navigateToPostDetail(post),
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.all(0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Post header with category, time, and honesty score
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                    child: Row(
                      children: [
                        // Category badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 5),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                _getCategoryColor(post.category),
                                _getCategoryColor(post.category)
                                    .withOpacity(0.8),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: [
                              BoxShadow(
                                color: _getCategoryColor(post.category)
                                    .withOpacity(0.12),
                                blurRadius: 3,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _getCategoryIcon(post.category),
                                size: 13,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _capitalizeFirstLetter(post.category),
                                style: Theme.of(context)
                                    .textTheme
                                    .labelSmall
                                    ?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                    ),
                              ),
                            ],
                          ),
                        ),

                        const Spacer(),

                        // Time
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 4),
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .surface
                                .withOpacity(0.9),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.schedule,
                                size: 11,
                                color: Theme.of(context)
                                    .hintColor
                                    .withOpacity(0.7),
                              ),
                              const SizedBox(width: 3),
                              Text(
                                _formatTimeAgo(post.createdAt),
                                style: Theme.of(context)
                                    .textTheme
                                    .labelSmall
                                    ?.copyWith(
                                      fontSize: 10,
                                      color: Theme.of(context)
                                          .hintColor
                                          .withOpacity(0.8),
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Honesty score
                  if (post.honestyScore > 0)
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 12),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            _getHonestyColor(post.honestyScore)
                                .withOpacity(0.08),
                            _getHonestyColor(post.honestyScore)
                                .withOpacity(0.03),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: _getHonestyColor(post.honestyScore)
                              .withOpacity(0.13),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: _getHonestyColor(post.honestyScore),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.psychology,
                              size: 14,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Honesty',
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelSmall
                                      ?.copyWith(
                                        fontSize: 10,
                                        color: Theme.of(context)
                                            .hintColor
                                            .withOpacity(0.8),
                                        fontWeight: FontWeight.w500,
                                      ),
                                ),
                                const SizedBox(height: 1),
                                Text(
                                  '${post.honestyScore}%',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleSmall
                                      ?.copyWith(
                                        fontSize: 15,
                                        color:
                                            _getHonestyColor(post.honestyScore),
                                        fontWeight: FontWeight.bold,
                                      ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: _getHonestyColor(post.honestyScore),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              post.honestyScore >= 80
                                  ? 'Excellent'
                                  : post.honestyScore >= 60
                                      ? 'Good'
                                      : 'Poor',
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(
                                    fontSize: 9,
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  if (post.honestyScore > 0) const SizedBox(height: 8),

                  // Post image/video
                  if (post.hasMedia && post.mediaUrls.isNotEmpty)
                    Container(
                      width: double.infinity,
                      constraints: const BoxConstraints(
                        maxHeight: 150,
                        minHeight: 90,
                      ),
                      margin: const EdgeInsets.symmetric(horizontal: 12),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: AspectRatio(
                          aspectRatio: 4 / 3,
                          child: Stack(
                            children: [
                              Image.network(
                                _getMediaUrl(post.mediaUrls.first),
                                fit: BoxFit.cover,
                                width: double.infinity,
                                height: double.infinity,
                                loadingBuilder:
                                    (context, child, loadingProgress) {
                                  if (loadingProgress == null) return child;
                                  return Container(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          Theme.of(context).colorScheme.surface,
                                          Theme.of(context)
                                              .scaffoldBackgroundColor,
                                        ],
                                      ),
                                    ),
                                    child: Center(
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          SizedBox(
                                            width: 24,
                                            height: 24,
                                            child: CircularProgressIndicator(
                                              value: loadingProgress
                                                          .expectedTotalBytes !=
                                                      null
                                                  ? loadingProgress
                                                          .cumulativeBytesLoaded /
                                                      loadingProgress
                                                          .expectedTotalBytes!
                                                  : null,
                                              strokeWidth: 2,
                                              valueColor:
                                                  AlwaysStoppedAnimation<Color>(
                                                _getCategoryColor(
                                                    post.category),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            _isVideoUrl(post.mediaUrls.first)
                                                ? 'Loading video thumbnail...'
                                                : 'Loading image...',
                                            style: Theme.of(context)
                                                .textTheme
                                                .labelSmall
                                                ?.copyWith(
                                                  fontSize: 10,
                                                  color: Theme.of(context)
                                                      .hintColor
                                                      .withOpacity(0.7),
                                                  fontWeight: FontWeight.w500,
                                                ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          _getCategoryColor(post.category)
                                              .withOpacity(0.08),
                                          _getCategoryColor(post.category)
                                              .withOpacity(0.03),
                                        ],
                                      ),
                                    ),
                                    child: Center(
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: _getCategoryColor(
                                                      post.category)
                                                  .withOpacity(0.1),
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                            child: Icon(
                                              _isVideoUrl(post.mediaUrls.first)
                                                  ? Icons.videocam_off
                                                  : Icons.image_not_supported,
                                              color: _getCategoryColor(
                                                  post.category),
                                              size: 28,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            _isVideoUrl(post.mediaUrls.first)
                                                ? 'Video thumbnail unavailable'
                                                : 'Image unavailable',
                                            style: Theme.of(context)
                                                .textTheme
                                                .labelSmall
                                                ?.copyWith(
                                                  fontSize: 10,
                                                  color: _getCategoryColor(
                                                      post.category),
                                                  fontWeight: FontWeight.w500,
                                                ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),

                              // Video play indicator
                              if (_isVideoUrl(post.mediaUrls.first))
                                Positioned.fill(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          Colors.black.withOpacity(0.18),
                                          Colors.transparent,
                                          Colors.black.withOpacity(0.18),
                                        ],
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                      ),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Center(
                                      child: Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withOpacity(0.5),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.play_arrow,
                                          size: 28,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),

                              // Video badge
                              if (_isVideoUrl(post.mediaUrls.first))
                                Positioned(
                                  top: 6,
                                  right: 6,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.6),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: const [
                                        Icon(
                                          Icons.videocam,
                                          size: 10,
                                          color: Colors.white,
                                        ),
                                        SizedBox(width: 2),
                                        Text(
                                          'VIDEO',
                                          style: TextStyle(
                                            fontSize: 8,
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                          ),
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

                  // Post content
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title
                        Text(
                          post.title,
                          style:
                              Theme.of(context).textTheme.titleSmall?.copyWith(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context)
                                        .textTheme
                                        .titleSmall
                                        ?.color,
                                    height: 1.2,
                                    letterSpacing: -0.2,
                                  ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),

                        const SizedBox(height: 6),

                        // Content preview
                        Text(
                          post.content,
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    fontSize: 12,
                                    color: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.color
                                        ?.withOpacity(0.8),
                                    height: 1.3,
                                    letterSpacing: 0.05,
                                  ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),

                  // Bottom section
                  Container(
                    margin: const EdgeInsets.fromLTRB(12, 4, 12, 10),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .surface
                          .withOpacity(0.95),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        // Location
                        if (post.location.address != null) ...[
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.location_on,
                              size: 12,
                              color: Colors.blue.shade600,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Location',
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelSmall
                                      ?.copyWith(
                                        fontSize: 9,
                                        color: Theme.of(context)
                                            .hintColor
                                            .withOpacity(0.6),
                                        fontWeight: FontWeight.w500,
                                      ),
                                ),
                                const SizedBox(height: 1),
                                Text(
                                  post.location.address!,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                        fontSize: 11,
                                        color: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.color
                                            ?.withOpacity(0.9),
                                        fontWeight: FontWeight.w600,
                                      ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],

                        // Upvotes
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 5),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.green.shade400,
                                Colors.green.shade600,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.green.withOpacity(0.18),
                                blurRadius: 3,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.arrow_upward,
                                size: 12,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                '${post.upvotes}',
                                style: Theme.of(context)
                                    .textTheme
                                    .labelSmall
                                    ?.copyWith(
                                      fontSize: 11,
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ));
  }

  Widget _buildRecentSearches() {
    if (_recentUserSearches.isEmpty && _recentPostSearches.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search,
              size: 64,
              color: ThemeConstants.grey.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'Search for people and posts',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: ThemeConstants.grey,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Discover new content and connect with others',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: ThemeConstants.grey.withOpacity(0.7),
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with clear button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recent Searches',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              TextButton(
                onPressed: _clearRecentSearches,
                child: const Text(
                  'Clear All',
                  style: TextStyle(
                    color: ThemeConstants.primaryColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Recent user searches
          if (_recentUserSearches.isNotEmpty) ...[
            Text(
              'People',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 12),
            ..._recentUserSearches
                .take(5)
                .map((user) => _buildRecentUserItem(user))
                ,
            const SizedBox(height: 24),
          ],

          // Recent post searches
          if (_recentPostSearches.isNotEmpty) ...[
            Text(
              'Posts',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 12),
            ..._recentPostSearches
                .take(5)
                .map((post) => _buildRecentPostItem(post))
                ,
          ],
        ],
      ),
    );
  }

  Widget _buildRecentUserItem(Map<String, dynamic> user) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        leading: CircleAvatar(
          radius: 20,
          backgroundImage: user['profileImage'] != null &&
                  user['profileImage'].toString().isNotEmpty
              ? NetworkImage(user['profileImage'])
              : null,
          backgroundColor: ThemeConstants.primaryColor.withOpacity(0.1),
          child: user['profileImage'] == null ||
                  user['profileImage'].toString().isEmpty
              ? Text(
                  (user['name'] ?? user['username'] ?? 'U')
                      .toString()
                      .substring(0, 1)
                      .toUpperCase(),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: ThemeConstants.primaryColor,
                  ),
                )
              : null,
        ),
        title: Text(
          user['name'] ?? user['username'] ?? 'Unknown',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Theme.of(context).textTheme.bodyMedium?.color,
          ),
        ),
        subtitle: user['username'] != null
            ? Text(
                '@${user['username']}',
                style: TextStyle(
                  color: ThemeConstants.grey.withOpacity(0.7),
                ),
              )
            : null,
        trailing: const Icon(
          Icons.history,
          color: ThemeConstants.grey,
          size: 20,
        ),
        onTap: () => _refreshUserFromServer(user),
      ),
    );
  }

  Widget _buildRecentPostItem(Map<String, dynamic> post) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            color: _getCategoryColor(post['category'] ?? 'general')
                .withOpacity(0.1),
          ),
          child: post['imageUrl'] != null &&
                  post['imageUrl'].toString().isNotEmpty
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Image.network(
                    _getMediaUrl(post['imageUrl']),
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Icon(
                        _getCategoryIcon(post['category'] ?? 'general'),
                        color: _getCategoryColor(post['category'] ?? 'general'),
                        size: 20,
                      );
                    },
                  ),
                )
              : Icon(
                  _getCategoryIcon(post['category'] ?? 'general'),
                  color: _getCategoryColor(post['category'] ?? 'general'),
                  size: 20,
                ),
        ),
        title: Text(
          post['title'] ?? 'Untitled',
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: ThemeConstants.black,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          post['content'] ?? '',
          style: TextStyle(
            color: ThemeConstants.grey.withOpacity(0.7),
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: const Icon(
          Icons.history,
          color: ThemeConstants.grey,
          size: 20,
        ),
        onTap: () => _refreshPostFromServer(post),
      ),
    );
  }

  // Helper methods
  Color _getCategoryColor(String category) {
    return CategoryUtils.getCategoryColor(category);
  }

  IconData _getCategoryIcon(String category) {
    return CategoryUtils.getCategoryIcon(category);
  }

  String _capitalizeFirstLetter(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1);
  }

  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  // Helper method to get honesty score color
  Color _getHonestyColor(int honestyScore) {
    if (honestyScore >= 80) {
      return Colors.green;
    } else if (honestyScore >= 60) {
      return Colors.orange;
    } else {
      return Colors.red;
    }
  }

  // Helper method to check if URL is a video with improved detection
  bool _isVideoUrl(String url) {
    final videoExtensions = [
      '.mp4',
      '.mov',
      '.avi',
      '.mkv',
      '.webm',
      '.m4v',
      '.3gp',
      '.flv'
    ];
    final lowerUrl = url.toLowerCase();
    return videoExtensions.any((ext) => lowerUrl.contains(ext)) ||
        lowerUrl.contains('video') ||
        lowerUrl.contains('/videos/');
  }

  // Helper method to get media URL with enhanced thumbnail handling
  String _getMediaUrl(String originalUrl) {
    debugPrint('🔄 _getMediaUrl called with: $originalUrl');

    if (_isVideoUrl(originalUrl)) {
      debugPrint('📹 Detected video URL, converting to thumbnail');

      // Extract thumbnail URL using the correct server path structure
      String? thumbnailUrl = _extractThumbnailUrl(originalUrl);
      if (thumbnailUrl != null) {
        debugPrint('🖼️ Generated thumbnail URL: $thumbnailUrl');
        return thumbnailUrl;
      }

      // Fallback if extraction fails
      debugPrint('⚠️ Thumbnail extraction failed, using original URL');
      return _ensureFullUrl(originalUrl);
    }

    // For non-video URLs, ensure they have the base URL if needed
    return _ensureFullUrl(originalUrl);
  }

  // Extract thumbnail URL from video URL using correct server path structure
  String? _extractThumbnailUrl(String videoUrl) {
    try {
      debugPrint('🎯 Extracting thumbnail from: $videoUrl');

      // Extract the filename from the URL
      String filename = '';
      if (videoUrl.contains('/')) {
        filename = videoUrl.split('/').last;
      } else {
        filename = videoUrl;
      }

      // Remove video extension and add _thumb.jpg
      filename = filename.replaceAll('.mp4', '');
      filename = filename.replaceAll('.mov', '');
      filename = filename.replaceAll('.avi', '');
      filename = filename.replaceAll('.mkv', '');
      filename = filename.replaceAll('.webm', '');
      filename = filename.replaceAll('.m4v', '');
      filename += '_thumb.jpg';

      // Construct the correct thumbnail URL path
      String thumbnailUrl =
          '${ApiUrls.baseUrl}/media/attachments/thumbnails/$filename';
      debugPrint('🎬 Generated thumbnail URL: $thumbnailUrl');
      return thumbnailUrl;
    } catch (e) {
      debugPrint('🎬 Error extracting thumbnail URL: $e');
    }
    return null;
  }

  // Ensure URL has proper base URL prefix
  String _ensureFullUrl(String url) {
    if (url.startsWith('http')) {
      debugPrint('🖼️ Using original full URL: $url');
      return url;
    } else if (url.startsWith('/')) {
      final fullUrl = '${ApiUrls.baseUrl}$url';
      debugPrint('🖼️ Added base URL to path: $fullUrl');
      return fullUrl;
    } else {
      final fullUrl = '${ApiUrls.baseUrl}/$url';
      debugPrint('🖼️ Made relative URL absolute: $fullUrl');
      return fullUrl;
    }
  }

  // Method to refresh user data from server
  Future<void> _refreshUserFromServer(Map<String, dynamic> cachedUser) async {
    try {
      // Search for this specific user to get fresh data
      final results = await widget.userProfileProvider
          .searchUsers(cachedUser['username'] ?? '');

      // Find the matching user in results
      final freshUser = results.firstWhere(
        (user) => user['id'] == cachedUser['id'],
        orElse: () => cachedUser, // Fallback to cached data if not found
      );

      // Navigate with fresh data
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => OtherUserProfilePage(
            userData: freshUser,
          ),
        ),
      );
    } catch (e) {
      debugPrint('Error refreshing user data: $e');
      // Fallback to cached navigation
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => OtherUserProfilePage(
            userData: cachedUser,
          ),
        ),
      );
    }
  }

  // Method to refresh post data from server
  Future<void> _refreshPostFromServer(Map<String, dynamic> cachedPost) async {
    try {
      // Search for posts with the same title to get fresh data
      final results =
          await widget.postsProvider.searchPosts(cachedPost['title'] ?? '');

      // Try to find the matching post in results
      Post? freshPost;
      try {
        freshPost = results.firstWhere((post) => post.id == cachedPost['id']);
      } catch (e) {
        freshPost = null;
      }

      if (freshPost != null) {
        _navigateToPostDetail(freshPost);
      } else {
        // Fallback: create post object from cached data
        final postObj = Post(
          id: cachedPost['id'],
          title: cachedPost['title'],
          content: cachedPost['content'],
          mediaUrls: cachedPost['imageUrl'] != null &&
                  cachedPost['imageUrl'].toString().isNotEmpty
              ? [cachedPost['imageUrl']]
              : [],
          category: cachedPost['category'] ?? 'general',
          location: PostCoordinates(
            latitude: 0,
            longitude: 0,
            address: cachedPost['address'],
          ),
          author: User(
            id: 0,
            username: 'user',
            fullName: '',
            profileImage: null,
            isVerified: false,
          ),
          createdAt: DateTime.parse(cachedPost['createdAt']),
          upvotes: 0,
          downvotes: 0,
          honestyScore: cachedPost['honestyScore'] ?? 0,
          distance: 0,
          status: 'active',
          isVerifiedLocation: false,
          takenWithinApp: false,
          tags: [],
        );
        _navigateToPostDetail(postObj);
      }
    } catch (e) {
      debugPrint('Error refreshing post data: $e');
      // Fallback to cached navigation
      final postObj = Post(
        id: cachedPost['id'],
        title: cachedPost['title'],
        content: cachedPost['content'],
        mediaUrls: cachedPost['imageUrl'] != null &&
                cachedPost['imageUrl'].toString().isNotEmpty
            ? [cachedPost['imageUrl']]
            : [],
        category: cachedPost['category'] ?? 'general',
        location: PostCoordinates(
          latitude: 0,
          longitude: 0,
          address: cachedPost['address'],
        ),
        author: User(
          id: 0,
          username: 'user',
          fullName: '',
          profileImage: null,
          isVerified: false,
        ),
        createdAt: DateTime.parse(cachedPost['createdAt']),
        upvotes: 0,
        downvotes: 0,
        honestyScore: cachedPost['honestyScore'] ?? 0,
        distance: 0,
        status: 'active',
        isVerifiedLocation: false,
        takenWithinApp: false,
        tags: [],
      );
      _navigateToPostDetail(postObj);
    }
  }
}
