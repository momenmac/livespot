import 'package:flutter/foundation.dart';
import 'package:flutter_application_2/ui/pages/messages/messages_controller.dart';

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
  final MessageStatus? status; // Only for outgoing messages
  final bool isRead;
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

  // Change from final to allow setting after initialization
  MessagesController? controller; // Reference to the controller

  Message({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.content,
    required this.timestamp,
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
    };
  }

  static Message fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'],
      senderId: json['senderId'],
      senderName: json['senderName'],
      content: json['content'],
      timestamp: json['timestamp'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['timestamp'])
          : DateTime.now(),
      messageType: _parseMessageType(json['messageType']),
      status:
          json['status'] != null ? _parseMessageStatus(json['status']) : null,
      isRead: json['isRead'] ?? false,
      isSent: json['isSent'] ?? true,
      isEdited: json['isEdited'] ?? false,
      mediaUrl: json['mediaUrl'],
      voiceDuration: json['voiceDuration'],
      replyToId: json['replyToId'],
      replyToSenderName: json['replyToSenderName'],
      replyToContent: json['replyToContent'],
      replyToMessageType: json['replyToMessageType'] != null
          ? _parseMessageType(json['replyToMessageType'])
          : null,
      forwardedFrom: json['forwardedFrom'],
      editedAt: json['editedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['editedAt'])
          : null,
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
