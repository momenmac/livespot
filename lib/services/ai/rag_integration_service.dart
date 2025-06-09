import 'dart:math';
import 'package:flutter_application_2/models/post.dart';
import 'package:flutter_application_2/services/posts/posts_service.dart';
import 'package:flutter_application_2/providers/posts_provider.dart';
import 'package:flutter_application_2/services/location/location_cache_service.dart';

/// Enhanced RAG (Retrieval-Augmented Generation) service for intelligent post retrieval
/// This service provides advanced context-aware data retrieval for the Gemini AI assistant
class RAGIntegrationService {
  final PostsService _postsService;
  PostsProvider? _postsProvider;
  LocationCacheService? _locationCacheService;

  static final RAGIntegrationService _instance =
      RAGIntegrationService._internal();
  factory RAGIntegrationService() => _instance;

  RAGIntegrationService._internal() : _postsService = PostsService();

  /// Initialize the RAG service with required providers
  void initialize({
    PostsProvider? postsProvider,
    LocationCacheService? locationCacheService,
  }) {
    _postsProvider = postsProvider;
    _locationCacheService = locationCacheService;
  }

  /// Intelligent post retrieval with improved diversity and relevance
  Future<List<Post>> retrieveRelevantPosts(
    String userQuery, {
    int maxResults = 10,
    Map<String, dynamic>? context,
  }) async {
    try {
      // 1. Extract query intent and keywords
      final queryAnalysis = _analyzeUserQuery(userQuery);

      // 2. Multi-strategy retrieval with better error handling
      final retrievalResults = <Post>[];

      // Try different retrieval strategies and combine results
      try {
        final keywordResults =
            await _searchPostsByKeywords(queryAnalysis['keywords']);
        retrievalResults.addAll(keywordResults);
      } catch (e) {
        print('Keyword search failed: $e');
      }

      try {
        final categoryResults =
            await _retrievePostsByCategory(queryAnalysis['categories']);
        retrievalResults.addAll(categoryResults);
      } catch (e) {
        print('Category search failed: $e');
      }

      try {
        final locationResults =
            await _retrieveLocationBasedPosts(queryAnalysis['locations']);
        retrievalResults.addAll(locationResults);
      } catch (e) {
        print('Location search failed: $e');
      }

      try {
        final timeResults =
            await _retrieveTimeBasedPosts(queryAnalysis['timeframe']);
        retrievalResults.addAll(timeResults);
      } catch (e) {
        print('Time-based search failed: $e');
      }

      // 3. Deduplicate results
      final uniquePosts = <Post>[];
      final seenPostIds = <int>{};

      for (final post in retrievalResults) {
        if (!seenPostIds.contains(post.id)) {
          uniquePosts.add(post);
          seenPostIds.add(post.id);
        }
      }

      // 4. If we have very few results, try broader search
      if (uniquePosts.length < 3) {
        try {
          final broadResults = await _performBroadSearch();
          for (final post in broadResults) {
            if (!seenPostIds.contains(post.id) &&
                uniquePosts.length < maxResults) {
              uniquePosts.add(post);
              seenPostIds.add(post.id);
            }
          }
        } catch (e) {
          print('Broad search failed: $e');
        }
      }

      // 5. Rank results by relevance with improved scoring
      final rankedPosts = _rankPostsByRelevance(
        uniquePosts,
        userQuery,
        queryAnalysis,
        context,
      );

      // 6. Ensure diversity in results
      final diversePosts = _ensureResultDiversity(rankedPosts, maxResults);

      return diversePosts;
    } catch (e) {
      print('Error in RAG retrieval: $e');
      // Fallback to getting any available posts
      return await _getFallbackPosts(maxResults);
    }
  }

  /// Perform broader search when specific queries return few results
  Future<List<Post>> _performBroadSearch() async {
    try {
      // Get recent posts from multiple categories
      final categories = ['news', 'community', 'event', 'sports', 'health'];
      final allPosts = <Post>[];

      for (final category in categories) {
        try {
          final result =
              await _postsService.getPosts(category: category, pageSize: 5);
          final posts = result['posts'] as List<Post>? ?? [];
          allPosts.addAll(posts);
        } catch (e) {
          print('Failed to get posts for category $category: $e');
          continue;
        }
      }

      return allPosts;
    } catch (e) {
      print('Broad search completely failed: $e');
      return [];
    }
  }

  /// Get fallback posts when all searches fail
  Future<List<Post>> _getFallbackPosts(int maxResults) async {
    try {
      // Try to get any posts available
      if (_postsProvider?.posts.isNotEmpty == true) {
        return _postsProvider!.posts.take(maxResults).toList();
      }

      // Last resort - try to get some posts from service
      final result = await _postsService.getPosts(pageSize: maxResults);
      return result['posts'] as List<Post>? ?? [];
    } catch (e) {
      print('Fallback posts failed: $e');
      return [];
    }
  }

  /// Ensure diversity in results to avoid repetitive responses
  List<Post> _ensureResultDiversity(List<Post> posts, int maxResults) {
    if (posts.length <= maxResults) return posts;

    final diversePosts = <Post>[];
    final usedCategories = <String>{};
    final usedLocations = <String>{};

    // First pass: one post per category
    for (final post in posts) {
      if (diversePosts.length >= maxResults) break;

      if (!usedCategories.contains(post.category)) {
        diversePosts.add(post);
        usedCategories.add(post.category);
      }
    }

    // Second pass: fill remaining slots with highest scored posts
    for (final post in posts) {
      if (diversePosts.length >= maxResults) break;

      if (!diversePosts.contains(post)) {
        diversePosts.add(post);
      }
    }

    return diversePosts.take(maxResults).toList();
  }

  /// Analyze user query to extract intent, keywords, categories, locations, and timeframe
  Map<String, dynamic> _analyzeUserQuery(String query) {
    final lowerQuery = query.toLowerCase();

    // Extract keywords with better filtering
    final stopWords = {
      'the',
      'is',
      'at',
      'which',
      'on',
      'a',
      'an',
      'and',
      'or',
      'but',
      'in',
      'with',
      'to',
      'for',
      'of',
      'as',
      'by',
      'this',
      'that',
      'are',
      'was',
      'were',
      'be',
      'been',
      'have',
      'has',
      'had',
      'do',
      'does',
      'did',
      'will',
      'would',
      'could',
      'should',
      'can',
      'may',
      'might',
      'must',
      'shall'
    };

    final words = lowerQuery
        .replaceAll(RegExp(r'[^\w\s]'), ' ')
        .split(RegExp(r'\s+'))
        .where((word) => word.length > 2 && !stopWords.contains(word))
        .toList();

    // Enhanced category detection
    final categories = <String>[];
    final categoryMap = {
      'news': ['news', 'update', 'announcement', 'breaking', 'report', 'story'],
      'event': [
        'event',
        'party',
        'concert',
        'festival',
        'celebration',
        'gathering',
        'meeting',
        'show'
      ],
      'sports': [
        'sports',
        'game',
        'match',
        'tournament',
        'football',
        'basketball',
        'soccer',
        'tennis',
        'team'
      ],
      'health': [
        'health',
        'medical',
        'hospital',
        'doctor',
        'wellness',
        'fitness',
        'medicine',
        'treatment'
      ],
      'traffic': [
        'traffic',
        'road',
        'accident',
        'construction',
        'jam',
        'highway',
        'street'
      ],
      'weather': [
        'weather',
        'rain',
        'snow',
        'storm',
        'sunny',
        'cloudy',
        'temperature',
        'forecast'
      ],
      'community': [
        'community',
        'local',
        'neighborhood',
        'residents',
        'people',
        'neighbors'
      ],
      'education': [
        'school',
        'university',
        'education',
        'student',
        'class',
        'college',
        'learning'
      ],
      'environment': [
        'environment',
        'nature',
        'pollution',
        'green',
        'eco',
        'climate',
        'sustainability'
      ],
      'crime': [
        'crime',
        'police',
        'theft',
        'robbery',
        'security',
        'safety',
        'law'
      ],
      'fire': ['fire', 'emergency', 'firefighter', 'smoke', 'burn'],
      'alert': ['alert', 'warning', 'urgent', 'emergency', 'danger'],
      'business': [
        'business',
        'shop',
        'store',
        'restaurant',
        'service',
        'company'
      ],
    };

    for (final category in categoryMap.keys) {
      if (categoryMap[category]!
          .any((keyword) => lowerQuery.contains(keyword))) {
        categories.add(category);
      }
    }

    // Better location detection
    final locations = <String>[];
    final locationIndicators = [
      'near',
      'at',
      'in',
      'around',
      'nearby',
      'close to',
      'from'
    ];

    for (final indicator in locationIndicators) {
      final index = lowerQuery.indexOf(indicator);
      if (index != -1) {
        final afterIndicator =
            lowerQuery.substring(index + indicator.length).trim();
        final locationWords = afterIndicator
            .split(' ')
            .take(3)
            .where((w) => w.isNotEmpty)
            .join(' ');
        if (locationWords.length > 2) {
          locations.add(locationWords);
        }
      }
    }

    // Enhanced timeframe detection
    String? timeframe;
    final timePatterns = {
      'today': RegExp(r'\btoday\b'),
      'yesterday': RegExp(r'\byesterday\b'),
      'tomorrow': RegExp(r'\btomorrow\b'),
      'week': RegExp(r'\bthis week\b|\bweek\b'),
      'recent': RegExp(r'\brecent\b|\blately\b|\blatest\b'),
      'now': RegExp(r'\bnow\b|\bcurrent\b|\bpresent\b'),
    };

    for (final pattern in timePatterns.keys) {
      if (timePatterns[pattern]!.hasMatch(lowerQuery)) {
        timeframe = pattern;
        break;
      }
    }

    return {
      'keywords': words,
      'categories': categories,
      'locations': locations,
      'timeframe': timeframe,
      'original_query': query,
      'intent': _detectQueryIntent(lowerQuery),
    };
  }

  /// Detect the intent behind the user's query
  String _detectQueryIntent(String lowerQuery) {
    if (lowerQuery.contains('recommend') || lowerQuery.contains('suggest')) {
      return 'recommendation';
    }
    if (lowerQuery.contains('find') ||
        lowerQuery.contains('search') ||
        lowerQuery.contains('look for')) {
      return 'search';
    }
    if (lowerQuery.contains('what') ||
        lowerQuery.contains('how') ||
        lowerQuery.contains('when')) {
      return 'question';
    }
    if (lowerQuery.contains('analyze') || lowerQuery.contains('summary')) {
      return 'analysis';
    }
    return 'general';
  }

  /// Search posts by keywords using the posts service
  Future<List<Post>> _searchPostsByKeywords(List<String> keywords) async {
    if (keywords.isEmpty) return [];

    try {
      final searchQuery = keywords.join(' ');
      return await _postsService.searchPosts(searchQuery);
    } catch (e) {
      print('Error in keyword search: $e');
      return [];
    }
  }

  /// Retrieve posts by specific categories
  Future<List<Post>> _retrievePostsByCategory(List<String> categories) async {
    if (categories.isEmpty) return [];

    try {
      final allCategoryPosts = <Post>[];

      for (final category in categories) {
        final result =
            await _postsService.getPosts(category: category, pageSize: 20);
        final posts = result['posts'] as List<Post>? ?? [];
        allCategoryPosts.addAll(posts);
      }

      return allCategoryPosts;
    } catch (e) {
      print('Error in category retrieval: $e');
      return [];
    }
  }

  /// Retrieve location-based posts
  Future<List<Post>> _retrieveLocationBasedPosts(List<String> locations) async {
    if (locations.isEmpty && _locationCacheService?.cachedPosition == null) {
      return [];
    }

    try {
      final position = _locationCacheService?.cachedPosition;
      if (position != null) {
        final posts = await _postsService.getNearbyPosts(
          latitude: position.latitude,
          longitude: position.longitude,
          radius: 10000, // 10km radius in meters
        );
        return posts;
      }
      return [];
    } catch (e) {
      print('Error in location-based retrieval: $e');
      return [];
    }
  }

  /// Retrieve time-based posts
  Future<List<Post>> _retrieveTimeBasedPosts(String? timeframe) async {
    if (timeframe == null) return [];

    try {
      String? dateFilter;
      final now = DateTime.now();

      switch (timeframe) {
        case 'today':
          dateFilter =
              '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
          break;
        case 'yesterday':
          final yesterday = now.subtract(const Duration(days: 1));
          dateFilter =
              '${yesterday.year}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}';
          break;
        case 'week':
        case 'recent':
          // Get posts from the last 7 days - we'll filter after retrieval
          break;
      }

      if (dateFilter != null) {
        final result =
            await _postsService.getPosts(date: dateFilter, pageSize: 20);
        return result['posts'] as List<Post>? ?? [];
      } else if (timeframe == 'week' || timeframe == 'recent') {
        // Get recent posts and filter by date
        final result = await _postsService.getPosts(pageSize: 50);
        final posts = result['posts'] as List<Post>? ?? [];
        final weekAgo = now.subtract(const Duration(days: 7));

        return posts.where((post) {
          return post.createdAt.isAfter(weekAgo);
        }).toList();
      }

      return [];
    } catch (e) {
      print('Error in time-based retrieval: $e');
      return [];
    }
  }

  /// Retrieve personalized posts based on user context and preferences
  Future<List<Post>> _retrievePersonalizedPosts(
      Map<String, dynamic>? context) async {
    if (_postsProvider == null) return [];

    try {
      // Get user's posts to understand preferences
      final userPosts = _postsProvider!.posts;
      if (userPosts.isEmpty) return [];

      // Analyze user's preferred categories
      final categoryFrequency = <String, int>{};
      for (final post in userPosts) {
        categoryFrequency[post.category] =
            (categoryFrequency[post.category] ?? 0) + 1;
      }

      // Get posts from user's top categories
      final topCategories = categoryFrequency.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      final personalizedPosts = <Post>[];

      for (final categoryEntry in topCategories.take(3)) {
        final result = await _postsService.getPosts(
          category: categoryEntry.key,
          pageSize: 10,
        );
        final posts = result['posts'] as List<Post>? ?? [];
        personalizedPosts.addAll(posts);
      }

      return personalizedPosts;
    } catch (e) {
      print('Error in personalized retrieval: $e');
      return [];
    }
  }

  /// Rank posts by relevance to the user query and context
  List<Post> _rankPostsByRelevance(
    List<Post> posts,
    String userQuery,
    Map<String, dynamic> queryAnalysis,
    Map<String, dynamic>? context,
  ) {
    final scoredPosts = posts.map((post) {
      double score = 0.0;

      // 1. Keyword matching score
      final keywords = queryAnalysis['keywords'] as List<String>;
      final postText =
          '${post.content} ${post.location.address ?? ''}'.toLowerCase();

      for (final keyword in keywords) {
        if (postText.contains(keyword.toLowerCase())) {
          score += 2.0; // Base keyword match

          // Bonus for exact matches in title/content start
          if (post.content.toLowerCase().startsWith(keyword.toLowerCase())) {
            score += 1.0;
          }
        }
      }

      // 2. Category relevance score
      final categories = queryAnalysis['categories'] as List<String>;
      if (categories.contains(post.category)) {
        score += 3.0;
      }

      // 3. Recency score (newer posts get higher scores)
      final daysSincePost = DateTime.now().difference(post.createdAt).inDays;
      if (daysSincePost == 0) {
        score += 1.5; // Today
      } else if (daysSincePost <= 3) {
        score += 1.0; // Last 3 days
      } else if (daysSincePost <= 7) {
        score += 0.5; // Last week
      }

      // 4. Engagement score (based on votes and status)
      final upvotes = post.upvotes;
      final downvotes = post.downvotes;
      final netVotes = upvotes - downvotes;
      score += netVotes * 0.1;

      // 5. Status relevance (happening events get priority)
      if (post.isHappening == true) {
        score += 2.0;
      }

      // 6. Location proximity (if user has location)
      final position = _locationCacheService?.cachedPosition;
      if (position != null) {
        final distance = _calculateDistance(
          position.latitude,
          position.longitude,
          post.location.latitude,
          post.location.longitude,
        );

        // Closer posts get higher scores
        if (distance <= 1.0) {
          score += 1.5; // Within 1km
        } else if (distance <= 5.0) {
          score += 1.0; // Within 5km
        } else if (distance <= 10.0) {
          score += 0.5; // Within 10km
        }
      }

      // 7. User preference alignment
      if (_postsProvider != null) {
        final userPosts = _postsProvider!.posts;
        final userCategories = userPosts.map((p) => p.category).toSet();
        if (userCategories.contains(post.category)) {
          score += 1.0;
        }
      }

      return {'post': post, 'score': score};
    }).toList();

    // Sort by score (highest first)
    scoredPosts
        .sort((a, b) => (b['score'] as double).compareTo(a['score'] as double));

    return scoredPosts.map((item) => item['post'] as Post).toList();
  }

  /// Calculate distance between two points using Haversine formula
  double _calculateDistance(
      double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371; // Earth radius in kilometers

    final double dLat = _degreesToRadians(lat2 - lat1);
    final double dLon = _degreesToRadians(lon2 - lon1);

    final double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_degreesToRadians(lat1)) *
            cos(_degreesToRadians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);

    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadius * c;
  }

  double _degreesToRadians(double degrees) {
    return degrees * pi / 180;
  }

  /// Generate contextual summary of retrieved posts for AI processing
  String generateContextualSummary(List<Post> posts, String userQuery) {
    if (posts.isEmpty) {
      return 'No relevant posts found for the query: "$userQuery"';
    }

    final summary = StringBuffer();
    summary.writeln(
        'Retrieved ${posts.length} relevant posts for query: "$userQuery"\n');

    // Group posts by category
    final categorizedPosts = <String, List<Post>>{};
    for (final post in posts) {
      categorizedPosts.putIfAbsent(post.category, () => []).add(post);
    }

    // Summarize by category
    for (final category in categorizedPosts.keys) {
      final categoryPosts = categorizedPosts[category]!;
      summary.writeln(
          '${category.toUpperCase()} (${categoryPosts.length} posts):');

      for (final post in categoryPosts.take(3)) {
        // Limit to top 3 per category
        final location = post.location.address ?? 'Unknown location';
        final content = post.content.length > 100
            ? '${post.content.substring(0, 100)}...'
            : post.content;
        final timeAgo = _getTimeAgo(post.createdAt);
        final status = (post.isHappening == true) ? '[HAPPENING NOW]' : '';

        summary.writeln('• $status $content');
        summary.writeln('  Location: $location | $timeAgo');
        summary.writeln('  Votes: ${post.upvotes} up, ${post.downvotes} down');
        summary.writeln();
      }
    }

    return summary.toString();
  }

  /// Get human-readable time ago string
  String _getTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes == 1 ? '' : 's'} ago';
    } else {
      return 'Just now';
    }
  }

  /// Get trending topics and categories for recommendations
  Future<Map<String, dynamic>> getTrendingInsights() async {
    try {
      final result = await _postsService.getPosts(pageSize: 100);
      final posts = result['posts'] as List<Post>? ?? [];

      if (posts.isEmpty) return {'error': 'No posts available for analysis'};

      // Analyze category trends
      final categoryCount = <String, int>{};
      final recentPosts = posts
          .where((p) => DateTime.now().difference(p.createdAt).inDays <= 7)
          .toList();

      for (final post in recentPosts) {
        categoryCount[post.category] = (categoryCount[post.category] ?? 0) + 1;
      }

      final trendingCategories = categoryCount.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      // Analyze location trends
      final locationCount = <String, int>{};
      for (final post in recentPosts) {
        final location = post.location.address;
        if (location != null && location.isNotEmpty) {
          locationCount[location] = (locationCount[location] ?? 0) + 1;
        }
      }

      final trendingLocations = locationCount.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      return {
        'trending_categories': trendingCategories
            .take(5)
            .map((e) => {
                  'category': e.key,
                  'count': e.value,
                })
            .toList(),
        'trending_locations': trendingLocations
            .take(5)
            .map((e) => {
                  'location': e.key,
                  'count': e.value,
                })
            .toList(),
        'total_recent_posts': recentPosts.length,
        'most_active_category':
            trendingCategories.isNotEmpty ? trendingCategories.first.key : null,
      };
    } catch (e) {
      print('Error getting trending insights: $e');
      return {'error': 'Failed to analyze trends'};
    }
  }
}
