import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_application_2/services/api/account/api_urls.dart';
import 'package:flutter_application_2/services/messaging/message_event_bus.dart';
import 'package:flutter_application_2/ui/pages/messages/models/user.dart';
import 'dart:async';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart'; // Add this import for date formatting
import 'models/message.dart';
import 'models/conversation.dart';
import 'package:flutter_application_2/ui/pages/messages/messages_controller.dart';
import 'package:flutter_application_2/constants/theme_constants.dart';
import 'package:flutter/services.dart';
import 'package:flutter_application_2/ui/pages/messages/image_preview_page.dart'; // Import for image preview
import 'package:flutter_application_2/services/permissions/permission_service.dart'; // Import the permission service
import 'package:flutter_application_2/ui/profile/other_user_profile_page.dart'; // Import for user profile
import 'package:flutter_application_2/services/ai/gemini_ai_service.dart'; // Import for AI service

class ChatDetailPage extends StatefulWidget {
  final MessagesController controller;
  final Conversation conversation;

  const ChatDetailPage({
    super.key,
    required this.controller,
    required this.conversation,
  });

  @override
  State<ChatDetailPage> createState() => _ChatDetailPageState();
}

class _ChatDetailPageState extends State<ChatDetailPage>
    with TickerProviderStateMixin {
  final TextEditingController _messageController = TextEditingController();
  late final ScrollController _scrollController;
  final FocusNode _messageFocusNode = FocusNode();

  // Keep our own reference to the controller that we'll manage
  late final MessagesController _controller;

  late Stream<QuerySnapshot> _messagesStream;
  bool _isLoadingMore = false;
  DocumentSnapshot? _lastMessageDoc;
  final int _messagesPerPage = 150; // Initial load of 150 messages
  final int _additionalMessagesPerPage = 50; // Load 50 more when scrolling up

  Message? _replyToMessage;
  Timer? _typingTimer;
  Timer? _scrollDebounceTimer;
  Timer? _readReceiptTimer; // Timer for periodic read receipt checks
  bool isTyping = false;
  bool _isInitialLoad = true;

  // Animation controllers for typing indicator
  final List<AnimationController> _dotControllers = [];
  final List<Animation<double>> _dotAnimations = [];

  // ValueNotifier to control visibility of the scroll-to-bottom button
  final ValueNotifier<bool> _showScrollToBottomButton = ValueNotifier(false);

  // Add this to the class variables section

  @override
  void initState() {
    super.initState();
    _controller = widget.controller;
    _scrollController = ScrollController();

    // Initially hide the scroll-to-bottom button
    _showScrollToBottomButton.value = false;

    // Set up listeners and load messages
    _setupMessageListener();
    _listenForTyping();

    // Add scroll listener to prevent scroll jumps when typing
    _messageFocusNode.addListener(() {
      // When text field gets focus, don't auto-scroll
      if (_messageFocusNode.hasFocus) {
        // Prevent automatic scrolling
        _scrollDebounceTimer?.cancel();
      }
    });

    // Improved approach for handling read status with proper timing
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Mark all messages as read when chat is opened
      _markAllUnreadMessagesAsRead();

      // Also run a check for read receipts after a short delay to let UI settle
      await Future.delayed(const Duration(milliseconds: 500), () {
        // Explicitly check if other participants have read user's messages
        _updateReadReceipts();
      });
    });
  }

  // More comprehensive handling of message read status
  void _markAllUnreadMessagesAsRead() async {
    try {
      if (widget.conversation.unreadCount > 0) {
        debugPrint('[ChatDetail] Marking conversation as read on open');
        // Mark the whole conversation as read, which handles backend updates
        await _controller.markConversationAsRead(widget.conversation);

        // Get updated total unread count and notify the message event bus
        final totalUnreadCount = _controller.getTotalUnreadCount();
        MessageEventBus().notifyUnreadCountChanged(totalUnreadCount);
        debugPrint(
            '[ChatDetail] Updated navigation badge to $totalUnreadCount');
      }

      // Force update read status for all messages from this sender
      for (final participant in widget.conversation.participants) {
        if (participant.id != _controller.currentUserId) {
          debugPrint(
              '[ChatDetail] Marking all messages from ${participant.id} as read');
          await _controller.markMessagesFromSenderAsRead(participant.id);
        }
      }

      // Update UI state
      setState(() {});

      // Force an extra update of the unread count after a delay
      // This ensures that the badge gets updated even if there were async delays
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          final updatedCount = _controller.getTotalUnreadCount();
          MessageEventBus().notifyUnreadCountChanged(updatedCount);
        }
      });
    } catch (e) {
      debugPrint('Error marking messages as read: $e');
    }
  }

  // Check and update read receipts for all messages from current user
  void _updateReadReceipts() async {
    try {
      debugPrint(
          '[ChatDetail] Updating read receipts for conversation ${widget.conversation.id}');

      // Use our new method to update read receipts for all messages
      await _controller.updateReadReceiptsForAllMessages();

      // Set a timer to periodically check read receipts in case of changes
      _readReceiptTimer = Timer.periodic(const Duration(seconds: 5), (_) {
        if (mounted) {
          _controller.updateReadReceiptsForAllMessages();
        }
      });
    } catch (e) {
      debugPrint('Error updating read receipts: $e');
    }
  }

  void _disposeTypingAnimations() {
    for (final controller in _dotControllers) {
      controller.dispose();
    }
    _dotControllers.clear();
    _dotAnimations.clear();
  }

  @override
  void dispose() {
    _disposeTypingAnimations();
    _messageController.dispose();
    _scrollController.dispose();
    _messageFocusNode.dispose();
    _typingTimer?.cancel();
    _scrollDebounceTimer?.cancel();
    _showScrollToBottomButton.dispose();
    _readReceiptTimer?.cancel(); // Cancel the read receipt timer when disposing
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Use our improved scrolling approach to avoid multiple scrolls
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom(animated: false);
    });
  }

  void _setupMessageListener() {
    // Initial query to load the most recent messages
    _messagesStream = FirebaseFirestore.instance
        .collection('conversations')
        .doc(widget.conversation.id)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .limit(_messagesPerPage)
        .snapshots();

    // Setup scroll listener for pagination and scroll button visibility
    _scrollController.addListener(() {
      // When user scrolls to the top, load more messages
      if (_scrollController.position.pixels <= 0 && !_isLoadingMore) {
        _loadMoreMessages();
      }

      // Properly check if we're at the bottom to hide the button
      _checkScrollPosition();
    });

    // Listen to message stream for updates
    _messagesStream.listen((snapshot) {
      if (snapshot.docs.isNotEmpty) {
        // Store the last document for pagination
        _lastMessageDoc = snapshot.docs.last;
      }

      // Handle new messages arriving
      bool hasNewMessages = snapshot.docChanges
          .any((change) => change.type == DocumentChangeType.added);

      if (hasNewMessages) {
        debugPrint('[ChatDetail] New messages detected in snapshot');

        // Use a short delay to ensure the UI updates before attempting to scroll
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted) _handleNewMessages();
        });
      }

      // Mark new incoming messages as read
      _markNewMessagesAsRead(snapshot);

      // Update scroll button visibility after data loads
      if (_isInitialLoad && mounted) {
        _isInitialLoad = false;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _checkScrollPosition();
        });
      }
    });
  }

  // Check scroll position and update button visibility
  void _checkScrollPosition() {
    if (!mounted || !_scrollController.hasClients) return;

    // For reversed list, position.pixels is how far we've scrolled UP from bottom
    // We consider "at bottom" when within 20 pixels of the bottom
    final atBottom = _scrollController.position.pixels < 20;

    // Only update value if it changed to avoid unnecessary rebuilds
    if (_showScrollToBottomButton.value == atBottom) {
      _showScrollToBottomButton.value = !atBottom;
    }
  }

  Future<void> _loadMoreMessages() async {
    if (_isLoadingMore || _lastMessageDoc == null) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      debugPrint('[ChatDetail] Loading more messages');

      final querySnapshot = await FirebaseFirestore.instance
          .collection('conversations')
          .doc(widget.conversation.id)
          .collection('messages')
          .orderBy('timestamp', descending: true)
          .startAfterDocument(_lastMessageDoc!)
          .limit(_additionalMessagesPerPage)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        debugPrint(
            '[ChatDetail] Loaded ${querySnapshot.docs.length} more messages');
        _lastMessageDoc = querySnapshot.docs.last;
      } else {
        debugPrint('[ChatDetail] No more messages to load');
      }

      if (mounted) {
        setState(() {
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      debugPrint('[ChatDetail] Error loading more messages: $e');
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
        });
      }
    }
  }

  void _listenForTyping() {
    FirebaseFirestore.instance
        .collection('conversations')
        .doc(widget.conversation.id)
        .snapshots()
        .listen((snapshot) {
      if (mounted && snapshot.exists) {
        final data = snapshot.data() as Map<String, dynamic>;
        if (data.containsKey('typingUsers') && data['typingUsers'] != null) {
          try {
            debugPrint('[Typing] Processing typing users data...');

            // Handle both Map and List formats for backwards compatibility
            Map<String, dynamic> typingUsersMap = {};

            if (data['typingUsers'] is Map) {
              // If it's already a Map, just cast it
              typingUsersMap = Map<String, dynamic>.from(data['typingUsers']);
              debugPrint('[Typing] Received typing users as Map format');
            } else if (data['typingUsers'] is List) {
              // If it's a List, convert to a Map
              final typingList = List<dynamic>.from(data['typingUsers']);

              // Convert list to map where each user in the list is marked as typing
              for (final userId in typingList) {
                if (userId is String) {
                  typingUsersMap[userId] = true;
                }
              }
              debugPrint(
                  '[Typing] Converted typing users from List to Map format: $typingUsersMap');
            } else {
              // Fallback to empty map if format is unexpected
              debugPrint(
                  '[Typing] Unexpected typing users format: ${data['typingUsers'].runtimeType}');
            }

            final currentUserId = _controller.currentUserId;

            // Check if AI is typing (for AI conversations)
            final isAIChat = _controller.isAIConversation(widget.conversation);
            final aiAssistantId = GeminiAIService().aiAssistantId;

            setState(() {
              if (isAIChat) {
                // For AI conversations, check if AI assistant is typing
                isTyping = typingUsersMap.containsKey(aiAssistantId) &&
                    typingUsersMap[aiAssistantId] == true;
              } else {
                // For regular conversations, check if any other user is typing
                isTyping = typingUsersMap.keys.any((id) =>
                    id != currentUserId &&
                    typingUsersMap[id] == true &&
                    widget.conversation.participants.any((u) => u.id == id));
              }
            });
          } catch (error) {
            debugPrint('[Typing] Error processing typing data: $error');
            setState(() {
              isTyping = false;
            });
          }
        } else {
          setState(() {
            isTyping = false;
          });
        }
      }
    }).onError((error) {
      debugPrint('[ChatDetail] Error listening for typing: $error');
      if (mounted) {
        setState(() {
          isTyping = false;
        });
      }
    });
  }

  // Handle new incoming messages while chat is open
  void _markNewMessagesAsRead(QuerySnapshot snapshot) {
    if (!mounted) return;

    // First, check if there are any changes at all
    final bool hasChanges = snapshot.docChanges.isNotEmpty;

    // Get all messages in the snapshot that are:
    // 1. Not from the current user
    // 2. Not already marked as read
    List<DocumentSnapshot> unreadMessages = [];

    // Process both existing and new messages to ensure nothing is missed
    for (final doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>?;
      if (data == null) continue;

      final String senderId = data['senderId'] as String? ?? '';
      final bool isRead = data['isRead'] as bool? ?? false;

      // Skip messages from current user or already read messages
      if (senderId == _controller.currentUserId || isRead) continue;

      unreadMessages.add(doc);
    }

    // If we found any unread messages that aren't from the current user
    if (unreadMessages.isNotEmpty) {
      debugPrint(
          '[ChatDetail] Found ${unreadMessages.length} unread messages to mark as read');

      // Mark individual messages as read
      final batch = FirebaseFirestore.instance.batch();
      for (final doc in unreadMessages) {
        final messageRef = FirebaseFirestore.instance
            .collection('conversations')
            .doc(widget.conversation.id)
            .collection('messages')
            .doc(doc.id);

        batch.update(messageRef, {'isRead': true});
      }

      // Commit all updates in a single batch
      batch.commit().then((_) {
        debugPrint(
            '[ChatDetail] Successfully marked ${unreadMessages.length} messages as read');

        // Update read status for the conversation
        _controller.markConversationAsRead(widget.conversation);

        // Notify other UI components of the change in unread status
        final totalUnreadCount = _controller.getTotalUnreadCount();
        MessageEventBus().notifyUnreadCountChanged(totalUnreadCount);
      }).catchError((error) {
        debugPrint('[ChatDetail] Error marking messages as read: $error');
      });
    } else if (hasChanges) {
      // Even if there were no unread messages but there were changes,
      // make sure the conversation is marked as read - this handles edge cases
      _controller.markConversationAsRead(widget.conversation);
    }
  }

  // Called when new messages are received
  void _handleNewMessages() {
    // Skip if widget is no longer mounted
    if (!mounted) return;

    // Cancel any existing debounce timer
    _scrollDebounceTimer?.cancel();

    // Debounce the scroll to prevent rapid UI updates
    _scrollDebounceTimer = Timer(const Duration(milliseconds: 100), () {
      if (!mounted) return;

      // Only auto-scroll if we're near the bottom already
      if (_scrollController.hasClients) {
        final isNearBottom = _scrollController.position.pixels >
            (_scrollController.position.maxScrollExtent - 100);

        if (isNearBottom && !_messageFocusNode.hasFocus) {
          // Smoothly scroll to bottom with animation
          _scrollToBottom(animated: true);
        } else {
          // Otherwise just show the scroll-to-bottom button
          _showScrollToBottomButton.value = true;
        }
      }
    });
  }

  // Track scroll position to show/hide the scroll-to-bottom button
  // Optimized scroll-to-bottom that prevents unwanted jumping
  void _scrollToBottom({bool animated = true}) {
    // Skip if widget is no longer mounted or scroll controller isn't attached
    if (!mounted || !_scrollController.hasClients) return;

    try {
      if (animated && !_messageFocusNode.hasFocus) {
        // For reversed list, 0 is the bottom
        _scrollController.animateTo(
          0.0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      } else {
        // Only jump if needed and not focused on message input
        if (!_messageFocusNode.hasFocus) {
          _scrollController.jumpTo(0.0);
        }
      }

      // Update button visibility right after scrolling
      Future.delayed(const Duration(milliseconds: 50), () {
        if (mounted) {
          _showScrollToBottomButton.value = false;
        }
      });
    } catch (e) {
      // Ignore scroll errors to prevent crashes
      debugPrint('[ChatDetail] Error scrolling: $e');
    }
  }

  @override
  void didUpdateWidget(covariant ChatDetailPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Use a short animation for smoothness but less lag
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _scrollToBottom(animated: true));
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    try {
      _messageController.clear();

      // Check if we're editing a message or sending a new one
      if (_controller.editingMessage != null) {
        // Update the existing message
        await _controller.updateMessage(
          _controller.editingMessage!.id,
          text,
        );
      } else {
        // Check if this is an AI conversation and send accordingly
        debugPrint(
            '[ChatDetail] Checking AI conversation for ID: ${widget.conversation.id}');
        debugPrint(
            '[ChatDetail] isAIConversation result: ${_controller.isAIConversation(widget.conversation)}');

        if (_controller.isAIConversation(widget.conversation)) {
          // Send message to AI assistant
          debugPrint('[ChatDetail] Sending AI message: $text');
          await _controller.sendAIMessage(text);
        } else {
          // Send regular message
          debugPrint('[ChatDetail] Sending regular message: $text');
          await _controller.sendMessage(
            text,
            replyTo: _replyToMessage,
          );
        }
      }

      setState(() {
        _replyToMessage = null;
      });

      // Use a single, reliable scroll approach
      _scrollToBottom(animated: true);

      _updateTypingStatus(false);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send message: ${e.toString()}')),
      );
    }
  }

  void _handleSwipeReply(Message message) {
    setState(() {
      _replyToMessage = message;
    });
    _messageFocusNode.requestFocus();
  }

  void _showAttachmentOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo),
              title: const Text('Gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Camera'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    // Use our permission service to handle permissions properly
    final PermissionService permissionService = PermissionService();
    final pickedFile = await permissionService.pickImage(
      context: context,
      source: source,
    );

    if (pickedFile != null) {
      try {
        await _controller.sendImageMessage(
          pickedFile,
        );

        setState(() {
          _replyToMessage = null;
        });
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send image: ${e.toString()}')),
        );
      }
    }
  }

  void _updateTypingStatus(bool typing) {
    final String userId = _controller.currentUserId;

    if (_typingTimer?.isActive ?? false) {
      _typingTimer!.cancel();
    }

    _typingTimer = Timer(const Duration(milliseconds: 500), () {
      if (mounted) {
        FirebaseFirestore.instance
            .collection('conversations')
            .doc(widget.conversation.id)
            .update({
          'typingUsers': typing
              ? FieldValue.arrayUnion([userId])
              : FieldValue.arrayRemove([userId])
        });
      }
    });
  }

  void _confirmDeleteMessage(Message message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Message'),
        content: const Text('Are you sure you want to delete this message?'),
        actions: [
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(context),
          ),
          TextButton(
            child: const Text('Delete'),
            onPressed: () {
              Navigator.pop(context);
              _controller.deleteMessage(message);
              _messageFocusNode.requestFocus();
            },
          ),
        ],
      ),
    );
  }

  void _confirmDeleteConversation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title:
            Text('Delete Conversation with ${widget.conversation.displayName}'),
        content: const Text(
            'This will delete the entire conversation. This action cannot be undone.'),
        actions: [
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(context),
          ),
          TextButton(
            child: const Text('Delete'),
            onPressed: () {
              // First pop the dialog
              Navigator.pop(context);

              // Then delete the conversation
              _controller.deleteConversation(widget.conversation);

              // Use Navigator.of with the right context, and check if we can pop
              if (mounted && Navigator.of(context).canPop()) {
                Navigator.of(context).pop(); // Return to previous screen safely
              }
            },
          ),
        ],
      ),
    );
  }

  void _toggleMuteConversation() {
    setState(() {
      widget.conversation.isMuted = !widget.conversation.isMuted;
    });
    // Update the conversation in the database or controller
    _controller.updateConversation(widget.conversation);
  }

  void _toggleArchiveConversation() {
    setState(() {
      widget.conversation.isArchived = !widget.conversation.isArchived;
    });
    // Update the conversation in the database or controller
    _controller.updateConversation(widget.conversation);
  }

  // Helper to validate and fix avatar URLs
  String _getValidAvatarUrl(String url, String userName) {
    if (url.isEmpty) return '';

    // If URL starts with file:/// - convert to proper HTTP URL
    if (url.startsWith('file:///')) {
      // Replace file:///with the actual server base URL from ApiUrls
      return '${ApiUrls.baseUrl}${url.substring(7)}';
    }

    // Handle URLs that are just paths without domain
    if (url.startsWith('/media/')) {
      return '${ApiUrls.baseUrl}$url';
    }

    // Already a valid URL (starts with http:// or https://)
    if (url.startsWith('http://') || url.startsWith('https://')) {
      if (url.contains('localhost')) {
        return url.replaceFirst('http://localhost:8000', ApiUrls.baseUrl);
      }
      return url;
    }

    // Default case - use a placeholder avatar
    return 'https://ui-avatars.com/api/?name=${Uri.encodeComponent(userName)}';
  }

  // Navigate to user profile when their name is clicked
  void _navigateToUserProfile(User otherParticipant) async {
    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return const AlertDialog(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Loading profile...'),
              ],
            ),
          );
        },
      );

      // Convert the User model (from chat) to a format that OtherUserProfilePage can understand
      Map<String, dynamic> userData = {
        'id': int.tryParse(otherParticipant.id) ?? -1,
        'username': otherParticipant.name,
        'name': otherParticipant.name,
        'profileImage': otherParticipant.avatarUrl,
        'isOnline': otherParticipant.isOnline,
        'email':
            '', // This is intentionally empty as we don't have email in chat User model
      };

      // Close loading dialog
      Navigator.of(context).pop();

      // Navigate to OtherUserProfilePage with user data
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => OtherUserProfilePage(userData: userData),
        ),
      );
    } catch (e) {
      // Close loading dialog if still open
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }

      // Show error
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not load profile: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    // Get other participant (not the current user)
    final otherParticipant = widget.conversation.participants.firstWhere(
      (user) => user.id != _controller.currentUserId,
      orElse: () => widget.conversation.participants.first,
    );

    // Check if this is an AI conversation
    final isAIChat = _controller.isAIConversation(widget.conversation);

    return Scaffold(
      resizeToAvoidBottomInset: true, // Ensure keyboard pushes up the view
      appBar: AppBar(
        title: Row(
          children: [
            // Make the avatar clickable (except for AI)
            GestureDetector(
              onTap: isAIChat
                  ? null
                  : () => _navigateToUserProfile(otherParticipant),
              child: CircleAvatar(
                backgroundColor: isAIChat
                    ? (isDarkMode ? Colors.grey[800] : Colors.grey[200])
                    : null,
                backgroundImage: !isAIChat &&
                        _getValidAvatarUrl(otherParticipant.avatarUrl,
                                otherParticipant.name)
                            .isNotEmpty
                    ? NetworkImage(_getValidAvatarUrl(
                        otherParticipant.avatarUrl, otherParticipant.name))
                    : null,
                child: isAIChat
                    ? Icon(
                        Icons.smart_toy,
                        color: isDarkMode ? Colors.white : Colors.black87,
                        size: 24,
                      )
                    : (_getValidAvatarUrl(otherParticipant.avatarUrl,
                                otherParticipant.name)
                            .isEmpty
                        ? Text(otherParticipant.name.isNotEmpty
                            ? otherParticipant.name[0].toUpperCase()
                            : '?')
                        : null),
              ),
            ),
            const SizedBox(width: 8),
            // Make the username clickable (except for AI)
            Expanded(
              child: GestureDetector(
                onTap: isAIChat
                    ? null
                    : () => _navigateToUserProfile(otherParticipant),
                child: Text(
                  isAIChat ? 'AI Assistant' : otherParticipant.name,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: isAIChat ? Theme.of(context).primaryColor : null,
                      ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'profile':
                  if (!isAIChat) {
                    _navigateToUserProfile(otherParticipant);
                  }
                  break;
                case 'delete':
                  _confirmDeleteConversation();
                  break;
                case 'mute':
                  _toggleMuteConversation();
                  break;
                case 'archive':
                  _toggleArchiveConversation();
                  break;
              }
            },
            itemBuilder: (context) => [
              // View profile option (only for non-AI conversations)
              if (!isAIChat)
                PopupMenuItem(
                  value: 'profile',
                  child: Row(
                    children: [
                      Icon(
                        Icons.person,
                        color: ThemeConstants.primaryColor,
                      ),
                      const SizedBox(width: 8),
                      Text('View Profile'),
                    ],
                  ),
                ),

              // Mute/Unmute option
              PopupMenuItem(
                value: 'mute',
                child: Row(
                  children: [
                    Icon(
                      widget.conversation.isMuted
                          ? Icons.volume_up
                          : Icons.volume_off,
                      color: ThemeConstants.primaryColor,
                    ),
                    const SizedBox(width: 8),
                    Text(widget.conversation.isMuted ? 'Unmute' : 'Mute'),
                  ],
                ),
              ),

              // Archive/Unarchive option
              PopupMenuItem(
                value: 'archive',
                child: Row(
                  children: [
                    Icon(
                      widget.conversation.isArchived
                          ? Icons.unarchive
                          : Icons.archive,
                      color: ThemeConstants.orange,
                    ),
                    const SizedBox(width: 8),
                    Text(widget.conversation.isArchived
                        ? 'Unarchive'
                        : 'Archive'),
                  ],
                ),
              ),

              // Delete option
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Delete Conversation'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                // Messages list
                Expanded(
                  child: NotificationListener<SizeChangedLayoutNotification>(
                    onNotification: (_) {
                      // Use jumpTo for instant scroll when keyboard appears
                      WidgetsBinding.instance.addPostFrameCallback(
                          (_) => _scrollToBottom(animated: false));
                      return true;
                    },
                    child: SizeChangedLayoutNotifier(
                      child: StreamBuilder<QuerySnapshot>(
                        stream: _messagesStream,
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                                child: CircularProgressIndicator());
                          }

                          if (snapshot.hasError) {
                            return const Center(
                                child: Text('Error loading messages'));
                          }

                          if (!snapshot.hasData ||
                              snapshot.data!.docs.isEmpty) {
                            return const Center(child: Text('No messages yet'));
                          }

                          final messages = snapshot.data!.docs.map((doc) {
                            final data = doc.data() as Map<String, dynamic>;
                            return Message.fromJson({...data, 'id': doc.id});
                          }).toList();

                          return ListView.builder(
                            controller: _scrollController,
                            reverse: true,
                            itemCount: messages.length + 1,
                            itemBuilder: (context, index) {
                              if (index == messages.length) {
                                return _isLoadingMore
                                    ? const Center(
                                        child: CircularProgressIndicator())
                                    : const SizedBox.shrink();
                              }

                              final message = messages[index];
                              final isCurrentUser =
                                  message.senderId == _controller.currentUserId;

                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                child: Dismissible(
                                  key: Key(message.id),
                                  direction: DismissDirection.startToEnd,
                                  confirmDismiss: (direction) async {
                                    _handleSwipeReply(message);
                                    return false;
                                  },
                                  child: _buildMessageBubble(
                                      message, isCurrentUser),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ),
                ),

                // Reply indicator
                if (_replyToMessage != null)
                  Container(
                    padding: const EdgeInsets.all(8),
                    color: isDarkMode
                        ? ThemeConstants.darkCardColor.withAlpha(128)
                        : ThemeConstants.lightCardColor.withAlpha(128),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                'Reply to:',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              Text(
                                _replyToMessage!.content,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () {
                            setState(() {
                              _replyToMessage = null;
                            });
                          },
                        ),
                      ],
                    ),
                  ),

                // Add typing indicator above the message composition area
                if (isTyping)
                  Padding(
                    padding: const EdgeInsets.only(left: 16.0, bottom: 8.0),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16.0, vertical: 12.0),
                        decoration: BoxDecoration(
                          color: isDarkMode
                              ? Colors.grey.withOpacity(0.2)
                              : Colors.grey.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: List.generate(3, (index) {
                            return Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 2.0),
                              child: _AnimatedDot(index: index),
                            );
                          }),
                        ),
                      ),
                    ),
                  ),

                // Message composition area - redesigned for better positioning
                Container(
                  margin: const EdgeInsets.only(
                    left: 8,
                    right: 8,
                    bottom: 20, // Add more bottom margin
                    top: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isDarkMode
                        ? ThemeConstants.darkCardColor
                        : ThemeConstants.lightCardColor,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Edit mode indicator with a consistent UI across all platforms
                      if (_controller.editingMessage != null)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          margin: const EdgeInsets.only(bottom: 4),
                          decoration: BoxDecoration(
                            color: ThemeConstants.primaryColor.withOpacity(0.1),
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(16),
                            ),
                            border: Border.all(
                              color:
                                  ThemeConstants.primaryColor.withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.edit,
                                  size: 16, color: ThemeConstants.primaryColor),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Text(
                                      'Editing message',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: ThemeConstants.primaryColor,
                                        fontSize: 12,
                                      ),
                                    ),
                                    Text(
                                      _controller.editingMessage!.content,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: isDarkMode
                                            ? Colors.white70
                                            : Colors.black87,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.close,
                                  size: 20,
                                  color: ThemeConstants.primaryColor,
                                ),
                                padding: const EdgeInsets.all(4),
                                constraints: const BoxConstraints(),
                                onPressed: () {
                                  _messageController.clear();
                                  _controller.setEditingMessage(null);
                                },
                              ),
                            ],
                          ),
                        ),
                      Row(
                        children: [
                          // Left icon - attachment in normal mode, edit icon in edit mode
                          IconButton(
                            icon: Icon(
                              _controller.editingMessage != null
                                  ? Icons.edit
                                  : Icons.attach_file,
                              color: _controller.editingMessage != null
                                  ? ThemeConstants.primaryColor
                                  : null,
                            ),
                            onPressed: _controller.editingMessage != null
                                ? null // Disabled when editing
                                : () => _showAttachmentOptions(context),
                            padding: const EdgeInsets.all(12),
                          ),
                          // Text input field
                          Expanded(
                            child: Container(
                              decoration: _controller.editingMessage != null
                                  ? BoxDecoration(
                                      color: ThemeConstants.primaryColor
                                          .withOpacity(0.08),
                                      borderRadius: BorderRadius.circular(18),
                                      border: Border.all(
                                        color: ThemeConstants.primaryColor
                                            .withOpacity(0.3),
                                        width: 1.0,
                                      ),
                                    )
                                  : null,
                              child: TextField(
                                controller: _messageController,
                                focusNode: _messageFocusNode,
                                decoration: InputDecoration(
                                  hintText: _controller.editingMessage != null
                                      ? 'Edit message...'
                                      : 'Type a message...',
                                  border: InputBorder.none,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                  // No need for filled background since we're using Container for styling
                                  filled: false,
                                ),
                                textCapitalization:
                                    TextCapitalization.sentences,
                                onChanged: (text) {
                                  // Don't show typing indicator when editing
                                  if (_controller.editingMessage == null) {
                                    _updateTypingStatus(text.isNotEmpty);
                                  }
                                },
                                onSubmitted: (_) => _sendMessage(),
                              ),
                            ),
                          ),
                          // Send/edit button
                          _controller.editingMessage != null
                              ? Container(
                                  margin: const EdgeInsets.only(left: 8),
                                  decoration: BoxDecoration(
                                    color: ThemeConstants.primaryColor,
                                    shape: BoxShape.circle,
                                  ),
                                  child: IconButton(
                                    icon: const Icon(
                                      Icons.check,
                                      color: Colors.white,
                                    ),
                                    onPressed: _sendMessage,
                                    padding: const EdgeInsets.all(12),
                                  ),
                                )
                              : IconButton(
                                  icon: const Icon(
                                    Icons.send,
                                    color: ThemeConstants.primaryColor,
                                  ),
                                  onPressed: _sendMessage,
                                  padding: const EdgeInsets.all(12),
                                ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // Scroll to bottom floating button (appears when not at bottom)
            ValueListenableBuilder<bool>(
              valueListenable: _showScrollToBottomButton,
              builder: (context, showButton, _) {
                return showButton
                    ? Positioned(
                        right: 16,
                        bottom: 80,
                        child: FloatingActionButton(
                          mini: true,
                          backgroundColor: ThemeConstants.primaryColor,
                          onPressed: () => _scrollToBottom(animated: true),
                          child: const Icon(Icons.keyboard_arrow_down,
                              color: Colors.white),
                        ),
                      )
                    : const SizedBox.shrink();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(Message message, bool isCurrentUser) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    // Fix media URL if needed (for images)
    String? fixedMediaUrl;
    if (message.messageType == MessageType.image && message.mediaUrl != null) {
      // Process image URL using the same method as in image_message_bubble.dart
      if (message.mediaUrl!.contains('firebasestorage.googleapis.com') ||
          message.mediaUrl!.contains('storage.googleapis.com')) {
        // Firebase Storage URLs remain intact
        fixedMediaUrl = message.mediaUrl;
      } else if (message.mediaUrl!.contains('localhost') ||
          message.mediaUrl!.contains('127.0.0.1') ||
          message.mediaUrl!.contains('192.168.')) {
        // Extract path from localhost or IP-based URL
        Uri uri = Uri.parse(message.mediaUrl!);
        String path = uri.path;
        // Ensure no leading slash for concatenation
        path = path.startsWith('/') ? path.substring(1) : path;
        fixedMediaUrl = '${ApiUrls.baseUrl}/$path';
      } else if (message.mediaUrl!.startsWith('/')) {
        // Handle relative paths
        fixedMediaUrl = '${ApiUrls.baseUrl}/${message.mediaUrl!.substring(1)}';
      } else {
        // Use the UrlUtils for any other cases
        fixedMediaUrl = message.mediaUrl;
      }
    }

    // Get message status icon
    Widget getStatusIcon() {
      if (isCurrentUser) {
        switch (message.status) {
          case MessageStatus.sending:
            return const Icon(Icons.access_time,
                size: 12, color: Colors.white70);
          case MessageStatus.sent:
            return const Icon(Icons.check, size: 12, color: Colors.white70);
          case MessageStatus.delivered:
            return const Icon(Icons.done_all, size: 12, color: Colors.white70);
          case MessageStatus.read:
            return const Icon(Icons.done_all,
                size: 12, color: Colors.lightBlueAccent);
          case MessageStatus.failed:
            return const Icon(Icons.error_outline,
                size: 12, color: Colors.redAccent);
        }
      }
      return const SizedBox.shrink();
    }

    return Align(
      alignment: isCurrentUser ? Alignment.centerRight : Alignment.centerLeft,
      child: InkWell(
        onTap: () {
          // Show message action popup when tapping on message
          _showMessageActionPopup(context, message, isCurrentUser);
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.75,
          ),
          decoration: BoxDecoration(
            color: isCurrentUser
                ? ThemeConstants.primaryColor.withAlpha(204)
                : isDarkMode
                    ? ThemeConstants.darkCardColor.withAlpha(204)
                    : ThemeConstants.lightCardColor.withAlpha(204),
            borderRadius: BorderRadius.circular(16),
          ),
          padding: message.messageType == MessageType.image
              ? const EdgeInsets.all(4) // Less padding for images
              : const EdgeInsets.all(12),
          margin: const EdgeInsets.only(bottom: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Reply reference if this message is a reply
              if (message.replyToContent != null)
                Container(
                  padding: const EdgeInsets.all(8),
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: Colors.black12,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        message.replyToSenderName ?? 'Unknown',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color:
                              isCurrentUser ? Colors.white70 : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        message.replyToContent!,
                        style: TextStyle(
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                          color:
                              isCurrentUser ? Colors.white70 : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),

              // Message content
              if (message.messageType == MessageType.text)
                Text(
                  message.content,
                  style: TextStyle(
                    color: isCurrentUser ? Colors.white : null,
                  ),
                )
              else if (message.messageType == MessageType.image &&
                  fixedMediaUrl != null)
                GestureDetector(
                  onTap: () {
                    // When image is tapped, navigate to ImagePreviewPage
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => ImagePreviewPage(
                          imageUrl: fixedMediaUrl!,
                          caption: message.content.isNotEmpty
                              ? message.content
                              : null,
                          imageId: message.id,
                        ),
                      ),
                    );
                  },
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxHeight:
                                MediaQuery.of(context).size.height * 0.35,
                          ),
                          child: Hero(
                            tag:
                                'image-preview-${message.id}-${fixedMediaUrl.hashCode}',
                            child: Image.network(
                              fixedMediaUrl,
                              fit: BoxFit.contain,
                              loadingBuilder:
                                  (context, child, loadingProgress) {
                                if (loadingProgress == null) return child;
                                return SizedBox(
                                  width:
                                      MediaQuery.of(context).size.width * 0.6,
                                  height: 150,
                                  child: Center(
                                    child: CircularProgressIndicator(
                                      value:
                                          loadingProgress.expectedTotalBytes !=
                                                  null
                                              ? loadingProgress
                                                      .cumulativeBytesLoaded /
                                                  loadingProgress
                                                      .expectedTotalBytes!
                                              : null,
                                      color: isCurrentUser
                                          ? Colors.white
                                          : ThemeConstants.primaryColor,
                                    ),
                                  ),
                                );
                              },
                              errorBuilder: (context, error, stackTrace) {
                                debugPrint('Error loading image: $error');
                                return Container(
                                  width: 200,
                                  height: 150,
                                  decoration: BoxDecoration(
                                    color: Colors.grey[300],
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.broken_image,
                                          color: Colors.grey[600]),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Image could not be loaded',
                                        style:
                                            TextStyle(color: Colors.grey[600]),
                                        textAlign: TextAlign.center,
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ),

                      // Add caption if present
                      if (message.content.isNotEmpty)
                        Padding(
                          padding:
                              const EdgeInsets.only(left: 8, right: 8, top: 6),
                          child: Text(
                            message.content,
                            style: TextStyle(
                              color: isCurrentUser ? Colors.white : null,
                              fontSize: 13,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

              // Time and message status row with edited indicator
              Padding(
                padding: message.messageType == MessageType.image
                    ? const EdgeInsets.only(
                        left: 8, right: 8, top: 4, bottom: 4)
                    : const EdgeInsets.only(top: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      DateFormat('HH:mm').format(message.timestamp),
                      style: TextStyle(
                        fontSize: 10,
                        color: isCurrentUser ? Colors.white70 : Colors.grey,
                      ),
                    ),

                    // Edited indicator
                    if (message.isEdited)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(width: 4),
                          Text(
                            "• edited",
                            style: TextStyle(
                              fontSize: 10,
                              fontStyle: FontStyle.italic,
                              color:
                                  isCurrentUser ? Colors.white70 : Colors.grey,
                            ),
                          ),
                        ],
                      ),

                    const SizedBox(width: 4),

                    // Message status indicator
                    InkWell(
                      onTap: () => _showMessageStatusInfo(context),
                      child: getStatusIcon(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Show bottom sheet with message actions using circular action buttons
  void _showMessageActionPopup(
      BuildContext context, Message message, bool isCurrentUser) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar at top of bottom sheet
              Container(
                margin: const EdgeInsets.only(top: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              const SizedBox(height: 20),

              // Circular action buttons row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Reply action
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      InkWell(
                        onTap: () {
                          Navigator.pop(context);
                          setState(() {
                            _replyToMessage = message;
                          });
                          _messageFocusNode.requestFocus();
                        },
                        borderRadius: BorderRadius.circular(30),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: ThemeConstants.primaryColor.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.reply,
                            color: ThemeConstants.primaryColor,
                            size: 28,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text('Reply', style: TextStyle(fontSize: 12)),
                    ],
                  ),

                  // Copy action
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      InkWell(
                        onTap: () {
                          Navigator.pop(context);
                          Clipboard.setData(
                              ClipboardData(text: message.content));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Message copied to clipboard')),
                          );
                        },
                        borderRadius: BorderRadius.circular(30),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: ThemeConstants.primaryColor.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.content_copy,
                            color: ThemeConstants.primaryColor,
                            size: 28,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text('Copy', style: TextStyle(fontSize: 12)),
                    ],
                  ),

                  // Edit option (only for sender's messages)
                  if (isCurrentUser)
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        InkWell(
                          onTap: () {
                            Navigator.pop(context);
                            _messageController.text = message.content;
                            _controller.setEditingMessage(message);
                            _messageFocusNode.requestFocus();
                          },
                          borderRadius: BorderRadius.circular(30),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color:
                                  ThemeConstants.primaryColor.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.edit,
                              color: ThemeConstants.primaryColor,
                              size: 28,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text('Edit', style: TextStyle(fontSize: 12)),
                      ],
                    ),

                  // Delete option (only for sender's messages)
                  if (isCurrentUser)
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        InkWell(
                          onTap: () {
                            Navigator.pop(context);
                            _confirmDeleteMessage(message);
                          },
                          borderRadius: BorderRadius.circular(30),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.delete,
                              color: Colors.red,
                              size: 28,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text('Delete',
                            style: TextStyle(fontSize: 12, color: Colors.red)),
                      ],
                    ),
                ],
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  // Helper for explaining message status
  void _showMessageStatusInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Message Status'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Row(children: [
              Icon(Icons.access_time, size: 16),
              SizedBox(width: 8),
              Text('Sending: Message is being sent')
            ]),
            SizedBox(height: 8),
            Row(children: [
              Icon(Icons.check, size: 16),
              SizedBox(width: 8),
              Text('Sent: Message sent to server')
            ]),
            SizedBox(height: 8),
            Row(children: [
              Icon(Icons.done_all, size: 16, color: Colors.grey),
              SizedBox(width: 8),
              Text('Delivered: Message delivered to recipient')
            ]),
            SizedBox(height: 8),
            Row(children: [
              Icon(Icons.done_all, size: 16, color: Colors.lightBlueAccent),
              SizedBox(width: 8),
              Text('Read: Message seen by recipient')
            ])
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }
}

// Specialized widget for continuous dot animation that never stops
class _AnimatedDot extends StatefulWidget {
  final int index;

  const _AnimatedDot({required this.index});

  @override
  State<_AnimatedDot> createState() => _AnimatedDotState();
}

class _AnimatedDotState extends State<_AnimatedDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    // Create a controller with different duration based on index for wave effect
    _controller = AnimationController(
      duration: Duration(milliseconds: 600 + (widget.index * 200)),
      vsync: this,
    );

    // Create a curved animation
    _animation = Tween<double>(begin: -5, end: 5).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );

    // Start the animation with a slight delay based on index
    Future.delayed(Duration(milliseconds: widget.index * 160), () {
      if (mounted) {
        _controller.repeat(reverse: true);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _animation.value),
          child: Container(
            width: 8.0,
            height: 8.0,
            decoration: BoxDecoration(
              color: ThemeConstants.primaryColor,
              shape: BoxShape.circle,
            ),
          ),
        );
      },
    );
  }
}
