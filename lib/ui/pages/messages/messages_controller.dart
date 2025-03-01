import 'dart:async';
import 'dart:core';
import 'package:flutter/material.dart';
import 'package:flutter_application_2/ui/pages/messages/models/conversation.dart';
import 'package:flutter_application_2/ui/pages/messages/models/message.dart';
import 'package:flutter_application_2/ui/pages/messages/models/user.dart';

enum FilterMode {
  all,
  unread,
  archived,
  groups,
}

class MessagesController extends ChangeNotifier {
  List<Conversation> _conversations = [];
  List<Conversation> _filteredConversations = [];
  Conversation? _selectedConversation;
  bool _isSearchMode = false;
  String _searchQuery = '';
  FilterMode _filterMode = FilterMode.all;

  List<Conversation> get conversations => _filteredConversations;
  Conversation? get selectedConversation {
    if (_selectedConversation == null) return null;

    final index =
        _conversations.indexWhere((c) => c.id == _selectedConversation!.id);
    if (index != -1) {
      _selectedConversation = _conversations[index];
      return _conversations[index];
    }
    return _selectedConversation;
  }

  bool get isSearchMode => _isSearchMode;
  FilterMode get filterMode => _filterMode;

  final TextEditingController searchController = TextEditingController();
  final TextEditingController messageController = TextEditingController();
  final ScrollController listScrollController = ScrollController();
  final ScrollController messageScrollController = ScrollController();

  MessagesController() {
    searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    if (_isSearchMode) {
      _searchQuery = searchController.text;
      _applyFilters();
    }
  }

  Future<void> loadConversations() async {
    // TODO: Replace with Firebase Firestore fetch
    // final snapshot = await FirebaseFirestore.instance
    //     .collection('conversations')
    //     .where('participants', arrayContains: currentUserId)
    //     .orderBy('lastMessageTimestamp', descending: true)
    //     .get();

    // Mock data for now
    _conversations = _generateMockConversations();
    _applyFilters();
  }

  List<Conversation> _generateMockConversations() {
    final currentUser = User(
      id: 'current', // Important: This ID is what identifies messages as sent by the current user
      name: 'Me',
      avatarUrl: 'https://ui-avatars.com/api/?name=Me',
      isOnline: true,
    );

    List<Conversation> mockConversations = [];

    for (int i = 1; i <= 15; i++) {
      final otherUser = User(
        id: 'user$i', // Any ID other than 'current' will be treated as messages from others
        name: 'User $i',
        avatarUrl: 'https://ui-avatars.com/api/?name=User+$i',
        isOnline: i % 3 == 0,
      );

      final messages = <Message>[];
      final isGroup = i % 5 == 0;

      // Add some messages with clearer sender identification
      for (int j = 1; j <= 20; j++) {
        final isFromCurrentUser = j % 2 == 0;
        final sender = isFromCurrentUser ? currentUser : otherUser;
        final time = DateTime.now().subtract(Duration(minutes: j * 5));

        // Voice message every 5th message
        if (j % 5 == 0) {
          messages.add(
            Message(
              id: 'vmsg${i}_$j',
              senderId: sender.id,
              senderName: sender.name,
              content: 'Voice message',
              timestamp: time,
              status: isFromCurrentUser ? MessageStatus.values[j % 3] : null,
              isRead: j > 3,
              messageType: MessageType.voice,
              voiceDuration: 15 + j % 45,
              mediaUrl: 'voice_message_mock_${i}_$j.mp3',
            ),
          );
        } else {
          // Regular text messages with clear identification of sender
          final text = isFromCurrentUser
              ? "This is my message #$j. It should appear on the right."
              : "This is a message #$j from ${sender.name}. It should appear on the left.";

          messages.add(
            Message(
              id: 'msg${i}_$j',
              senderId: sender.id,
              senderName: sender.name,
              content: text,
              timestamp: time,
              status: isFromCurrentUser ? MessageStatus.values[j % 3] : null,
              isRead: j > 3,
            ),
          );
        }
      }

      mockConversations.add(
        Conversation(
          id: 'conv$i',
          participants: isGroup
              ? [
                  currentUser,
                  otherUser,
                  ...List.generate(
                      3,
                      (index) => User(
                            id: 'group_member_${i}_$index',
                            name: 'Group Member $index',
                            avatarUrl:
                                'https://ui-avatars.com/api/?name=GM+$index',
                            isOnline: index % 2 == 0,
                          ))
                ]
              : [currentUser, otherUser],
          messages: messages,
          lastMessage: messages.first,
          unreadCount: i % 4,
          isGroup: isGroup,
          groupName: isGroup ? 'Group Chat $i' : null,
          isMuted: i % 7 == 0,
          isArchived: i % 9 == 0,
        ),
      );
    }

    return mockConversations;
  }

  void _applyFilters() {
    if (_searchQuery.isNotEmpty) {
      _filteredConversations = _conversations.where((conversation) {
        final participantNames = conversation.participants
            .map((p) => p.name.toLowerCase())
            .join(' ');
        final groupName = conversation.groupName?.toLowerCase() ?? '';
        final lastMessageContent =
            conversation.lastMessage.content.toLowerCase();

        return participantNames.contains(_searchQuery.toLowerCase()) ||
            groupName.contains(_searchQuery.toLowerCase()) ||
            lastMessageContent.contains(_searchQuery.toLowerCase());
      }).toList();
    } else {
      switch (_filterMode) {
        case FilterMode.unread:
          _filteredConversations =
              _conversations.where((c) => c.unreadCount > 0).toList();
          break;
        case FilterMode.archived:
          _filteredConversations =
              _conversations.where((c) => c.isArchived).toList();
          break;
        case FilterMode.groups:
          _filteredConversations =
              _conversations.where((c) => c.isGroup).toList();
          break;
        case FilterMode.all:
          _filteredConversations =
              _conversations.where((c) => !c.isArchived).toList();
          break;
      }
    }

    // Sort by timestamp
    _filteredConversations.sort(
        (a, b) => b.lastMessage.timestamp.compareTo(a.lastMessage.timestamp));

    notifyListeners();
  }

  void toggleSearchMode() {
    _isSearchMode = !_isSearchMode;
    if (!_isSearchMode) {
      searchController.clear();
      _searchQuery = '';
      _applyFilters();
    }
    notifyListeners();
  }

  void setFilterMode(FilterMode mode) {
    _filterMode = mode;
    _applyFilters();
  }

  void selectConversation(Conversation conversation) {
    final prevController = _selectedConversation?.controller;

    _selectedConversation = conversation;

    if (_selectedConversation != null) {
      _selectedConversation!.controller = prevController ?? this;
    }

    // Mark messages as read
    if (conversation.unreadCount > 0) {
      final updatedMessages = conversation.messages.map((message) {
        return message.copyWith(isRead: true);
      }).toList();

      final updatedConversation = conversation.copyWith(
        messages: updatedMessages,
        unreadCount: 0,
      );

      // Update conversation in the list
      final index = _conversations.indexWhere((c) => c.id == conversation.id);
      if (index != -1) {
        _conversations[index] = updatedConversation;
        _selectedConversation = updatedConversation;
        _applyFilters();
      }

      // TODO: Update read status in Firebase
      // FirebaseFirestore.instance
      //    .collection('conversations')
      //    .doc(conversation.id)
      //    .collection('messages')
      //    .where('isRead', isEqualTo: false)
      //    .where('senderId', isNotEqualTo: 'current')
      //    .get()
      //    .then((snapshot) {
      //      final batch = FirebaseFirestore.instance.batch();
      //      for (var doc in snapshot.docs) {
      //        batch.update(doc.reference, {'isRead': true});
      //      }
      //      return batch.commit();
      //    });
    }

    // Scroll to bottom of messages after frame is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (messageScrollController.hasClients) {
        messageScrollController.animateTo(
          0.0, // Scroll to the newest message
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });

    notifyListeners();
  }

  void clearSelection() {
    // Clear the selection but preserve the conversation object itself
    // for when we need to send messages to it later
    _selectedConversation = null;
  }

  void clearSelectedConversationUI() {
    // Don't set _selectedConversation to null anymore
    // This helps maintain conversation state when navigating
    notifyListeners();
  }

  Future<void> sendMessage(String content) async {
    if (content.isEmpty) return;

    if (_selectedConversation == null) {
      print("Warning: Trying to send message without selected conversation");
      return;
    }

    final currentUserId = 'current'; // TODO: Get from authentication
    final currentUser = _selectedConversation!.participants
        .firstWhere((p) => p.id == currentUserId);

    final newMessage = Message(
      id: 'temp_${DateTime.now().millisecondsSinceEpoch}',
      senderId: currentUserId,
      senderName: currentUser.name,
      content: content,
      timestamp: DateTime.now(),
      status: MessageStatus.sending,
      isRead: false,
    );

    // Add message locally first (optimistic update)
    final updatedMessages = [
      newMessage,
      ..._selectedConversation!.messages,
    ];

    final updatedConversation = _selectedConversation!.copyWith(
      messages: updatedMessages,
      lastMessage: newMessage,
    );

    // Update conversation in the lists
    final index =
        _conversations.indexWhere((c) => c.id == updatedConversation.id);
    if (index != -1) {
      _conversations[index] = updatedConversation;
      _selectedConversation = updatedConversation;
      _applyFilters(); // This refreshes filteredConversations
    }

    messageController.clear();

    // Immediately notify listeners to update UI
    notifyListeners();

    // Fixed: Scroll after a very short delay to ensure the ListView has updated
    await Future.delayed(const Duration(milliseconds: 10));
    _scrollToNewestMessage();

    // TODO: Send to Firebase
    // await FirebaseFirestore.instance
    //    .collection('conversations')
    //    .doc(_selectedConversation!.id)
    //    .collection('messages')
    //    .add(newMessage.toJson());
    //
    // await FirebaseFirestore.instance
    //    .collection('conversations')
    //    .doc(_selectedConversation!.id)
    //    .update({
    //      'lastMessage': newMessage.toJson(),
    //      'lastMessageTimestamp': FieldValue.serverTimestamp(),
    //    });

    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 800));

    // Update message status to sent
    final sentMessage = newMessage.copyWith(status: MessageStatus.sent);
    final updatedMessagesWithSent = updatedMessages.map((m) {
      return m.id == newMessage.id ? sentMessage : m;
    }).toList();

    final finalUpdatedConversation = updatedConversation.copyWith(
      messages: updatedMessagesWithSent,
      lastMessage: sentMessage,
    );

    // Update conversation in the lists
    final finalIndex =
        _conversations.indexWhere((c) => c.id == finalUpdatedConversation.id);
    if (finalIndex != -1) {
      _conversations[finalIndex] = finalUpdatedConversation;
      _selectedConversation = finalUpdatedConversation;
      _applyFilters();
    }

    notifyListeners();

    // Simulate delivered status after a delay
    await Future.delayed(const Duration(seconds: 1));

    final deliveredMessage =
        sentMessage.copyWith(status: MessageStatus.delivered);
    final updatedMessagesWithDelivered = updatedMessagesWithSent.map((m) {
      return m.id == sentMessage.id ? deliveredMessage : m;
    }).toList();

    final deliveredConversation = finalUpdatedConversation.copyWith(
      messages: updatedMessagesWithDelivered,
      lastMessage: deliveredMessage,
    );

    final deliveredIndex =
        _conversations.indexWhere((c) => c.id == deliveredConversation.id);
    if (deliveredIndex != -1) {
      _conversations[deliveredIndex] = deliveredConversation;
      _selectedConversation = deliveredConversation;
      _applyFilters();
    }

    notifyListeners();
  }

  void deleteMessage(Message message) {
    if (_selectedConversation == null) return;

    // TODO: Delete from Firebase
    // FirebaseFirestore.instance
    //    .collection('conversations')
    //    .doc(_selectedConversation!.id)
    //    .collection('messages')
    //    .doc(message.id)
    //    .delete();

    final updatedMessages = _selectedConversation!.messages
        .where((m) => m.id != message.id)
        .toList();

    final lastMsg = updatedMessages.isNotEmpty
        ? updatedMessages.first
        : Message(
            id: 'empty',
            senderId: '',
            senderName: '',
            content: 'No messages',
            timestamp: DateTime.now(),
          );

    final updatedConversation = _selectedConversation!.copyWith(
      messages: updatedMessages,
      lastMessage: lastMsg,
    );

    final index =
        _conversations.indexWhere((c) => c.id == updatedConversation.id);
    if (index != -1) {
      _conversations[index] = updatedConversation;
      _selectedConversation = updatedConversation;
      _applyFilters();
    }

    notifyListeners();
  }

  void toggleMute(Conversation conversation) {
    final updatedConversation = conversation.copyWith(
      isMuted: !conversation.isMuted,
    );

    final index = _conversations.indexWhere((c) => c.id == conversation.id);
    if (index != -1) {
      _conversations[index] = updatedConversation;
      if (_selectedConversation?.id == conversation.id) {
        _selectedConversation = updatedConversation;
      }
      _applyFilters();
    }

    // TODO: Update in Firebase
    // FirebaseFirestore.instance
    //    .collection('conversations')
    //    .doc(conversation.id)
    //    .update({'isMuted': !conversation.isMuted});

    notifyListeners();
  }

  void toggleArchive(Conversation conversation) {
    final updatedConversation = conversation.copyWith(
      isArchived: !conversation.isArchived,
    );

    final index = _conversations.indexWhere((c) => c.id == conversation.id);
    if (index != -1) {
      _conversations[index] = updatedConversation;
      if (_selectedConversation?.id == conversation.id) {
        _selectedConversation = updatedConversation;
      }
      _applyFilters();
    }

    // TODO: Update in Firebase
    // FirebaseFirestore.instance
    //    .collection('conversations')
    //    .doc(conversation.id)
    //    .update({'isArchived': !conversation.isArchived});

    notifyListeners();
  }

  void deleteConversation(Conversation conversation) {
    _conversations.removeWhere((c) => c.id == conversation.id);
    if (_selectedConversation?.id == conversation.id) {
      _selectedConversation = null;
    }
    _applyFilters();

    // TODO: Delete from Firebase
    // FirebaseFirestore.instance
    //    .collection('conversations')
    //    .doc(conversation.id)
    //    .delete();

    notifyListeners();
  }

  void sendVoiceMessage(int durationSeconds) {
    if (_selectedConversation == null) {
      print(
          "Warning: Trying to send voice message without selected conversation");
      return;
    }

    final now = DateTime.now();
    final newMessage = Message(
      id: 'msg_${now.millisecondsSinceEpoch}',
      content: 'Voice message (${_formatDuration(durationSeconds)})',
      senderId: 'current', // Assuming current user
      senderName: 'You',
      timestamp: now,
      isRead: true,
      isSent: true,
      messageType: MessageType.voice,
      voiceDuration: durationSeconds,
      // In a real app, you would save the file path or URL here
      mediaUrl: 'voice_message_${now.millisecondsSinceEpoch}.mp3',
      status: MessageStatus.sent, // Set an initial status
    );

    final updatedMessages = [newMessage, ..._selectedConversation!.messages];

    final updatedConversation = _selectedConversation!.copyWith(
      messages: updatedMessages,
      lastMessage: newMessage,
    );

    // Update the conversation in the list
    final index =
        _conversations.indexWhere((c) => c.id == updatedConversation.id);
    if (index >= 0) {
      _conversations[index] = updatedConversation;
      _selectedConversation = updatedConversation;

      // Move this conversation to the top of the list
      if (index > 0) {
        _conversations.removeAt(index);
        _conversations.insert(0, updatedConversation);
      }

      // Apply filters to refresh filteredConversations
      _applyFilters();
    }

    // Immediately notify listeners to update UI
    notifyListeners();

    // Fixed: Scroll after a very short delay to ensure the ListView has updated
    Future.delayed(const Duration(milliseconds: 10), _scrollToNewestMessage);

    // TODO: Upload voice recording to Firebase Storage
    // 1. Create a Firebase Storage reference
    // final storageRef = FirebaseStorage.instance.ref();
    // final voiceMessageRef = storageRef.child('voice_messages/${conversation.id}/${DateTime.now().millisecondsSinceEpoch}.m4a');
    //
    // 2. Upload the file
    // final uploadTask = voiceMessageRef.putFile(File(recordingPath));
    //
    // 3. Get the download URL
    // final downloadUrl = await (await uploadTask).ref.getDownloadURL();
    //
    // 4. Create message with URL
    // final message = Message(..., mediaUrl: downloadUrl)
  }

  String _formatDuration(int seconds) {
    final minutes = (seconds / 60).floor();
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  void _scrollToNewestMessage() {
    if (messageScrollController.hasClients) {
      messageScrollController.animateTo(
        0.0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  void dispose() {
    searchController.removeListener(_onSearchChanged);
    searchController.dispose();
    messageController.dispose();
    listScrollController.dispose();
    messageScrollController.dispose();
    super.dispose();
  }
}
