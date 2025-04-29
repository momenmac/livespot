import 'package:flutter_application_2/ui/pages/messages/messages_controller.dart';
import 'package:uuid/uuid.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Add this import for Timestamp

enum MessageType {
  text,
  voice,
  image,
  video,
  file,
}

enum MessageStatus {
  sending,
  sent,
  delivered,
  read,
  failed,
}

class Message {
  final String id;
  final String senderId;
  final String senderName;
  final String content;
  final DateTime timestamp;
  final MessageType messageType;
  late final MessageStatus? status; // Only for outgoing messages
  bool isRead; // Make mutable for marking as read
  final bool isSent;
  final bool isEdited;
  final String? mediaUrl; // URL for voice messages, images, etc.
  final int? voiceDuration; // Duration in seconds for voice messages
  final String? replyToId; // ID of the message this is replying to
  final String? replyToSenderName; // Name of the sender of the replied message
  final String? replyToContent; // Content of the replied message
  final MessageType? replyToMessageType; // Type of the replied message
  final String? forwardedFrom; // Name of the original sender if forwarded
  final DateTime? editedAt; // When the message was last edited
  final String conversationId; // Add conversationId field
  MessagesController? controller; // Reference to the controller

  Message({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.content,
    required this.timestamp,
    required this.conversationId, // Make conversationId required
    this.messageType = MessageType.text,
    this.status,
    this.isRead = false,
    this.isSent = true,
    this.isEdited = false,
    this.mediaUrl,
    this.voiceDuration,
    this.replyToId,
    this.replyToSenderName,
    this.replyToContent,
    this.replyToMessageType,
    this.forwardedFrom,
    this.editedAt,
    this.controller,
  });

  bool get isReply => replyToId != null;
  bool get isForwarded => forwardedFrom != null;
  bool get isMedia => messageType != MessageType.text;
  bool get isVoice => messageType == MessageType.voice;

  // Create a copy with potentially different values
  Message copyWith({
    String? id,
    String? senderId,
    String? senderName,
    String? content,
    DateTime? timestamp,
    MessageType? messageType,
    MessageStatus? status,
    bool? isRead,
    bool? isSent,
    bool? isEdited,
    String? mediaUrl,
    int? voiceDuration,
    String? replyToId,
    String? replyToSenderName,
    String? replyToContent,
    MessageType? replyToMessageType,
    String? forwardedFrom,
    DateTime? editedAt,
    String? conversationId,
    MessagesController? controller,
  }) {
    return Message(
      id: id ?? this.id,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
      messageType: messageType ?? this.messageType,
      status: status ?? this.status,
      isRead: isRead ?? this.isRead,
      isSent: isSent ?? this.isSent,
      isEdited: isEdited ?? this.isEdited,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      voiceDuration: voiceDuration ?? this.voiceDuration,
      replyToId: replyToId ?? this.replyToId,
      replyToSenderName: replyToSenderName ?? this.replyToSenderName,
      replyToContent: replyToContent ?? this.replyToContent,
      replyToMessageType: replyToMessageType ?? this.replyToMessageType,
      forwardedFrom: forwardedFrom ?? this.forwardedFrom,
      editedAt: editedAt ?? this.editedAt,
      conversationId: conversationId ?? this.conversationId,
      controller: controller ?? this.controller,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'senderId': senderId,
      'senderName': senderName,
      'content': content,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'messageType': messageType.toString().split('.').last,
      'status': status?.toString().split('.').last,
      'isRead': isRead,
      'isSent': isSent,
      'isEdited': isEdited,
      'mediaUrl': mediaUrl,
      'voiceDuration': voiceDuration,
      'replyToId': replyToId,
      'replyToSenderName': replyToSenderName,
      'replyToContent': replyToContent,
      'replyToMessageType': replyToMessageType?.toString().split('.').last,
      'forwardedFrom': forwardedFrom,
      'editedAt': editedAt?.millisecondsSinceEpoch,
      'conversationId': conversationId,
    };
  }

  static Message fromJson(Map<String, dynamic> json) {
    int timestampMillis;
    if (json['timestamp'] is int) {
      timestampMillis = json['timestamp'];
    } else if (json['timestamp'] is String) {
      try {
        timestampMillis =
            DateTime.parse(json['timestamp']).millisecondsSinceEpoch;
      } catch (_) {
        try {
          timestampMillis = int.parse(json['timestamp']);
        } catch (_) {
          timestampMillis = DateTime.now().millisecondsSinceEpoch;
        }
      }
    } else if (json['timestamp'] is Timestamp) {
      // Now Timestamp is properly imported from cloud_firestore
      timestampMillis =
          (json['timestamp'] as Timestamp).toDate().millisecondsSinceEpoch;
    } else {
      timestampMillis = DateTime.now().millisecondsSinceEpoch;
    }

    DateTime? editedAt;
    if (json['editedAt'] is int) {
      editedAt = DateTime.fromMillisecondsSinceEpoch(json['editedAt']);
    } else if (json['editedAt'] is String) {
      try {
        editedAt = DateTime.parse(json['editedAt']);
      } catch (_) {
        editedAt = null;
      }
    } else if (json['editedAt'] is Timestamp) {
      // Now Timestamp is properly imported from cloud_firestore
      editedAt = (json['editedAt'] as Timestamp).toDate();
    }

    return Message(
      id: json['id'] ?? const Uuid().v4(),
      senderId: json['senderId'] ?? '',
      senderName: json['senderName'] ?? 'Unknown',
      content: json['content'] ?? '',
      timestamp: DateTime.fromMillisecondsSinceEpoch(timestampMillis),
      messageType: _parseMessageType(json['messageType']),
      status: json['status'] != null
          ? _parseMessageStatus(json['status'].toString())
          : null,
      isRead: json['isRead'] ?? false,
      isSent: json['isSent'] ?? true,
      isEdited: json['isEdited'] ?? false,
      mediaUrl: json['mediaUrl'],
      voiceDuration: json['voiceDuration'],
      replyToId: json['replyToId'],
      replyToSenderName: json['replyToSenderName'],
      replyToContent: json['replyToContent'],
      replyToMessageType: json['replyToMessageType'] != null
          ? _parseMessageType(json['replyToMessageType'].toString())
          : null,
      forwardedFrom: json['forwardedFrom'],
      editedAt: editedAt,
      conversationId: json['conversationId'] ?? '',
    );
  }

  static MessageType _parseMessageType(String? type) {
    switch (type) {
      case 'text':
        return MessageType.text;
      case 'voice':
        return MessageType.voice;
      case 'image':
        return MessageType.image;
      case 'video':
        return MessageType.video;
      case 'file':
        return MessageType.file;
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
      case 'failed':
        return MessageStatus.failed;
      default:
        return MessageStatus.sending;
    }
  }
}
