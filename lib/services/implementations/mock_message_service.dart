import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter_application_2/services/interfaces/message_service.dart';
import 'package:flutter_application_2/ui/pages/messages/models/conversation.dart';
import 'package:flutter_application_2/ui/pages/messages/models/message.dart';
import 'package:flutter_application_2/ui/pages/messages/models/user.dart';

/// Mock implementation of MessageServiceInterface for development and testing
///
/// This implementation stores all data in memory and simulates network delays
/// for a more realistic experience. No external database is required.
class MockMessageService implements MessageServiceInterface {
  // In-memory data store
  final List<User> _users = [];
  final List<Conversation> _conversations = [];
  final Map<String, List<Message>> _messages = {};

  // Stream controllers for real-time updates
  final StreamController<List<Conversation>> _conversationsController =
      StreamController<List<Conversation>>.broadcast();

  final Map<String, StreamController<List<Message>>> _messageControllers = {};

  // Current user
  final User _currentUser;
  final Random _random = Random();

  MockMessageService()
      : _currentUser = User(
          id: 'current',
          name: 'Current User',
          avatarUrl: 'https://ui-avatars.com/api/?name=Current+User',
          isOnline: true,
        ) {
    _initMockData();
  }

  void _initMockData() {
    // Generate mock users
    _users.add(_currentUser);

    for (int i = 1; i <= 20; i++) {
      _users.add(User(
        id: 'user$i',
        name: 'User $i',
        avatarUrl: 'https://ui-avatars.com/api/?name=User+$i',
        isOnline: _random.nextBool(),
      ));
    }

    // Generate mock conversations
    for (int i = 1; i <= 15; i++) {
      // Create participant list (1-1 or group)
      final isGroup = i % 5 == 0;
      List<User> participants = [_currentUser];

      if (isGroup) {
        // Add 3-5 users for group conversations
        final groupSize = 3 + _random.nextInt(3);
        for (int j = 0; j < groupSize; j++) {
          final randomUserId = 'user${1 + _random.nextInt(20)}';
          final user = _users.firstWhere((u) => u.id == randomUserId,
              orElse: () => _users[1]);

          if (!participants.any((p) => p.id == user.id)) {
            participants.add(user);
          }
        }
      } else {
        // Add just one user for 1-1 conversations
        participants.add(_users[i % _users.length]);
      }

      // Create conversation ID
      final conversationId = 'conv$i';

      // Generate messages for this conversation
      final messages = _generateMockMessages(
        conversationId: conversationId,
        participants: participants,
        count: 20 + _random.nextInt(30),
      );

      // Store messages
      _messages[conversationId] = messages;

      // Create conversation object
      final conversation = Conversation(
        id: conversationId,
        participants: participants,
        messages: messages,
        lastMessage: messages.isNotEmpty
            ? messages.first
            : Message(
                id: 'empty',
                senderId: '',
                senderName: '',
                content: 'No messages',
                timestamp: DateTime.now(),
              ),
        unreadCount: _random.nextInt(5), // Random unread count
        isGroup: isGroup,
        groupName: isGroup ? 'Group $i' : null,
        isMuted: _random.nextBool() &&
            _random.nextInt(5) == 0, // 20% chance of being muted
        isArchived: _random.nextBool() &&
            _random.nextInt(10) == 0, // 10% chance of being archived
      );

      _conversations.add(conversation);

      // Create a message controller for this conversation
      _messageControllers[conversationId] =
          StreamController<List<Message>>.broadcast();
      _messageControllers[conversationId]!.add(messages);
    }

    // Sort conversations by last message timestamp
    _sortConversations();

    // Emit initial conversations data
    _conversationsController.add(_conversations);
  }

  // Generate mock messages for a conversation
  List<Message> _generateMockMessages(
      {required String conversationId,
      required List<User> participants,
      required int count}) {
    final messages = <Message>[];
    final now = DateTime.now();

    for (int i = 0; i < count; i++) {
      // Determine sender (50% chance it's the current user)
      final isFromCurrentUser = _random.nextBool();
      final sender = isFromCurrentUser
          ? _currentUser
          : participants.where((p) => p.id != _currentUser.id).toList()[
              _random.nextInt(
                  participants.where((p) => p.id != _currentUser.id).length)];

      // Message timestamp (older as i increases)
      final messageTime = now.subtract(Duration(
          minutes: i * 5 + _random.nextInt(10), seconds: _random.nextInt(60)));

      // Occasionally add a voice message
      final isVoiceMessage = _random.nextInt(10) == 0; // 10% chance

      if (isVoiceMessage) {
        messages.add(Message(
          id: '${conversationId}_msg$i',
          senderId: sender.id,
          senderName: sender.name,
          content: 'Voice message',
          timestamp: messageTime,
          messageType: MessageType.voice,
          voiceDuration: 5 + _random.nextInt(55), // 5-60 seconds
          status: isFromCurrentUser
              ? MessageStatus.values[_random.nextInt(3)]
              : null,
          isRead: _random.nextBool(),
        ));
      } else {
        // Text message
        final messageContent = isFromCurrentUser
            ? "This is message #$i from me. ${_loremText(_random.nextInt(20) + 10)}"
            : "Message #$i from ${sender.name}. ${_loremText(_random.nextInt(20) + 10)}";

        // Occasionally make it a reply
        final isReply = i > 5 &&
            _random.nextInt(10) == 0; // 10% chance for messages after the 5th

        if (isReply && messages.isNotEmpty) {
          final repliedToMessage = messages[_random.nextInt(messages.length)];

          messages.add(Message(
            id: '${conversationId}_msg$i',
            senderId: sender.id,
            senderName: sender.name,
            content: messageContent,
            timestamp: messageTime,
            status: isFromCurrentUser
                ? MessageStatus.values[_random.nextInt(3)]
                : null,
            isRead: _random.nextBool(),
            replyToId: repliedToMessage.id,
            replyToSenderName: repliedToMessage.senderName,
            replyToContent: repliedToMessage.content,
            replyToMessageType: repliedToMessage.messageType,
          ));
        } else {
          messages.add(Message(
            id: '${conversationId}_msg$i',
            senderId: sender.id,
            senderName: sender.name,
            content: messageContent,
            timestamp: messageTime,
            status: isFromCurrentUser
                ? MessageStatus.values[_random.nextInt(3)]
                : null,
            isRead: _random.nextBool(),
          ));
        }
      }
    }

    // Sort by timestamp (newest first)
    messages.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    return messages;
  }

  // Helper to generate lorem ipsum text of approximate word count
  String _loremText(int wordCount) {
    const loremWords = [
      'lorem',
      'ipsum',
      'dolor',
      'sit',
      'amet',
      'consectetur',
      'adipiscing',
      'elit',
      'sed',
      'do',
      'eiusmod',
      'tempor',
      'incididunt',
      'ut',
      'labore',
      'et',
      'dolore',
      'magna',
      'aliqua',
      'ut',
      'enim',
      'ad',
      'minim',
      'veniam',
      'quis',
      'nostrud',
      'exercitation',
      'ullamco',
      'laboris',
      'nisi',
      'ut',
      'aliquip',
      'ex',
      'ea',
      'commodo',
      'consequat'
    ];

    final result = <String>[];
    for (int i = 0; i < wordCount; i++) {
      result.add(loremWords[_random.nextInt(loremWords.length)]);
    }

    // Capitalize first word and add period at end
    if (result.isNotEmpty) {
      result[0] = result[0][0].toUpperCase() + result[0].substring(1);
      result[result.length - 1] = '${result[result.length - 1]}.';
    }

    return result.join(' ');
  }

  void _sortConversations() {
    _conversations.sort(
        (a, b) => b.lastMessage.timestamp.compareTo(a.lastMessage.timestamp));
  }

  // Simulate network delay
  Future<void> _delay({int minMs = 100, int maxMs = 500}) async {
    final delay = minMs + _random.nextInt(maxMs - minMs);
    await Future.delayed(Duration(milliseconds: delay));
  }

  @override
  String get currentUserId => _currentUser.id;

  @override
  Stream<List<Conversation>> getConversationsStream() {
    // Return the stream
    return _conversationsController.stream;
  }

  @override
  Future<List<Conversation>> getConversations() async {
    await _delay();
    return _conversations;
  }

  @override
  Future<List<Message>> getMessages(String conversationId,
      {int limit = 50}) async {
    await _delay();
    return _messages[conversationId] ?? [];
  }

  @override
  Stream<List<Message>> getMessagesStream(String conversationId,
      {int limit = 50}) {
    if (!_messageControllers.containsKey(conversationId)) {
      _messageControllers[conversationId] =
          StreamController<List<Message>>.broadcast();

      // Send initial data if we have it
      if (_messages.containsKey(conversationId)) {
        _messageControllers[conversationId]!.add(_messages[conversationId]!);
      } else {
        _messageControllers[conversationId]!.add([]);
      }
    }

    return _messageControllers[conversationId]!.stream;
  }

  @override
  Future<Message> sendTextMessage({
    required String conversationId,
    required String content,
    String? replyToId,
  }) async {
    // Simulate delay
    await _delay();

    final conversation = _conversations.firstWhere(
      (c) => c.id == conversationId,
      orElse: () => throw Exception('Conversation not found'),
    );

    // Create new message
    final newMessageId =
        '${conversationId}_${DateTime.now().millisecondsSinceEpoch}';

    Message? replyToMessage;
    if (replyToId != null && _messages.containsKey(conversationId)) {
      replyToMessage = _messages[conversationId]!.firstWhere(
        (m) => m.id == replyToId,
        orElse: () => throw Exception('Reply message not found'),
      );
    }

    final newMessage = Message(
      id: newMessageId,
      senderId: _currentUser.id,
      senderName: _currentUser.name,
      content: content,
      timestamp: DateTime.now(),
      status: MessageStatus.sending,
      isRead: false,
      replyToId: replyToId,
      replyToSenderName: replyToMessage?.senderName,
      replyToContent: replyToMessage?.content,
      replyToMessageType: replyToMessage?.messageType,
    );

    // Update our in-memory data
    _messages[conversationId] = [
      newMessage,
      ...(_messages[conversationId] ?? [])
    ];

    // Update conversation
    final updatedConversation = conversation.copyWith(
      messages: _messages[conversationId]!,
      lastMessage: newMessage,
      unreadCount: 0, // Reset unread for current user
    );

    // Update in our lists
    final index = _conversations.indexWhere((c) => c.id == conversationId);
    if (index != -1) {
      _conversations[index] = updatedConversation;
    }

    _sortConversations();

    // Emit updated conversations & messages
    _conversationsController.add(_conversations);
    _messageControllers[conversationId]?.add(_messages[conversationId]!);

    // Simulate message status progression
    _simulateMessageStatusUpdates(conversationId, newMessage);

    return newMessage;
  }

  // Simulate message going from sending -> sent -> delivered -> read
  Future<void> _simulateMessageStatusUpdates(
      String conversationId, Message message) async {
    // Sending -> Sent after a short delay
    await Future.delayed(const Duration(milliseconds: 800));
    await _updateMessageStatus(conversationId, message, MessageStatus.sent);

    // Sent -> Delivered after another delay
    await Future.delayed(const Duration(milliseconds: 1200));
    await _updateMessageStatus(
        conversationId, message, MessageStatus.delivered);

    // Delivered -> Read (50% chance immediately, otherwise later)
    if (_random.nextBool()) {
      await Future.delayed(const Duration(milliseconds: 500));
      await _updateMessageStatus(conversationId, message, MessageStatus.read);
    } else {
      await Future.delayed(const Duration(seconds: 3));
      // 70% chance it gets read after the longer delay
      if (_random.nextDouble() < 0.7) {
        await _updateMessageStatus(conversationId, message, MessageStatus.read);
      }
    }
  }

  Future<void> _updateMessageStatus(
      String conversationId, Message message, MessageStatus status) async {
    if (!_messages.containsKey(conversationId)) return;

    final index =
        _messages[conversationId]!.indexWhere((m) => m.id == message.id);
    if (index == -1) return;

    // Update message
    final updatedMessage =
        _messages[conversationId]![index].copyWith(status: status);
    _messages[conversationId]![index] = updatedMessage;

    // If this is the last message in the conversation, update that too
    final convoIndex = _conversations.indexWhere((c) => c.id == conversationId);
    if (convoIndex != -1 &&
        _conversations[convoIndex].lastMessage.id == message.id) {
      _conversations[convoIndex] = _conversations[convoIndex].copyWith(
        lastMessage: updatedMessage,
      );

      _conversationsController.add(_conversations);
    }

    // Emit updated messages
    _messageControllers[conversationId]?.add(_messages[conversationId]!);
  }

  @override
  Future<Message> sendVoiceMessage(
      {required String conversationId,
      required File audioFile,
      required int durationSeconds}) async {
    // Simulate upload delay (longer for voice messages)
    await _delay(minMs: 500, maxMs: 2000);

    final conversation = _conversations.firstWhere(
      (c) => c.id == conversationId,
      orElse: () => throw Exception('Conversation not found'),
    );

    // Create voice message
    final newMessageId =
        '${conversationId}_voice_${DateTime.now().millisecondsSinceEpoch}';
    final newMessage = Message(
      id: newMessageId,
      senderId: _currentUser.id,
      senderName: _currentUser.name,
      content: 'Voice message',
      timestamp: DateTime.now(),
      messageType: MessageType.voice,
      voiceDuration: durationSeconds,
      status: MessageStatus.sending,
      isRead: false,
      // Mock URL for voice file
      mediaUrl: 'mock://voice/$conversationId/$newMessageId.m4a',
    );

    // Update our in-memory data
    _messages[conversationId] = [
      newMessage,
      ...(_messages[conversationId] ?? [])
    ];

    // Update conversation
    final updatedConversation = conversation.copyWith(
      messages: _messages[conversationId]!,
      lastMessage: newMessage,
      unreadCount: 0, // Reset unread for current user
    );

    // Update in our lists
    final index = _conversations.indexWhere((c) => c.id == conversationId);
    if (index != -1) {
      _conversations[index] = updatedConversation;
    }

    _sortConversations();

    // Emit updated conversations & messages
    _conversationsController.add(_conversations);
    _messageControllers[conversationId]?.add(_messages[conversationId]!);

    // Simulate message status progression
    _simulateMessageStatusUpdates(conversationId, newMessage);

    return newMessage;
  }

  @override
  Future<void> updateMessage(
      {required String conversationId, required Message message}) async {
    // Simulate network delay
    await _delay();

    if (!_messages.containsKey(conversationId)) return;

    final index =
        _messages[conversationId]!.indexWhere((m) => m.id == message.id);
    if (index == -1) return;

    // Create updated message
    final updatedMessage = _messages[conversationId]![index].copyWith(
      content: message.content,
      isEdited: true,
      editedAt: DateTime.now(),
    );

    _messages[conversationId]![index] = updatedMessage;

    // If this is the last message in the conversation, update that too
    final convoIndex = _conversations.indexWhere((c) => c.id == conversationId);
    if (convoIndex != -1 &&
        _conversations[convoIndex].lastMessage.id == message.id) {
      _conversations[convoIndex] = _conversations[convoIndex].copyWith(
        lastMessage: updatedMessage,
      );

      _conversationsController.add(_conversations);
    }

    // Emit updated messages
    _messageControllers[conversationId]?.add(_messages[conversationId]!);
  }

  @override
  Future<void> deleteMessage({
    required String conversationId,
    required String messageId,
  }) async {
    // Simulate network delay
    await _delay();

    if (!_messages.containsKey(conversationId)) return;

    // Filter out the deleted message
    _messages[conversationId] =
        _messages[conversationId]!.where((m) => m.id != messageId).toList();

    // Get the new latest message
    final latestMessage = _messages[conversationId]!.isNotEmpty
        ? _messages[conversationId]!.first
        : Message(
            id: 'empty',
            senderId: '',
            senderName: '',
            content: 'No messages',
            timestamp: DateTime.now(),
          );

    // If this was the last message, update the conversation
    final convoIndex = _conversations.indexWhere((c) => c.id == conversationId);
    if (convoIndex != -1) {
      _conversations[convoIndex] = _conversations[convoIndex].copyWith(
        lastMessage: latestMessage,
        messages: _messages[conversationId]!,
      );

      _conversationsController.add(_conversations);
    }

    // Emit updated messages
    _messageControllers[conversationId]?.add(_messages[conversationId]!);
  }

  @override
  Future<Conversation> createConversation({
    required List<String> participantIds,
    String? groupName,
    bool isGroup = false,
  }) async {
    // Simulate network delay
    await _delay(minMs: 500, maxMs: 1200);

    // First check if a conversation with these exact participants already exists
    if (!isGroup) {
      final existing = _conversations.where((c) => !c.isGroup).where((c) {
        final participantSet = c.participants.map((p) => p.id).toSet();
        return participantSet.length == participantIds.length &&
            participantIds.every((id) => participantSet.contains(id));
      }).toList();

      if (existing.isNotEmpty) return existing.first;
    }

    // Get participant users
    final participants = <User>[];
    for (final userId in participantIds) {
      final user = _users.firstWhere(
        (u) => u.id == userId,
        orElse: () => User(
          id: userId,
          name: 'User $userId',
          avatarUrl: 'https://ui-avatars.com/api/?name=User+$userId',
          isOnline: _random.nextBool(),
        ),
      );
      participants.add(user);
    }

    // Create a unique conversation ID
    final conversationId = 'conv_${DateTime.now().millisecondsSinceEpoch}';

    // Create initial welcome message
    final initialMessage = Message(
      id: '${conversationId}_msg_init',
      senderId: _currentUser.id,
      senderName: _currentUser.name,
      content: isGroup ? 'Group chat created' : 'Conversation started',
      timestamp: DateTime.now(),
      status: MessageStatus.sent,
      isRead: true,
    );

    // Create message list
    final messages = [initialMessage];
    _messages[conversationId] = messages;

    // Create conversation
    final conversation = Conversation(
      id: conversationId,
      participants: participants,
      messages: messages,
      lastMessage: initialMessage,
      unreadCount: 0,
      isGroup: isGroup,
      groupName: isGroup ? groupName ?? 'New Group' : null,
      isMuted: false,
      isArchived: false,
    );

    // Add to our list
    _conversations.add(conversation);
    _sortConversations();

    // Create message stream controller for this conversation
    _messageControllers[conversationId] =
        StreamController<List<Message>>.broadcast();
    _messageControllers[conversationId]!.add(messages);

    // Emit updated conversations
    _conversationsController.add(_conversations);

    return conversation;
  }

  @override
  Future<void> markConversationAsRead(String conversationId) async {
    await _delay(minMs: 50, maxMs: 200);

    final convoIndex = _conversations.indexWhere((c) => c.id == conversationId);
    if (convoIndex == -1) return;

    // Update conversation unread count
    _conversations[convoIndex] = _conversations[convoIndex].copyWith(
      unreadCount: 0,
    );

    if (!_messages.containsKey(conversationId)) return;

    // Mark all messages as read
    for (int i = 0; i < _messages[conversationId]!.length; i++) {
      _messages[conversationId]![i] = _messages[conversationId]![i].copyWith(
        isRead: true,
      );
    }

    // Emit updates
    _conversationsController.add(_conversations);
    _messageControllers[conversationId]?.add(_messages[conversationId]!);
  }

  @override
  Future<void> markConversationAsUnread(String conversationId) async {
    await _delay(minMs: 50, maxMs: 200);

    final convoIndex = _conversations.indexWhere((c) => c.id == conversationId);
    if (convoIndex == -1) return;

    // Update conversation unread count
    _conversations[convoIndex] = _conversations[convoIndex].copyWith(
      unreadCount: 1,
    );

    if (!_messages.containsKey(conversationId)) return;

    // Find a message that's not from current user and mark unread
    for (int i = 0; i < _messages[conversationId]!.length; i++) {
      if (_messages[conversationId]![i].senderId != _currentUser.id) {
        _messages[conversationId]![i] = _messages[conversationId]![i].copyWith(
          isRead: false,
        );
        break;
      }
    }

    // Emit updates
    _conversationsController.add(_conversations);
    _messageControllers[conversationId]?.add(_messages[conversationId]!);
  }

  @override
  Future<void> setConversationArchiveStatus({
    required String conversationId,
    required bool isArchived,
  }) async {
    await _delay();

    final convoIndex = _conversations.indexWhere((c) => c.id == conversationId);
    if (convoIndex == -1) return;

    // Update archive status
    _conversations[convoIndex] = _conversations[convoIndex].copyWith(
      isArchived: isArchived,
    );

    // Emit update
    _conversationsController.add(_conversations);
  }

  @override
  Future<void> setConversationMuteStatus({
    required String conversationId,
    required bool isMuted,
  }) async {
    await _delay();

    final convoIndex = _conversations.indexWhere((c) => c.id == conversationId);
    if (convoIndex == -1) return;

    // Update mute status
    _conversations[convoIndex] = _conversations[convoIndex].copyWith(
      isMuted: isMuted,
    );

    // Emit update
    _conversationsController.add(_conversations);
  }

  @override
  Future<void> deleteConversation(String conversationId) async {
    await _delay();

    // Remove message stream controller
    _messageControllers[conversationId]?.close();
    _messageControllers.remove(conversationId);

    // Remove messages
    _messages.remove(conversationId);

    // Remove conversation
    _conversations.removeWhere((c) => c.id == conversationId);

    // Emit update
    _conversationsController.add(_conversations);
  }

  @override
  Future<List<User>> searchUsers(String query) async {
    await _delay();

    if (query.isEmpty) return [];

    final lowercaseQuery = query.toLowerCase();

    return _users
        .where((u) => u.id != _currentUser.id) // Don't include current user
        .where((u) => u.name.toLowerCase().contains(lowercaseQuery))
        .toList();
  }

  @override
  Future<void> setupPresenceMonitoring() async {
    // Nothing to do in mock implementation
    return;
  }

  @override
  Future<Message> forwardMessage({
    required String sourceConversationId,
    required String messageId,
    required String targetConversationId,
  }) async {
    await _delay();

    // Find source message
    if (!_messages.containsKey(sourceConversationId)) {
      throw Exception("Source conversation not found");
    }

    final sourceMessage = _messages[sourceConversationId]!.firstWhere(
      (m) => m.id == messageId,
      orElse: () => throw Exception("Source message not found"),
    );

    // Create a new forwarded message
    final forwardedMessage = Message(
      id: '${targetConversationId}_fwd_${DateTime.now().millisecondsSinceEpoch}',
      senderId: _currentUser.id,
      senderName: _currentUser.name,
      content: sourceMessage.content,
      timestamp: DateTime.now(),
      messageType: sourceMessage.messageType,
      mediaUrl: sourceMessage.mediaUrl,
      voiceDuration: sourceMessage.voiceDuration,
      status: MessageStatus.sending,
      isRead: false,
      forwardedFrom: sourceMessage.senderName,
    );

    // Update target conversation
    if (!_messages.containsKey(targetConversationId)) {
      _messages[targetConversationId] = [];
    }

    _messages[targetConversationId] = [
      forwardedMessage,
      ..._messages[targetConversationId]!
    ];

    // Update conversation
    final convoIndex =
        _conversations.indexWhere((c) => c.id == targetConversationId);
    if (convoIndex != -1) {
      _conversations[convoIndex] = _conversations[convoIndex].copyWith(
        lastMessage: forwardedMessage,
        messages: _messages[targetConversationId]!,
      );

      _sortConversations();
      _conversationsController.add(_conversations);
    }

    // Emit messages
    _messageControllers[targetConversationId]
        ?.add(_messages[targetConversationId]!);

    // Simulate status progress
    _simulateMessageStatusUpdates(targetConversationId, forwardedMessage);

    return forwardedMessage;
  }

  @override
  Future<void> dispose() async {
    // Close all controllers
    await _conversationsController.close();

    for (final controller in _messageControllers.values) {
      await controller.close();
    }
    _messageControllers.clear();
  }
}
