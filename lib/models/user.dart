class User {
  final int id;
  final String username;
  final String? fullName;
  final String? profileImage;
  final bool isVerified;
  final bool isAdmin;

  User({
    required this.id,
    required this.username,
    this.fullName,
    this.profileImage,
    this.isVerified = false,
    this.isAdmin = false,
  });

  // Add getters for compatibility with post_detail_page.dart
  String get name => fullName ?? username;
  String? get profilePictureUrl => profileImage;

  factory User.fromJson(Map<String, dynamic> json) {
    // Handle the new format from AccountAuthorSerializer
    if (json.containsKey('display_name')) {
      // This is the new format using AccountAuthorSerializer
      return User(
        id: json['id'] is String ? int.parse(json['id']) : json['id'],
        username: json['display_name'] ?? 'Anonymous',
        fullName:
            '${json['first_name'] ?? ''} ${json['last_name'] ?? ''}'.trim(),
        profileImage: json['profile_picture'],
        isVerified: json['is_verified'] ?? false, // Default to false if missing
        isAdmin: json['is_admin'] ?? false, // Default to false if missing
      );
    } else {
      // Original format for backward compatibility
      return User(
        id: json['id'] is String ? int.parse(json['id']) : json['id'],
        username: json['username'],
        fullName: json['full_name'],
        profileImage: json['profile_image'],
        isVerified: json['is_verified'] ?? false,
        isAdmin: json['is_admin'] ?? false, // Default to false if missing
      );
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'full_name': fullName,
      'profile_image': profileImage,
      'is_verified': isVerified,
      'is_admin': isAdmin,
    };
  }
}
