import 'package:flutter/foundation.dart';

enum MessageType {
  text,
  image,
  video,
  voice,
  file,
  location,
  contact,
  system,
}

// Add MessageStatus enum
enum MessageStatus {
  sending,
  sent,
  delivered,
  read,
}

class Message {
  final String id;
  final String content;
  final String senderId;
  final String senderName;
  final DateTime timestamp;
  final bool isRead;
  final bool isSent;
  final bool isDelivered;
  final MessageType messageType;
  final String? mediaUrl;
  final int? voiceDuration; // Duration in seconds for voice messages
  final MessageStatus? status; // Add status property

  const Message({
    required this.id,
    required this.content,
    required this.senderId,
    required this.senderName,
    required this.timestamp,
    this.isRead = false,
    this.isSent = true,
    this.isDelivered = true,
    this.messageType = MessageType.text,
    this.mediaUrl,
    this.voiceDuration,
    this.status, // Make it optional for now
  });

  bool get isVoiceMessage => messageType == MessageType.voice;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'content': content,
      'senderId': senderId,
      'senderName': senderName,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'isRead': isRead,
      'isSent': isSent,
      'isDelivered': isDelivered,
      'messageType': describeEnum(messageType),
      'mediaUrl': mediaUrl,
      'voiceDuration': voiceDuration,
      'status':
          status != null ? describeEnum(status!) : null, // Add status to JSON
    };
  }

  Message copyWith({
    String? id,
    String? content,
    String? senderId,
    String? senderName,
    DateTime? timestamp,
    bool? isRead,
    bool? isSent,
    bool? isDelivered,
    MessageType? messageType,
    String? mediaUrl,
    int? voiceDuration,
    MessageStatus? status, // Add status to copyWith
  }) {
    return Message(
      id: id ?? this.id,
      content: content ?? this.content,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      timestamp: timestamp ?? this.timestamp,
      isRead: isRead ?? this.isRead,
      isSent: isSent ?? this.isSent,
      isDelivered: isDelivered ?? this.isDelivered,
      messageType: messageType ?? this.messageType,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      voiceDuration: voiceDuration ?? this.voiceDuration,
      status: status ?? this.status, // Include status in copyWith
    );
  }

  static Message fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'],
      content: json['content'],
      senderId: json['senderId'],
      senderName: json['senderName'],
      timestamp: DateTime.fromMillisecondsSinceEpoch(json['timestamp']),
      isRead: json['isRead'] ?? false,
      isSent: json['isSent'] ?? true,
      isDelivered: json['isDelivered'] ?? true,
      messageType: _parseMessageType(json['messageType']),
      mediaUrl: json['mediaUrl'],
      voiceDuration: json['voiceDuration'],
      status: json['status'] != null
          ? _parseMessageStatus(json['status'])
          : null, // Parse status
    );
  }

  static MessageType _parseMessageType(String? type) {
    switch (type) {
      case 'text':
        return MessageType.text;
      case 'image':
        return MessageType.image;
      case 'video':
        return MessageType.video;
      case 'voice':
        return MessageType.voice;
      case 'file':
        return MessageType.file;
      case 'location':
        return MessageType.location;
      case 'contact':
        return MessageType.contact;
      case 'system':
        return MessageType.system;
      default:
        return MessageType.text;
    }
  }

  // Add helper method to parse MessageStatus from string
  static MessageStatus _parseMessageStatus(String status) {
    switch (status) {
      case 'sending':
        return MessageStatus.sending;
      case 'sent':
        return MessageStatus.sent;
      case 'delivered':
        return MessageStatus.delivered;
      case 'read':
        return MessageStatus.read;
      default:
        return MessageStatus.sending;
    }
  }
}
