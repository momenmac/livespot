import 'dart:convert';

class Account {
  final int? id;
  final String email;
  final String firstName;
  final String lastName;
  final String? profilePicture;
  final String? googleId;
  String? token;

  Account({
    this.id,
    required this.email,
    required this.firstName,
    required this.lastName,
    this.profilePicture,
    this.googleId,
    this.token,
  });

  // Create a copy of the account with modified fields
  Account copyWith({
    int? id,
    String? email,
    String? firstName,
    String? lastName,
    String? profilePicture,
    String? googleId,
    String? token,
  }) {
    return Account(
      id: id ?? this.id,
      email: email ?? this.email,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      profilePicture: profilePicture ?? this.profilePicture,
      googleId: googleId ?? this.googleId,
      token: token ?? this.token,
    );
  }

  // Convert Account object to a Map for JSON serialization
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'first_name': firstName,
      'last_name': lastName,
      'profile_picture': profilePicture,
      'google_id': googleId,
    };
  }

  // Create Account object from JSON Map
  factory Account.fromJson(Map<String, dynamic> json) {
    return Account(
      id: json['id'],
      email: json['email'],
      firstName: json['first_name'],
      lastName: json['last_name'],
      profilePicture: json['profile_picture'],
      googleId: json['google_id'],
    );
  }

  // Create Account from JSON string
  factory Account.fromJsonString(String jsonString) {
    return Account.fromJson(json.decode(jsonString));
  }

  // Get full name (convenience method)
  String get fullName => '$firstName $lastName';

  @override
  String toString() {
    return 'Account{id: $id, email: $email, firstName: $firstName, lastName: $lastName}';
  }
}
