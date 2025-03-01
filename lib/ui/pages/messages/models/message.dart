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
  final int? voiceDuration;
  final MessageStatus? status;

  // Add these new fields for reply functionality
  final String? replyToId; // ID of the message this is replying to
  final String? replyToSenderName; // Name of the sender of the original message
  final String? replyToContent; // Content of the original message
  final MessageType? replyToMessageType; // Type of original message
  final bool? isEdited; // Flag to indicate if message was edited
  final String? forwardedFrom; // Name of original sender if forwarded

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
    this.status,
    // Add the new fields to constructor
    this.replyToId,
    this.replyToSenderName,
    this.replyToContent,
    this.replyToMessageType,
    this.isEdited = false,
    this.forwardedFrom,
  });

  bool get isVoiceMessage => messageType == MessageType.voice;

  // Add helper method to check if this is a reply
  bool get isReply => replyToId != null;

  // Add helper method to check if this is forwarded
  // Update to make it simpler - just check if forwardedFrom exists
  bool get isForwarded => forwardedFrom != null;

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
      'status': status != null ? describeEnum(status!) : null,
      // Add new fields to JSON
      'replyToId': replyToId,
      'replyToSenderName': replyToSenderName,
      'replyToContent': replyToContent,
      'replyToMessageType':
          replyToMessageType != null ? describeEnum(replyToMessageType!) : null,
      'isEdited': isEdited,
      'forwardedFrom': forwardedFrom,
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
    MessageStatus? status,
    // Add new fields to copyWith
    String? replyToId,
    String? replyToSenderName,
    String? replyToContent,
    MessageType? replyToMessageType,
    bool? isEdited,
    String? forwardedFrom,
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
      status: status ?? this.status,
      // Include new fields in copyWith
      replyToId: replyToId ?? this.replyToId,
      replyToSenderName: replyToSenderName ?? this.replyToSenderName,
      replyToContent: replyToContent ?? this.replyToContent,
      replyToMessageType: replyToMessageType ?? this.replyToMessageType,
      isEdited: isEdited ?? this.isEdited,
      forwardedFrom: forwardedFrom ?? this.forwardedFrom,
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
      status:
          json['status'] != null ? _parseMessageStatus(json['status']) : null,
      // Parse new fields from JSON
      replyToId: json['replyToId'],
      replyToSenderName: json['replyToSenderName'],
      replyToContent: json['replyToContent'],
      replyToMessageType: json['replyToMessageType'] != null
          ? _parseMessageType(json['replyToMessageType'])
          : null,
      isEdited: json['isEdited'] ?? false,
      forwardedFrom: json['forwardedFrom'],
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
