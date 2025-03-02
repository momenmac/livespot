import 'package:flutter_application_2/ui/pages/messages/models/message.dart';

/// Utility class to transform data between app models and Firebase formats
class FirebaseTransformer {
  /// Transform message status from string to enum
  static MessageStatus messageStatusFromString(String? status) {
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

  /// Transform message status from enum to string
  static String messageStatusToString(MessageStatus status) {
    switch (status) {
      case MessageStatus.sending:
        return 'sending';
      case MessageStatus.sent:
        return 'sent';
      case MessageStatus.delivered:
        return 'delivered';
      case MessageStatus.read:
        return 'read';
      case MessageStatus.failed:
        return 'failed';
    }
  }

  /// Transform message type from string to enum
  static MessageType messageTypeFromString(String? type) {
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

  /// Transform message type from enum to string
  static String messageTypeToString(MessageType type) {
    switch (type) {
      case MessageType.text:
        return 'text';
      case MessageType.voice:
        return 'voice';
      case MessageType.image:
        return 'image';
      case MessageType.video:
        return 'video';
      case MessageType.file:
        return 'file';
    }
  }

  /// When Firestore is integrated, uncommment this code:
  ///
  /// ```dart
  /// /// Convert Firestore timestamp to DateTime
  /// static DateTime? timestampToDateTime(dynamic timestamp) {
  ///   if (timestamp == null) return null;
  ///
  ///   if (timestamp is Timestamp) {
  ///     return timestamp.toDate();
  ///   } else if (timestamp is int) {
  ///     return DateTime.fromMillisecondsSinceEpoch(timestamp);
  ///   }
  ///
  ///   return null;
  /// }
  /// ```
}
