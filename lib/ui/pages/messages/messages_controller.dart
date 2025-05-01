import 'dart:core';
import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_application_2/constants/text_strings.dart';
import 'package:flutter_application_2/ui/pages/messages/models/conversation.dart';
import 'package:flutter_application_2/ui/pages/messages/models/message.dart';
import 'package:flutter_application_2/ui/pages/messages/models/user.dart';
import 'package:flutter_application_2/ui/widgets/responsive_snackbar.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_application_2/services/api/account/account_provider.dart';
import 'package:uuid/uuid.dart';

enum FilterMode {
  all,
  unread,
  archived,
  groups,
}

class MessagesController extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final AccountProvider accountProvider = AccountProvider();

  String get currentUserId {
    final user = accountProvider.currentUser;
    if (user != null && user.id.toString().isNotEmpty) {
      return user.id.toString();
    }
    return ''; // Fallback for debugging: show all conversations if not authenticated
  }

  List<Conversation> _conversations = [];
  List<Conversation> _filteredConversations = [];
  Conversation? _selectedConversation;
  bool _isSearchMode = false;
  String _searchQuery = '';
  FilterMode _filterMode = FilterMode.all;

  Message? _replyToMessage;
  Message? get replyToMessage => _replyToMessage;

  Message? _editingMessage;
  Message? get editingMessage => _editingMessage;

  final List<StreamSubscription> _subscriptions = [];

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

  bool _isDisposed = false;

  // Getter to check if controller is disposed
  bool get disposed => _isDisposed;

  String? _highlightedMessageId;
  String? get highlightedMessageId => _highlightedMessageId;

  // Add typing indicator state
  final Map<String, bool> _typingUsers = {};
  Map<String, bool> get typingUsers => _typingUsers;

  // Throttle for typing indicator updates
  DateTime? _lastTypingNotification;
  Timer? _typingTimer;

  MessagesController() {
    searchController.addListener(_onSearchChanged);
    _initFirebaseListeners();
    ensureMessageControllerReferences();
  }

  void _onSearchChanged() {
    if (_isSearchMode) {
      _searchQuery = searchController.text;
      _applyFilters();
      notifyListeners();
    }
  }

  Future<List<User>> _fetchAllUsers() async {
    final url = Uri.parse('http://192.168.1.7:8000/accounts/all-users/');
    final response = await http.get(url);
    if (response.statusCode == 200) {
      final List<dynamic> userList = jsonDecode(response.body);
      return userList.map((user) => User.fromJson(user)).toList();
    } else {
      return [];
    }
  }

  void _initFirebaseListeners() async {
    final users = await _fetchAllUsers();
    final conversationsStream = _firestore
        .collection('conversations')
        .where('participants', arrayContains: currentUserId)
        .snapshots();

    final subscription = conversationsStream.listen((snapshot) async {
      _conversations = await Future.wait(
        snapshot.docs
            .map((doc) async => Conversation.fromFirestore(doc.data(), users)),
      );
      _applyFilters();
      notifyListeners();
    });

    _subscriptions.add(subscription);
  }

  Future<void> loadConversations() async {
    try {
      final users = await _fetchAllUsers();
      final snapshot = await _firestore
          .collection('conversations')
          .where('participants', arrayContains: currentUserId)
          .get();

      _conversations = await Future.wait(
        snapshot.docs
            .map((doc) async => Conversation.fromFirestore(doc.data(), users)),
      );
      _applyFilters();
      notifyListeners();
      return;
    } catch (e) {
      print('Error loading conversations: $e');
      _conversations = _generateMockConversations();
      _applyFilters();
    }
    ensureMessageControllerReferences();
  }

  List<Conversation> _generateMockConversations() {
    return [];
  }

  Future<void> sendMessage(
    String content, {
    Message? replyTo,
    MessageType type = MessageType.text,
  }) async {
    if (_selectedConversation == null) return;

    final messageId = const Uuid().v4();
    final timestamp = DateTime.now();

    debugPrint(
        '[sendMessage] Preparing message: $messageId, content="$content"');

    // First create message with 'sending' status
    final message = Message(
      id: messageId,
      senderId: currentUserId,
      senderName: accountProvider.currentUser?.firstName ?? 'You',
      content: content.trim(),
      timestamp: timestamp,
      messageType: MessageType.text,
      conversationId: _selectedConversation!.id,
      replyToMessageId: replyTo?.id,
      replyToSenderName: replyTo?.senderName,
      replyToContent: replyTo?.content,
      status: MessageStatus.sending, // Start with sending status
    );

    // Update UI immediately with the sending message
    _selectedConversation!.messages.insert(0, message);
    notifyListeners();

    try {
      debugPrint(
          '[sendMessage] Writing to Firestore: conversationId=${_selectedConversation!.id} messageId=$messageId');

      // Write to Firestore (this might take a moment)
      await _firestore
          .collection('conversations')
          .doc(_selectedConversation!.id)
          .collection('messages')
          .doc(messageId)
          .set(message.toJson())
          .then((_) {
        debugPrint('[sendMessage] Message written to Firestore');

        // Update message status to 'sent' after successful write
        _updateMessageStatus(messageId, MessageStatus.sent);
      }).catchError((e) {
        debugPrint('[sendMessage] Error writing message: $e');

        // Mark as failed if there was an error
        _updateMessageStatus(messageId, MessageStatus.failed);
      });

      debugPrint('[sendMessage] Updating conversation lastMessage');

      // Update conversation last message
      await _firestore
          .collection('conversations')
          .doc(_selectedConversation!.id)
          .update({
            'lastMessage': message.toJson(),
            'lastMessageTimestamp': FieldValue.serverTimestamp(),
          })
          .then((_) => debugPrint('[sendMessage] Conversation updated'))
          .catchError((e) =>
              debugPrint('[sendMessage] Error updating conversation: $e'));

      // Stop showing typing indicator
      _stopTypingIndicator();

      // Clear reply message after sending
      _replyToMessage = null;

      debugPrint('[sendMessage] Message send complete, notifyListeners()');
      notifyListeners();

      // Simulate message being delivered after a short delay
      Future.delayed(const Duration(seconds: 1), () {
        _updateMessageStatus(messageId, MessageStatus.delivered);
      });
    } catch (e, stack) {
      debugPrint('[sendMessage] Exception: $e');
      debugPrint('[sendMessage] Stack: $stack');
      notifyListeners();
      rethrow;
    }
  }

  // Update the status of a message
  void _updateMessageStatus(String messageId, MessageStatus newStatus) {
    if (_selectedConversation == null) return;

    try {
      // Find and update message in memory
      final index =
          _selectedConversation!.messages.indexWhere((m) => m.id == messageId);
      if (index != -1) {
        _selectedConversation!.messages[index].status = newStatus;

        // Also update in Firestore
        _firestore
            .collection('conversations')
            .doc(_selectedConversation!.id)
            .collection('messages')
            .doc(messageId)
            .update({'status': newStatus.toString().split('.').last});

        notifyListeners();
      }
    } catch (e) {
      debugPrint('[updateMessageStatus] Error: $e');
    }
  }

  // Update the read status of all messages from a sender
  Future<void> markMessagesFromSenderAsRead(String senderId) async {
    if (_selectedConversation == null) return;

    try {
      // Find unread messages from this sender in one operation
      final unreadMessages = _selectedConversation!.messages
          .where((message) => message.senderId == senderId && !message.isRead)
          .toList();

      if (unreadMessages.isEmpty) return; // Early exit if no unread messages

      final batch = _firestore.batch();
      int updateCount = 0;

      // Update messages in memory and prepare batch updates
      for (final message in unreadMessages) {
        message.isRead = true;
        updateCount++;

        // If this is our own message, update its status to 'read'
        if (message.senderId == currentUserId &&
            message.status != MessageStatus.read) {
          message.status = MessageStatus.read;
        }

        // Add to batch update
        final docRef = _firestore
            .collection('conversations')
            .doc(_selectedConversation!.id)
            .collection('messages')
            .doc(message.id);

        batch.update(docRef, {
          'isRead': true,
          if (message.senderId == currentUserId) 'status': 'read'
        });
      }

      // Only continue if we have messages to update
      if (updateCount > 0) {
        // Update the conversation's unreadCount if needed (when marking messages from others as read)
        if (senderId != currentUserId) {
          await _firestore
              .collection('conversations')
              .doc(_selectedConversation!.id)
              .update({'unreadCount': FieldValue.increment(-updateCount)});

          // Update local conversation unread count
          if (_selectedConversation!.unreadCount >= updateCount) {
            _selectedConversation!.unreadCount -= updateCount;
          } else {
            _selectedConversation!.unreadCount = 0;
          }
        }

        // Commit all the batch operations
        await batch.commit();
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[markMessagesFromSenderAsRead] Error: $e');
    }
  }

  Future<void> loadMoreMessages() async {
    if (_selectedConversation == null) return;

    try {
      final lastMessage = _selectedConversation!.messages.last;
      final snapshot = await _firestore
          .collection('conversations')
          .doc(_selectedConversation!.id)
          .collection('messages')
          .orderBy('timestamp', descending: true)
          .startAfter([lastMessage.timestamp])
          .limit(20)
          .get();

      final newMessages = snapshot.docs
          .map((doc) => Message.fromJson({...doc.data(), 'id': doc.id}))
          .toList();

      _selectedConversation = _selectedConversation!.copyWith(
        messages: [..._selectedConversation!.messages, ...newMessages],
      );

      notifyListeners();
    } catch (e) {
      print('Error loading more messages: $e');
    }
  }

  Future<void> markMessageAsRead(Message message) async {
    try {
      // Only update if conversationId and message.id are not empty
      if ((message.conversationId).isEmpty || (message.id).isEmpty) return;

      // Skip if message is already read
      if (message.isRead) return;

      // Update message in Firestore
      await FirebaseFirestore.instance
          .collection('conversations')
          .doc(message.conversationId)
          .collection('messages')
          .doc(message.id)
          .update({
        'isRead': true,
      });

      // Update message locally
      message.isRead = true;

      // Find and update the conversation's unread count
      final conversationIndex = _conversations.indexWhere(
          (conversation) => conversation.id == message.conversationId);

      if (conversationIndex != -1) {
        final conversation = _conversations[conversationIndex];

        // Only decrement if count is greater than 0
        if (conversation.unreadCount > 0) {
          // Update conversation unread count in Firestore
          await _firestore
              .collection('conversations')
              .doc(message.conversationId)
              .update({'unreadCount': FieldValue.increment(-1)});

          // Update locally
          conversation.unreadCount--;
          _conversations[conversationIndex] = conversation;

          // If this is the selected conversation, update it too
          if (_selectedConversation?.id == message.conversationId) {
            _selectedConversation = conversation;
          }

          // Re-apply filters to update UI
          _applyFilters();
        }
      }

      // Notify UI of changes
      notifyListeners();
    } catch (e) {
      print('Error marking message as read: $e');
    }
  }

  // Method to get the total unread messages count across all conversations
  int getTotalUnreadCount() {
    int total = 0;
    for (final conversation in _conversations) {
      total += conversation.unreadCount;
    }
    return total;
  }

  void deleteMessage(Message message) async {
    if (_selectedConversation == null) return;

    await _firestore
        .collection('conversations')
        .doc(_selectedConversation!.id)
        .collection('messages')
        .doc(message.id)
        .delete();

    notifyListeners();
  }

  void toggleMute(Conversation conversation) async {
    await _firestore
        .collection('conversations')
        .doc(conversation.id)
        .update({'isMuted': !conversation.isMuted});
    notifyListeners();
  }

  void toggleArchive(Conversation conversation) async {
    await _firestore
        .collection('conversations')
        .doc(conversation.id)
        .update({'isArchived': !conversation.isArchived});
    notifyListeners();
  }

  Future<void> updateConversation(Conversation conversation) async {
    try {
      // Update conversation in Firestore
      await _firestore
          .collection('conversations')
          .doc(conversation.id)
          .update({
        'isMuted': conversation.isMuted,
        'isArchived': conversation.isArchived,
      });
      
      // Update in local list
      final index = _conversations.indexWhere((c) => c.id == conversation.id);
      if (index != -1) {
        _conversations[index] = conversation;
      }
      
      // Update selected conversation if needed
      if (_selectedConversation?.id == conversation.id) {
        _selectedConversation = conversation;
      }
      
      // Reapply filters to update UI
      _applyFilters();
      notifyListeners();
    } catch (e) {
      debugPrint('Error updating conversation: $e');
    }
  }

  void deleteConversation(Conversation conversation) async {
    final batch = _firestore.batch();
    final messagesSnapshot = await _firestore
        .collection('conversations')
        .doc(conversation.id)
        .collection('messages')
        .get();
    for (final doc in messagesSnapshot.docs) {
      batch.delete(doc.reference);
    }
    batch.delete(_firestore.collection('conversations').doc(conversation.id));
    await batch.commit();
    notifyListeners();
  }

  Future<void> forwardMessage(
      Message message, Conversation targetConversation) async {
    final newMessageId = const Uuid().v4();
    final forwardedMessage = Message(
      id: newMessageId,
      senderId: currentUserId,
      senderName: 'You',
      content: message.content,
      timestamp: DateTime.now(),
      messageType: message.messageType,
      mediaUrl: message.mediaUrl,
      status: MessageStatus.sending,
      isRead: false,
      conversationId: targetConversation.id,
      forwardedFrom: message.senderName, // Using the forwardedFrom field
    );

    await _firestore
        .collection('conversations')
        .doc(targetConversation.id)
        .collection('messages')
        .doc(newMessageId)
        .set(forwardedMessage.toJson());

    await _firestore
        .collection('conversations')
        .doc(targetConversation.id)
        .update({
      'lastMessage': forwardedMessage.toJson(),
      'lastMessageTimestamp': FieldValue.serverTimestamp(),
      'unreadCount': FieldValue.increment(1)
    });

    notifyListeners();
  }

  Future<void> markConversationAsRead(Conversation conversation) async {
    if (conversation.unreadCount > 0) {
      try {
        // Update Firestore conversation document to reset unread count
        await _firestore
            .collection('conversations')
            .doc(conversation.id)
            .update({'unreadCount': 0});

        // Mark all messages as read in this conversation
        final batch = _firestore.batch();

        // Changed approach: Instead of using a compound query (which requires an index),
        // get all unread messages first, then filter in memory
        final messages = await _firestore
            .collection('conversations')
            .doc(conversation.id)
            .collection('messages')
            .where('isRead', isEqualTo: false)
            .get();

        // Filter messages from other users in memory
        for (final _doc in messages.docs) {
          final data = _doc.data();
          final senderId = data['senderId'] as String?;

          // Only update messages from other users
          if (senderId != null && senderId != currentUserId) {
            batch.update(_doc.reference, {'isRead': true});
          }
        }

        // Also update messages from current user to 'read' status if they're delivered
        final currentUserMessages = await _firestore
            .collection('conversations')
            .doc(conversation.id)
            .collection('messages')
            .where('senderId', isEqualTo: currentUserId)
            .get();

        for (final doc in currentUserMessages.docs) {
          final data = doc.data();
          final status = data['status'] as String?;

          if (status == 'sent' || status == 'delivered') {
            batch.update(doc.reference, {'status': 'read'});
          }
        }

        await batch.commit();

        // Update locally
        final updatedIndex =
            _conversations.indexWhere((c) => c.id == conversation.id);
        if (updatedIndex != -1) {
          // Update the local conversation object
          conversation.unreadCount = 0;
          _conversations[updatedIndex] = conversation;

          // If this is the currently selected conversation, update it too
          if (_selectedConversation?.id == conversation.id) {
            for (final message in _selectedConversation!.messages) {
              // Mark messages from other users as read
              if (message.senderId != currentUserId) {
                message.isRead = true;
              }
              // Update status of user's own messages
              else if (message.status == MessageStatus.sent ||
                  message.status == MessageStatus.delivered) {
                message.status = MessageStatus.read;
              }
            }
            _selectedConversation = _conversations[updatedIndex];
          }
        }

        // Recalculate filtered conversations to ensure badge counts update
        _applyFilters();

        // Notify UI of changes to update badges
        notifyListeners();
      } catch (e) {
        print('Error marking conversation as read: $e');
      }
    }
  }

  void markConversationAsUnread(Conversation conversation) async {
    await _firestore
        .collection('conversations')
        .doc(conversation.id)
        .update({'unreadCount': 1});
    notifyListeners();
  }

  void sendVoiceMessage(int durationSeconds) async {
    if (_selectedConversation == null) return;

    final accountProvider = AccountProvider();
    await accountProvider.initialize();

    final String messageId = const Uuid().v4();
    final DateTime timestamp = DateTime.now();

    final message = Message(
      id: messageId,
      senderId: currentUserId,
      senderName: accountProvider.currentUser?.firstName ?? 'You',
      content: TextStrings.voiceMessage,
      timestamp: timestamp,
      messageType: MessageType.voice,
      conversationId: _selectedConversation!.id,
      status: MessageStatus.sending,
      voiceDuration: durationSeconds, // Using the voiceDuration field
    );

    // Update UI immediately with the sending message
    _selectedConversation!.messages.insert(0, message);
    notifyListeners();

    try {
      // Write to Firestore
      await _firestore
          .collection('conversations')
          .doc(_selectedConversation!.id)
          .collection('messages')
          .doc(messageId)
          .set(message.toJson())
          .then((_) {
        // Update message status to 'sent' after successful write
        _updateMessageStatus(messageId, MessageStatus.sent);
      }).catchError((e) {
        debugPrint('[sendVoiceMessage] Error writing message: $e');
        // Mark as failed if there was an error
        _updateMessageStatus(messageId, MessageStatus.failed);
      });

      // Update conversation last message
      await _firestore
          .collection('conversations')
          .doc(_selectedConversation!.id)
          .update({
        'lastMessage': message.toJson(),
        'lastMessageTimestamp': FieldValue.serverTimestamp(),
      });

      // Simulate message being delivered after a short delay
      Future.delayed(const Duration(seconds: 1), () {
        _updateMessageStatus(messageId, MessageStatus.delivered);
      });
    } catch (e) {
      debugPrint('[sendVoiceMessage] Error: $e');
    }
  }

  Future<void> sendImageMessage(XFile imageFile, {String caption = ''}) async {
    notifyListeners();
  }

  Future<void> copyToClipboard(String text, BuildContext context) async {
    try {
      await Clipboard.setData(ClipboardData(text: text));
      if (context.mounted) {
        ResponsiveSnackBar.showSuccess(
          context: context,
          message: TextStrings.copiedToClipboard,
        );
      }
    } catch (e) {
      print("Failed to copy text: $e");
    }
  }

  Future<void> scrollToMessage(String messageId) async {
    print('scrollToMessage called for $messageId');
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
    if (_isDisposed) return; // Don't do anything if disposed

    if (_selectedConversation != null) {
      final prevIndex =
          _conversations.indexWhere((c) => c.id == _selectedConversation!.id);
      if (prevIndex != -1) {
        _conversations[prevIndex] = _selectedConversation!;
      }
    }

    final index = _conversations.indexWhere((c) => c.id == conversation.id);
    if (index != -1) {
      _selectedConversation = _conversations[index];
    } else {
      _selectedConversation = conversation;
    }

    if (_selectedConversation!.unreadCount > 0) {
      final updatedMessages = _selectedConversation!.messages.map((message) {
        return message.copyWith(isRead: true);
      }).toList();

      final updatedConversation = _selectedConversation!.copyWith(
        messages: updatedMessages,
        unreadCount: 0,
      );

      final updatedIndex =
          _conversations.indexWhere((c) => c.id == updatedConversation.id);
      if (updatedIndex != -1) {
        _conversations[updatedIndex] = updatedConversation;
        _selectedConversation = updatedConversation;
      }

      _applyFilters();
    }

    // Remove controller references - they're not needed anymore
    final updatedMessages = _selectedConversation!.messages.toList();

    final updatedConversation = _selectedConversation!.copyWith(
      messages: updatedMessages,
    );

    final updatedIndex =
        _conversations.indexWhere((c) => c.id == updatedConversation.id);
    if (updatedIndex != -1) {
      _conversations[updatedIndex] = updatedConversation;
      _selectedConversation = updatedConversation;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_isDisposed && messageScrollController.hasClients) {
        messageScrollController.animateTo(
          0.0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });

    _subscribeToTypingIndicators();

    notifyListeners();
  }

  void clearSelection() {
    _selectedConversation = null;
  }

  void clearSelectedConversationUI() {
    if (_selectedConversation != null) {
      final index =
          _conversations.indexWhere((c) => c.id == _selectedConversation!.id);
      if (index != -1) {
        _conversations[index] = _selectedConversation!;
      }
    }

    notifyListeners();
  }

  void setReplyToMessage(Message message) {
    _replyToMessage = message;
    notifyListeners();
  }

  void cancelReply() {
    _replyToMessage = null;
    notifyListeners();
  }

  void setEditingMessage(Message? message) {
    _editingMessage = message;
    // Prefill the message controller with the content to edit
    if (message != null) {
      messageController.text = message.content;
      messageController.selection = TextSelection.fromPosition(
        TextPosition(offset: messageController.text.length),
      );
    }
    notifyListeners();
  }

  void cancelEditing() {
    _editingMessage = null;
    messageController.clear();
    notifyListeners();
  }

  // Add the updateMessage method to handle editing
  Future<void> updateMessage(Message message, String newContent) async {
    if (_selectedConversation == null) return;
    
    try {
      // Get a reference to the message document in Firestore
      final messageRef = _firestore
          .collection('conversations')
          .doc(_selectedConversation!.id)
          .collection('messages')
          .doc(message.id);

      // Update the message in Firestore
      await messageRef.update({
        'content': newContent,
        'isEdited': true, // Mark the message as edited
      });

      // Find and update the in-memory message
      final index = _selectedConversation!.messages
          .indexWhere((msg) => msg.id == message.id);
      
      if (index != -1) {
        // Create a new message with updated properties
        _selectedConversation!.messages[index] = _selectedConversation!.messages[index].copyWith(
          content: newContent,
          isEdited: true,
        );
      }

      // Clear the editing state
      setEditingMessage(null);

      // Notify listeners that the message has been updated
      notifyListeners();
      
      // Show a debug print to verify this code is running
      debugPrint("Message updated with isEdited=true: ${message.id}");
      
    } catch (e) {
      debugPrint("Error updating message: $e");
      rethrow;
    }
  }

  void ensureMessageControllerReferences() {
    if (_isDisposed) return; // Don't do anything if already disposed

    for (final conversation in _conversations) {
      // No longer need to set controller references
      for (final message in conversation.messages) {
        // No longer need to set controller references
      }
    }
  }

  // Handle typing indicator
  void startTypingIndicator() {
    if (_selectedConversation == null) return;

    final now = DateTime.now();
    final shouldSendUpdate = _lastTypingNotification == null ||
        now.difference(_lastTypingNotification!).inSeconds >= 3;

    if (shouldSendUpdate) {
      _lastTypingNotification = now;

      // Send typing status to Firestore
      _firestore
          .collection('conversations')
          .doc(_selectedConversation!.id)
          .collection('typing')
          .doc(currentUserId)
          .set({
        'userId': currentUserId,
        'isTyping': true,
        'timestamp': FieldValue.serverTimestamp(),
      });
    }

    // Reset the typing timer
    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 5), _stopTypingIndicator);
  }

  void _stopTypingIndicator() {
    _typingTimer?.cancel();
    _typingTimer = null;

    if (_selectedConversation != null) {
      // Update Firestore to show user stopped typing
      _firestore
          .collection('conversations')
          .doc(_selectedConversation!.id)
          .collection('typing')
          .doc(currentUserId)
          .set({
        'userId': currentUserId,
        'isTyping': false,
        'timestamp': FieldValue.serverTimestamp(),
      });
    }
  }

  // Subscribe to typing indicators from other users
  void _subscribeToTypingIndicators() {
    if (_selectedConversation == null) return;

    final typingStream = _firestore
        .collection('conversations')
        .doc(_selectedConversation!.id)
        .collection('typing')
        .snapshots();

    final subscription = typingStream.listen((snapshot) {
      _typingUsers.clear();

      for (final doc in snapshot.docs) {
        final userId = doc.data()['userId'] as String;
        final isTyping = doc.data()['isTyping'] as bool;

        // Only add users who are not the current user and are typing
        if (userId != currentUserId && isTyping) {
          _typingUsers[userId] = isTyping;
        }
      }

      notifyListeners();
    });

    _subscriptions.add(subscription);
  }

  // Resets unread count for a specific conversation
  void resetUnreadCount(String conversationId) {
    final index = _conversations.indexWhere((c) => c.id == conversationId);
    if (index != -1) {
      final updatedConversation =
          _conversations[index].copyWith(unreadCount: 0);
      _conversations[index] = updatedConversation;

      // If this is the selected conversation, update that too
      if (_selectedConversation?.id == conversationId) {
        _selectedConversation = updatedConversation;
      }

      notifyListeners();
    }
  }

  @override
  void notifyListeners() {
    if (!_isDisposed) {
      super.notifyListeners();
    }
  }

  @override
  void dispose() {
    _isDisposed = true;

    // Cancel timers
    _typingTimer?.cancel();

    // Clean up controllers
    try {
      searchController.removeListener(_onSearchChanged);
      searchController.dispose();
    } catch (e) {
      // Ignore errors during disposal
    }

    try {
      messageController.dispose();
    } catch (e) {
      // Ignore errors during disposal
    }

    try {
      listScrollController.dispose();
    } catch (e) {
      // Ignore errors during disposal
    }

    try {
      messageScrollController.dispose();
    } catch (e) {
      // Ignore errors during disposal
    }

    // Stop any typing indicators when disposing
    try {
      _stopTypingIndicator();
    } catch (e) {
      // Ignore errors during disposal
    }

    // Cancel all subscriptions
    for (final subscription in _subscriptions) {
      try {
        subscription.cancel();
      } catch (e) {
        // Ignore errors during cancellation
      }
    }
    _subscriptions.clear();

    // Use try-catch when calling the super method
    try {
      super.dispose();
    } catch (e) {
      // Ignore errors during super.dispose()
    }
  }

  // Call this when user is typing a message
  void onMessageTyping(String text) {
    // Only trigger typing indicator if there's actual text
    if (text.isNotEmpty) {
      startTypingIndicator();
    } else {
      _stopTypingIndicator();
    }
  }
}
