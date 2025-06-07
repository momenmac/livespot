import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../api/account/api_urls.dart';
import '../auth/token_manager.dart';
import '../auth/session_manager.dart';
import 'notification_types.dart';

/// Service for sending message notifications directly via FCM without database storage
class MessageNotificationService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final TokenManager _tokenManager = TokenManager();
  static final SessionManager _sessionManager = SessionManager();

  /// Send a message notification to conversation participants
  static Future<void> sendMessageNotification({
    required String messageId,
    required String conversationId,
    required String messageContent,
    required String messageType,
    required List<String> participantIds,
    required String senderName,
    String? senderAvatar,
  }) async {
    print('🚀 [MessageNotification] Starting notification send process');
    print(
        '🚀 [MessageNotification] ConversationId: $conversationId, MessageId: $messageId');
    print(
        '🚀 [MessageNotification] Participants: $participantIds, Sender: $senderName');

    try {
      // Use Django authentication instead of Firebase Auth
      if (!_sessionManager.isAuthenticated) {
        print(
            '❌ [MessageNotification] No authenticated user (Django session) for sending message notification');
        return;
      }

      final currentUser = _sessionManager.user;
      if (currentUser == null) {
        print(
            '❌ [MessageNotification] Failed to get current user data from Django session');
        return;
      }

      final senderId = currentUser.id.toString();
      print('🚀 [MessageNotification] Current user ID: $senderId');

      // Filter out the sender from participants (don't send notification to yourself)
      final recipientIds =
          participantIds.where((id) => id != senderId).toList();

      if (recipientIds.isEmpty) {
        print(
            '⚠️ [MessageNotification] No recipients for message notification (all participants filtered out)');
        return;
      }

      print(
          '📤 [MessageNotification] Sending message notification to ${recipientIds.length} recipients: $recipientIds');

      // Create notification data
      final messageNotificationData = MessageNotificationData(
        messageId: messageId,
        conversationId: conversationId,
        fromUserId: senderId,
        fromUserName: senderName,
        fromUserAvatar: senderAvatar ?? '',
        messageContent: messageContent,
        messageType: messageType,
        title: senderName,
        body: _formatMessageBody(messageContent, messageType),
        timestamp: DateTime.now(),
        additionalData: {
          'click_action': 'FLUTTER_NOTIFICATION_CLICK',
          'conversation_id': conversationId,
          'message_id': messageId,
        },
      );

      // Send notification to each recipient via Django backend
      for (final recipientId in recipientIds) {
        print('🔄 [MessageNotification] Sending to recipient: $recipientId');
        await _sendNotificationToUser(recipientId, messageNotificationData);
      }

      print('✅ [MessageNotification] Message notifications sent successfully');
    } catch (e, stackTrace) {
      print('❌ [MessageNotification] Error sending message notification: $e');
      print('❌ [MessageNotification] Stack trace: $stackTrace');
    }
  }

  /// Send notification to a specific user via Django backend
  static Future<void> _sendNotificationToUser(
    String userId,
    MessageNotificationData notificationData,
  ) async {
    print(
        '🔄 [MessageNotification] _sendNotificationToUser called for user: $userId');

    try {
      if (!_tokenManager.isAuthenticated) {
        print(
            '⚠️ [MessageNotification] User not authenticated, cannot send notification');
        return;
      }

      print('🔄 [MessageNotification] Getting access token...');
      final accessToken = await _tokenManager.getValidAccessToken();
      if (accessToken == null) {
        print('⚠️ [MessageNotification] Failed to get valid access token');
        return;
      }

      print('✅ [MessageNotification] Got access token, preparing request...');

      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      };

      final body = jsonEncode({
        'recipient_user_id': userId,
        'notification_type': 'message',
        'title': notificationData.title,
        'body': notificationData.body,
        'data': notificationData.toMap(),
        'priority': 'high', // Messages should be high priority
        'android': {
          'notification': {
            'channel_id': 'messages',
            'group_key': 'message_group_${notificationData.conversationId}',
            'group_summary': false,
            'tag':
                'message_${notificationData.conversationId}_${notificationData.messageId}',
            'actions': [
              {
                'action': 'reply',
                'title': 'Reply',
                'icon': 'ic_reply',
              },
              {
                'action': 'mark_read',
                'title': 'Mark as Read',
                'icon': 'ic_check',
              }
            ]
          }
        },
        'apns': {
          'payload': {
            'aps': {
              'category': 'MESSAGE_CATEGORY',
              'thread-id': notificationData.conversationId,
            }
          }
        }
      });

      print(
          '🔄 [MessageNotification] Making HTTP request to: ${ApiUrls.baseUrl}/api/notifications/actions/send-direct/');
      print('🔄 [MessageNotification] Request body: $body');

      final response = await http.post(
        Uri.parse('${ApiUrls.baseUrl}/api/notifications/actions/send-direct/'),
        headers: headers,
        body: body,
      );

      print('📨 [MessageNotification] Response status: ${response.statusCode}');
      print('📨 [MessageNotification] Response body: ${response.body}');

      if (response.statusCode == 200) {
        print(
            '✅ [MessageNotification] Message notification sent to user: $userId');
      } else {
        print(
            '❌ [MessageNotification] Failed to send message notification to user $userId: ${response.statusCode}');
        print('❌ [MessageNotification] Response: ${response.body}');
      }
    } catch (e, stackTrace) {
      print(
          '❌ [MessageNotification] Error sending notification to user $userId: $e');
      print('❌ [MessageNotification] Stack trace: $stackTrace');
    }
  }

  /// Format message body for notification display
  static String _formatMessageBody(String content, String messageType) {
    switch (messageType.toLowerCase()) {
      case 'image':
        return '📷 Sent a photo';
      case 'file':
        return '📎 Sent a file';
      case 'voice':
        return '🎤 Sent a voice message';
      case 'video':
        return '🎥 Sent a video';
      default:
        // For text messages, truncate if too long
        if (content.length > 50) {
          return '${content.substring(0, 47)}...';
        }
        return content;
    }
  }

  /// Get conversation participants from Firestore
  static Future<List<String>> getConversationParticipants(
      String conversationId) async {
    try {
      final conversationDoc = await _firestore
          .collection('conversations')
          .doc(conversationId)
          .get();

      if (!conversationDoc.exists) {
        print('❌ Conversation not found: $conversationId');
        return [];
      }

      final data = conversationDoc.data();
      if (data == null || !data.containsKey('participants')) {
        print('❌ No participants found in conversation: $conversationId');
        return [];
      }

      final participants = data['participants'] as List<dynamic>?;
      if (participants == null) return [];

      // Extract user IDs from participant objects
      final participantIds = participants
          .map((participant) {
            if (participant is Map<String, dynamic>) {
              return participant['id'] as String?;
            }
            return participant as String?;
          })
          .where((id) => id != null)
          .cast<String>()
          .toList();

      print('📋 Found ${participantIds.length} participants in conversation');
      return participantIds;
    } catch (e) {
      print('❌ Error getting conversation participants: $e');
      return [];
    }
  }
}
