import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_application_2/ui/pages/messages/messages_controller.dart';

enum MessageType { text, image, video, file, location, voice, system }

enum MessageStatus { sending, sent, delivered, read, failed }

class Message {
  final String id;
  final String conversationId;
  final String senderId;
  final String senderName;
  final String content;
  final DateTime timestamp;
  bool isRead;
  MessageStatus status;
  final MessageType messageType;
  final String? mediaUrl;
  final String? replyToMessageId;
  final String? replyToContent;
  final String? replyToSenderName;
  final int? voiceDuration;
  final String? forwardedFrom;
  MessagesController? controller;
  final bool isEdited;
  final MessageType? replyToMessageType;

  // Getters for convenience
  bool get isForwarded => forwardedFrom != null;
  bool get isReply => replyToMessageId != null;
  String? get replyToId => replyToMessageId;

  Message({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.senderName,
    required this.content,
    required this.timestamp,
    this.isRead = false,
    this.status = MessageStatus.sending,
    this.messageType = MessageType.text,
    this.mediaUrl,
    this.replyToMessageId,
    this.replyToContent,
    this.replyToSenderName,
    this.voiceDuration,
    this.forwardedFrom,
    this.controller,
    this.isEdited = false,
    this.replyToMessageType,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    // Handle different timestamp formats
    DateTime timestamp;
    final timestampData = json['timestamp'];
    if (timestampData is Timestamp) {
      timestamp = timestampData.toDate();
    } else if (timestampData is int) {
      // Handle Unix timestamp in milliseconds
      timestamp = DateTime.fromMillisecondsSinceEpoch(timestampData);
    } else if (timestampData is String) {
      try {
        // Try parsing as ISO date string
        timestamp = DateTime.parse(timestampData);
      } catch (e) {
        try {
          // If parsing fails, try converting string to int (milliseconds)
          timestamp =
              DateTime.fromMillisecondsSinceEpoch(int.parse(timestampData));
        } catch (e) {
          // If all parsing attempts fail, use current date as fallback
          print(
              'Failed to parse timestamp: $timestampData. Using current time.');
          timestamp = DateTime.now();
        }
      }
    } else {
      // Default to current time if no valid timestamp
      print(
          'Unsupported timestamp format: $timestampData. Using current time.');
      timestamp = DateTime.now();
    }

    // Convert string status to enum
    MessageStatus messageStatus = MessageStatus.sent;
    if (json.containsKey('status')) {
      final statusStr = json['status'] as String? ?? 'sent';
      switch (statusStr) {
        case 'sending':
          messageStatus = MessageStatus.sending;
          break;
        case 'sent':
          messageStatus = MessageStatus.sent;
          break;
        case 'delivered':
          messageStatus = MessageStatus.delivered;
          break;
        case 'read':
          messageStatus = MessageStatus.read;
          break;
        case 'failed':
          messageStatus = MessageStatus.failed;
          break;
      }
    }

    // Convert message type
    final typeStr = json['messageType'] as String? ?? 'text';
    MessageType type;
    switch (typeStr) {
      case 'image':
        type = MessageType.image;
        break;
      case 'video':
        type = MessageType.video;
        break;
      case 'file':
        type = MessageType.file;
        break;
      case 'location':
        type = MessageType.location;
        break;
      case 'voice':
        type = MessageType.voice;
        break;
      case 'system':
        type = MessageType.system;
        break;
      default:
        type = MessageType.text;
    }

    return Message(
      id: json['id'],
      conversationId: json['conversationId'] ?? '',
      senderId: json['senderId'] ?? '',
      senderName: json['senderName'] ?? 'Unknown',
      content: json['content'] ?? '',
      timestamp: timestamp,
      isRead: json['isRead'] ?? false,
      status: messageStatus,
      messageType: type,
      mediaUrl: json['mediaUrl'],
      replyToMessageId: json['replyToMessageId'],
      replyToContent: json['replyToContent'],
      replyToSenderName: json['replyToSenderName'],
      voiceDuration: json['voiceDuration'],
      forwardedFrom: json['forwardedFrom'],
      controller: null, // Default value for controller
      isEdited: json['isEdited'] ?? false,
      replyToMessageType: json['replyToMessageType'] != null
          ? MessageType.values.firstWhere(
              (e) =>
                  e.toString() == 'MessageType.${json['replyToMessageType']}',
              orElse: () => MessageType.text)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    // Convert enum status to string
    String statusStr;
    switch (status) {
      case MessageStatus.sending:
        statusStr = 'sending';
        break;
      case MessageStatus.sent:
        statusStr = 'sent';
        break;
      case MessageStatus.delivered:
        statusStr = 'delivered';
        break;
      case MessageStatus.read:
        statusStr = 'read';
        break;
      case MessageStatus.failed:
        statusStr = 'failed';
        break;
    }

    // Convert message type to string
    String messageTypeStr;
    switch (messageType) {
      case MessageType.image:
        messageTypeStr = 'image';
        break;
      case MessageType.video:
        messageTypeStr = 'video';
        break;
      case MessageType.file:
        messageTypeStr = 'file';
        break;
      case MessageType.location:
        messageTypeStr = 'location';
        break;
      case MessageType.voice:
        messageTypeStr = 'voice';
        break;
      case MessageType.system:
        messageTypeStr = 'system';
        break;
      default:
        messageTypeStr = 'text';
    }

    return {
      'id': id,
      'conversationId': conversationId,
      'senderId': senderId,
      'senderName': senderName,
      'content': content,
      'timestamp': timestamp,
      'isRead': isRead,
      'status': statusStr,
      'messageType': messageTypeStr,
      'mediaUrl': mediaUrl,
      'replyToMessageId': replyToMessageId,
      'replyToContent': replyToContent,
      'replyToSenderName': replyToSenderName,
      'voiceDuration': voiceDuration,
      'forwardedFrom': forwardedFrom,
      'isEdited': isEdited,
      'replyToMessageType': replyToMessageType?.toString().split('.').last,
    };
  }

  // Add a copyWith method to enable creating copies with some fields changed
  Message copyWith({
    String? id,
    String? conversationId,
    String? senderId,
    String? senderName,
    String? content,
    DateTime? timestamp,
    bool? isRead,
    MessageStatus? status,
    MessageType? messageType,
    String? mediaUrl,
    String? replyToMessageId,
    String? replyToContent,
    String? replyToSenderName,
    int? voiceDuration,
    String? forwardedFrom,
    MessagesController? controller,
    bool? isEdited,
    MessageType? replyToMessageType,
  }) {
    return Message(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
      isRead: isRead ?? this.isRead,
      status: status ?? this.status,
      messageType: messageType ?? this.messageType,
      mediaUrl: mediaUrl,
      replyToMessageId: replyToMessageId ?? this.replyToMessageId,
      replyToContent: replyToContent ?? this.replyToContent,
      replyToSenderName: replyToSenderName ?? this.replyToSenderName,
      voiceDuration: voiceDuration ?? this.voiceDuration,
      forwardedFrom: forwardedFrom ?? this.forwardedFrom,
      controller: controller ?? this.controller,
      isEdited: isEdited ?? this.isEdited,
      replyToMessageType: replyToMessageType ?? this.replyToMessageType,
    );
  }
}
