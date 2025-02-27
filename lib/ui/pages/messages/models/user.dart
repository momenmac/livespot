class User {
  final String id;
  final String name;
  final String avatarUrl;
  final bool isOnline;

  User({
    required this.id,
    required this.name,
    required this.avatarUrl,
    this.isOnline = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'avatarUrl': avatarUrl,
      'isOnline': isOnline,
    };
  }

  static User fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      name: json['name'],
      avatarUrl: json['avatarUrl'] ??
          'https://ui-avatars.com/api/?name=${Uri.encodeComponent(json['name'])}',
      isOnline: json['isOnline'] ?? false,
    );
  }

  User copyWith({
    String? id,
    String? name,
    String? avatarUrl,
    bool? isOnline,
  }) {
    return User(
      id: id ?? this.id,
      name: name ?? this.name,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      isOnline: isOnline ?? this.isOnline,
    );
  }
}
