import 'package:flutter_application_2/models/coordinates.dart';
import 'package:flutter_application_2/models/user.dart';

class Post {
  final int id;
  final String title;
  final String content;
  final List<String> mediaUrls;
  final String category;
  final PostCoordinates location;
  final User author;
  final DateTime createdAt;
  final DateTime? updatedAt;
  int upvotes;
  int downvotes;
  int honestyScore;
  final String status;
  final int? threadId;
  final bool isVerifiedLocation;
  final bool takenWithinApp;
  final List<String> tags;
  final bool isAnonymous; // Added for anonymous posts

  // Added properties to fix errors in post_detail_page.dart
  int userVote = 0; // 1 for upvote, -1 for downvote, 0 for no vote
  double latitude;
  double longitude;
  String imageUrl = '';
  String? authorProfilePic; // Changed to nullable
  String authorName = '';
  bool isAuthorVerified = false;
  DateTime timePosted;
  double distance = 0.0;
  String description = '';
  bool? isSaved; // Added isSaved field to track if post is saved by user

  Post({
    required this.id,
    required this.title,
    required this.content,
    required this.mediaUrls,
    required this.category,
    required this.location,
    required this.author,
    required this.createdAt,
    this.updatedAt,
    required this.upvotes,
    required this.downvotes,
    required this.honestyScore,
    required this.status,
    this.threadId,
    required this.isVerifiedLocation,
    required this.takenWithinApp,
    required this.tags,
    this.isAnonymous = false, // Default to not anonymous
    this.userVote = 0,
    double? latitude,
    double? longitude,
    String? imageUrl,
    String? authorProfilePic,
    String? authorName,
    bool? isAuthorVerified,
    DateTime? timePosted,
    double? distance,
    String? description,
    this.isSaved, // Add isSaved parameter
  })  : latitude = latitude ?? location.latitude,
        longitude = longitude ?? location.longitude,
        imageUrl = imageUrl ?? (mediaUrls.isNotEmpty ? mediaUrls[0] : ''),
        authorProfilePic = authorProfilePic ?? author.profilePictureUrl,
        authorName = authorName ??
            (isAnonymous
                ? 'Anonymous'
                : author.name), // Use Anonymous name if isAnonymous is true
        isAuthorVerified = isAuthorVerified ?? author.isVerified,
        timePosted = timePosted ?? createdAt,
        distance = distance ?? 0.0,
        description = description ?? content;

  factory Post.fromJson(Map<String, dynamic> json) {
    final bool isAnonymous = json['is_anonymous'] ?? false;

    final post = Post(
      id: json['id'],
      title: json['title'],
      content: json['content'],
      mediaUrls:
          (json['media_urls'] as List? ?? []).map((e) => e.toString()).toList(),
      category: json['category'],
      location: PostCoordinates.fromJson(json['location']),
      author: User.fromJson(json['author']),
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : null,
      upvotes: json['upvotes'],
      downvotes: json['downvotes'],
      honestyScore: json['honesty_score'],
      status: json['status'],
      threadId: json['thread'],
      isVerifiedLocation: json['is_verified_location'],
      takenWithinApp: json['taken_within_app'],
      tags: (json['tags'] as List? ?? []).map((e) => e.toString()).toList(),
      isAnonymous: isAnonymous, // Set from API response
      userVote: json['user_vote'] ?? 0,
      distance: json['distance']?.toDouble() ?? 0.0,
      // If post is anonymous, use 'Anonymous' as author name
      authorName: isAnonymous ? 'Anonymous' : null,
      isSaved: json['is_saved'], // Map isSaved from API response
    );

    return post;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'media_urls': mediaUrls,
      'category': category,
      'location': location.toJson(),
      'author': author.toJson(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'upvotes': upvotes,
      'downvotes': downvotes,
      'honesty_score': honestyScore,
      'status': status,
      'thread': threadId,
      'is_verified_location': isVerifiedLocation,
      'taken_within_app': takenWithinApp,
      'tags': tags,
      'is_anonymous': isAnonymous,
      'user_vote': userVote,
      'distance': distance,
      'latitude': latitude,
      'longitude': longitude,
      'is_saved': isSaved, // Include isSaved in JSON
    };
  }

  // Helper method to get the display name respecting anonymity settings
  String getDisplayName() {
    if (isAnonymous) {
      return 'Anonymous';
    } else {
      return authorName;
    }
  }

  int get voteScore => upvotes - downvotes;

  bool get hasMedia => mediaUrls.isNotEmpty;

  bool get isInThread => threadId != null;
}
