import 'dart:convert';
import 'dart:math' show min;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_application_2/models/post.dart';
import 'package:flutter_application_2/models/thread.dart';
import 'package:flutter_application_2/services/api/account/account_provider.dart';
import 'package:flutter_application_2/services/auth/auth_service.dart';
import 'package:flutter_application_2/services/api/account/api_urls.dart';

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

  // Get all posts
  Future<List<Post>> getPosts({
    String? category,
    String? date,
    String? tag,
  }) async {
    try {
      // Build query parameters
      final queryParams = <String, String>{};
      if (category != null) queryParams['category'] = category;
      if (date != null) queryParams['date'] = date;
      if (tag != null) queryParams['tag'] = tag;

      final url = Uri.parse('$baseUrl/api/posts/')
          .replace(queryParameters: queryParams);
      final headers = await _getHeaders();

      debugPrint('Fetching posts with URL: $url and headers: $headers');
      final response = await http.get(url, headers: headers);
      debugPrint('Posts API response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        // Check if the response is a direct array or has a results field
        final dynamic decodedBody = json.decode(response.body);
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
        debugPrint('Failed response body: ${response.body}');
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
        // Check if the response is a direct array or has a results field
        final dynamic decodedBody = json.decode(response.body);
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
          if (address != null) 'address': address,
        },
        'category': category,
        'media_urls': mediaUrls,
        'tags': tags,
        if (threadId != null) 'thread': threadId,
      };

      final response = await http.post(
        url,
        headers: headers,
        body: json.encode(postData),
      );

      if (response.statusCode == 201) {
        return Post.fromJson(json.decode(response.body));
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
        final responseData = json.decode(response.body);
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
        // Check if the response is a direct array or has a results field
        final dynamic decodedBody = json.decode(response.body);
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
        return Thread.fromJson(json.decode(response.body));
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
        return Post.fromJson(json.decode(response.body));
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
        // Check if the response is a direct array or has a results field
        final dynamic decodedBody = json.decode(response.body);
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
        // Check if the response is a direct array or has a results field
        final dynamic decodedBody = json.decode(response.body);
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
        return json.decode(response.body);
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
      final url = Uri.parse('$baseUrl/api/media/upload/');
      final headers = await _getHeaders();

      // Create a multipart request
      var request = http.MultipartRequest('POST', url);

      // Add authorization headers
      request.headers.addAll(headers);

      // Add file
      request.files.add(await http.MultipartFile.fromPath(
        'file',
        filePath,
      ));

      // Send the request
      final response = await request.send();
      final responseString = await response.stream.bytesToString();

      if (response.statusCode == 201 || response.statusCode == 200) {
        final responseData = json.decode(responseString);
        return responseData['file_url']; // The URL of the uploaded file
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
}
