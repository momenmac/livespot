import 'dart:core';
import 'dart:convert';
import 'dart:math';
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
import 'package:firebase_storage/firebase_storage.dart';
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
  final FirebaseStorage _storage = FirebaseStorage.instance;

  final AccountProvider accountProvider = AccountProvider();

  String get currentUserId {
    final user = accountProvider.currentUser;
    if (user != null && user.id != null && user.id.toString().isNotEmpty) {
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

  List<StreamSubscription> _subscriptions = [];

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

  String? _highlightedMessageId;
  String? get highlightedMessageId => _highlightedMessageId;

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
        snapshot.docs.map((doc) async => Conversation.fromFirestore(
            doc.data() as Map<String, dynamic>, users)),
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
        snapshot.docs.map((doc) async => Conversation.fromFirestore(
            doc.data() as Map<String, dynamic>, users)),
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

  Future<void> sendMessage(String content, {Message? replyTo}) async {
    // Debug: print selected conversation and content
    debugPrint('[sendMessage] selectedConversation: $_selectedConversation');
    debugPrint('[sendMessage] content: "$content"');

    if (_selectedConversation == null || content.trim().isEmpty) {
      debugPrint('[sendMessage] No selected conversation or empty content');
      return;
    }

    try {
      final messageId = const Uuid().v4();
      final timestamp = DateTime.now();

      debugPrint(
          '[sendMessage] Preparing message: $messageId, content="$content"');

      final message = Message(
        id: messageId,
        senderId: currentUserId,
        senderName: accountProvider.currentUser?.firstName ?? 'You',
        content: content.trim(),
        timestamp: timestamp,
        messageType: MessageType.text,
        conversationId: _selectedConversation!.id,
        replyToId: replyTo?.id,
        replyToSenderName: replyTo?.senderName,
        replyToContent: replyTo?.content,
        replyToMessageType: replyTo?.messageType,
        status: MessageStatus.sent,
      );

      debugPrint(
          '[sendMessage] Writing to Firestore: conversationId=${_selectedConversation!.id} messageId=$messageId');

      await _firestore
          .collection('conversations')
          .doc(_selectedConversation!.id)
          .collection('messages')
          .doc(messageId)
          .set(message.toJson())
          .then((_) => debugPrint('[sendMessage] Message written to Firestore'))
          .catchError(
              (e) => debugPrint('[sendMessage] Error writing message: $e'));

      debugPrint('[sendMessage] Updating conversation lastMessage');

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

      // Clear reply message after sending
      _replyToMessage = null;

      debugPrint('[sendMessage] Message send complete, notifyListeners()');
      notifyListeners();
    } catch (e, stack) {
      debugPrint('[sendMessage] Exception: $e');
      debugPrint('[sendMessage] Stack: $stack');
      notifyListeners();
      rethrow;
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

      await FirebaseFirestore.instance
          .collection('conversations')
          .doc(message.conversationId)
          .collection('messages')
          .doc(message.id)
          .update({
        'isRead': true,
      });

      message.isRead = true;
      notifyListeners();
    } catch (e) {
      print('Error marking message as read: $e');
    }
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
    final newMessageRef = _firestore
        .collection('conversations')
        .doc(targetConversation.id)
        .collection('messages')
        .doc();
    final forwardedMessage = Message(
      id: const Uuid().v4(),
      senderId: currentUserId,
      senderName: 'You',
      content: message.content,
      timestamp: DateTime.now(),
      messageType: message.messageType,
      mediaUrl: message.mediaUrl,
      voiceDuration: message.voiceDuration,
      status: MessageStatus.sending,
      isRead: false,
      forwardedFrom:
          message.senderId == currentUserId ? null : message.senderName,
      conversationId: targetConversation.id,
    );
    await newMessageRef.set(forwardedMessage.toJson());
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

  void markConversationAsRead(Conversation conversation) async {
    if (conversation.unreadCount > 0) {
      await _firestore
          .collection('conversations')
          .doc(conversation.id)
          .update({'unreadCount': 0});
      notifyListeners();
    }
  }

  void markConversationAsUnread(Conversation conversation) async {
    await _firestore
        .collection('conversations')
        .doc(conversation.id)
        .update({'unreadCount': 1});
    notifyListeners();
  }

  void sendVoiceMessage(int durationSeconds) {
    notifyListeners();
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

    final updatedMessages = _selectedConversation!.messages.map((message) {
      return message.copyWith(controller: this);
    }).toList();

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
      if (messageScrollController.hasClients) {
        messageScrollController.animateTo(
          0.0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });

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

  void setEditingMessage(Message message) {
    _editingMessage = message;
    messageController.text = message.content;
    notifyListeners();
  }

  void cancelEditing() {
    _editingMessage = null;
    messageController.clear();
    notifyListeners();
  }

  void ensureMessageControllerReferences() {
    for (final conversation in _conversations) {
      if (conversation.controller != this) {
        conversation.controller = this;
      }

      for (final message in conversation.messages) {
        if (message.controller != this) {
          message.controller = this;
        }
      }
    }

    if (_selectedConversation != null) {
      if (_selectedConversation!.controller != this) {
        _selectedConversation!.controller = this;
      }

      for (final message in _selectedConversation!.messages) {
        if (message.controller != this) {
          message.controller = this;
        }
      }
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

    searchController.removeListener(_onSearchChanged);
    searchController.dispose();
    messageController.dispose();
    listScrollController.dispose();
    messageScrollController.dispose();

    for (final subscription in _subscriptions) {
      subscription.cancel();
    }

    super.dispose();
  }
}
