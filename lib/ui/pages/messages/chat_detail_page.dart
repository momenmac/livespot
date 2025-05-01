import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart'; // Add this import for date formatting
import 'models/message.dart';
import 'models/conversation.dart';
import 'package:flutter_application_2/ui/pages/messages/messages_controller.dart';
import 'package:flutter_application_2/constants/theme_constants.dart';
import 'package:flutter/services.dart';

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
  final ScrollController _scrollController = ScrollController();
  final FocusNode _messageFocusNode = FocusNode();

  // Keep our own reference to the controller that we'll manage
  late final MessagesController _controller;

  late Stream<QuerySnapshot> _messagesStream;
  Message? _replyToMessage;
  Timer? _typingTimer;
  Timer? _scrollDebounceTimer;
  bool isTyping = false;

  // Animation controllers for typing indicator
  final List<AnimationController> _dotControllers = [];
  final List<Animation<double>> _dotAnimations = [];

  // ValueNotifier to control visibility of the scroll-to-bottom button
  final ValueNotifier<bool> _showScrollToBottomButton = ValueNotifier(false);

  @override
  void initState() {
    super.initState();
    // Create a new controller instance if provided controller is disposed
    // This ensures we don't use a disposed controller
    if (widget.controller.disposed) {
      _controller = MessagesController();
      _controller.selectConversation(widget.conversation);
    } else {
      _controller = widget.controller;
    }

    // Initialize typing indicator animations
    _initTypingAnimations();

    _setupMessagesStream();
    _listenForTyping();

    // Add listener to scroll controller to detect when scrolling finishes
    _scrollController.addListener(() {
      // Update visibility of scroll-to-bottom button
      if (_scrollController.hasClients) {
        _showScrollToBottomButton.value = _scrollController.offset <
            _scrollController.position.maxScrollExtent - 100;
      }
    });
  }

  void _initTypingAnimations() {
    // Clean up any existing controllers first
    _disposeTypingAnimations();

    // Create 3 dot animations with staggered delays
    for (int i = 0; i < 3; i++) {
      final controller = AnimationController(
        vsync: this, // Using "this" which implements TickerProviderStateMixin
        duration: const Duration(milliseconds: 600),
      );

      // Create a curved animation
      final animation = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
          parent: controller,
          curve: Curves.easeInOut,
        ),
      );

      _dotControllers.add(controller);
      _dotAnimations.add(animation);

      // Start the animation with a staggered delay
      Future.delayed(Duration(milliseconds: i * 120), () {
        if (mounted) {
          controller.repeat(reverse: true);
        }
      });
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

  void _setupMessagesStream() {
    _messagesStream = FirebaseFirestore.instance
        .collection('conversations')
        .doc(widget.conversation.id)
        .collection('messages')
        .orderBy('timestamp',
            descending: false) // Change to ascending order (oldest to newest)
        .limit(150) // Increased limit for more history
        .snapshots();

    // Add listener to scroll to bottom when new messages come in
    _messagesStream.listen((_) {
      // Use a slight delay to ensure messages are rendered
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted && _scrollController.hasClients) {
          _scrollToBottom(animated: true);
        }
      });
    });
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
          final typingUsers = List<String>.from(data['typingUsers'] ?? []);
          final currentUserId = _controller.currentUserId;
          setState(() {
            isTyping = typingUsers.any((id) =>
                id != currentUserId &&
                widget.conversation.participants.any((u) => u.id == id));
          });
        }
      }
    });
  }

  // More reliable and smoother scroll mechanism
  void _scrollToBottom({bool animated = true}) {
    // Cancel any previous timer to avoid multiple scrolls
    _scrollDebounceTimer?.cancel();

    // Use a simple post-frame callback instead of a timer for more reliability
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _scrollController.positions.isEmpty) return;

      try {
        final maxScroll = _scrollController.position.maxScrollExtent;

        if (animated) {
          _scrollController.animateTo(
            maxScroll,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutQuart,
          );
        } else {
          // Immediate jump to bottom
          _scrollController.jumpTo(maxScroll);
        }
      } catch (e) {
        // Handle any errors during scrolling
        debugPrint('Error scrolling to bottom: $e');
      }
    });
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
          _controller.editingMessage!,
          text,
        );
      } else {
        // Send a new message
        await _controller.sendMessage(
          text,
          replyTo: _replyToMessage,
        );
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
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source);

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

  // Helper to validate and fix avatar URLs
  String _getValidAvatarUrl(String url, String userName) {
    if (url.isEmpty) return '';

    // If URL starts with file:/// - convert to proper HTTP URL
    if (url.startsWith('file:///media/')) {
      // Replace file:/// with the actual server base URL
      return 'http://localhost:8000${url.substring(7)}';
    }

    // Handle URLs that are just paths without domain
    if (url.startsWith('/media/')) {
      return 'http://localhost:8000$url';
    }

    // Already a valid URL (starts with http:// or https://)
    if (url.startsWith('http://') || url.startsWith('https://')) {
      return url;
    }

    // Default case - use a placeholder avatar
    return 'https://ui-avatars.com/api/?name=${Uri.encodeComponent(userName)}';
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    // Get other participant (not the current user)
    final otherParticipant = widget.conversation.participants.firstWhere(
      (user) => user.id != _controller.currentUserId,
      orElse: () => widget.conversation.participants.first,
    );

    // Fix and validate the avatar URL
    final validAvatarUrl =
        _getValidAvatarUrl(otherParticipant.avatarUrl, otherParticipant.name);

    return Scaffold(
      resizeToAvoidBottomInset: true, // Ensure keyboard pushes up the view
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              backgroundImage: validAvatarUrl.isNotEmpty
                  ? NetworkImage(validAvatarUrl)
                  : null,
              child: validAvatarUrl.isEmpty
                  ? Text(otherParticipant.name.isNotEmpty
                      ? otherParticipant.name[0].toUpperCase()
                      : '?')
                  : null,
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  otherParticipant.name,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                // Removed typing indicator from here
              ],
            ),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'delete') {
                _confirmDeleteConversation();
              }
            },
            itemBuilder: (context) => [
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
                            return Center(
                                child: Text('Error: ${snapshot.error}'));
                          }

                          if (!snapshot.hasData ||
                              snapshot.data!.docs.isEmpty) {
                            return const Center(child: Text('No messages yet'));
                          }

                          // Always sort messages by timestamp ascending (oldest first)
                          final messages = snapshot.data!.docs.map((doc) {
                            final data = doc.data() as Map<String, dynamic>;
                            return Message.fromJson({...data, 'id': doc.id});
                          }).toList()
                            ..sort(
                                (a, b) => a.timestamp.compareTo(b.timestamp));

                          // --- Group messages by date ---
                          final List<Widget> messageWidgets = [];
                          DateTime? lastDate;

                          // Mark all messages in this conversation as read when the chat is opened
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (widget.conversation.unreadCount > 0) {
                              _controller
                                  .markConversationAsRead(widget.conversation);
                            }
                          });

                          for (int i = 0; i < messages.length; i++) {
                            final message = messages[i];
                            final isCurrentUser =
                                message.senderId == _controller.currentUserId;

                            // Insert date separator if date changes
                            final messageDate = DateTime(
                              message.timestamp.year,
                              message.timestamp.month,
                              message.timestamp.day,
                            );
                            if (lastDate == null || messageDate != lastDate) {
                              messageWidgets
                                  .add(_buildDateSeparator(messageDate));
                              lastDate = messageDate;
                            }

                            messageWidgets.add(
                              Dismissible(
                                key: Key(message.id),
                                direction: DismissDirection.startToEnd,
                                confirmDismiss: (direction) async {
                                  _handleSwipeReply(message);
                                  return false;
                                },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  child: _buildMessageBubble(
                                      message, isCurrentUser),
                                ),
                              ),
                            );
                          }

                          // Add the typing indicator as a temporary message at the bottom if someone is typing
                          if (isTyping) {
                            messageWidgets.add(
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                child: _buildTypingIndicator(isTyping),
                              ),
                            );
                          }

                          // --- Scroll to bottom after build if new message arrives ---
                          WidgetsBinding.instance.addPostFrameCallback(
                              (_) => _scrollToBottom(animated: true));

                          return ListView(
                            controller: _scrollController,
                            children: messageWidgets,
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
                      // Edit mode indicator with a UI similar to reply
                      if (_controller.editingMessage != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          color: isDarkMode
                              ? Colors.grey.withOpacity(0.2)
                              : Colors.grey.withOpacity(0.1),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: ThemeConstants.primaryColor,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.edit,
                                    size: 16, color: Colors.white),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Edit message',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close, size: 18),
                                onPressed: () {
                                  setState(() {
                                    _messageController.text = '';
                                    _controller.setEditingMessage(null);
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                      Row(
                        children: [
                          // Hide attachment button when editing
                          if (_controller.editingMessage == null)
                            IconButton(
                              icon: const Icon(Icons.attach_file),
                              onPressed: () => _showAttachmentOptions(context),
                              padding: const EdgeInsets.all(12),
                            )
                          else
                            const SizedBox(width: 12),
                          Expanded(
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
                              ),
                              textCapitalization: TextCapitalization.sentences,
                              onChanged: (text) {
                                // Don't show typing indicator when editing
                                if (_controller.editingMessage == null) {
                                  _updateTypingStatus(text.isNotEmpty);
                                }
                              },
                              onSubmitted: (_) => _sendMessage(),
                            ),
                          ),
                          IconButton(
                            icon: Icon(
                              _controller.editingMessage != null
                                  ? Icons.check
                                  : Icons.send,
                              color: _controller.editingMessage != null
                                  ? ThemeConstants.orange
                                  : ThemeConstants.primaryColor,
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
      if (message.mediaUrl!.startsWith('file:///')) {
        fixedMediaUrl =
            'http://localhost:8000${message.mediaUrl!.substring(7)}';
      } else if (message.mediaUrl!.startsWith('/media/')) {
        fixedMediaUrl = 'http://localhost:8000${message.mediaUrl!}';
      } else {
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
          padding: const EdgeInsets.all(12),
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
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    fixedMediaUrl,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return SizedBox(
                        width: 200,
                        height: 200,
                        child: Center(
                          child: CircularProgressIndicator(
                            value: loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded /
                                    loadingProgress.expectedTotalBytes!
                                : null,
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
                            Icon(Icons.broken_image, color: Colors.grey[600]),
                            const SizedBox(height: 8),
                            Text(
                              'Image could not be loaded',
                              style: TextStyle(color: Colors.grey[600]),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),

              // Time and message status row
              Row(
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
                  const SizedBox(width: 4),
                  InkWell(
                    onTap: () => _showMessageStatusInfo(context),
                    child: getStatusIcon(),
                  ),
                ],
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

  Widget _buildDateSeparator(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    String label;
    if (date == today) {
      label = "Today";
    } else if (date == yesterday) {
      label = "Yesterday";
    } else {
      label = DateFormat('MMMM d, yyyy').format(date);
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.grey.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTypingIndicator(bool isTyping) {
    if (!isTyping || !mounted) return const SizedBox.shrink();

    // Check if we need to initialize animations
    if (_dotAnimations.isEmpty && mounted) {
      // The animations might have been disposed, reinitialize them if needed
      _initTypingAnimations();
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(right: 80),
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
        decoration: BoxDecoration(
          color: Colors.grey.withOpacity(0.2),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildBouncingDot(0),
            const SizedBox(width: 4.0),
            _buildBouncingDot(1),
            const SizedBox(width: 4.0),
            _buildBouncingDot(2),
          ],
        ),
      ),
    );
  }

  Widget _buildBouncingDot(int index) {
    // Make sure we have enough animations initialized
    if (_dotAnimations.isEmpty || index >= _dotAnimations.length) {
      // Return an empty widget if the animations aren't ready yet
      return const SizedBox(width: 8.0, height: 8.0);
    }

    // Safety check to prevent errors with disposed controllers
    if (!mounted) {
      return Container(
        width: 8.0,
        height: 8.0,
        decoration: BoxDecoration(
          color: Theme.of(context).primaryColor.withOpacity(0.6),
          shape: BoxShape.circle,
        ),
      );
    }

    return AnimatedBuilder(
      animation: _dotAnimations[index],
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, -4.0 * _dotAnimations[index].value),
          child: Container(
            width: 8.0,
            height: 8.0,
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor,
              shape: BoxShape.circle,
            ),
          ),
        );
      },
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
