import 'package:flutter/material.dart';

class NotificationModel {
  final String message;
  final DateTime dateTime;
  final IconData icon;
  final String? title;
  final String? imageUrl;
  bool isRead;

  NotificationModel({
    required this.message,
    required this.dateTime,
    required this.icon,
    this.title,
    this.imageUrl,
    this.isRead = false,
  });
}
