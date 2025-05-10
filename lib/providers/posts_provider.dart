import 'package:flutter/material.dart';
import 'package:flutter_application_2/models/post.dart';
import 'package:flutter_application_2/models/thread.dart';
import 'package:flutter_application_2/services/posts/posts_service.dart';
import 'package:flutter_application_2/services/location/location_service.dart';

class PostsProvider with ChangeNotifier {
  final PostsService _postsService;
  final LocationService _locationService;

  List<Post> _posts = [];
  List<Thread> _threads = [];
  bool _isLoading = false;
  String? _errorMessage;

  // Getters
  List<Post> get posts => _posts;
  List<Thread> get threads => _threads;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  PostsProvider({
    required PostsService postsService,
    required LocationService locationService,
  })  : _postsService = postsService,
        _locationService = locationService;

  // Load posts from API
  Future<void> fetchPosts({
    String? category,
    String? date,
    String? tag,
  }) async {
    _setLoading(true);
    try {
      _posts = await _postsService.getPosts(
        category: category,
        date: date,
        tag: tag,
      );
      _errorMessage = null;
    } catch (e) {
      _errorMessage = 'Failed to fetch posts: $e';
      debugPrint(_errorMessage);
    } finally {
      _setLoading(false);
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

  // Load threads near user's location
  Future<void> fetchNearbyThreads({
    int radius = 1000,
    String? category,
  }) async {
    _setLoading(true);
    try {
      final position = await _locationService.getCurrentPosition();

      _threads = await _postsService.getNearbyThreads(
        latitude: position.latitude,
        longitude: position.longitude,
        radius: radius,
        category: category,
      );
      _errorMessage = null;
    } catch (e) {
      _errorMessage = 'Failed to fetch nearby threads: $e';
      debugPrint(_errorMessage);
    } finally {
      _setLoading(false);
    }
  }

  // Create a new post
  Future<Post?> createPost({
    required String title,
    required String content,
    String? address,
    String category = 'general',
    List<String> mediaUrls = const [],
    List<String> tags = const [],
    int? threadId,
  }) async {
    _setLoading(true);
    try {
      final position = await _locationService.getCurrentPosition();

      final post = await _postsService.createPost(
        title: title,
        content: content,
        latitude: position.latitude,
        longitude: position.longitude,
        address: address,
        category: category,
        mediaUrls: mediaUrls,
        tags: tags,
        threadId: threadId,
      );

      // Add the new post to our list
      _posts.insert(0, post);
      notifyListeners();

      _errorMessage = null;
      return post;
    } catch (e) {
      _errorMessage = 'Failed to create post: $e';
      debugPrint(_errorMessage);
      return null;
    } finally {
      _setLoading(false);
    }
  }

  // Vote on a post
  Future<Map<String, dynamic>> voteOnPost(Post post, bool isUpvote) async {
    try {
      final result = await _postsService.voteOnPost(
        postId: post.id,
        isUpvote: isUpvote,
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

  // Get threads for a specific post
  Future<List<Map<String, dynamic>>> getThreadsForPost(int postId) async {
    _setLoading(true);
    try {
      final threads = await _postsService.getThreadsForPost(postId);
      _errorMessage = null;
      return threads;
    } catch (e) {
      _errorMessage = 'Failed to fetch threads for post: $e';
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

  // Helper method to update loading state
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }
}
