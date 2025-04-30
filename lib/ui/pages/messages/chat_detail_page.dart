import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart'; // Add this import for date formatting
import 'models/message.dart';
import 'models/conversation.dart';
import 'package:flutter_application_2/ui/pages/messages/messages_controller.dart';
import 'package:flutter_application_2/constants/theme_constants.dart';

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

class _ChatDetailPageState extends State<ChatDetailPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _messageFocusNode = FocusNode();

  late Stream<QuerySnapshot> _messagesStream;
  Message? _replyToMessage;
  Timer? _typingTimer;
  bool isTyping = false;

  @override
  void initState() {
    super.initState();
    _setupMessagesStream();
    _listenForTyping();

    // Add listener to scroll controller to detect when scrolling finishes
    _scrollController.addListener(() {
      if (_scrollController.hasClients &&
          !_scrollController.position.isScrollingNotifier.value) {
        // This gets called when the scrolling stops
        _maybeNeedToScrollToBottom();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Instantly jump to bottom on first build for best perceived performance
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _scrollToBottom(animated: false));
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
          final currentUserId = widget.controller.currentUserId;
          setState(() {
            isTyping = typingUsers.any((id) =>
                id != currentUserId &&
                widget.conversation.participants.any((u) => u.id == id));
          });
        }
      }
    });
  }

  void _scrollToBottom({bool animated = true}) {
    // Don't attempt to scroll if we don't have a valid scroll controller
    if (!_scrollController.hasClients) return;

    try {
      // Get the max scroll extent - this is the bottom of the list
      final maxScroll = _scrollController.position.maxScrollExtent;

      // Use a more robust approach with delayed execution to ensure rendering is complete
      Future.delayed(const Duration(milliseconds: 100), () {
        if (!mounted || !_scrollController.hasClients) return;

        if (animated) {
          _scrollController.animateTo(
            maxScroll + 100, // Add extra padding to ensure we get to the bottom
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
          );
        } else {
          _scrollController.jumpTo(maxScroll + 100); // Add padding here too
        }
      });
    } catch (e) {
      debugPrint('Error in _scrollToBottom: $e');
    }
  }

  // A more aggressive approach to ensure scrolling to bottom
  void _maybeNeedToScrollToBottom() {
    if (!_scrollController.hasClients) return;

    // Schedule this after the frame to ensure all widgets are laid out
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;

      try {
        // Use jumpTo for immediate response
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      } catch (e) {
        debugPrint('Scroll error in _maybeNeedToScrollToBottom: $e');
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

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _messageFocusNode.dispose();
    _typingTimer?.cancel();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    try {
      _messageController.clear();

      await widget.controller.sendMessage(
        text,
        replyTo: _replyToMessage,
      );

      setState(() {
        _replyToMessage = null;
      });

      // Improved scrolling after sending message
      // Use a double post-frame callback for more reliable scrolling
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // Short delay to ensure message is rendered
        Future.delayed(const Duration(milliseconds: 50), () {
          if (mounted && _scrollController.hasClients) {
            _scrollToBottom(animated: true);
          }
        });
      });

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
        await widget.controller.sendImageMessage(
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
    final String userId = widget.controller.currentUserId;

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
              widget.controller.deleteMessage(message);
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
              widget.controller.deleteConversation(widget.conversation);

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
      (user) => user.id != widget.controller.currentUserId,
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
                if (isTyping)
                  Text(
                    'typing...',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: ThemeConstants.primaryColor,
                        ),
                  ),
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
        child: Column(
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
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (snapshot.hasError) {
                        return Center(child: Text('Error: ${snapshot.error}'));
                      }

                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return const Center(child: Text('No messages yet'));
                      }

                      // Always sort messages by timestamp ascending (oldest first)
                      final messages = snapshot.data!.docs.map((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        return Message.fromJson({...data, 'id': doc.id});
                      }).toList()
                        ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

                      // --- Group messages by date ---
                      final List<Widget> messageWidgets = [];
                      DateTime? lastDate;
                      for (int i = 0; i < messages.length; i++) {
                        final message = messages[i];
                        final isCurrentUser =
                            message.senderId == widget.controller.currentUserId;

                        // Insert date separator if date changes
                        final messageDate = DateTime(
                          message.timestamp.year,
                          message.timestamp.month,
                          message.timestamp.day,
                        );
                        if (lastDate == null || messageDate != lastDate) {
                          messageWidgets.add(_buildDateSeparator(messageDate));
                          lastDate = messageDate;
                        }

                        // Mark message as read if from other user
                        if (!isCurrentUser && !message.isRead) {
                          widget.controller.markMessageAsRead(message);
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
                              child:
                                  _buildMessageBubble(message, isCurrentUser),
                            ),
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
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.attach_file),
                    onPressed: () => _showAttachmentOptions(context),
                    padding: const EdgeInsets.all(12), // Increased padding
                  ),
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      focusNode: _messageFocusNode,
                      decoration: InputDecoration(
                        hintText: 'Type a message...',
                        border: InputBorder
                            .none, // Remove border since container has background
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12, // Increased vertical padding
                        ),
                      ),
                      textCapitalization: TextCapitalization.sentences,
                      onChanged: (text) {
                        _updateTypingStatus(text.isNotEmpty);
                      },
                      onSubmitted: (_) => _sendMessage(), // Send on enter
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.send),
                    color: ThemeConstants.primaryColor,
                    onPressed: _sendMessage,
                    padding: const EdgeInsets.all(12), // Increased padding
                  ),
                ],
              ),
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

    return Align(
      alignment: isCurrentUser ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress:
            isCurrentUser ? () => _confirmDeleteMessage(message) : null,
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
                  child: Text(
                    message.replyToContent!,
                    style: TextStyle(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                      color: isCurrentUser ? Colors.white70 : Colors.black87,
                    ),
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

              // Only show time (not date)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  DateFormat('HH:mm').format(message.timestamp),
                  style: TextStyle(
                    fontSize: 10,
                    color: isCurrentUser ? Colors.white70 : Colors.grey,
                  ),
                ),
              ),
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
}
