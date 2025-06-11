import 'dart:convert';
import 'dart:developer' as developer;
import 'package:flutter_application_2/models/account.dart';

enum ActivityStatus {
  online,
  offline,
  away,
  doNotDisturb,
}

class UserProfile {
  final Account account; // Base account information
  final String username;
  final String bio;
  final String location;
  final int honestyScore; // Percentage score indicating user credibility
  final int followersCount;
  final int followingCount;
  final int postsCount;
  final int savedPostsCount;
  final int upvotedPostsCount;
  final int commentsCount;
  final DateTime joinDate;
  final ActivityStatus activityStatus;
  final bool isVerified;
  final String? coverPhotoUrl;

  // Additional Fields for Social Features
  final List<String>? interests; // Topics the user is interested in
  final String? website; // User's personal website

  const UserProfile({
    required this.account,
    required this.username,
    this.bio = '',
    this.location = '',
    this.honestyScore = 0,
    this.followersCount = 0,
    this.followingCount = 0,
    this.postsCount = 0,
    this.savedPostsCount = 0,
    this.upvotedPostsCount = 0,
    this.commentsCount = 0,
    required this.joinDate,
    this.activityStatus = ActivityStatus.offline,
    this.isVerified = false,
    this.coverPhotoUrl,
    this.interests,
    this.website,
  });

  // Helper getters
  String get fullName => account.fullName;
  String get profilePictureUrl => account.profilePictureUrl ?? '';
  String get email => account.email;

  // Activity Status string representation
  String get activityStatusStr {
    switch (activityStatus) {
      case ActivityStatus.online:
        return 'Online';
      case ActivityStatus.offline:
        return 'Offline';
      case ActivityStatus.away:
        return 'Away';
      case ActivityStatus.doNotDisturb:
        return 'Do Not Disturb';
    }
  }

  // Format join date as a string (e.g., "March 2022")
  String get joinDateFormatted {
    final months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December'
    ];
    return '${months[joinDate.month - 1]} ${joinDate.year}';
  }

  // Factory to create from json (server response)
  factory UserProfile.fromJson(Map<String, dynamic> json) {
    // Log the input for debugging
    developer.log(
        'Parsing UserProfile from JSON: ${json.toString().substring(0, json.toString().length > 100 ? 100 : json.toString().length)}...',
        name: 'UserProfileModel');

    // Handle nullable account data safely
    Account? account;
    try {
      // First, ensure the account field exists and is properly formatted
      if (json['account'] == null) {
        developer.log(
            'Account data is missing in profile JSON. Looking for account_id instead.',
            name: 'UserProfileModel');

        // Try to construct an account from separate fields if account object is missing
        if (json['account_id'] != null || json['user_id'] != null) {
          int userId = -1;

          if (json['account_id'] != null) {
            userId = json['account_id'] is String
                ? int.parse(json['account_id'])
                : json['account_id'];
          } else if (json['user_id'] != null) {
            userId = json['user_id'] is String
                ? int.parse(json['user_id'])
                : json['user_id'];
          }

          account = Account(
            id: userId,
            email: json['email'] ?? 'unknown@example.com',
            firstName: json['first_name'] ?? '',
            lastName: json['last_name'] ?? '',
            profilePictureUrl: json['profile_picture_url'],
          );
        } else {
          throw Exception(
              'Neither account object nor account_id/user_id found in profile JSON');
        }
      } else {
        account = Account.fromJson(json['account']);
      }
    } catch (e) {
      developer.log('Error parsing account in UserProfile: $e',
          name: 'UserProfileModel', error: e);
      // Create a fallback account with empty data if parsing fails
      account = Account(
        id: json['account_id'] ?? json['user_id'] ?? -1,
        email: json['email'] ?? 'unknown@example.com',
        firstName: json['first_name'] ?? '',
        lastName: json['last_name'] ?? '',
      );
    }

    // Parse numeric fields with better error handling
    int parseIntSafely(dynamic value, String fieldName,
        {int defaultValue = 0}) {
      if (value == null) return defaultValue;

      try {
        if (value is String) {
          return int.parse(value);
        } else if (value is int) {
          return value;
        } else if (value is double) {
          return value.toInt();
        }
      } catch (e) {
        developer.log('Error parsing $fieldName ($value): $e',
            name: 'UserProfileModel');
      }
      return defaultValue;
    }

    // Parse date safely
    DateTime parseDateSafely(dynamic value, {required DateTime defaultValue}) {
      if (value == null) return defaultValue;

      try {
        if (value is String) {
          return DateTime.parse(value);
        } else if (value is int) {
          // Assume timestamp in milliseconds
          return DateTime.fromMillisecondsSinceEpoch(value);
        }
      } catch (e) {
        developer.log('Error parsing date ($value): $e',
            name: 'UserProfileModel');
      }
      return defaultValue;
    }

    // Return the UserProfile with safer parsing
    // Final safety check - if account is still null, this indicates a critical parsing error
    if (account == null) {
      developer.log(
          'CRITICAL: Account is null after all parsing attempts. Raw JSON: ${json.toString()}',
          name: 'UserProfileModel');
      throw Exception(
          'Failed to parse account data from profile JSON. Cannot create UserProfile without valid account.');
    }

    return UserProfile(
      account: account,
      username: json['username'] ?? '',
      bio: json['bio'] ?? '',
      location: json['location'] ?? '',
      honestyScore: parseIntSafely(json['honesty_score'], 'honesty_score'),
      followersCount:
          parseIntSafely(json['followers_count'], 'followers_count'),
      followingCount:
          parseIntSafely(json['following_count'], 'following_count'),
      postsCount: parseIntSafely(json['posts_count'], 'posts_count'),
      savedPostsCount:
          parseIntSafely(json['saved_posts_count'], 'saved_posts_count'),
      upvotedPostsCount:
          parseIntSafely(json['upvoted_posts_count'], 'upvoted_posts_count'),
      commentsCount: parseIntSafely(json['comments_count'], 'comments_count'),
      joinDate: parseDateSafely(json['join_date'],
          defaultValue: account.createdAt ?? DateTime.now()),
      activityStatus: _parseActivityStatus(json['activity_status']),
      isVerified: json['is_verified'] ?? false,
      coverPhotoUrl: json['cover_photo_url'],
      interests: json['interests'] != null
          ? List<String>.from(json['interests'])
          : null,
      website: json['website'],
    );
  }

  // Helper method to parse activity status
  static ActivityStatus _parseActivityStatus(String? status) {
    if (status == null) return ActivityStatus.offline;

    switch (status.toLowerCase()) {
      case 'online':
        return ActivityStatus.online;
      case 'away':
        return ActivityStatus.away;
      case 'do not disturb':
      case 'donotdisturb':
      case 'do_not_disturb':
        return ActivityStatus.doNotDisturb;
      case 'offline':
      default:
        return ActivityStatus.offline;
    }
  }

  // Convert to JSON for API requests
  Map<String, dynamic> toJson() {
    return {
      'account': account.toJson(),
      'username': username,
      'bio': bio,
      'location': location,
      'honesty_score': honestyScore,
      'followers_count': followersCount,
      'following_count': followingCount,
      'posts_count': postsCount,
      'saved_posts_count': savedPostsCount,
      'upvoted_posts_count': upvotedPostsCount,
      'comments_count': commentsCount,
      'join_date': joinDate.toIso8601String(),
      'activity_status': activityStatusStr,
      'is_verified': isVerified,
      'cover_photo_url': coverPhotoUrl,
      'interests': interests,
      'website': website,
    };
  }

  // Create a copy with updated fields
  UserProfile copyWith({
    Account? account,
    String? username,
    String? bio,
    String? location,
    int? honestyScore,
    int? followersCount,
    int? followingCount,
    int? postsCount,
    int? savedPostsCount,
    int? upvotedPostsCount,
    int? commentsCount,
    DateTime? joinDate,
    ActivityStatus? activityStatus,
    bool? isVerified,
    String? coverPhotoUrl,
    List<String>? interests,
    String? website,
    String? profilePictureUrl,
  }) {
    return UserProfile(
      account: profilePictureUrl != null
          ? account?.copyWith(profilePictureUrl: profilePictureUrl) ??
              this.account
          : account ?? this.account,
      username: username ?? this.username,
      bio: bio ?? this.bio,
      location: location ?? this.location,
      honestyScore: honestyScore ?? this.honestyScore,
      followersCount: followersCount ?? this.followersCount,
      followingCount: followingCount ?? this.followingCount,
      postsCount: postsCount ?? this.postsCount,
      savedPostsCount: savedPostsCount ?? this.savedPostsCount,
      upvotedPostsCount: upvotedPostsCount ?? this.upvotedPostsCount,
      commentsCount: commentsCount ?? this.commentsCount,
      joinDate: joinDate ?? this.joinDate,
      activityStatus: activityStatus ?? this.activityStatus,
      isVerified: isVerified ?? this.isVerified,
      coverPhotoUrl: coverPhotoUrl ?? this.coverPhotoUrl,
      interests: interests ?? this.interests,
      website: website ?? this.website,
    );
  }

  @override
  String toString() {
    return jsonEncode(toJson());
  }
}
