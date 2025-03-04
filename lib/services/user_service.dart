import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_application_2/ui/pages/messages/models/user.dart';

class UserService {
  // Singleton instance
  static final UserService _instance = UserService._internal();

  factory UserService() => _instance;

  UserService._internal();

  // Cache users after loading them
  List<User>? _cachedUsers;

  /// Loads user data from mock JSON file
  ///
  /// TODO: Replace this with Firebase Authentication and Firestore user data
  /// - Create a Cloud Firestore "users" collection
  /// - Use Firebase Authentication to manage user accounts
  /// - Update this method to fetch users from Firestore instead of JSON
  /// - Implement real-time user status with Firebase presence system
  Future<List<User>> getUsers() async {
    // Return cached data if available
    if (_cachedUsers != null) {
      return _cachedUsers!;
    }

    try {
      // Fix the asset path - ensure there's no duplicate 'assets/' prefix
      final String jsonData =
          await rootBundle.loadString('assets/mock/users.json');
      print("Successfully loaded users.json");
      final List<dynamic> jsonList = json.decode(jsonData);

      // Convert to UserWithEmail objects
      _cachedUsers =
          jsonList.map((userData) => UserWithEmail.fromJson(userData)).toList();

      return _cachedUsers!;
    } catch (e) {
      print('Error loading user data: $e');
      // Create default users as fallback
      _cachedUsers = _createDefaultUsers();
      return _cachedUsers!;
    }
  }

  // Create some default users when loading fails
  List<User> _createDefaultUsers() {
    return [
      UserWithEmail(
        id: 'user1',
        name: 'John Smith',
        email: 'john.smith@example.com',
        avatarUrl: 'https://ui-avatars.com/api/?name=John+Smith',
        isOnline: true,
      ),
      UserWithEmail(
        id: 'user2',
        name: 'Sarah Johnson',
        email: 'sarah.j@example.com',
        avatarUrl: 'https://ui-avatars.com/api/?name=Sarah+Johnson',
        isOnline: false,
      ),
      UserWithEmail(
        id: 'user3',
        name: 'Michael Brown',
        email: 'm.brown@example.com',
        avatarUrl: 'https://ui-avatars.com/api/?name=Michael+Brown',
        isOnline: true,
      ),
      UserWithEmail(
        id: 'user4',
        name: 'Emma Wilson',
        email: 'emma.w@example.com',
        avatarUrl: 'https://ui-avatars.com/api/?name=Emma+Wilson',
        isOnline: false,
      ),
    ];
  }

  /// Search users by name or email
  ///
  /// TODO: Replace with Firebase Firestore query
  /// - Update to use Firestore queries with where() filters
  /// - Implement pagination for large result sets
  /// - Consider using Firebase Functions for complex searches
  Future<List<User>> searchUsers(String query) async {
    final users = await getUsers();

    if (query.isEmpty) {
      return users;
    }

    final normalizedQuery = query.toLowerCase().trim();

    return users.where((user) {
      final name = user.name.toLowerCase();
      final email = (user is UserWithEmail) ? user.email.toLowerCase() : '';

      return name.contains(normalizedQuery) || email.contains(normalizedQuery);
    }).toList();
  }
}

// Extended class to include email (could be part of your main User class)
class UserWithEmail extends User {
  final String email;

  UserWithEmail({
    required super.id,
    required super.name,
    required super.avatarUrl,
    required this.email,
    super.isOnline,
  });

  @override
  Map<String, dynamic> toJson() {
    final map = super.toJson();
    map['email'] = email;
    return map;
  }

  static UserWithEmail fromJson(Map<String, dynamic> json) {
    return UserWithEmail(
      id: json['id'],
      name: json['name'],
      email: json['email'],
      avatarUrl: json['avatarUrl'] ??
          'https://ui-avatars.com/api/?name=${Uri.encodeComponent(json['name'])}',
      isOnline: json['isOnline'] ?? false,
    );
  }
}
