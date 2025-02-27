import 'dart:async';
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
  Conversation? get selectedConversation => _selectedConversation;
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
    // await Future.delayed(const Duration(seconds: 1));
    _conversations = _generateMockConversations();
    _applyFilters();
  }

  List<Conversation> _generateMockConversations() {
    final currentUser = User(
      id: 'current',
      name: 'Me',
      avatarUrl: 'https://ui-avatars.com/api/?name=Me',
      isOnline: true,
    );

    List<Conversation> mockConversations = [];

    for (int i = 1; i <= 15; i++) {
      final otherUser = User(
        id: 'user$i',
        name: 'User $i',
        avatarUrl: 'https://ui-avatars.com/api/?name=User+$i',
        isOnline: i % 3 == 0,
      );

      final messages = <Message>[];
      final isGroup = i % 5 == 0;

      // Add some messages
      for (int j = 1; j <= 20; j++) {
        final isFromCurrentUser = j % 2 == 0;
        final sender = isFromCurrentUser ? currentUser : otherUser;
        final time = DateTime.now().subtract(Duration(minutes: j * 5));

        messages.add(
          Message(
            id: 'msg${i}_$j',
            senderId: sender.id,
            senderName: sender.name,
            content:
                'This is message $j in conversation $i. Adding some more text to make it longer and more realistic.',
            timestamp: time,
            status: isFromCurrentUser ? MessageStatus.values[j % 3] : null,
            isRead: j > 3,
          ),
        );
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
    _selectedConversation = conversation;

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
          messageScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });

    notifyListeners();
  }

  void clearSelectedConversation() {
    _selectedConversation = null;
    notifyListeners();
  }

  Future<void> sendMessage(String content) async {
    if (content.isEmpty || _selectedConversation == null) return;

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
      _applyFilters();
    }

    messageController.clear();
    notifyListeners();

    // Scroll to bottom after adding message
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (messageScrollController.hasClients) {
        messageScrollController.animateTo(
          messageScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });

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
