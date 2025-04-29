import 'package:flutter_application_2/ui/pages/messages/messages_controller.dart';
import 'package:flutter_application_2/ui/pages/messages/models/message.dart';
import 'package:flutter_application_2/ui/pages/messages/models/user.dart';
import 'package:flutter_application_2/services/api/account/api_urls.dart';

class Conversation {
  final String id;
  final List<User> participants;
  final List<Message> messages;
  final Message lastMessage;
  final int unreadCount;
  final bool isGroup;
  final String? groupName;
  final bool isMuted;
  final bool isArchived;
  MessagesController? controller;

  Conversation({
    required this.id,
    required this.participants,
    required this.messages,
    required this.lastMessage,
    this.unreadCount = 0,
    this.isGroup = false,
    this.groupName,
    this.isMuted = false,
    this.isArchived = false,
    this.controller,
  });

  Conversation copyWith({
    String? id,
    List<User>? participants,
    List<Message>? messages,
    Message? lastMessage,
    int? unreadCount,
    bool? isGroup,
    String? groupName,
    bool? isMuted,
    bool? isArchived,
  }) {
    return Conversation(
      id: id ?? this.id,
      participants: participants ?? this.participants,
      messages: messages ?? this.messages,
      lastMessage: lastMessage ?? this.lastMessage,
      unreadCount: unreadCount ?? this.unreadCount,
      isGroup: isGroup ?? this.isGroup,
      groupName: groupName ?? this.groupName,
      isMuted: isMuted ?? this.isMuted,
      isArchived: isArchived ?? this.isArchived,
      controller: controller,
    );
  }

  String get displayName {
    if (isGroup && groupName != null) return groupName!;
    // Use the actual current user id from the controller if available
    final currentUserId = controller?.currentUserId ?? 'current';
    final otherParticipants =
        participants.where((p) => p.id != currentUserId).toList();
    if (otherParticipants.isEmpty) return "Me";
    if (otherParticipants.length == 1) {
      return otherParticipants.first.name;
    } else {
      return otherParticipants.map((p) => p.name).join(", ");
    }
  }

  String get avatarUrl {
    if (isGroup) {
      return "https://ui-avatars.com/api/?name=${Uri.encodeComponent(groupName ?? "Group")}&background=random";
    }
    final currentUserId = controller?.currentUserId ?? 'current';
    final otherParticipants =
        participants.where((p) => p.id != currentUserId).toList();
    if (otherParticipants.isEmpty) return "";
    final url = otherParticipants.first.avatarUrl;
    // Always return a fully qualified URL for avatars
    if (url.isEmpty) return "";
    if (url.startsWith('http')) return url;
    final fixedUrl = url.startsWith('/') ? url : '/$url';
    return '${ApiUrls.baseUrl}$fixedUrl';
  }

  bool get isOnline {
    if (isGroup) return false;
    final currentUserId = controller?.currentUserId ?? 'current';
    final otherParticipants =
        participants.where((p) => p.id != currentUserId).toList();
    if (otherParticipants.isEmpty) return false;
    return otherParticipants.first.isOnline;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'participants': participants.map((p) => p.id).toList(),
      'lastMessage': lastMessage.toJson(),
      'unreadCount': unreadCount,
      'isGroup': isGroup,
      'groupName': groupName,
      'isMuted': isMuted,
      'isArchived': isArchived,
      'updatedAt': lastMessage.timestamp.millisecondsSinceEpoch,
    };
  }

  // Firestore integration for Conversation
  static Conversation fromFirestore(
      Map<String, dynamic> doc, List<User> users) {
    // users: list of all users, so we can match participant ids to User objects
    final participantIds = List<String>.from(doc['participants'] ?? []);
    final participants =
        users.where((u) => participantIds.contains(u.id)).toList();

    return Conversation(
      id: doc['id'],
      participants: participants,
      messages: [], // You should fetch messages from the messages collection
      lastMessage: Message.fromJson(doc['lastMessage'] ?? {}),
      unreadCount: doc['unreadCount'] ?? 0,
      isGroup: doc['isGroup'] ?? false,
      groupName: doc['groupName'],
      isMuted: doc['isMuted'] ?? false,
      isArchived: doc['isArchived'] ?? false,
    );
  }
}

// --- FIRESTORE STRUCTURE SUGGESTION ---
//
// Collection: conversations
//   - id: string (Firestore document id)
//   - participants: [userId1, userId2, ...]
//   - isGroup: bool
//   - groupName: string (nullable)
//   - lastMessage: Map (see Message.toJson())
//   - unreadCount: int
//   - isMuted: bool
//   - isArchived: bool
//   - updatedAt: timestamp (for sorting)
//
// Collection: messages (subcollection under each conversation)
//   conversations/{conversationId}/messages/{messageId}
//   - id: string
//   - senderId: string
//   - senderName: string
//   - content: string
//   - timestamp: int (millisecondsSinceEpoch)
//   - messageType: string
//   - status: string
//   - isRead: bool
//   - isSent: bool
//   - isEdited: bool
//   - mediaUrl: string
//   - voiceDuration: int
//   - replyToId: string
//   - replyToSenderName: string
//   - replyToContent: string
//   - replyToMessageType: string
//   - forwardedFrom: string
//   - editedAt: int
//
// Collection: users
//   - id: string
//   - name: string
//   - email: string
//   - avatarUrl: string
//   - isOnline: bool
