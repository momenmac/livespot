import 'dart:convert';
import 'dart:math' show min;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_application_2/models/post.dart';
import 'package:flutter_application_2/models/thread.dart';
import 'package:flutter_application_2/services/api/account/account_provider.dart';
import 'package:flutter_application_2/services/auth/auth_service.dart';
import 'package:flutter_application_2/services/api/account/api_urls.dart';
import 'package:flutter_application_2/constants/category_utils.dart'; // Added category utils import

class PostsService {
  final String baseUrl;
  final AuthService? authService;
  final AccountProvider? accountProvider;

  PostsService({
    String? baseUrl,
    this.authService,
    this.accountProvider,
  })  : baseUrl = baseUrl ?? ApiUrls.baseUrl,
        assert(authService != null || accountProvider != null,
            'Either authService or accountProvider must be provided');

  // Get headers with auth token
  Future<Map<String, String>> _getHeaders() async {
    String? token;

    // Try to get token from AccountProvider first (preferred)
    if (accountProvider != null && accountProvider!.token != null) {
      token = accountProvider!.token!.accessToken;
      debugPrint('Using token from AccountProvider');
    }
    // Fallback to AuthService if AccountProvider is not available or token is null
    else if (authService != null) {
      token = authService!.token;
      debugPrint('Using token from AuthService');
    }

    final headers = {
      'Content-Type': 'application/json',
      'Authorization': token != null && token.isNotEmpty ? 'Bearer $token' : '',
    };

    debugPrint(
        'Authorization header: ${headers['Authorization']?.substring(0, 10)}...');

    return headers;
  }

  // Get all posts with pagination
  Future<Map<String, dynamic>> getPosts({
    String? category,
    String? date,
    String? tag,
    int page = 1,
    int pageSize = 10,
  }) async {
    try {
      // Build query parameters
      final queryParams = <String, String>{
        'page': page.toString(),
        'page_size': pageSize.toString(),
      };
      if (category != null) queryParams['category'] = category;
      if (date != null) queryParams['date'] = date;
      if (tag != null) queryParams['tag'] = tag;

      final url = Uri.parse('$baseUrl/api/posts/')
          .replace(queryParameters: queryParams);
      final headers = await _getHeaders();

      debugPrint('Fetching posts with URL: $url');
      final response = await http.get(url, headers: headers);
      debugPrint('Posts API response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final String responseBody = utf8.decode(response.bodyBytes);
        final dynamic decodedBody = json.decode(responseBody);

        if (decodedBody is Map && decodedBody.containsKey('results')) {
          // Parse paginated response
          final posts = (decodedBody['results'] as List)
              .map((json) => Post.fromJson(json))
              .toList();
          final nextUrl = decodedBody['next'] as String?;
          final totalItems = decodedBody['count'] as int?;

          // Calculate if there are more pages based on the next URL
          final hasMore = nextUrl != null;
          debugPrint(
              'Loaded ${posts.length} posts, hasMore: $hasMore, totalItems: $totalItems, currentPage: $page');

          return {
            'posts': posts,
            'hasMore': hasMore,
            'totalItems': totalItems ?? 0,
            'currentPage': page,
          };
        } else {
          debugPrint(
              'Invalid response format from server, expected paginated results');
          return {
            'posts': <Post>[],
            'hasMore': false,
            'totalItems': 0,
            'currentPage': page,
          };
        }
      } else {
        throw Exception('Failed to load posts: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error getting posts: $e');
      throw Exception('Network error: $e');
    }
  }

  // Get posts near a location
  Future<List<Post>> getNearbyPosts({
    required double latitude,
    required double longitude,
    int radius = 1000,
  }) async {
    try {
      final queryParams = {
        'lat': latitude.toString(),
        'lng': longitude.toString(),
        'radius': radius.toString(),
      };

      final url = Uri.parse('$baseUrl/api/posts/nearby/')
          .replace(queryParameters: queryParams);
      final headers = await _getHeaders();

      final response = await http.get(url, headers: headers);

      if (response.statusCode == 200) {
        final String responseBody = utf8.decode(response.bodyBytes);
        final dynamic decodedBody = json.decode(responseBody);
        final List<dynamic> data;

        if (decodedBody is List) {
          // Handle direct array response
          data = decodedBody;
        } else if (decodedBody is Map && decodedBody.containsKey('results')) {
          // Handle response with results field
          data = decodedBody['results'] ?? [];
        } else {
          debugPrint(
              'Unexpected response format: ${response.body.substring(0, 100)}...');
          data = [];
        }

        return data.map((json) => Post.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load nearby posts: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error getting nearby posts: $e');
      throw Exception('Network error: $e');
    }
  }

  // Create a new post
  Future<Post> createPost({
    required String title,
    required String content,
    required double latitude,
    required double longitude,
    String? address,
    String category = 'general',
    List<String> mediaUrls = const [],
    List<String> tags = const [],
    int? threadId,
    bool isAnonymous = false, // Added isAnonymous parameter
  }) async {
    try {
      final url = Uri.parse('$baseUrl/api/posts/');
      final headers = await _getHeaders();

      final postData = {
        'title': title,
        'content': content,
        'location': {
          'latitude': latitude,
          'longitude': longitude,
          if (address != null) 'address': Uri.encodeFull(address),
        },
        'category': category,
        'media_urls': mediaUrls,
        'tags': tags,
        'is_anonymous': isAnonymous, // Add to request payload
        if (threadId != null) 'thread': threadId,
      };

      final response = await http.post(
        url,
        headers: headers,
        body: json.encode(postData),
      );

      if (response.statusCode == 201) {
        final String responseBody = utf8.decode(response.bodyBytes);
        return Post.fromJson(json.decode(responseBody));
      } else {
        throw Exception('Failed to create post: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error creating post: $e');
      throw Exception('Network error: $e');
    }
  }

  // Vote on a post
  Future<Map<String, dynamic>> voteOnPost({
    required int postId,
    required bool isUpvote,
  }) async {
    try {
      final url = Uri.parse('$baseUrl/api/posts/$postId/vote/');
      final headers = await _getHeaders();

      // Debug the request being sent
      debugPrint('Voting on post with URL: $url and isUpvote=$isUpvote');

      // Make sure to format the payload exactly as the server expects it
      final response = await http.post(
        url,
        headers: headers,
        body: json.encode({'is_upvote': isUpvote}),
      );

      debugPrint('Vote response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final String responseBody = utf8.decode(response.bodyBytes);
        final responseData = json.decode(responseBody);
        debugPrint('Vote response: $responseData');
        return responseData;
      } else {
        debugPrint(
            'Failed to vote on post: ${response.statusCode} - ${response.body}');
        throw Exception('Failed to vote on post: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error voting on post: $e');
      throw Exception('Network error: $e');
    }
  }

  // Get threads near a location
  Future<List<Thread>> getNearbyThreads({
    required double latitude,
    required double longitude,
    int radius = 1000,
    String? category,
  }) async {
    try {
      final queryParams = {
        'lat': latitude.toString(),
        'lng': longitude.toString(),
        'radius': radius.toString(),
        if (category != null) 'category': category,
      };

      final url = Uri.parse('$baseUrl/api/threads/nearby/')
          .replace(queryParameters: queryParams);
      final headers = await _getHeaders();

      final response = await http.get(url, headers: headers);

      if (response.statusCode == 200) {
        final String responseBody = utf8.decode(response.bodyBytes);
        final dynamic decodedBody = json.decode(responseBody);
        final List<dynamic> data;

        if (decodedBody is List) {
          // Handle direct array response
          data = decodedBody;
        } else if (decodedBody is Map && decodedBody.containsKey('results')) {
          // Handle response with results field
          data = decodedBody['results'] ?? [];
        } else {
          debugPrint(
              'Unexpected response format: ${response.body.substring(0, 100)}...');
          data = [];
        }

        return data.map((json) => Thread.fromJson(json)).toList();
      } else {
        throw Exception(
            'Failed to load nearby threads: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error getting nearby threads: $e');
      throw Exception('Network error: $e');
    }
  }

  // Get thread details
  Future<Thread> getThreadDetails(int threadId) async {
    try {
      final url = Uri.parse('$baseUrl/api/threads/$threadId/');
      final headers = await _getHeaders();

      final response = await http.get(url, headers: headers);

      if (response.statusCode == 200) {
        final String responseBody = utf8.decode(response.bodyBytes);
        return Thread.fromJson(json.decode(responseBody));
      } else {
        throw Exception(
            'Failed to load thread details: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error getting thread details: $e');
      throw Exception('Network error: $e');
    }
  }

  // Add post to thread
  Future<Post> addPostToThread({
    required int threadId,
    required String content,
    required double latitude,
    required double longitude,
    String? title,
    List<String> mediaUrls = const [],
    String? address,
  }) async {
    try {
      final url = Uri.parse('$baseUrl/api/threads/$threadId/add_post/');
      final headers = await _getHeaders();

      final postData = {
        'content': content,
        'title': title ?? 'Reply to thread $threadId',
        'location': {
          'latitude': latitude,
          'longitude': longitude,
          if (address != null) 'address': address,
        },
        'media_urls': mediaUrls,
      };

      final response = await http.post(
        url,
        headers: headers,
        body: json.encode(postData),
      );

      if (response.statusCode == 201) {
        final String responseBody = utf8.decode(response.bodyBytes);
        return Post.fromJson(json.decode(responseBody));
      } else {
        throw Exception('Failed to add post to thread: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error adding post to thread: $e');
      throw Exception('Network error: $e');
    }
  }

  // Search posts
  Future<List<Post>> searchPosts(String query) async {
    try {
      final url = Uri.parse('$baseUrl/api/posts/search/')
          .replace(queryParameters: {'query': query});
      final headers = await _getHeaders();

      final response = await http.get(url, headers: headers);

      if (response.statusCode == 200) {
        final String responseBody = utf8.decode(response.bodyBytes);
        final dynamic decodedBody = json.decode(responseBody);
        final List<dynamic> data;

        if (decodedBody is List) {
          // Handle direct array response
          data = decodedBody;
        } else if (decodedBody is Map && decodedBody.containsKey('results')) {
          // Handle response with results field
          data = decodedBody['results'] ?? [];
        } else {
          debugPrint(
              'Unexpected response format: ${response.body.substring(0, 100)}...');
          data = [];
        }

        return data.map((json) => Post.fromJson(json)).toList();
      } else {
        throw Exception('Failed to search posts: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error searching posts: $e');
      throw Exception('Network error: $e');
    }
  }

  // Get threads for a specific post
  Future<List<Map<String, dynamic>>> getThreadsForPost(int postId) async {
    try {
      // Use the general threads endpoint with a query parameter for post_id
      final url = Uri.parse(ApiUrls.threads).replace(
        queryParameters: {'post_id': postId.toString()},
      );
      final headers = await _getHeaders();

      debugPrint('Fetching threads for post with URL: $url');
      final response = await http.get(url, headers: headers);

      if (response.statusCode == 200) {
        final String responseBody = utf8.decode(response.bodyBytes);
        final dynamic decodedBody = json.decode(responseBody);
        final List<dynamic> data;

        if (decodedBody is List) {
          // Handle direct array response
          data = decodedBody;
        } else if (decodedBody is Map && decodedBody.containsKey('results')) {
          // Handle response with results field
          data = decodedBody['results'] ?? [];
        } else {
          debugPrint(
              'Unexpected response format: ${response.body.substring(0, min(100, response.body.length))}...');
          data = [];
        }

        return data.map((json) => json as Map<String, dynamic>).toList();
      } else {
        debugPrint(
            'Failed to load threads for post: ${response.statusCode} - ${response.body}');
        throw Exception(
            'Failed to load threads for post: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error getting threads for post: $e');
      throw Exception('Network error: $e');
    }
  }

  // Create a new thread for a post
  Future<Map<String, dynamic>> createThread({
    required int postId,
    required String content,
    String? mediaUrl,
  }) async {
    try {
      // Use the threads endpoint directly
      final url = Uri.parse(ApiUrls.threads);
      final headers = await _getHeaders();

      final threadData = {
        'content': content,
        'post': postId, // Associating with post via the post field
        if (mediaUrl != null)
          'media_url': mediaUrl, // Include media if provided
      };

      debugPrint('Creating thread for post with URL: $url');
      final response = await http.post(
        url,
        headers: headers,
        body: json.encode(threadData),
      );

      if (response.statusCode == 201) {
        final String responseBody = utf8.decode(response.bodyBytes);
        return json.decode(responseBody);
      } else {
        debugPrint(
            'Failed to create thread: ${response.statusCode} - ${response.body}');
        throw Exception('Failed to create thread: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error creating thread: $e');
      throw Exception('Network error: $e');
    }
  }

  // Upload media for post or thread
  Future<String> uploadMedia(String filePath) async {
    try {
      final url = Uri.parse('$baseUrl/media-api/upload/');
      final headers = await _getHeaders();

      // Create a multipart request
      var request = http.MultipartRequest('POST', url);

      // Add authorization headers
      request.headers.addAll(headers);

      // Add file with content type
      final fileName = filePath.split('/').last;
      String contentType = 'image';
      if (fileName.toLowerCase().endsWith('.mp4') ||
          fileName.toLowerCase().endsWith('.mov')) {
        contentType = 'video';
      }

      // Add file
      request.files.add(await http.MultipartFile.fromPath(
        'file',
        filePath,
      ));

      // Add content type field
      request.fields['content_type'] = contentType;

      // Send the request
      final response = await request.send();
      final responseString = await response.stream.bytesToString();

      if (response.statusCode == 201 || response.statusCode == 200) {
        final String responseBody = utf8.decode(responseString.codeUnits);
        final responseData = json.decode(responseBody);

        // Try to get the Firebase URL first, then fall back to local URL
        String? url = responseData['firebase_url'] ?? responseData['url'];
        if (url == null || url.isEmpty) {
          throw Exception('No valid URL in upload response');
        }
        return url;
      } else {
        debugPrint(
            'Failed to upload media: ${response.statusCode} - $responseString');
        throw Exception('Failed to upload media: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error uploading media: $e');
      throw Exception('Network error when uploading media: $e');
    }
  }

  // Get posts created by a specific user
  Future<List<Post>> getUserPosts(int userId) async {
    try {
      final url = Uri.parse('$baseUrl/api/posts/user_posts/')
          .replace(queryParameters: {'user_id': userId.toString()});
      final headers = await _getHeaders();

      final response = await http.get(url, headers: headers);

      if (response.statusCode == 200) {
        final String responseBody = utf8.decode(response.bodyBytes);
        final dynamic decodedBody = json.decode(responseBody);
        final List<dynamic> data;

        if (decodedBody is List) {
          data = decodedBody;
        } else if (decodedBody is Map && decodedBody.containsKey('results')) {
          data = decodedBody['results'] ?? [];
        } else {
          debugPrint(
              'Unexpected response format: ${response.body.substring(0, min(100, response.body.length))}...');
          data = [];
        }

        return data.map((json) => Post.fromJson(json)).toList();
      } else {
        debugPrint(
            'Failed to load user posts: ${response.statusCode} - ${response.body}');
        throw Exception('Failed to load user posts: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error getting user posts: $e');
      throw Exception('Network error: $e');
    }
  }

  // Get posts by a specific user on a specific date
  Future<List<Post>> getUserPostsByDate(int userId, String date) async {
    try {
      // The date parameter should be in YYYY-MM-DD format
      final queryParams = {
        'user_id': userId.toString(),
        'date': date,
      };

      final url = Uri.parse('$baseUrl/api/posts/user_posts/')
          .replace(queryParameters: queryParams);
      final headers = await _getHeaders();

      debugPrint('🔍 API URL with date filter: $url');

      final response = await http.get(url, headers: headers);

      if (response.statusCode == 200) {
        final String responseBody = utf8.decode(response.bodyBytes);
        final dynamic decodedBody = json.decode(responseBody);
        final List<dynamic> data;

        if (decodedBody is List) {
          data = decodedBody;
        } else if (decodedBody is Map && decodedBody.containsKey('results')) {
          data = decodedBody['results'] ?? [];
        } else {
          debugPrint('Unexpected response format for date filtered posts');
          data = [];
        }

        return data.map((json) => Post.fromJson(json)).toList();
      } else {
        debugPrint(
            'Failed to load user posts by date: ${response.statusCode} - ${response.body}');
        throw Exception(
            'Failed to load user posts by date: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error getting user posts by date: $e');
      throw Exception('Network error: $e');
    }
  }

  // Get saved posts for a specific user
  Future<List<Post>> getSavedPosts(int userId) async {
    try {
      final url = Uri.parse('$baseUrl/api/posts/saved/')
          .replace(queryParameters: {'user_id': userId.toString()});
      final headers = await _getHeaders();

      final response = await http.get(url, headers: headers);

      if (response.statusCode == 200) {
        final String responseBody = utf8.decode(response.bodyBytes);
        final dynamic decodedBody = json.decode(responseBody);
        final List<dynamic> data;

        if (decodedBody is List) {
          data = decodedBody;
        } else if (decodedBody is Map && decodedBody.containsKey('results')) {
          data = decodedBody['results'] ?? [];
        } else {
          debugPrint(
              'Unexpected response format: ${response.body.substring(0, min(100, response.body.length))}...');
          data = [];
        }

        return data.map((json) => Post.fromJson(json)).toList();
      } else {
        debugPrint(
            'Failed to load saved posts: ${response.statusCode} - ${response.body}');
        throw Exception('Failed to load saved posts: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error getting saved posts: $e');
      throw Exception('Network error: $e');
    }
  }

  // Get upvoted posts for a specific user
  Future<List<Post>> getUpvotedPosts(int userId) async {
    try {
      final url = Uri.parse('$baseUrl/api/posts/upvoted/')
          .replace(queryParameters: {'user_id': userId.toString()});
      final headers = await _getHeaders();

      final response = await http.get(url, headers: headers);

      if (response.statusCode == 200) {
        final String responseBody = utf8.decode(response.bodyBytes);
        final dynamic decodedBody = json.decode(responseBody);
        final List<dynamic> data;

        if (decodedBody is List) {
          data = decodedBody;
        } else if (decodedBody is Map && decodedBody.containsKey('results')) {
          data = decodedBody['results'] ?? [];
        } else {
          debugPrint(
              'Unexpected response format: ${response.body.substring(0, min(100, response.body.length))}...');
          data = [];
        }

        return data.map((json) => Post.fromJson(json)).toList();
      } else {
        debugPrint(
            'Failed to load upvoted posts: ${response.statusCode} - ${response.body}');
        throw Exception('Failed to load upvoted posts: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error getting upvoted posts: $e');
      throw Exception('Network error: $e');
    }
  }

  // Toggle save/unsave a post
  Future<Map<String, dynamic>> toggleSavePost(int postId) async {
    try {
      final url = Uri.parse('$baseUrl/api/posts/$postId/toggle_save/');
      final headers = await _getHeaders();

      // Debug the request being sent
      debugPrint('Toggling save status for post with URL: $url');

      final response = await http.post(
        url,
        headers: headers,
      );

      debugPrint('Save toggle response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final String responseBody = utf8.decode(response.bodyBytes);
        final responseData = json.decode(responseBody);
        debugPrint('Save toggle response: $responseData');
        return responseData;
      } else {
        debugPrint(
            'Failed to toggle save status: ${response.statusCode} - ${response.body}');
        throw Exception('Failed to toggle save status: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error toggling save status: $e');
      throw Exception('Network error: $e');
    }
  }

  // Get stories from users that the current user is following
  // Get stories from following users - formatted from posts
  Future<Map<String, List<Map<String, dynamic>>>> getFollowingStories(
      {String? date}) async {
    try {
      // Build the URL with query parameters
      final queryParams = <String, String>{};

      // Always include date parameter, using current date if none provided
      if (date != null) {
        queryParams['date'] = date;
      } else {
        // Use current date if no date provided
        final now = DateTime.now();
        queryParams['date'] =
            "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
      }

      final url = Uri.parse('$baseUrl/api/posts/following_posts/')
          .replace(queryParameters: queryParams);
      final headers = await _getHeaders();

      debugPrint('Fetching stories with URL: $url');
      final response = await http.get(url, headers: headers);
      debugPrint('Stories API response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final String responseBody = utf8.decode(response.bodyBytes);
        final Map<String, dynamic> responseData = json.decode(responseBody);
        final Map<String, List<Map<String, dynamic>>> stories = {};

        // Parse the response data into a map of username -> list of stories
        responseData.forEach((username, userStories) {
          // Skip empty keys or empty lists
          if (username.isEmpty || userStories == null) {
            return;
          }

          if (userStories is List) {
            // Only add non-empty lists of stories
            if (userStories.isNotEmpty) {
              stories[username] = List<Map<String, dynamic>>.from(userStories);
              debugPrint(
                  "Added ${userStories.length} stories for user: $username");
            }
          }
        });

        // Enhance stories with location data
        final enhancedStories = _enhanceStoriesWithLocationData(stories);
        debugPrint(
            "Enhanced stories with location data. Total users: ${enhancedStories.length}");

        // Log successful loading
        debugPrint(
            '[StorySection] Loaded stories from API: ${enhancedStories.keys.length} users with stories');
        return enhancedStories;
      } else {
        debugPrint(
            'Failed to load stories: ${response.statusCode} - ${response.body}');
        throw Exception(
            'Failed to load stories: ${response.statusCode} - ${response.reasonPhrase}');
      }
    } catch (e) {
      debugPrint('Error getting following stories: $e');
      throw Exception('Network error when fetching stories: $e');
    }
  }

  // Helper method to enhance stories with location data if missing
  Map<String, List<Map<String, dynamic>>> _enhanceStoriesWithLocationData(
      Map<String, List<Map<String, dynamic>>> stories) {
    final result = <String, List<Map<String, dynamic>>>{};

    stories.forEach((username, userStories) {
      final enhancedStories = <Map<String, dynamic>>[];

      for (final story in userStories) {
        final enhancedStory = Map<String, dynamic>.from(story);

        // Add location data if missing
        if (!enhancedStory.containsKey('location') ||
            enhancedStory['location'] == null) {
          // Check if we have coordinates to use
          if (enhancedStory.containsKey('latitude') &&
              enhancedStory.containsKey('longitude') &&
              enhancedStory['latitude'] != null &&
              enhancedStory['longitude'] != null) {
            enhancedStory['location'] = {
              'coordinates': {
                'latitude': enhancedStory['latitude'],
                'longitude': enhancedStory['longitude']
              },
              'address': 'Location available'
            };
          }
        } else if (enhancedStory['location'] is Map) {
          // Ensure location map has all required fields
          var loc = enhancedStory['location'] as Map;

          // If location has no coordinates but we have lat/lng directly, add them
          if (!loc.containsKey('coordinates') &&
              enhancedStory.containsKey('latitude') &&
              enhancedStory.containsKey('longitude')) {
            loc['coordinates'] = {
              'latitude': enhancedStory['latitude'],
              'longitude': enhancedStory['longitude']
            };
          }

          // Handle address field
          if (!loc.containsKey('address') ||
              loc['address'] == null ||
              loc['address'] == 'null') {
            loc['address'] = 'Location available';
          } else {
            // Ensure address is properly decoded if it's a string
            final address = loc['address'];
            if (address is String && address.isNotEmpty) {
              try {
                // Try to decode if it's URL encoded
                final decodedAddress = Uri.decodeFull(address);
                loc['address'] = decodedAddress;
              } catch (e) {
                debugPrint('Error decoding address: $e');
                // Keep original address if decoding fails
              }
            }
          }
        }

        // Validate category data
        if (enhancedStory.containsKey('category') &&
            enhancedStory['category'] != null) {
          String category = enhancedStory['category'].toString().toLowerCase();

          // Check if this is a valid category
          if (!CategoryUtils.allCategories.contains(category)) {
            debugPrint(
                'Warning: Unknown category in story data: $category. Setting to "other"');
            enhancedStory['category'] = 'other';
          }
        } else {
          // Set a default category if none is provided
          enhancedStory['category'] = 'other';
        }

        enhancedStories.add(enhancedStory);
      }

      result[username] = enhancedStories;
    });

    return result;
  }

  // Get post details by ID
  Future<Post> getPostDetails(int postId) async {
    try {
      final url = Uri.parse('$baseUrl/api/posts/$postId/');
      final headers = await _getHeaders();
      final response = await http.get(url, headers: headers);
      if (response.statusCode == 200) {
        final String responseBody = utf8.decode(response.bodyBytes);
        return Post.fromJson(json.decode(responseBody));
      } else {
        throw Exception('Failed to load post details: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error getting post details: $e');
      throw Exception('Network error: $e');
    }
  }
}
