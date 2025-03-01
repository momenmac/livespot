import 'package:flutter_application_2/ui/pages/messages/messages_controller.dart';
import 'package:flutter_application_2/ui/pages/messages/models/message.dart';
import 'package:flutter_application_2/ui/pages/messages/models/user.dart';

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
  // Add reference to controller to maintain state
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
      controller: controller, // Preserve the controller reference
    );
  }

  // Get the conversation display name based on participants
  String get displayName {
    if (isGroup && groupName != null) return groupName!;

    // Filter out the current user and get the other participants
    final otherParticipants =
        participants.where((p) => p.id != 'current').toList();

    if (otherParticipants.isEmpty) return "Me";

    if (otherParticipants.length == 1) {
      return otherParticipants.first.name;
    } else {
      return otherParticipants.map((p) => p.name).join(", ");
    }
  }

  // Get the avatar URL for display
  String get avatarUrl {
    if (isGroup) {
      return "https://ui-avatars.com/api/?name=${Uri.encodeComponent(groupName ?? "Group")}&background=random";
    }

    final otherParticipants =
        participants.where((p) => p.id != 'current').toList();

    if (otherParticipants.isEmpty) return "";

    return otherParticipants.first.avatarUrl;
  }

  // Get online status
  bool get isOnline {
    if (isGroup) return false;

    final otherParticipants =
        participants.where((p) => p.id != 'current').toList();

    if (otherParticipants.isEmpty) return false;

    return otherParticipants.first.isOnline;
  }

  // Convert to map for Firestore
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

  // Create from Firestore document
  static Future<Conversation> fromFirestore(Map<String, dynamic> doc) async {
    // TODO: Implement when integrating with Firebase
    throw UnimplementedError("Firebase integration not implemented yet");
  }
}
