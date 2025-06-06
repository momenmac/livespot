class NewsArticle {
  final String id;
  final String title;
  final String description;
  final String content;
  final String url;
  final String? imageUrl;
  final String source;
  final String author;
  final DateTime publishedAt;
  final String category;

  NewsArticle({
    required this.id,
    required this.title,
    required this.description,
    required this.content,
    required this.url,
    this.imageUrl,
    required this.source,
    required this.author,
    required this.publishedAt,
    this.category = 'general',
  });

  factory NewsArticle.fromJson(Map<String, dynamic> json) {
    return NewsArticle(
      id: json['id'] ?? _generateId(json['title'] ?? ''),
      title: json['title'] ?? 'No Title',
      description: json['description'] ?? '',
      content: json['content'] ?? json['description'] ?? '',
      url: json['url'] ?? '',
      imageUrl: json['urlToImage'] ?? json['imageUrl'],
      source: json['source']?['name'] ?? json['source'] ?? 'Unknown Source',
      author: json['author'] ?? 'Unknown',
      publishedAt: json['publishedAt'] != null
          ? DateTime.tryParse(json['publishedAt']) ?? DateTime.now()
          : DateTime.now(),
      category: json['category'] ?? 'general',
    );
  }

  factory NewsArticle.fromNewsAPI(Map<String, dynamic> json) {
    return NewsArticle(
      id: _generateId(json['title'] ?? ''),
      title: json['title'] ?? 'No Title',
      description: json['description'] ?? '',
      content: json['content'] ?? json['description'] ?? '',
      url: json['url'] ?? '', // Direct URL from NewsAPI
      imageUrl: json['urlToImage'],
      source: json['source']?['name'] ?? 'Unknown Source',
      author: json['author'] ?? 'Unknown',
      publishedAt: json['publishedAt'] != null
          ? DateTime.tryParse(json['publishedAt']) ?? DateTime.now()
          : DateTime.now(),
      category: 'general',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'content': content,
      'url': url,
      'urlToImage': imageUrl,
      'source': {'name': source},
      'author': author,
      'publishedAt': publishedAt.toIso8601String(),
      'category': category,
    };
  }

  static String _generateId(String title) {
    return title
            .toLowerCase()
            .replaceAll(RegExp(r'[^a-z0-9]'), '')
            .substring(0, title.length > 20 ? 20 : title.length) +
        DateTime.now().millisecondsSinceEpoch.toString();
  }

  String get timeAgo {
    final now = DateTime.now();
    final difference = now.difference(publishedAt);

    if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes == 1 ? '' : 's'} ago';
    } else {
      return 'Just now';
    }
  }

  String get shortDescription {
    if (description.length <= 100) return description;
    return '${description.substring(0, 100)}...';
  }

  NewsArticle copyWith({
    String? id,
    String? title,
    String? description,
    String? content,
    String? url,
    String? imageUrl,
    String? source,
    String? author,
    DateTime? publishedAt,
    String? category,
  }) {
    return NewsArticle(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      content: content ?? this.content,
      url: url ?? this.url,
      imageUrl: imageUrl ?? this.imageUrl,
      source: source ?? this.source,
      author: author ?? this.author,
      publishedAt: publishedAt ?? this.publishedAt,
      category: category ?? this.category,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NewsArticle &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'NewsArticle{id: $id, title: $title, source: $source, publishedAt: $publishedAt}';
  }
}
