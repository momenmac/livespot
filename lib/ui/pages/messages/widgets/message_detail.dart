import 'package:flutter/material.dart';
import 'package:flutter_application_2/constants/theme_constants.dart';
import 'package:flutter_application_2/ui/pages/messages/messages_controller.dart';
import 'package:flutter_application_2/ui/pages/messages/models/conversation.dart';
import 'package:flutter_application_2/ui/pages/messages/models/message.dart';
import 'package:flutter_application_2/ui/pages/messages/models/user.dart';
import 'package:flutter_application_2/ui/pages/messages/widgets/message_bubble.dart';
import 'dart:async';
import 'package:flutter_application_2/constants/text_strings.dart';
import 'package:flutter_application_2/services/api/account/api_urls.dart';

class MessageDetail extends StatefulWidget {
  final MessagesController controller;
  final Conversation conversation;
  final VoidCallback onBackPressed;
  final bool showHeader;

  const MessageDetail({
    super.key,
    required this.controller,
    required this.conversation,
    required this.onBackPressed,
    this.showHeader = true,
  });

  @override
  State<MessageDetail> createState() => _MessageDetailState();
}

class _MessageDetailState extends State<MessageDetail> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Message? _replyMessage;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();

    // Initialize messages with controller reference
    for (var message in widget.conversation.messages) {
      message.controller = widget.controller;
    }

    // Listen for new messages to auto-scroll
    widget.controller.addListener(_handleControllerChanges);

    // Listen for typing changes
    _messageController.addListener(_onTextChanged);

    // Mark all received messages as read when the chat is opened
    _markReceivedMessagesAsRead();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleControllerChanges);
    _messageController.removeListener(_onTextChanged);
    _messageController.dispose();
    _scrollController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  // Handle user typing with debounce
  void _onTextChanged() {
    // Cancel previous timer
    _debounceTimer?.cancel();

    // Create new timer
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      // Send typing indicator status to controller
      widget.controller.onMessageTyping(_messageController.text);
    });
  }

  // Mark received messages as read
  void _markReceivedMessagesAsRead() {
    if (widget.conversation.unreadCount > 0) {
      // Use the new method to mark conversation as read
      widget.controller.markConversationAsRead(widget.conversation);
    }
  }

  void _handleControllerChanges() {
    // Auto-scroll to bottom when new messages arrive
    if (_scrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  String _absoluteAvatarUrl(String url) {
    if (url.isEmpty) return url;
    if (url.startsWith('http')) return url;
    // Always prepend base URL for non-absolute URLs (e.g. "/media/...")
    final fixedUrl = url.startsWith('/') ? url : '/$url';
    return '${ApiUrls.baseUrl}$fixedUrl';
  }

  // Helper to get users who are typing
  List<User> _getTypingUsers() {
    if (widget.controller.typingUsers.isEmpty) return [];

    return widget.conversation.participants
        .where((user) => widget.controller.typingUsers[user.id] == true)
        .toList();
  }

  // Get typing indicator text
  String _getTypingText() {
    final typingUsers = _getTypingUsers();

    if (typingUsers.isEmpty) return '';

    if (typingUsers.length == 1) {
      return '${typingUsers.first.name} is typing...';
    } else if (typingUsers.length == 2) {
      return '${typingUsers[0].name} and ${typingUsers[1].name} are typing...';
    } else {
      return 'Several people are typing...';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.conversation.messages.isEmpty) {
      return Center(
        child: Text(
          "No messages yet.",
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      );
    }

    // Get typing users
    final typingIndicatorText = _getTypingText();

    return Column(
      children: [
        // Message list (expanded to fill available space)
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.all(16),
            itemCount: widget.conversation.messages.length,
            itemBuilder: (context, index) {
              final message = widget.conversation.messages[index];
              final prevMessage =
                  index > 0 ? widget.conversation.messages[index - 1] : null;
              final showAvatar = _shouldShowAvatar(message, prevMessage);
              final showName = _shouldShowName(message, prevMessage) &&
                  widget.conversation.isGroup;

              // If you use an avatar in MessageBubble, pass the fixed URL:
              // avatarUrl: _absoluteAvatarUrl(message.senderAvatarUrl)
              return MessageBubble(
                message: message,
                showAvatar: showAvatar,
                showName: showName,
                onLongPress: () => _handleLongPress(message),
                onSwipeReply: _handleSwipeReply,
                onReplyTap: _scrollToMessage,
                // avatarUrl: _absoluteAvatarUrl(message.senderAvatarUrl), // <-- use this if needed
              );
            },
          ),
        ),

        // Typing indicator (only show if someone is typing)
        if (typingIndicatorText.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            alignment: Alignment.centerLeft,
            child: Row(
              children: [
                // Animated typing dots
                SizedBox(
                  width: 35,
                  child: _buildTypingDots(),
                ),
                const SizedBox(width: 4),
                // Typing text
                Text(
                  typingIndicatorText,
                  style: TextStyle(
                    fontSize: 12,
                    color: ThemeConstants.grey,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),

        // Input area for composing messages (ensure not cropped)
        Padding(
          padding: const EdgeInsets.fromLTRB(
              8, 12, 8, 20), // Top padding for more space above
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.attach_file),
                onPressed: () {
                  // Handle attachment
                },
              ),
              Expanded(
                child: TextField(
                  controller: _messageController,
                  decoration: InputDecoration(
                    hintText: TextStrings.typeMessage,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 18, // Even more vertical padding
                    ),
                  ),
                  onSubmitted: (content) {
                    _sendMessage(context, content);
                  },
                ),
              ),
              IconButton(
                icon: const Icon(Icons.send),
                color: ThemeConstants.primaryColor,
                onPressed: () {
                  _sendMessage(context, _messageController.text.trim());
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Animated typing indicator dots
  Widget _buildTypingDots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        for (int i = 0; i < 3; i++)
          _AnimatedDot(
            delay: Duration(milliseconds: 300 * i),
          ),
      ],
    );
  }

  void _sendMessage(BuildContext context, String content) {
    if (content.isEmpty) return;
    widget.controller.sendMessage(content);
    _messageController.clear();
    _replyMessage = null;
    setState(() {}); // Ensure UI updates after sending
  }

  bool _shouldShowAvatar(Message message, Message? prevMessage) {
    // Show avatar when the message is from someone else and:
    // 1. It's the first message in the list, or
    // 2. The previous message was from a different sender, or
    // 3. The messages are separated by more than 5 minutes
    return message.senderId != widget.controller.currentUserId &&
        (prevMessage == null ||
            prevMessage.senderId != message.senderId ||
            message.timestamp.difference(prevMessage.timestamp).inMinutes > 5);
  }

  bool _shouldShowName(Message message, Message? prevMessage) {
    // Show name for messages from others when:
    // 1. It's the first message in a group chat, or
    // 2. The previous message was from a different sender
    return message.senderId != widget.controller.currentUserId &&
        (prevMessage == null || prevMessage.senderId != message.senderId);
  }

  void _handleLongPress(Message message) {
    // Show message options dialog or menu - this integrates with your existing code
    debugPrint('Long press on message: ${message.id}');
  }

  void _handleSwipeReply(Message message) {
    setState(() {
      _replyMessage = message;
    });
  }

  void _scrollToMessage(String messageId) {
    // Find the message in the list
    final index =
        widget.conversation.messages.indexWhere((m) => m.id == messageId);
    if (index != -1) {
      // Scroll to the message
      _scrollController.animateTo(
        index * 70.0, // Approximate height of each message
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }
}

// Animated dot for typing indicator
class _AnimatedDot extends StatefulWidget {
  final Duration delay;

  const _AnimatedDot({required this.delay});

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

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _animation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );

    // Add delay before starting animation
    Future.delayed(widget.delay, () {
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
      animation: _animation,
      builder: (context, child) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 2),
          height:
              6 + (4 * _animation.value), // 6-10px height based on animation
          width: 6 + (4 * _animation.value), // 6-10px width based on animation
          decoration: BoxDecoration(
            color: ThemeConstants.primaryColor
                .withOpacity(0.6 + (0.4 * _animation.value)),
            shape: BoxShape.circle,
          ),
        );
      },
    );
  }
}
