import 'dart:convert';

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

  factory Account.fromJson(Map<String, dynamic> json) {
    String? profilePictureUrl = json['profile_picture_url'];

    // Check if we need to prepend the base URL for relative URLs
    if (profilePictureUrl != null &&
        !profilePictureUrl.startsWith('http') &&
        profilePictureUrl.isNotEmpty) {
      // This is a relative URL, prepend the base API URL
      final apiBaseUrl = ApiUrls.baseUrl;
      profilePictureUrl = '$apiBaseUrl$profilePictureUrl';
    }

    return Account(
      id: json['id'],
      email: json['email'],
      firstName: json['first_name'],
      lastName: json['last_name'],
      profilePictureUrl: profilePictureUrl,
      isVerified: json['is_verified'] ?? false,
      googleId: json['google_id'],
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
      lastLogin: json['last_login'] != null
          ? DateTime.parse(json['last_login'])
          : null,
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
