import 'package:flutter/material.dart';

class NotificationModel {
  final String id;
  final String title;
  final String body;
  final DateTime timestamp;
  final bool read;
  final String type;
  final Map<String, dynamic> data;

  // Legacy fields for backward compatibility
  final String? message;
  final DateTime? dateTime;
  final IconData? icon;
  final String? imageUrl;
  final bool? isRead;

  NotificationModel({
    required this.id,
    required this.title,
    required this.body,
    required this.timestamp,
    required this.read,
    required this.type,
    required this.data,
    // Legacy fields
    this.message,
    this.dateTime,
    this.icon,
    this.imageUrl,
    this.isRead,
  });

  // Legacy constructor for backward compatibility
  NotificationModel.legacy({
    required String message,
    required DateTime dateTime,
    required IconData icon,
    String? title,
    String? imageUrl,
    bool isRead = false,
  }) : this(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          title: title ?? 'Notification',
          body: message,
          timestamp: dateTime,
          read: isRead,
          type: 'general',
          data: {},
          message: message,
          dateTime: dateTime,
          icon: icon,
          imageUrl: imageUrl,
          isRead: isRead,
        );

  // CopyWith method
  NotificationModel copyWith({
    String? id,
    String? title,
    String? body,
    DateTime? timestamp,
    bool? read,
    String? type,
    Map<String, dynamic>? data,
    String? message,
    DateTime? dateTime,
    IconData? icon,
    String? imageUrl,
    bool? isRead,
  }) {
    return NotificationModel(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      timestamp: timestamp ?? this.timestamp,
      read: read ?? this.read,
      type: type ?? this.type,
      data: data ?? this.data,
      message: message ?? this.message,
      dateTime: dateTime ?? this.dateTime,
      icon: icon ?? this.icon,
      imageUrl: imageUrl ?? this.imageUrl,
      isRead: isRead ?? this.isRead,
    );
  }

  // Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'body': body,
      'timestamp': timestamp.toIso8601String(),
      'read': read,
      'type': type,
      'data': data,
    };
  }

  // Create from JSON
  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      body: json['body'] ?? '',
      timestamp:
          DateTime.parse(json['timestamp'] ?? DateTime.now().toIso8601String()),
      read: json['read'] ?? false,
      type: json['type'] ?? 'general',
      data: Map<String, dynamic>.from(json['data'] ?? {}),
    );
  }

  // Create from Django backend data
  factory NotificationModel.fromDjangoData(Map<String, dynamic> data) {
    return NotificationModel(
      id: data['id']?.toString() ?? '',
      title: data['title'] ?? 'Notification',
      body: data['body'] ?? '',
      timestamp: DateTime.tryParse(data['created_at'] ?? '') ?? DateTime.now(),
      read: data['read'] ?? false,
      type: data['notification_type'] ?? 'general',
      data: Map<String, dynamic>.from(data['data'] ?? {}),
      // Legacy fields for UI compatibility
      message: data['body'] ?? '',
      dateTime: DateTime.tryParse(data['created_at'] ?? '') ?? DateTime.now(),
      isRead: data['read'] ?? false,
    );
  }
}
