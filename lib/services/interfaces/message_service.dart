import 'dart:io';
import 'package:flutter_application_2/ui/pages/messages/models/conversation.dart';
import 'package:flutter_application_2/ui/pages/messages/models/message.dart';
import 'package:flutter_application_2/ui/pages/messages/models/user.dart';

/// Interface for database-agnostic message operations.
/// This abstraction allows switching between Firebase, REST APIs, or any other data source
abstract class MessageServiceInterface {
  /// Get the current user ID
  String get currentUserId;

  /// Stream of conversations for real-time updates
  Stream<List<Conversation>> getConversationsStream();

  /// Fetch conversations for the current user
  Future<List<Conversation>> getConversations();

  /// Get messages for a specific conversation
  Future<List<Message>> getMessages(String conversationId, {int limit = 50});

  /// Stream of messages for real-time updates
  Stream<List<Message>> getMessagesStream(String conversationId,
      {int limit = 50});

  /// Send a text message
  Future<Message> sendTextMessage({
    required String conversationId,
    required String content,
    String? replyToId,
  });

  /// Send a voice message
  Future<Message> sendVoiceMessage({
    required String conversationId,
    required File audioFile,
    required int durationSeconds,
  });

  /// Update a message (e.g. edit text)
  Future<void> updateMessage({
    required String conversationId,
    required Message message,
  });

  /// Delete a message
  Future<void> deleteMessage({
    required String conversationId,
    required String messageId,
  });

  /// Create a new conversation
  Future<Conversation> createConversation({
    required List<String> participantIds,
    String? groupName,
    bool isGroup = false,
  });

  /// Mark a conversation as read
  Future<void> markConversationAsRead(String conversationId);

  /// Mark a conversation as unread
  Future<void> markConversationAsUnread(String conversationId);

  /// Toggle archive status of a conversation
  Future<void> setConversationArchiveStatus({
    required String conversationId,
    required bool isArchived,
  });

  /// Toggle mute status of a conversation
  Future<void> setConversationMuteStatus({
    required String conversationId,
    required bool isMuted,
  });

  /// Delete an entire conversation
  Future<void> deleteConversation(String conversationId);

  /// Search for users
  Future<List<User>> searchUsers(String query);

  /// Set up user's online presence monitoring
  Future<void> setupPresenceMonitoring();

  /// Cleanup resources
  Future<void> dispose();
}
