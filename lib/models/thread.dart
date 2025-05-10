import 'package:flutter_application_2/models/coordinates.dart';
import 'package:flutter_application_2/models/post.dart';

class Thread {
  final int id;
  final String title;
  final String category;
  final PostCoordinates location;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<String> tags;
  final int honestyScore;
  final List<Post>? posts;

  Thread({
    required this.id,
    required this.title,
    required this.category,
    required this.location,
    required this.createdAt,
    required this.updatedAt,
    required this.tags,
    required this.honestyScore,
    this.posts,
  });

  factory Thread.fromJson(Map<String, dynamic> json) {
    return Thread(
      id: json['id'],
      title: json['title'],
      category: json['category'],
      location: PostCoordinates.fromJson(json['location']),
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
      tags: (json['tags'] as List).map((e) => e.toString()).toList(),
      honestyScore: json['honesty_score'],
      posts: json['posts'] != null
          ? (json['posts'] as List).map((e) => Post.fromJson(e)).toList()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'category': category,
      'location': location.toJson(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'tags': tags,
      'honesty_score': honestyScore,
      if (posts != null) 'posts': posts!.map((p) => p.toJson()).toList(),
    };
  }
}
