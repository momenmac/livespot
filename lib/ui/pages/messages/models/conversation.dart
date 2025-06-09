import 'package:flutter_application_2/ui/pages/messages/messages_controller.dart';
import 'package:flutter_application_2/ui/pages/messages/models/message.dart';
import 'package:flutter_application_2/ui/pages/messages/models/user.dart';
import 'package:flutter_application_2/services/api/account/api_urls.dart';

class Conversation {
  final String id;
  final List<User> participants;
  final String? groupName;
  final bool isGroup;
  bool isArchived; // Changed from final to mutable
  bool isMuted; // Changed from final to mutable
  int unreadCount;
  final List<Message> messages;
  Message _lastMessage;

  Conversation({
    required this.id,
    required this.participants,
    required Message lastMessage,
    this.groupName,
    this.isGroup = false,
    this.isArchived = false,
    this.isMuted = false,
    this.unreadCount = 0,
    List<Message>? messages,
  })  : _lastMessage = lastMessage,
        messages = messages ?? [];

  // Adding setter for lastMessage
  set lastMessage(Message message) {
    _lastMessage = message;
  }

  // We already have a setter for lastMessage, now add a getter
  Message get lastMessage => _lastMessage;

  // Virtual property for pinning - can be overridden in subclasses
  bool get isPinned => false;

  // Instead of storing the controller, we'll provide a getter that gets it from context when needed
  MessagesController? get controller =>
      null; // This will be handled by the widget tree

  // Safely get members excluding the current user
  List<User> getMembersExcludingCurrentUser(String currentUserId) {
    return participants.where((user) => user.id != currentUserId).toList();
  }

  // Create a copy with potentially different values
  Conversation copyWith({
    String? id,
    List<User>? participants,
    String? groupName,
    bool? isGroup,
    bool? isArchived,
    bool? isMuted,
    int? unreadCount,
    List<Message>? messages,
    Message? lastMessage,
    MessagesController? controller,
  }) {
    return Conversation(
      id: id ?? this.id,
      participants: participants ?? this.participants,
      groupName: groupName ?? this.groupName,
      isGroup: isGroup ?? this.isGroup,
      isArchived: isArchived ?? this.isArchived,
      isMuted: isMuted ?? this.isMuted,
      unreadCount: unreadCount ?? this.unreadCount,
      messages: messages ?? this.messages,
      lastMessage: lastMessage ?? _lastMessage,
    );
  }

  String get displayName {
    if (isGroup && groupName != null) return groupName!;
    final currentUserId = controller?.currentUserId ?? 'current';
    final otherParticipants = getMembersExcludingCurrentUser(currentUserId);
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
    final otherParticipants = getMembersExcludingCurrentUser(currentUserId);
    if (otherParticipants.isEmpty) return "";
    final url = otherParticipants.first.avatarUrl;
    if (url.isEmpty) return "";
    if (url.startsWith('http')) return url;
    final fixedUrl = url.startsWith('/') ? url : '/$url';
    return '${ApiUrls.baseUrl}$fixedUrl';
  }

  bool get isOnline {
    if (isGroup) return false;
    final currentUserId = controller?.currentUserId ?? 'current';
    final otherParticipants = getMembersExcludingCurrentUser(currentUserId);
    if (otherParticipants.isEmpty) return false;
    return otherParticipants.first.isOnline;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'participants': participants.map((p) => p.id).toList(),
      'lastMessage': _lastMessage.toJson(),
      'unreadCount': unreadCount,
      'isGroup': isGroup,
      'groupName': groupName,
      'isMuted': isMuted,
      'isArchived': isArchived,
      'updatedAt': _lastMessage.timestamp.millisecondsSinceEpoch,
    };
  }

  static Conversation fromFirestore(
      Map<String, dynamic> doc, List<User> users) {
    final participantIds = List<String>.from(doc['participants'] ?? []);
    final participants =
        users.where((u) => participantIds.contains(u.id)).toList();

    return Conversation(
      id: doc['id'],
      participants: participants,
      messages: [],
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
