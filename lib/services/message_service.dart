import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_application_2/ui/pages/messages/models/message.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_application_2/utils/image_path_helper.dart';
import 'package:flutter_application_2/utils/upload_helper.dart';

class MessageService {
  // Mock data for conversations
  final Map<String, List<Message>> _conversationMessages = {};

  // Get messages for a conversation
  Future<List<Message>> getMessages(String conversationId) async {
    // In a real app, this would fetch from an API or database
    return _conversationMessages[conversationId] ?? [];
  }

  // Send a text message
  Future<Message?> sendTextMessage(
    String conversationId,
    String content,
    String senderName,
  ) async {
    try {
      final message = Message(
        id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
        senderId: 'current', // Current user ID
        senderName: senderName,
        content: content,
        timestamp: DateTime.now(),
        messageType: MessageType.text,
        status: MessageStatus.sent,
      );

      // Add to conversation messages
      if (!_conversationMessages.containsKey(conversationId)) {
        _conversationMessages[conversationId] = [];
      }
      _conversationMessages[conversationId]!.add(message);

      return message;
    } catch (e) {
      print('Error sending text message: $e');
      return null;
    }
  }

  /// Uploads an image and returns the URL
  Future<String> uploadImage(dynamic imageSource) async {
    try {
      // Convert uploaded image to data URL to preserve original image
      if (imageSource is File ||
          (imageSource is String && imageSource.startsWith('file://'))) {
        // This is a locally selected file, convert to data URL
        return await UploadHelper.imageToDataUrl(imageSource);
      } else if (imageSource is String && imageSource.startsWith('data:')) {
        // Already a data URL, use as is
        return imageSource;
      } else if (imageSource is String && !imageSource.contains(' ')) {
        // Regular URL without spaces, use as is
        return imageSource;
      } else {
        // For other cases or URLs with spaces, use original approach
        String? imageUrl;

        if (imageSource is String && imageSource.contains(' ')) {
          try {
            // Fix URLs with spaces
            imageUrl = Uri.encodeFull(imageSource);
          } catch (e) {
            // Use a reliable fallback
            imageUrl = 'https://picsum.photos/800/600';
          }
        } else {
          // Use a random image as fallback
          final randomId = DateTime.now().millisecondsSinceEpoch;
          imageUrl = 'https://picsum.photos/seed/$randomId/800/600';
        }

        return ImagePathHelper.getValidImageUrl(imageUrl) ??
            'https://picsum.photos/800/600';
      }
    } catch (e) {
      print('Error uploading image: $e');
      return 'https://picsum.photos/800/600';
    }
  }

  /// Creates a new message with an image
  Future<Message?> sendImageMessage(
    String conversationId,
    dynamic imageSource,
    String caption,
    String senderName,
  ) async {
    try {
      final imageUrl = await uploadImage(imageSource);

      // Create and send the message with the image URL
      final message = Message(
        id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
        senderId: 'current', // Current user
        senderName: senderName, // Add sender name from parameter
        content: caption.isEmpty ? 'Image message' : caption,
        timestamp: DateTime.now(),
        messageType: MessageType.image,
        mediaUrl: imageUrl,
        status: MessageStatus.sent,
      );

      // Add to conversation messages
      if (!_conversationMessages.containsKey(conversationId)) {
        _conversationMessages[conversationId] = [];
      }
      _conversationMessages[conversationId]!.add(message);

      return message;
    } catch (e) {
      print('Error sending image message: $e');
      return null;
    }
  }

  // Delete a message
  Future<bool> deleteMessage(String conversationId, String messageId) async {
    try {
      final messages = _conversationMessages[conversationId];
      if (messages == null) return false;

      final index = messages.indexWhere((m) => m.id == messageId);
      if (index == -1) return false;

      messages.removeAt(index);
      return true;
    } catch (e) {
      print('Error deleting message: $e');
      return false;
    }
  }

  // Edit a message
  Future<Message?> editMessage(
      String conversationId, String messageId, String newContent) async {
    try {
      final messages = _conversationMessages[conversationId];
      if (messages == null) return null;

      final index = messages.indexWhere((m) => m.id == messageId);
      if (index == -1) return null;

      // Create an edited copy of the message
      final oldMessage = messages[index];
      final editedMessage = oldMessage.copyWith(
        content: newContent,
        isEdited: true,
        editedAt: DateTime.now(),
      );

      // Replace the message in the list
      messages[index] = editedMessage;
      return editedMessage;
    } catch (e) {
      print('Error editing message: $e');
      return null;
    }
  }

  // Forward a message to another conversation
  Future<Message?> forwardMessage(
    String sourceMessageId,
    String sourceConversationId,
    String targetConversationId,
    String senderName,
  ) async {
    try {
      // Find the original message
      final sourceMessages = _conversationMessages[sourceConversationId];
      if (sourceMessages == null) return null;

      final sourceMessage = sourceMessages.firstWhere(
        (m) => m.id == sourceMessageId,
        orElse: () => throw Exception('Source message not found'),
      );

      // Create a new forwarded message
      final forwardedMessage = Message(
        id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
        senderId: 'current',
        senderName: senderName,
        content: sourceMessage.content,
        timestamp: DateTime.now(),
        messageType: sourceMessage.messageType,
        mediaUrl: sourceMessage.mediaUrl,
        voiceDuration: sourceMessage.voiceDuration,
        status: MessageStatus.sent,
        forwardedFrom: sourceMessage.senderName,
      );

      // Add to target conversation
      if (!_conversationMessages.containsKey(targetConversationId)) {
        _conversationMessages[targetConversationId] = [];
      }
      _conversationMessages[targetConversationId]!.add(forwardedMessage);

      return forwardedMessage;
    } catch (e) {
      print('Error forwarding message: $e');
      return null;
    }
  }
}
