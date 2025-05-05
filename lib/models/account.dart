import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter_application_2/services/api/account/api_urls.dart';
import 'package:flutter_application_2/app_entry.dart' as app;

void main() => app.main();

class Account {
  final int id;
  final String email;
  final String firstName;
  final String lastName;
  final String? profilePictureUrl;
  final bool isVerified;
  final String? googleId;
  final DateTime? createdAt;
  final DateTime? lastLogin;

  Account({
    required this.id,
    required this.email,
    required this.firstName,
    required this.lastName,
    this.profilePictureUrl,
    this.isVerified = false,
    this.googleId,
    this.createdAt,
    this.lastLogin,
  });

  String get fullName => '$firstName $lastName';

  // Add this getter for compatibility with AccountProvider
  bool get isEmailVerified => isVerified;

  factory Account.fromJson(Map<String, dynamic> json) {
    // Add logging to help debug profile issues
    developer.log(
        'Parsing Account from JSON: ${json.toString().substring(0, json.toString().length > 100 ? 100 : json.toString().length)}...',
        name: 'AccountModel');

    // Check if the account data is nested inside the "account" key
    Map<String, dynamic> accountData = json;
    if (json.containsKey('account') &&
        json['account'] is Map<String, dynamic>) {
      developer.log('Found nested account structure', name: 'AccountModel');
      accountData = json['account'];
    }

    // Handle potentially null or missing id
    var accountId = -1;
    try {
      if (accountData.containsKey('id') && accountData['id'] != null) {
        // Handle either int or String representation of ID
        accountId = accountData['id'] is String
            ? int.parse(accountData['id'])
            : accountData['id'] as int;
      } else if (json.containsKey('user_id') && json['user_id'] != null) {
        // Alternative key for ID
        accountId = json['user_id'] is String
            ? int.parse(json['user_id'])
            : json['user_id'] as int;
      } else if (json.containsKey('account_id') && json['account_id'] != null) {
        // Another alternative key for ID
        accountId = json['account_id'] is String
            ? int.parse(json['account_id'])
            : json['account_id'] as int;
      } else {
        developer.log('Warning: Account ID is null in JSON response',
            name: 'AccountModel');
      }
    } catch (e) {
      developer.log('Error parsing account ID: $e', name: 'AccountModel');
    }

    // Extract email with better fallback handling
    String email = 'unknown@example.com';
    if (accountData.containsKey('email') && accountData['email'] != null) {
      email = accountData['email'];
    } else if (json.containsKey('email') && json['email'] != null) {
      email = json['email'];
    }

    // Log if we're using the fallback email
    if (email == 'unknown@example.com') {
      developer.log(
          '⚠️ WARNING: Using fallback email because email is missing in API response',
          name: 'AccountModel');
    }

    // Handle profile picture URL with nested structure awareness
    String? profilePictureUrl = accountData['profile_picture_url'] ??
        accountData['profile_picture'] ??
        json['profile_picture_url'] ??
        json['profile_picture'];

    // Check if we need to prepend the base URL for relative URLs
    if (profilePictureUrl != null &&
        !profilePictureUrl.startsWith('http') &&
        profilePictureUrl.isNotEmpty) {
      // This is a relative URL, prepend the base API URL
      final apiBaseUrl = ApiUrls.baseUrl;
      profilePictureUrl = '$apiBaseUrl$profilePictureUrl';
    }

    // Extract other fields with nested structure awareness
    String firstName = accountData['first_name'] ?? json['first_name'] ?? '';
    String lastName = accountData['last_name'] ?? json['last_name'] ?? '';
    bool isVerified =
        accountData['is_verified'] ?? json['is_verified'] ?? false;
    String? googleId = accountData['google_id'] ?? json['google_id'];

    // Parse dates with better error handling
    DateTime? createdAt;
    try {
      String? createdAtStr = accountData['created_at'] ?? json['created_at'];
      if (createdAtStr != null) {
        createdAt = DateTime.parse(createdAtStr);
      }
    } catch (e) {
      developer.log('Error parsing created_at date: $e', name: 'AccountModel');
    }

    DateTime? lastLogin;
    try {
      String? lastLoginStr = accountData['last_login'] ?? json['last_login'];
      if (lastLoginStr != null) {
        lastLogin = DateTime.parse(lastLoginStr);
      }
    } catch (e) {
      developer.log('Error parsing last_login date: $e', name: 'AccountModel');
    }

    return Account(
      id: accountId,
      email: email,
      firstName: firstName,
      lastName: lastName,
      profilePictureUrl: profilePictureUrl,
      isVerified: isVerified,
      googleId: googleId,
      createdAt: createdAt,
      lastLogin: lastLogin,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'first_name': firstName,
      'last_name': lastName,
      'profile_picture_url': profilePictureUrl,
      'is_verified': isVerified,
      'google_id': googleId,
      'created_at': createdAt?.toIso8601String(),
      'last_login': lastLogin?.toIso8601String(),
    };
  }

  @override
  String toString() {
    return jsonEncode(toJson());
  }

  Account copyWith({
    int? id,
    String? email,
    String? firstName,
    String? lastName,
    String? profilePictureUrl,
    bool? isVerified,
    String? googleId,
    DateTime? createdAt,
    DateTime? lastLogin,
  }) {
    return Account(
      id: id ?? this.id,
      email: email ?? this.email,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      profilePictureUrl: profilePictureUrl ?? this.profilePictureUrl,
      isVerified: isVerified ?? this.isVerified,
      googleId: googleId ?? this.googleId,
      createdAt: createdAt ?? this.createdAt,
      lastLogin: lastLogin ?? this.lastLogin,
    );
  }
}
