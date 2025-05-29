import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:flutter_application_2/models/post.dart';
import 'package:flutter_application_2/services/posts/posts_service.dart';
import 'package:flutter_application_2/services/location/location_service.dart';
import 'package:flutter_application_2/constants/category_utils.dart';
import 'package:flutter_application_2/services/api/account/api_urls.dart';
import 'package:flutter_application_2/services/auth/token_manager.dart';
import 'package:geolocator/geolocator.dart';

class PostsProvider with ChangeNotifier {
  final PostsService _postsService;
  final LocationService _locationService;

  List<Post> _posts = [];
  bool _isLoading = false;
  String? _errorMessage;
  bool _hasMore = true;
  int _currentPage = 1;
  static const int _pageSize = 20;
  bool _isFetchingMore = false;

  // Map of usernames to their stories
  Map<String, List<Map<String, dynamic>>> _userStories = {};
  Map<String, List<Map<String, dynamic>>> get userStories => _userStories;

  // Cache for user posts by date to prevent excessive API calls
  Map<String, List<Post>> _userPostsByDateCache = {};
  Map<String, Future<List<Post>>> _ongoingUserPostRequests = {};

  // Getters
  List<Post> get posts => _posts;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get hasMore => _hasMore;
  bool get isFetchingMore => _isFetchingMore;

  PostsProvider({
    required PostsService postsService,
    required LocationService locationService,
  })  : _postsService = postsService,
        _locationService = locationService;

  // Load initial posts from API
  Future<bool> fetchPosts({
    String? category,
    String? date,
    String? tag,
    bool refresh = false,
  }) async {
    if (refresh) {
      _currentPage = 1;
      _hasMore = true;
      _posts = [];
    } else if (!_hasMore) {
      return false;
    }

    _errorMessage = null;

    debugPrint(
        '🚀 PostsProvider.fetchPosts: Starting fetch with refresh=$refresh, date=$date');
    debugPrint('🚀 PostsProvider.fetchPosts: Setting loading to true...');
    _setLoading(true);

    try {
      final result = await _postsService.getPosts(
        category: category,
        date: date,
        tag: tag,
        page: _currentPage,
        pageSize: _pageSize,
      );

      final List<Post> newPosts = result['posts'] as List<Post>;
      debugPrint(
          '🚀 PostsProvider.fetchPosts: Received ${newPosts.length} posts from service');

      if (refresh) {
        _posts = newPosts;
      } else {
        // Filter out any duplicates when adding new posts
        final existingIds = _posts.map((p) => p.id).toSet();
        final uniqueNewPosts =
            newPosts.where((p) => !existingIds.contains(p.id)).toList();
        _posts.addAll(uniqueNewPosts);
      }

      // Update pagination state
      _hasMore = result['hasMore'] == true;
      _currentPage = result['currentPage'] + 1;
      _errorMessage = null;

      debugPrint(
          '🚀 PostsProvider.fetchPosts: Successfully loaded ${newPosts.length} posts. Total posts: ${_posts.length}');
      debugPrint(
          '🚀 PostsProvider.fetchPosts: Has more: $_hasMore, Next page: $_currentPage');
      return true;
    } catch (e) {
      _errorMessage = 'Failed to fetch posts: $e';
      debugPrint('❌ PostsProvider.fetchPosts: Error occurred: $e');
      debugPrint(
          '❌ PostsProvider.fetchPosts: Setting error message: $_errorMessage');
      return false;
    } finally {
      debugPrint('🚀 PostsProvider.fetchPosts: Setting loading to false...');
      _setLoading(false);
    }
  }

  // Load more posts (pagination)
  Future<void> loadMorePosts({
    String? category,
    String? date,
    String? tag,
  }) async {
    // Guard against concurrent loading or when there are no more posts
    if (!_hasMore || _isFetchingMore) {
      debugPrint(
          'Skipping loadMorePosts: hasMore=$_hasMore, isFetchingMore=$_isFetchingMore');
      return;
    }

    _isFetchingMore = true;
    notifyListeners();

    try {
      debugPrint('Fetching page $_currentPage with pageSize $_pageSize');

      final result = await _postsService.getPosts(
        category: category,
        date: date,
        tag: tag,
        page: _currentPage,
        pageSize: _pageSize,
      );

      final List<Post> newPosts = result['posts'] as List<Post>;

      if (newPosts.isNotEmpty) {
        // Filter out any duplicates before adding
        final existingIds = _posts.map((p) => p.id).toSet();
        final uniqueNewPosts =
            newPosts.where((p) => !existingIds.contains(p.id)).toList();

        _posts.addAll(uniqueNewPosts);

        // Update pagination state
        _hasMore = result['hasMore'] == true;
        _currentPage = result['currentPage'] + 1;

        debugPrint(
            'Added ${uniqueNewPosts.length} new posts (${newPosts.length} total, ${uniqueNewPosts.length} unique). Has more: $_hasMore, Next page: $_currentPage');
      } else {
        _hasMore = false;
        debugPrint('No more posts to load');
      }

      _errorMessage = null;
    } catch (e) {
      _errorMessage = 'Failed to fetch more posts: $e';
      debugPrint(_errorMessage);
      _hasMore = false; // Stop trying to load more on error
    } finally {
      _isFetchingMore = false;
      notifyListeners();
    }
  }

  // Load nearby posts based on user's location
  Future<void> fetchNearbyPosts({int radius = 1000}) async {
    _setLoading(true);
    try {
      final position = await _locationService.getCurrentPosition();

      _posts = await _postsService.getNearbyPosts(
        latitude: position.latitude,
        longitude: position.longitude,
        radius: radius,
      );
      _errorMessage = null;
    } catch (e) {
      _errorMessage = 'Failed to fetch nearby posts: $e';
      debugPrint(_errorMessage);
    } finally {
      _setLoading(false);
    }
  }

  // Create a new post
  Future<Post?> createPost({
    required String title,
    required String content,
    required double latitude,
    required double longitude,
    String? address,
    String category = 'general',
    List<String> mediaUrls = const [],
    List<String> tags = const [],
    bool isAnonymous = false, // New parameter
    String? eventStatus, // Added eventStatus parameter
  }) async {
    try {
      _setLoading(true);

      final post = await _postsService.createPost(
        title: title,
        content: content,
        latitude: latitude,
        longitude: longitude,
        address: address,
        category: category,
        mediaUrls: mediaUrls,
        tags: tags,
        isAnonymous: isAnonymous, // Pass the parameter to the service
        eventStatus:
            eventStatus, // Pass the eventStatus parameter to the service
      );

      // Add the new post to the beginning of our list
      _posts.insert(0, post);

      return post;
    } catch (e) {
      _errorMessage = 'Failed to create post: $e';
      debugPrint(_errorMessage);
      return null;
    } finally {
      _setLoading(false);
      notifyListeners();
    }
  }

  // Fetch details for a single post
  Future<Post?> fetchPostDetails(int postId) async {
    _setLoading(true);
    try {
      final post = await _postsService.getPostDetails(postId);
      _errorMessage = null;
      // Optionally update the post in the list if it exists
      final index = _posts.indexWhere((p) => p.id == postId);
      if (index != -1) {
        _posts[index] = post;
      }
      return post;
    } catch (e) {
      _errorMessage = 'Failed to fetch post details: $e';
      debugPrint(_errorMessage);
      return null;
    } finally {
      _setLoading(false);
    }
  }

  // Vote on a post
  Future<Map<String, dynamic>> voteOnPost(Post post, bool isUpvote) async {
    try {
      // Check if this is a related post, and if so, use the original post ID
      int? originalPostId;
      if (post.relatedPostId != null) {
        // If this post is a related post, use its relatedPostId for the API call
        originalPostId = post.relatedPostId;
        debugPrint(
            'Using original post ID ${post.relatedPostId} for related post ${post.id}');
      }

      final result = await _postsService.voteOnPost(
        postId: post.id,
        isUpvote: isUpvote,
        originalPostId: originalPostId,
      );

      // Update post with new vote counts
      final postIndex = _posts.indexWhere((p) => p.id == post.id);
      if (postIndex != -1) {
        _posts[postIndex].upvotes = result['upvotes'];
        _posts[postIndex].downvotes = result['downvotes'];
        _posts[postIndex].honestyScore = result['honesty_score'];
        notifyListeners();
      }

      return result;
    } catch (e) {
      _errorMessage = 'Failed to vote on post: $e';
      debugPrint(_errorMessage);
      // Rethrow to allow proper error handling in UI
      throw Exception(_errorMessage);
    }
  }

  // Vote on event status (ended/happening)
  Future<Map<String, dynamic>> voteOnEventStatus({
    required Post post,
    required bool eventEnded,
  }) async {
    try {
      debugPrint(
          '🎯 PostsProvider: Voting on event status for post ${post.id}, eventEnded: $eventEnded');

      final result = await _postsService.voteOnEventStatus(
        postId: post.id,
        eventEnded: eventEnded,
      );

      // Update post with new event status information
      final postIndex = _posts.indexWhere((p) => p.id == post.id);
      if (postIndex != -1) {
        _posts[postIndex].isHappening = result['status'] == 'HAPPENING';
        _posts[postIndex].isEnded = result['status'] == 'ENDED';
        _posts[postIndex].endedVotesCount = result['ended_votes'];
        _posts[postIndex].happeningVotesCount = result['happening_votes'];
        _posts[postIndex].userStatusVote = eventEnded ? 'ended' : 'happening';

        debugPrint(
            '🔄 PostsProvider: Updated post status - isHappening: ${_posts[postIndex].isHappening}, isEnded: ${_posts[postIndex].isEnded}');

        // Schedule notification for the next frame to avoid setState during build
        WidgetsBinding.instance.addPostFrameCallback((_) {
          notifyListeners();
        });
      }

      _errorMessage = null;
      return result;
    } catch (e) {
      _errorMessage = 'Failed to vote on event status: $e';
      debugPrint('❌ PostsProvider: Error in voteOnEventStatus: $e');
      throw Exception(_errorMessage);
    }
  }

  // Check if user is within 100 meters of a post location
  Future<bool> isUserNearPost(Post post,
      {double maxDistanceMeters = 100.0}) async {
    try {
      final currentPosition = await _locationService.getCurrentPosition();

      final distance = _locationService.calculateDistanceInMeters(
        currentPosition.latitude,
        currentPosition.longitude,
        post.latitude,
        post.longitude,
      );

      debugPrint(
          '🎯 PostsProvider: User distance from post ${post.id}: ${distance.toStringAsFixed(1)}m');

      return distance <= maxDistanceMeters;
    } catch (e) {
      debugPrint('❌ PostsProvider: Error checking user proximity: $e');
      return false;
    }
  }

  // Search posts by query
  Future<List<Post>> searchPosts(String query) async {
    _setLoading(true);
    try {
      final results = await _postsService.searchPosts(query);
      _errorMessage = null;
      return results;
    } catch (e) {
      _errorMessage = 'Failed to search posts: $e';
      debugPrint(_errorMessage);
      return [];
    } finally {
      _setLoading(false);
    }
  }

  // Create a new thread for a post
  Future<Map<String, dynamic>> createThread({
    required int postId,
    required String content,
    String? mediaUrl,
  }) async {
    _setLoading(true);
    try {
      final thread = await _postsService.createThread(
        postId: postId,
        content: content,
        mediaUrl: mediaUrl,
      );

      _errorMessage = null;
      return thread;
    } catch (e) {
      _errorMessage = 'Failed to create thread: $e';
      debugPrint(_errorMessage);
      throw Exception(_errorMessage);
    } finally {
      _setLoading(false);
    }
  }

  // Verify user's location to ensure they are near the post
  Future<bool> verifyUserLocation({
    required double latitude,
    required double longitude,
    required int maxDistanceInMeters,
  }) async {
    try {
      // Get current user location
      final currentPosition = await _locationService.getCurrentPosition();

      // Calculate distance between user and post
      final distance = _locationService.calculateDistanceInMeters(
          currentPosition.latitude,
          currentPosition.longitude,
          latitude,
          longitude);

      // Return true if user is within the allowed distance
      return distance <= maxDistanceInMeters;
    } catch (e) {
      _errorMessage = 'Failed to verify location: $e';
      debugPrint(_errorMessage);
      return false;
    }
  }

  // Upload media for thread (image or video)
  Future<String?> uploadThreadMedia(String filePath) async {
    _setLoading(true);
    try {
      // Upload the media file to the server
      final mediaUrl = await _postsService.uploadMedia(filePath);
      _errorMessage = null;
      return mediaUrl;
    } catch (e) {
      _errorMessage = 'Failed to upload media: $e';
      debugPrint(_errorMessage);
      return null;
    } finally {
      _setLoading(false);
    }
  }

  // Upload media from local file path
  Future<String?> uploadMedia(String filePath) async {
    try {
      _setLoading(true);
      final mediaUrl = await _postsService.uploadMedia(filePath);
      return mediaUrl;
    } catch (e) {
      _errorMessage = 'Failed to upload media: $e';
      debugPrint(_errorMessage);
      return null;
    } finally {
      _setLoading(false);
      notifyListeners();
    }
  }

  // Add video post with upload functionality
  Future<Post?> addVideoPost({
    required String title,
    required String content,
    required String category,
    required List<String> tags,
    required String videoPath,
    required Position? position,
    required String? address,
    required bool isAnonymous,
  }) async {
    try {
      _setLoading(true);

      if (position == null) {
        throw Exception('Location is required');
      }

      // First upload the video
      final String? mediaUrl = await uploadMedia(videoPath);
      if (mediaUrl == null) {
        throw Exception('Failed to upload video');
      }

      // Create the post with the uploaded video URL
      final post = await createPost(
        title: title,
        content: content,
        latitude: position.latitude,
        longitude: position.longitude,
        address: address,
        category: category,
        mediaUrls: [mediaUrl],
        tags: tags,
        isAnonymous: isAnonymous,
      );

      return post;
    } catch (e) {
      _errorMessage = 'Failed to create video post: $e';
      debugPrint(_errorMessage);
      throw Exception(_errorMessage);
    } finally {
      _setLoading(false);
    }
  }

  // Get posts created by a specific user
  Future<List<Post>> getUserPosts(int userId) async {
    _setLoading(true);
    try {
      final posts = await _postsService.getUserPosts(userId);
      _errorMessage = null;
      return posts;
    } catch (e) {
      _errorMessage = 'Failed to fetch user posts: $e';
      debugPrint(_errorMessage);
      return [];
    } finally {
      _setLoading(false);
    }
  }

  // Get posts by a specific user on a specific date
  Future<List<Post>> getUserPostsByDate(int userId, String date) async {
    final cacheKey = '${userId}_$date';

    // Return cached data if available
    if (_userPostsByDateCache.containsKey(cacheKey)) {
      debugPrint('📋 Using cached data for key: $cacheKey');
      return _userPostsByDateCache[cacheKey]!;
    }

    // Return ongoing request if one exists
    if (_ongoingUserPostRequests.containsKey(cacheKey)) {
      debugPrint('⏳ Reusing ongoing request for key: $cacheKey');
      return _ongoingUserPostRequests[cacheKey]!;
    }

    // Create new request
    debugPrint('🆕 Creating new request for key: $cacheKey');
    final future = _fetchUserPostsByDate(userId, date, cacheKey);
    _ongoingUserPostRequests[cacheKey] = future;

    return future;
  }

  Future<List<Post>> _fetchUserPostsByDate(
      int userId, String date, String cacheKey) async {
    try {
      debugPrint('🔄 Fetching user posts for cache key: $cacheKey');
      final posts = await _postsService.getUserPostsByDate(userId, date);

      // Cache the result
      _userPostsByDateCache[cacheKey] = posts;
      _errorMessage = null;
      debugPrint('✅ Cached ${posts.length} posts for key: $cacheKey');

      return posts;
    } catch (e) {
      _errorMessage = 'Failed to fetch user posts by date: $e';
      debugPrint('❌ Error fetching posts for $cacheKey: $_errorMessage');
      return [];
    } finally {
      // Remove from ongoing requests
      _ongoingUserPostRequests.remove(cacheKey);
    }
  }

  // Clear cache when date changes
  void clearUserPostsByDateCache() {
    _userPostsByDateCache.clear();
    _ongoingUserPostRequests.clear();
  }

  // Get saved posts for a specific user
  Future<List<Post>> getSavedPosts(int userId) async {
    _setLoading(true);
    try {
      final posts = await _postsService.getSavedPosts(userId);
      _errorMessage = null;
      return posts;
    } catch (e) {
      _errorMessage = 'Failed to fetch saved posts: $e';
      debugPrint(_errorMessage);
      return [];
    } finally {
      _setLoading(false);
    }
  }

  // Get upvoted posts for a specific user
  Future<List<Post>> getUpvotedPosts(int userId) async {
    _setLoading(true);
    try {
      final posts = await _postsService.getUpvotedPosts(userId);
      _errorMessage = null;
      return posts;
    } catch (e) {
      _errorMessage = 'Failed to fetch upvoted posts: $e';
      debugPrint(_errorMessage);
      return [];
    } finally {
      _setLoading(false);
    }
  }

  // Toggle save/unsave a post
  Future<bool> toggleSavePost(int postId) async {
    try {
      // First make the API call
      final result = await _postsService.toggleSavePost(postId);
      debugPrint('🔗 PostsProvider: toggleSavePost result: $result');

      // Check for the actual response format: {status: saved} or {status: unsaved}
      final String? status = result['status'];

      if (status != null && (status == 'saved' || status == 'unsaved')) {
        // Only update the local state if the API call was successful
        final postIndex = _posts.indexWhere((p) => p.id == postId);
        if (postIndex != -1) {
          // Set the exact state based on server response
          final bool newSavedState = status == 'saved';
          _posts[postIndex].isSaved = newSavedState;

          debugPrint(
              '🔗 PostsProvider: Updated post $postId isSaved to $newSavedState');

          // Schedule notification for the next frame to avoid setState during build
          WidgetsBinding.instance.addPostFrameCallback((_) {
            notifyListeners();
          });
        }

        _errorMessage = null;
        return true; // API call was successful
      } else {
        _errorMessage = 'Invalid response from server: $result';
        debugPrint('❌ PostsProvider: Invalid response format: $result');
        return false;
      }
    } catch (e) {
      _errorMessage = 'Failed to save/unsave post: $e';
      debugPrint('❌ PostsProvider: Error in toggleSavePost: $e');
      return false;
    }
  }

  // Get the current saved state of a post from the provider's local state
  bool? getPostSavedState(int postId) {
    final postIndex = _posts.indexWhere((p) => p.id == postId);
    if (postIndex != -1) {
      return _posts[postIndex].isSaved;
    }
    return null; // Post not found in local state
  }

  // Fetch stories from users the current user is following
  Future<Map<String, List<Map<String, dynamic>>>> fetchFollowingStories(
      {String? date}) async {
    _setLoading(true);
    try {
      _userStories = await _postsService.getFollowingStories(date: date);

      // Process stories to ensure categories and locations are valid
      _userStories = _sanitizeStoriesData(_userStories);

      // Deduplicate stories by their ID
      _userStories = _deduplicateStoriesByUserId(_userStories);

      _errorMessage = null;
      // Use addPostFrameCallback to avoid setState during build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        notifyListeners();
      });
      return _userStories;
    } catch (e) {
      _errorMessage = 'Failed to fetch following stories: $e';
      debugPrint(_errorMessage);
      return {};
    } finally {
      _setLoading(false);
    }
  }

  // Method to clear stories, used when switching dates or when no stories are available
  void clearStories() {
    _userStories = {};
    // Use addPostFrameCallback to avoid setState during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      notifyListeners();
    });
  }

  // Helper method to ensure story data has valid categories and locations
  Map<String, List<Map<String, dynamic>>> _sanitizeStoriesData(
      Map<String, List<Map<String, dynamic>>> stories) {
    final result = <String, List<Map<String, dynamic>>>{};

    stories.forEach((username, userStories) {
      final sanitizedStories = <Map<String, dynamic>>[];

      for (final story in userStories) {
        final sanitizedStory = Map<String, dynamic>.from(story);

        // Sanitize category
        if (sanitizedStory.containsKey('category') &&
            sanitizedStory['category'] != null) {
          String category = sanitizedStory['category'].toString().toLowerCase();

          // Check if this is a valid category from our list
          if (!CategoryUtils.allCategories.contains(category)) {
            debugPrint(
                'Warning: Unknown category in story: $category. Using "other" as fallback.');
            sanitizedStory['category'] = 'other';
          }
        } else {
          // If no category, set default
          sanitizedStory['category'] = 'other';
        }

        sanitizedStories.add(sanitizedStory);
      }

      result[username] = sanitizedStories;
    });

    return result;
  }

  // Helper method to deduplicate stories by their ID
  Map<String, List<Map<String, dynamic>>> _deduplicateStoriesByUserId(
      Map<String, List<Map<String, dynamic>>> stories) {
    final result = <String, List<Map<String, dynamic>>>{};

    stories.forEach((username, userStories) {
      // Use a set to track the IDs we've already seen
      final seenIds = <int>{};
      final uniqueStories = <Map<String, dynamic>>[];

      for (final story in userStories) {
        // Get the ID of the story (post)
        final id = story['id'] is int
            ? story['id']
            : (story['id'] is String ? int.tryParse(story['id']) ?? -1 : -1);

        // Fix honesty rating
        if (story.containsKey('honesty_score') &&
            story['honesty_score'] != null) {
          story['honesty'] = story['honesty_score'];
        } else if (story.containsKey('honesty') && story['honesty'] == 0) {
          // Default to 50% if no honesty score is provided
          story['honesty'] = 50;
        }

        // Fix description/content fields
        if (!story.containsKey('description') ||
            story['description'] == null ||
            story['description'] == '') {
          if (story.containsKey('content') && story['content'] != null) {
            story['description'] = story['content'];
          } else if (story.containsKey('caption') && story['caption'] != null) {
            story['description'] = story['caption'];
          }
        }

        // Add location information if missing
        if (!story.containsKey('location') || story['location'] == null) {
          // Try to use coordinates if available
          if (story.containsKey('latitude') &&
              story.containsKey('longitude') &&
              story['latitude'] != null &&
              story['longitude'] != null) {
            story['location'] = {
              'coordinates': {
                'latitude': story['latitude'],
                'longitude': story['longitude']
              },
              'address': 'Location available'
            };
          }
          // Try to use category as a fallback location
          else if (story.containsKey('category') && story['category'] != null) {
            String category = story['category'].toString();
            if ([
              'event',
              'news',
              'traffic',
              'weather',
              'fire',
              'explosion',
              'disaster'
            ].contains(category.toLowerCase())) {
              story['location'] = 'Category: ${category.toUpperCase()}';
            }
          }
        }

        // Only add stories with unique IDs
        if (id != -1 && !seenIds.contains(id)) {
          seenIds.add(id);
          uniqueStories.add(story);
        }
      }

      // Only add users who have at least one story
      if (uniqueStories.isNotEmpty) {
        result[username] = uniqueStories;
      }
    });

    debugPrint(
        'Deduplicated stories: Original count: ${_countTotalStories(stories)}, New count: ${_countTotalStories(result)}');
    return result;
  }

  // Helper to count total stories across all users
  int _countTotalStories(Map<String, List<Map<String, dynamic>>> stories) {
    int count = 0;
    stories.forEach((_, userStories) => count += userStories.length);
    return count;
  }

  // Helper method to update loading state
  void _setLoading(bool loading) {
    _isLoading = loading;
    debugPrint('🔧 PostsProvider._setLoading: Setting loading to $loading');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      debugPrint(
          '🔧 PostsProvider._setLoading: Notifying listeners after frame callback');
      notifyListeners();
    });
  }

  /// Get related posts for a specific post ID
  /// Works for both main posts and related posts using the server's dedicated endpoint
  Future<List<Post>> getRelatedPosts(int postId) async {
    try {
      final url = '${ApiUrls.baseUrl}/api/posts/$postId/related/';
      print('DEBUG: Requesting related posts from: $url');

      final response = await http.get(
        Uri.parse(url),
        headers: await _getAuthHeaders(),
      );

      print('DEBUG: Related posts response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        // Properly decode UTF-8 response for Arabic content
        final responseBody = utf8.decode(response.bodyBytes);
        print('DEBUG: Related posts response body (UTF-8): $responseBody');

        final List<dynamic> data = json.decode(responseBody);

        // Debug Arabic content handling
        for (var item in data) {
          if (item['title'] != null) {
            print('DEBUG: Post title: ${item['title']}');
            print('DEBUG: Title bytes: ${item['title'].runes.toList()}');
          }
          if (item['content'] != null) {
            print('DEBUG: Post content: ${item['content']}');
            print('DEBUG: Content bytes: ${item['content'].runes.toList()}');
          }
        }

        final posts = data.map((json) => Post.fromJson(json)).toList();
        print(
            'DEBUG: Parsed ${posts.length} related posts with proper UTF-8 encoding');
        return posts;
      } else {
        print(
            'Error loading related posts: ${response.statusCode} - ${response.body}');
        return [];
      }
    } catch (e) {
      print('Exception loading related posts: $e');
      return [];
    }
  }

  /// Create a post that is related to another post
  Future<Post?> createRelatedPost({
    required String title,
    required String content,
    required double latitude,
    required double longitude,
    required String address,
    required String category,
    required bool isAnonymous,
    required List<String> mediaUrls,
    required int relatedToPostId,
  }) async {
    try {
      final Map<String, dynamic> postData = {
        'title': title,
        'content': content,
        'category': category,
        'is_anonymous': isAnonymous,
        'location': {
          'latitude': latitude,
          'longitude': longitude,
          'address': address,
        },
        'media_urls': mediaUrls,
        'related_post': relatedToPostId,
      };

      final url = Uri.parse(ApiUrls.posts);
      final response = await http.post(
        url,
        headers: await getAuthHeaders(isMultipart: false),
        body: json.encode(postData),
      );

      if (response.statusCode == 201) {
        final responseData = json.decode(response.body);
        return Post.fromJson(responseData);
      } else {
        final responseData = json.decode(response.body);
        _errorMessage =
            responseData['detail'] ?? 'Failed to create related post';
        return null;
      }
    } catch (e) {
      _errorMessage = 'Error creating related post: ${e.toString()}';
      return null;
    }
  }

  // Helper method to get authentication headers (private version)
  Future<Map<String, String>> _getAuthHeaders() async {
    final Map<String, String> headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    final String? token = await getAuthToken();
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }

    return headers;
  }

  // Make sure this method exists for authentication headers
  Future<Map<String, String>> getAuthHeaders({bool isMultipart = false}) async {
    final Map<String, String> headers = {
      'Content-Type': isMultipart ? 'multipart/form-data' : 'application/json',
      'Accept': 'application/json',
    };

    final String? token = await getAuthToken();
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }

    return headers;
  }

  // Helper method to get the authentication token using TokenManager
  Future<String?> getAuthToken() async {
    try {
      final tokenManager = TokenManager();
      final accessToken = await tokenManager.getValidAccessToken();

      if (accessToken != null && accessToken.isNotEmpty) {
        print(
            'DEBUG: Found JWT access token: ${accessToken.substring(0, 20)}...');
        return accessToken;
      } else {
        print('DEBUG: No valid JWT access token found');
        return null;
      }
    } catch (e) {
      print('Error getting JWT access token: $e');
      return null;
    }
  }
}
