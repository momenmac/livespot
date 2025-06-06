import 'dart:core';
import 'dart:convert';
import 'dart:async';
// Add this import for min function
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_application_2/constants/text_strings.dart';
import 'package:flutter_application_2/services/api/account/api_urls.dart';
import 'package:flutter_application_2/services/messaging/message_event_bus.dart';
import 'package:flutter_application_2/ui/pages/messages/models/conversation.dart';
import 'package:flutter_application_2/ui/pages/messages/models/message.dart';
import 'package:flutter_application_2/ui/pages/messages/models/user.dart';
import 'package:flutter_application_2/ui/widgets/responsive_snackbar.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_application_2/services/api/account/account_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_application_2/services/api/attachments/attachments_api.dart'
    as import_api;
import 'package:flutter_application_2/models/user_profile.dart'; // Add import for UserProfile class

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
    final apiBaseUrl = ApiUrls.baseUrl;
    final url = Uri.parse('$apiBaseUrl/api/accounts/all-users/');
    final response = await http.get(url);
    if (response.statusCode == 200) {
      final List<dynamic> userList = jsonDecode(response.body);
      return userList.map((user) => User.fromJson(user)).toList();
    } else {
      return [];
    }
  }

  // Fix the Firebase listener to handle per-user read status
  void _initFirebaseListeners() {
    try {
      // Clear any existing subscriptions to avoid duplicates
      _cancelSubscriptions();

      // Listen for conversation updates using snapshots for real-time updates
      final userConversations = _firestore
          .collection('conversations')
          .where('participants', arrayContains: currentUserId);

      final conversationSubscription =
          userConversations.snapshots().listen((snapshot) async {
        bool needsUpdate = false;
        bool unreadCountChanged = false;
        int previousTotalUnread = getTotalUnreadCount();

        // Process all changes - added, modified or removed conversations
        for (final change in snapshot.docChanges) {
          final conversationData = change.doc.data() as Map<String, dynamic>;
          final String conversationId = change.doc.id;

          // For both added and modified conversations
          if (change.type == DocumentChangeType.added ||
              change.type == DocumentChangeType.modified) {
            // Try to find existing conversation first
            final existingIndex =
                _conversations.indexWhere((c) => c.id == conversationId);

            // Get the last message data
            final lastMessageData = conversationData['lastMessage'];

            if (existingIndex != -1) {
              // Update existing conversation
              final oldUnreadCount = _conversations[existingIndex].unreadCount;

              // Update basic fields
              _conversations[existingIndex].isMuted =
                  conversationData['isMuted'] ?? false;
              _conversations[existingIndex].isArchived =
                  conversationData['isArchived'] ?? false;

              // Update the lastMessage if provided and different from current one
              bool hasNewMessage = false;
              if (lastMessageData != null) {
                final String lastMessageId = lastMessageData['id'] ?? '';
                final String currentLastMessageId =
                    _conversations[existingIndex].lastMessage.id;

                hasNewMessage = lastMessageId.isNotEmpty &&
                    lastMessageId != currentLastMessageId;

                if (hasNewMessage) {
                  debugPrint(
                      '[ConvListener] New message detected for conversation $conversationId');

                  // Create the message object
                  final Message lastMsg = Message.fromJson({
                    ...lastMessageData as Map<String, dynamic>,
                    'id': lastMessageData['id'] ??
                        'temp-${DateTime.now().millisecondsSinceEpoch}',
                  });

                  // Update the conversation with the new last message
                  _conversations[existingIndex].lastMessage = lastMsg;

                  // Most important part: Check if this is from someone else
                  // and immediately mark it as unread in memory
                  if (lastMsg.senderId != currentUserId) {
                    debugPrint(
                        '[ConvListener] Message is from another user - marking as unread');
                    // Mark as unread and trigger update immediately
                    _conversations[existingIndex].unreadCount = 1;
                    needsUpdate = true;
                    unreadCountChanged = true;
                  }

                  // Detailed logging for debugging
                  final preview = lastMsg.content.length > 20
                      ? "${lastMsg.content.substring(0, 20)}..."
                      : lastMsg.content;

                  debugPrint('[ConvListener] Updated lastMessage: "$preview" '
                      'from: ${lastMsg.senderId}, '
                      'current user: $currentUserId, '
                      'unreadCount: ${_conversations[existingIndex].unreadCount}');
                }
              }

              // Check if unread count changed
              final newUnreadCount = _conversations[existingIndex].unreadCount;
              if (oldUnreadCount != newUnreadCount) {
                debugPrint(
                    '[ConvListener] Unread count changed: $oldUnreadCount -> $newUnreadCount for conv $conversationId');
                unreadCountChanged = true;
                needsUpdate = true;
              }

              // If this conversation is the selected one, update its reference too
              if (_selectedConversation?.id == conversationId) {
                _selectedConversation = _conversations[existingIndex];
              }
            } else {
              // New conversation - fetch all users first for full info
              _fetchAllUsers().then((users) async {
                final newConversation =
                    Conversation.fromFirestore(conversationData, users);

                // Check read status for new conversation
                try {
                  // Get the last message sender
                  final String lastMessageSenderId =
                      newConversation.lastMessage.senderId;

                  // If last message is not from current user, check read status
                  if (lastMessageSenderId != currentUserId) {
                    final readStatusDoc = await _firestore
                        .collection('conversations')
                        .doc(conversationId)
                        .collection('readStatus')
                        .doc(currentUserId)
                        .get();

                    if (readStatusDoc.exists) {
                      final bool isRead =
                          readStatusDoc.data()?['isRead'] ?? true;
                      if (!isRead) {
                        // Mark as unread for this user
                        newConversation.unreadCount = 1;
                      } else {
                        newConversation.unreadCount = 0;
                      }
                    } else {
                      // No read status yet, so mark as unread
                      newConversation.unreadCount = 1;
                    }
                  } else {
                    // Message from current user is always read to them
                    newConversation.unreadCount = 0;
                  }
                } catch (e) {
                  debugPrint(
                      'Error checking read status for new conversation: $e');
                }

                _conversations.add(newConversation);
                debugPrint(
                    '[ConvListener] Added new conversation: ${newConversation.id}');

                if (newConversation.unreadCount > 0) {
                  unreadCountChanged = true;
                }

                // Re-apply filters and notify
                _applyFilters();
                notifyListeners();

                // Also notify MessageEventBus if unread count changed
                if (unreadCountChanged) {
                  final newTotalUnread = getTotalUnreadCount();
                  MessageEventBus().notifyUnreadCountChanged(newTotalUnread);
                }
              });
            }
          } else if (change.type == DocumentChangeType.removed) {
            // Remove deleted conversation
            final index =
                _conversations.indexWhere((c) => c.id == conversationId);
            if (index != -1) {
              final removedConv = _conversations.removeAt(index);
              debugPrint(
                  '[ConvListener] Removed conversation: $conversationId');

              // If this was the selected conversation, clear it
              if (_selectedConversation?.id == conversationId) {
                _selectedConversation = null;
              }

              // Check if removing this affects unread count
              if (removedConv.unreadCount > 0) {
                unreadCountChanged = true;
              }

              needsUpdate = true;
            }
          }
        }

        // Apply changes if needed - only if we actually have changes to apply
        if (needsUpdate) {
          debugPrint('[ConvListener] Applying filter and updating UI');
          _applyFilters();
          notifyListeners();

          // Check if total unread count changed
          if (unreadCountChanged) {
            final newTotalUnread = getTotalUnreadCount();
            if (previousTotalUnread != newTotalUnread) {
              debugPrint(
                  '[ConvListener] Total unread changed: $previousTotalUnread -> $newTotalUnread');
              MessageEventBus().notifyUnreadCountChanged(newTotalUnread);
            }
          }
        }
      });

      _subscriptions.add(conversationSubscription);
    } catch (e) {
      debugPrint('Error setting up Firebase listeners: $e');
    }
  }

  // Helper method to cancel all subscriptions
  void _cancelSubscriptions() {
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    _subscriptions.clear();
  }

  // Load conversations with proper handling of per-user read status
  Future<void> loadConversations() async {
    try {
      final users = await _fetchAllUsers();
      final snapshot = await _firestore
          .collection('conversations')
          .where('participants', arrayContains: currentUserId)
          .get();

      // Create a list to hold the conversations
      List<Conversation> conversationsData = await Future.wait(
        snapshot.docs.map((doc) async {
          // First create basic conversation with server data
          final conversation = Conversation.fromFirestore(doc.data(), users);

          // Then check per-user read status
          try {
            // 1. Get the last message timestamp for this conversation
            final lastMessageTimestamp = conversation.lastMessage.timestamp;

            // 2. Check the read status document for current user
            final readStatusDoc = await _firestore
                .collection('conversations')
                .doc(conversation.id)
                .collection('readStatus')
                .doc(currentUserId)
                .get();

            if (readStatusDoc.exists) {
              // Get the isRead status
              final bool isRead = readStatusDoc.data()?['isRead'] ?? true;

              // Get the last time this user read the conversation
              final lastReadTimestamp =
                  readStatusDoc.data()?['lastReadTimestamp'];
              Timestamp? lastReadTimestampObj;

              if (lastReadTimestamp != null) {
                if (lastReadTimestamp is Timestamp) {
                  lastReadTimestampObj = lastReadTimestamp;
                }
              }

              // Logic: A conversation is unread if explicitly marked as unread OR
              // if the last message is newer than the last read timestamp
              if (!isRead ||
                  (lastReadTimestampObj != null &&
                      lastMessageTimestamp
                          .isAfter(lastReadTimestampObj.toDate()))) {
                // Mark this conversation as having unread messages for this user
                conversation.unreadCount = 1;
              } else {
                // Otherwise mark as read
                conversation.unreadCount = 0;
              }
            } else if (conversation.lastMessage.senderId != currentUserId) {
              // If there's no read status yet and the last message is not from current user,
              // consider it unread
              conversation.unreadCount = 1;
            } else {
              // Current user's own messages are always read
              conversation.unreadCount = 0;
            }
          } catch (e) {
            debugPrint(
                'Error processing read status for conversation ${conversation.id}: $e');
          }

          return conversation;
        }),
      );

      _conversations = conversationsData;
      _applyFilters();
      notifyListeners();
      return;
    } catch (e) {
      debugPrint('Error loading conversations: $e');
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
      isRead: true, // Messages from current user are always read by them
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

      // Update conversation last message and mark as unread for other participants
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

      // Mark conversation as unread for all participants except the sender
      for (final participant in _selectedConversation!.participants) {
        if (participant.id != currentUserId) {
          // Set as unread for other participants
          await _firestore
              .collection('conversations')
              .doc(_selectedConversation!.id)
              .collection('readStatus')
              .doc(participant.id)
              .set({
            'userId': participant.id,
            'isRead': false,
            'lastReadTimestamp': FieldValue.serverTimestamp(),
          });
        } else {
          // Explicitly mark as read for the sender
          await _firestore
              .collection('conversations')
              .doc(_selectedConversation!.id)
              .collection('readStatus')
              .doc(currentUserId)
              .set({
            'userId': currentUserId,
            'isRead': true,
            'lastReadTimestamp': FieldValue.serverTimestamp(),
          });
        }
      }

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

  // Update the status of a message with better error handling and synchronization
  void _updateMessageStatus(String messageId, MessageStatus newStatus) {
    if (_selectedConversation == null) return;

    try {
      debugPrint(
          '[updateMessageStatus] Updating message $messageId to $newStatus');
      // Find and update message in memory
      final index =
          _selectedConversation!.messages.indexWhere((m) => m.id == messageId);
      if (index != -1) {
        // Only update if new status is different or an advancement in status
        final currentStatus = _selectedConversation!.messages[index].status;
        final shouldUpdate = newStatus != currentStatus &&
            (currentStatus == MessageStatus.sending ||
                (currentStatus == MessageStatus.sent &&
                    newStatus != MessageStatus.sending) ||
                (currentStatus == MessageStatus.delivered &&
                    newStatus == MessageStatus.read));

        if (shouldUpdate) {
          _selectedConversation!.messages[index].status = newStatus;

          // Update in Firestore with a structured approach
          final messageRef = _firestore
              .collection('conversations')
              .doc(_selectedConversation!.id)
              .collection('messages')
              .doc(messageId);

          // Get current message data first to validate before updating
          messageRef.get().then((doc) {
            if (doc.exists) {
              // Continue with update only if message exists
              messageRef.update(
                  {'status': newStatus.toString().split('.').last}).then((_) {
                debugPrint(
                    '[updateMessageStatus] Successfully updated status in Firestore');

                // If this is read status, also ensure isRead is set to true
                if (newStatus == MessageStatus.read) {
                  messageRef.update({'isRead': true});
                  _selectedConversation!.messages[index].isRead = true;
                }

                notifyListeners(); // Notify after successful Firestore update
              }).catchError((e) {
                debugPrint('[updateMessageStatus] Error updating status: $e');
                notifyListeners(); // Still update UI even if Firestore update fails
              });
            } else {
              debugPrint(
                  '[updateMessageStatus] Message document does not exist');
            }
          }).catchError((e) {
            debugPrint('[updateMessageStatus] Error reading message: $e');
          });
        } else {
          debugPrint(
              '[updateMessageStatus] Status update not needed or would be a regression');
        }
      } else {
        debugPrint(
            '[updateMessageStatus] Message not found in conversation: $messageId');
      }
    } catch (e) {
      debugPrint('[updateMessageStatus] Error: $e');
      // Make sure UI is updated even in case of error
      notifyListeners();
    }
  }

  // Check if all participants (except the current user) have read a message
  Future<bool> checkReadReceiptsForMessage(Message message) async {
    if (message.senderId != currentUserId) {
      return false; // Only check read receipts for messages sent by current user
    }
    if (_selectedConversation == null) return false;

    try {
      // First check if the message is already marked as read
      if (message.status == MessageStatus.read) return true;

      // Get read statuses for all other participants
      final otherParticipants = _selectedConversation!.participants
          .where((p) => p.id != currentUserId)
          .toList();

      // If there are no other participants, return false
      if (otherParticipants.isEmpty) return false;

      // Check read status for each participant
      bool allRead = true;
      for (final participant in otherParticipants) {
        final readStatusDoc = await _firestore
            .collection('conversations')
            .doc(_selectedConversation!.id)
            .collection('readStatus')
            .doc(participant.id)
            .get();

        if (readStatusDoc.exists) {
          final isRead = readStatusDoc.data()?['isRead'] ?? false;
          final lastReadTimestamp = readStatusDoc.data()?['lastReadTimestamp'];

          if (!isRead) {
            debugPrint(
                '[ReadReceipt] User ${participant.id} has not read conversation');
            allRead = false;
            break;
          }

          // Check if the lastReadTimestamp is after the message timestamp
          if (lastReadTimestamp != null) {
            final lastRead = (lastReadTimestamp as Timestamp).toDate();
            if (lastRead.isBefore(message.timestamp)) {
              debugPrint(
                  '[ReadReceipt] User ${participant.id} read status is before message timestamp');
              allRead = false;
              break;
            }
          } else {
            // No timestamp means they haven't read the message
            debugPrint(
                '[ReadReceipt] User ${participant.id} has no read timestamp');
            allRead = false;
            break;
          }
        } else {
          // No read status means they haven't read the message
          debugPrint(
              '[ReadReceipt] User ${participant.id} has no read status document');
          allRead = false;
          break;
        }
      }

      if (allRead) {
        debugPrint(
            '[ReadReceipt] Message ${message.id} has been read by all participants');
      }
      return allRead;
    } catch (e) {
      debugPrint('[checkReadReceiptsForMessage] Error: $e');
      return false;
    }
  }

  // Explicitly check and update read receipts for all messages in the conversation
  Future<void> updateReadReceiptsForAllMessages() async {
    if (_selectedConversation == null) return;

    try {
      // Only process user's own messages
      final ownMessages = _selectedConversation!.messages
          .where((msg) =>
              msg.senderId == currentUserId &&
              msg.status != MessageStatus.read &&
              msg.status != MessageStatus.failed)
          .toList();

      for (final message in ownMessages) {
        final bool isReadByAll = await checkReadReceiptsForMessage(message);
        if (isReadByAll && message.status != MessageStatus.read) {
          _updateMessageStatus(message.id, MessageStatus.read);
        } else if (message.status == MessageStatus.sending) {
          // Ensure messages aren't stuck in sending state
          _updateMessageStatus(message.id, MessageStatus.sent);
        }
      }
    } catch (e) {
      debugPrint('[updateReadReceiptsForAllMessages] Error: $e');
    }
  }

  // Public method to update message status that can be called from outside
  void updateMessageStatus(String messageId, MessageStatus newStatus) {
    _updateMessageStatus(messageId, newStatus);
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
    // Reset the count just to be safe
    int total = 0;

    // Iterate through all conversations and sum up their unread counts
    for (final conversation in _conversations) {
      // Skip counting if the message is from the current user
      if (conversation.lastMessage.senderId != currentUserId) {
        total += conversation.unreadCount;
      } else {
        // If the last message is from the current user, the conversation should not be unread for them
        // If it's showing as unread, fix it
        if (conversation.unreadCount > 0) {
          debugPrint(
              '[UnreadFix] Correcting unread count for conversation ${conversation.id}');
          conversation.unreadCount = 0;
        }
      }
    }

    debugPrint('[UnreadCount] Current total unread count: $total');
    return total;
  }

  // Add a method to validate unread status for all conversations
  Future<void> validateUnreadCounts() async {
    debugPrint(
        '[UnreadValidation] Starting validation of all conversation unread counts');

    for (final conversation in _conversations) {
      // The current user's sent messages should never count as unread to them
      if (conversation.lastMessage.senderId == currentUserId &&
          conversation.unreadCount > 0) {
        debugPrint(
            '[UnreadValidation] Fixing conversation ${conversation.id}: lastMessage from current user but showing unread');

        // Fix in-memory count
        conversation.unreadCount = 0;

        // Also update the read status in Firestore
        try {
          await _firestore
              .collection('conversations')
              .doc(conversation.id)
              .collection('readStatus')
              .doc(currentUserId)
              .set({
            'userId': currentUserId,
            'isRead': true,
            'lastReadTimestamp': FieldValue.serverTimestamp(),
          });

          debugPrint(
              '[UnreadValidation] Updated read status for conversation ${conversation.id}');
        } catch (e) {
          debugPrint('[UnreadValidation] Error updating read status: $e');
        }
      }
    }

    // Apply filters and notify listeners of any changes
    _applyFilters();
    notifyListeners();

    // Update the global unread count for UI
    final newTotalUnread = getTotalUnreadCount();
    MessageEventBus().notifyUnreadCountChanged(newTotalUnread);

    debugPrint(
        '[UnreadValidation] Validation complete. Total unread: $newTotalUnread');
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
    try {
      // Determine the new muted state - opposite of current
      final newMutedState = !conversation.isMuted;

      // Update in Firestore
      await _firestore
          .collection('conversations')
          .doc(conversation.id)
          .update({'isMuted': newMutedState});

      // Update local conversation object directly
      final index = _conversations.indexWhere((c) => c.id == conversation.id);
      if (index != -1) {
        _conversations[index].isMuted = newMutedState;
      }

      // Update selected conversation if needed
      if (_selectedConversation?.id == conversation.id) {
        _selectedConversation!.isMuted = newMutedState;
      }

      // Reapply filters to update UI
      _applyFilters();
      notifyListeners();
    } catch (e) {
      debugPrint('Error toggling mute: $e');
    }
  }

  void toggleArchive(Conversation conversation) async {
    try {
      // Determine the new archived state - opposite of current
      final newArchivedState = !conversation.isArchived;

      // Update in Firestore
      await _firestore
          .collection('conversations')
          .doc(conversation.id)
          .update({'isArchived': newArchivedState});

      // Update local conversation object directly
      final index = _conversations.indexWhere((c) => c.id == conversation.id);
      if (index != -1) {
        _conversations[index].isArchived = newArchivedState;
      }

      // Update selected conversation if needed
      if (_selectedConversation?.id == conversation.id) {
        _selectedConversation!.isArchived = newArchivedState;
      }

      // Reapply filters to update UI
      _applyFilters();
      notifyListeners();
    } catch (e) {
      debugPrint('Error toggling archive: $e');
    }
  }

  Future<void> updateConversation(Conversation conversation) async {
    try {
      // Update conversation in Firestore
      await _firestore.collection('conversations').doc(conversation.id).update({
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
    try {
      debugPrint(
          '[READ] Marking conversation ${conversation.id} as read for user $currentUserId');

      // 1. First ensure we have a valid user ID before proceeding
      if (currentUserId.isEmpty) {
        debugPrint('⚠️ [READ] Cannot mark as read: currentUserId is empty');
        return;
      }

      // 2. Update read status in Firestore with additional error handling
      try {
        await _firestore
            .collection('conversations')
            .doc(conversation.id)
            .collection('readStatus')
            .doc(currentUserId)
            .set({
          'userId': currentUserId,
          'isRead': true,
          'lastReadTimestamp': FieldValue.serverTimestamp(),
        });
        debugPrint('[READ] ✓ Successfully updated read status document');
      } catch (e) {
        debugPrint('[READ] ⚠️ Error updating read status document: $e');
        // Continue with other operations even if this one fails
      }

      // 3. Mark all messages in this conversation as read
      try {
        final unreadMessagesQuery = await _firestore
            .collection('conversations')
            .doc(conversation.id)
            .collection('messages')
            .where('isRead', isEqualTo: false)
            .get();

        debugPrint(
            '[READ] Found ${unreadMessagesQuery.docs.length} unread messages to update');

        if (unreadMessagesQuery.docs.isNotEmpty) {
          final batch = _firestore.batch();
          int updateCount = 0;

          for (final messageDoc in unreadMessagesQuery.docs) {
            final messageData = messageDoc.data();
            final senderId = messageData['senderId'] as String? ?? '';

            // Skip messages that aren't properly formed
            if (messageDoc.id.isEmpty) continue;

            batch.update(messageDoc.reference, {'isRead': true});
            updateCount++;

            // Update status to "read" for sender's visibility (only for others' messages)
            if (senderId != currentUserId && senderId.isNotEmpty) {
              batch.update(messageDoc.reference, {'status': 'read'});
            }
          }

          if (updateCount > 0) {
            await batch.commit();
            debugPrint(
                '[READ] ✓ Successfully marked $updateCount messages as read');
          }
        }
      } catch (e) {
        debugPrint('[READ] ⚠️ Error marking messages as read: $e');
        // Continue with in-memory updates regardless
      }

      // 4. Update the conversation's unreadCount in the database
      // (using set with merge rather than update to handle missing fields)
      try {
        await _firestore
            .collection('conversations')
            .doc(conversation.id)
            .set({'unreadCount': 0}, SetOptions(merge: true));
        debugPrint(
            '[READ] ✓ Successfully reset conversation unread count in Firestore');
      } catch (e) {
        debugPrint('[READ] ⚠️ Error updating conversation unread count: $e');
      }

      // 5. Always update local conversation object
      // Even if the previous operations failed, we want the UI to reflect "read" status
      conversation.unreadCount = 0;

      // 6. Also update any messages in memory if this is the selected conversation
      if (_selectedConversation?.id == conversation.id) {
        for (final message in _selectedConversation!.messages) {
          message.isRead = true;
          // Update status to read for messages from others
          if (message.senderId != currentUserId &&
              message.status != MessageStatus.read) {
            message.status = MessageStatus.read;
          }
        }
        _selectedConversation = conversation;
      }

      // 7. Update local state
      final index = _conversations.indexWhere((c) => c.id == conversation.id);
      if (index >= 0) {
        _conversations[index] = conversation;
      }

      // 8. Reapply filters to ensure list display is updated
      _applyFilters();

      // 9. Notify listeners to update the UI
      notifyListeners();

      // 10. Notify event bus of changes - do this after UI is updated
      final updatedTotalUnreadCount = getTotalUnreadCount();
      MessageEventBus().notifyUnreadCountChanged(updatedTotalUnreadCount);
      MessageEventBus().notifyConversationChanged(conversation.id);

      debugPrint(
          '[READ] ✅ Successfully marked conversation ${conversation.id} as read. Updated badge count: $updatedTotalUnreadCount');
    } catch (e) {
      debugPrint('[READ] ❌ Error marking conversation as read: $e');
      // Final attempt to update local state even if all else fails
      try {
        conversation.unreadCount = 0;
        notifyListeners();
      } catch (_) {}
    }
  }

  Future<void> markConversationAsUnread(Conversation conversation) async {
    try {
      debugPrint(
          '[UNREAD] Marking conversation ${conversation.id} as unread for user $currentUserId');

      // 1. First ensure we have a valid user ID before proceeding
      if (currentUserId.isEmpty) {
        debugPrint('⚠️ [UNREAD] Cannot mark as unread: currentUserId is empty');
        return;
      }

      // 2. Update read status in Firestore with error handling
      try {
        await _firestore
            .collection('conversations')
            .doc(conversation.id)
            .collection('readStatus')
            .doc(currentUserId)
            .set({
          'userId': currentUserId,
          'isRead': false,
          'lastReadTimestamp': FieldValue.serverTimestamp(),
        });
        debugPrint('[UNREAD] ✓ Successfully updated read status document');
      } catch (e) {
        debugPrint('[UNREAD] ⚠️ Error updating read status document: $e');
        // Continue with other operations even if this fails
      }

      // 3. Update local conversation object for UI feedback regardless of Firestore success
      conversation.unreadCount = 1;

      // 4. Update local state
      final index = _conversations.indexWhere((c) => c.id == conversation.id);
      if (index >= 0) {
        _conversations[index] = conversation;
      }

      // 5. Recalculate filtered conversations
      _applyFilters();

      // 6. Notify UI of changes
      notifyListeners();

      // 7. Make sure to update the conversation in Firestore too (this was missing before)
      try {
        await _firestore
            .collection('conversations')
            .doc(conversation.id)
            .set({'unreadCount': 1}, SetOptions(merge: true));
        debugPrint(
            '[UNREAD] ✓ Successfully updated conversation unread count in Firestore');
      } catch (e) {
        debugPrint('[UNREAD] ⚠️ Error updating conversation unread count: $e');
      }

      // 8. Calculate the updated total unread count
      final totalUnreadCount = getTotalUnreadCount();

      // 9. Force a notification to the navigation bar with the updated count
      MessageEventBus().notifyUnreadCountChanged(totalUnreadCount);
      MessageEventBus().notifyConversationChanged(conversation.id);

      // 10. Extra notification after a delay to ensure UI updates
      // Sometimes the first notification might be missed due to timing issues
      await Future.delayed(const Duration(milliseconds: 300), () {
        if (!_isDisposed) {
          final refreshedCount = getTotalUnreadCount();
          MessageEventBus().notifyUnreadCountChanged(refreshedCount);
          debugPrint(
              '[UNREAD] Sent delayed unread count update: $refreshedCount');
        }
      });

      debugPrint(
          '[UNREAD] ✅ Successfully marked conversation as unread for user $currentUserId. Updated badge count: $totalUnreadCount');
    } catch (e) {
      debugPrint('[UNREAD] ❌ Error marking conversation as unread: $e');
      // Final attempt to update local state even if all else fails
      try {
        conversation.unreadCount = 1;
        notifyListeners();

        // Even on error, try to update the badge
        final count = getTotalUnreadCount();
        MessageEventBus().notifyUnreadCountChanged(count);
      } catch (_) {}
    }
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
    if (_selectedConversation == null) return;

    try {
      // Show sending state immediately
      final String messageId = const Uuid().v4();
      final DateTime timestamp = DateTime.now();
      final String displayCaption = caption.isEmpty ? 'Image' : caption;

      // Create temporary message to show loading state
      final message = Message(
        id: messageId,
        senderId: currentUserId,
        senderName: accountProvider.currentUser?.firstName ?? 'You',
        content: displayCaption,
        timestamp: timestamp,
        messageType: MessageType.image,
        conversationId: _selectedConversation!.id,
        status: MessageStatus.sending,
        isRead: true, // Message from current user is always read by them
      );

      // Update UI immediately with sending state
      _selectedConversation!.messages.insert(0, message);
      notifyListeners();

      // Import the AttachmentsApi only when needed
      // ignore: unused_local_variable
      final attachmentsApi = await _getAttachmentsApi();

      // Upload the image to server
      final firebaseUrl =
          await attachmentsApi.uploadFile(imageFile, contentType: 'image');

      if (firebaseUrl == null) {
        debugPrint('[sendImageMessage] Failed to upload image');
        _updateMessageStatus(messageId, MessageStatus.failed);
        return;
      }

      // Update the message with the uploaded URL
      final updatedMessage = message.copyWith(
        mediaUrl: firebaseUrl,
        status: MessageStatus.sent,
      );

      // Update in memory
      final index =
          _selectedConversation!.messages.indexWhere((m) => m.id == messageId);
      if (index != -1) {
        _selectedConversation!.messages[index] = updatedMessage;
      }

      // Save to Firestore
      await _firestore
          .collection('conversations')
          .doc(_selectedConversation!.id)
          .collection('messages')
          .doc(messageId)
          .set(updatedMessage.toJson())
          .then((_) {
        debugPrint('[sendImageMessage] Message written to Firestore');
      }).catchError((e) {
        debugPrint('[sendImageMessage] Error writing message: $e');
        _updateMessageStatus(messageId, MessageStatus.failed);
        return;
      });

      // Update conversation last message
      await _firestore
          .collection('conversations')
          .doc(_selectedConversation!.id)
          .update({
        'lastMessage': updatedMessage.toJson(),
        'lastMessageTimestamp': FieldValue.serverTimestamp(),
      });

      // Mark conversation as unread for all participants except sender
      for (final participant in _selectedConversation!.participants) {
        if (participant.id != currentUserId) {
          await _firestore
              .collection('conversations')
              .doc(_selectedConversation!.id)
              .collection('readStatus')
              .doc(participant.id)
              .set({
            'userId': participant.id,
            'isRead': false,
            'lastReadTimestamp': FieldValue.serverTimestamp(),
          });
        } else {
          await _firestore
              .collection('conversations')
              .doc(_selectedConversation!.id)
              .collection('readStatus')
              .doc(currentUserId)
              .set({
            'userId': currentUserId,
            'isRead': true,
            'lastReadTimestamp': FieldValue.serverTimestamp(),
          });
        }
      }

      notifyListeners();

      // Simulate message being delivered after a short delay
      Future.delayed(const Duration(seconds: 1), () {
        _updateMessageStatus(messageId, MessageStatus.delivered);
      });
    } catch (e) {
      debugPrint('[sendImageMessage] Error: $e');
    }
  }

  // Helper method to load the AttachmentsApi lazily
  Future<dynamic> _getAttachmentsApi() async {
    // Using dynamic to avoid import cycle issues
    try {
      // Instead of using dynamic import, create the instance directly
      return await Future.value(import_api.AttachmentsApi());
    } catch (e) {
      debugPrint('[_getAttachmentsApi] Error loading API: $e');
      rethrow;
    }
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

  // Modified to properly handle read receipts when selecting conversation
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

    // We don't auto-mark as read here because ChatDetailPage will take care of that
    // This allows the badge to persist until explicitly read in the chat

    // Set up timer to periodically check for read receipts once conversation is selected
    _setupReadReceiptChecking();

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

  // Set up periodic checking of read receipts
  Timer? _readReceiptTimer;
  void _setupReadReceiptChecking() {
    // Cancel any existing timer
    _readReceiptTimer?.cancel();

    // Start a new periodic timer
    _readReceiptTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (_selectedConversation != null && !_isDisposed) {
        updateReadReceiptsForAllMessages();
      }
    });
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
      // Special handling for web platforms to ensure proper focus and selection
      messageController.text = message.content;

      // Use a small delay to ensure the text field gets proper focus on web
      Future.delayed(const Duration(milliseconds: 50), () {
        if (!_isDisposed) {
          // Set cursor position at the end with proper selection
          messageController.selection = TextSelection.fromPosition(
            TextPosition(offset: messageController.text.length),
          );

          // Request focus on the field if needed
          FocusManager.instance.primaryFocus?.unfocus();

          // Force a refresh to ensure UI updates correctly
          notifyListeners();
        }
      });
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

      debugPrint(
          "Updating message ${message.id} with new content: $newContent");

      // First update our local message immediately for a responsive UI
      final index = _selectedConversation!.messages
          .indexWhere((msg) => msg.id == message.id);

      if (index != -1) {
        // Create a new message with updated properties
        _selectedConversation!.messages[index] =
            _selectedConversation!.messages[index].copyWith(
          content: newContent,
          isEdited: true,
        );
        // Force UI update right away
        notifyListeners();
      }

      // Update the message in Firestore
      await messageRef.update({
        'content': newContent,
        'isEdited': true, // Mark the message as edited
      }).catchError((e) {
        debugPrint("Error updating message in Firestore: $e");
        // Revert the local change if Firestore update fails
        if (index != -1) {
          _selectedConversation!.messages[index] = message;
          notifyListeners();
        }
        return Future.error(e);
      });

      // Clear the editing state
      cancelEditing();

      // Show a debug print to verify this code is running
      debugPrint(
          "✅ Message successfully updated with isEdited=true: ${message.id}");
    } catch (e) {
      debugPrint("❌ Error updating message: $e");
      // Make sure editing is canceled even if there was an error
      cancelEditing();
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

  // Check if a message has been read by all participants
  bool isMessageReadByAll(Message message) {
    // If this isn't from the current user, we don't care about read receipts
    if (message.senderId != currentUserId) return false;

    if (_selectedConversation == null) return false;

    // First check message status - if it's already marked as read, return true
    if (message.status == MessageStatus.read) return true;

    // For one-on-one conversations, if the message is delivered and the other person has read something,
    // we can infer this message has been read
    if (_selectedConversation!.participants.length == 2 &&
        message.status == MessageStatus.delivered) {
      // Find the last message from other participant
      final otherParticipantId = _selectedConversation!.participants
          .firstWhere((user) => user.id != currentUserId)
          .id;

      // If the other user has sent a message after this one, we can assume they've read this message
      final newerMessages = _selectedConversation!.messages
          .where((msg) =>
              msg.senderId == otherParticipantId &&
              msg.timestamp.isAfter(message.timestamp))
          .toList();

      return newerMessages.isNotEmpty;
    }

    return false;
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
    _readReceiptTimer?.cancel();

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

  // Create or get a conversation with a user
  Future<Conversation?> createOrGetConversation(UserProfile userProfile) async {
    try {
      final String otherUserId = userProfile.account.id.toString();

      // Check if current user id is valid
      if (currentUserId.isEmpty) {
        debugPrint('[createOrGetConversation] Current user ID is empty');
        return null;
      }

      // First check if conversation already exists
      final querySnapshot = await _firestore
          .collection('conversations')
          .where('participants', arrayContains: currentUserId)
          .get();

      // Search for existing conversation with this user
      for (final doc in querySnapshot.docs) {
        final data = doc.data();
        final List<dynamic> participants = data['participants'] ?? [];

        // Check if this is a one-on-one conversation with the target user
        if (participants.length == 2 &&
            participants.contains(otherUserId) &&
            participants.contains(currentUserId)) {
          debugPrint(
              '[createOrGetConversation] Found existing conversation: ${doc.id}');

          // Load all users to properly populate the conversation
          final users = await _fetchAllUsers();

          // Create and return the conversation object
          return Conversation.fromFirestore(data, users);
        }
      }

      // No existing conversation found, create a new one
      debugPrint(
          '[createOrGetConversation] Creating new conversation with user: ${userProfile.username}');

      // Generate a unique ID for the conversation
      final String conversationId =
          _firestore.collection('conversations').doc().id;

      // Create a user object for the other participant
      final otherUser = User(
        id: otherUserId,
        name: userProfile.fullName,
        avatarUrl: userProfile.profilePictureUrl,
      );

      // Create a user object for the current user
      final currentUser = User(
        id: currentUserId,
        name: accountProvider.currentUser?.firstName ?? 'You',
        avatarUrl: accountProvider.currentUser?.profilePictureUrl ?? '',
      );

      // Create an initial message
      final messageId = const Uuid().v4();
      final now = DateTime.now();
      final message = Message(
        id: messageId,
        senderId: currentUserId,
        senderName: currentUser.name,
        content: 'Started a conversation',
        timestamp: now,
        conversationId: conversationId,
        status: MessageStatus.sent,
        messageType: MessageType.system, // Mark as a system message
        isRead: true,
      );

      // Create conversation document
      final conversationData = {
        'id': conversationId,
        'participants': [currentUserId, otherUserId],
        'participantDetails': [
          {
            'id': currentUserId,
            'name': currentUser.name,
            'avatarUrl': currentUser.avatarUrl,
          },
          {
            'id': otherUserId,
            'name': otherUser.name,
            'avatarUrl': otherUser.avatarUrl,
          },
        ],
        'lastMessage': message.toJson(),
        'lastMessageTimestamp': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'isMuted': false,
        'isArchived': false,
        'isGroup': false,
      };

      // Create the conversation in Firestore
      await _firestore
          .collection('conversations')
          .doc(conversationId)
          .set(conversationData);

      // Add the initial message to the conversation
      await _firestore
          .collection('conversations')
          .doc(conversationId)
          .collection('messages')
          .doc(messageId)
          .set(message.toJson());

      // Set read status for both participants
      await _firestore
          .collection('conversations')
          .doc(conversationId)
          .collection('readStatus')
          .doc(currentUserId)
          .set({
        'userId': currentUserId,
        'isRead': true,
        'lastReadTimestamp': FieldValue.serverTimestamp(),
      });

      await _firestore
          .collection('conversations')
          .doc(conversationId)
          .collection('readStatus')
          .doc(otherUserId)
          .set({
        'userId': otherUserId,
        'isRead': false,
        'lastReadTimestamp': FieldValue.serverTimestamp(),
      });

      // Create and return the new conversation object
      final newConversation = Conversation(
        id: conversationId,
        participants: [currentUser, otherUser],
        lastMessage: message,
        messages: [message],
        isMuted: false,
        isArchived: false,
        unreadCount: 0,
        isGroup: false,
        groupName: null,
      );

      // Add to the conversations list
      _conversations.add(newConversation);
      _applyFilters();
      notifyListeners();

      return newConversation;
    } catch (e) {
      debugPrint('[createOrGetConversation] Error: $e');
      return null;
    }
  }
}
