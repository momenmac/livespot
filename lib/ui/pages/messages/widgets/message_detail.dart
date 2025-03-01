import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For clipboard
import 'package:flutter_application_2/core/constants/text_strings.dart';
import 'package:flutter_application_2/core/constants/theme_constants.dart';
import 'package:flutter_application_2/ui/pages/messages/messages_controller.dart';
import 'package:flutter_application_2/ui/pages/messages/models/conversation.dart';
import 'package:flutter_application_2/ui/pages/messages/models/message.dart';
import 'package:flutter_application_2/ui/pages/messages/widgets/message_bubble.dart';
import 'dart:async';

class ActionItem {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  ActionItem({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });
}

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

class _MessageDetailState extends State<MessageDetail>
    with SingleTickerProviderStateMixin {
  bool _isRecording = false;
  int _recordDuration = 0;
  Timer? _recordTimer;

  // Animation controller for recording animation
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    // Setup animation controller
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);

    widget.controller.addListener(_handleControllerChanges);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToFirstUnreadMessage();
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    widget.controller.removeListener(_handleControllerChanges);
    _stopRecording();
    super.dispose();
  }

  // Improved handler for controller changes
  void _handleControllerChanges() {
    if (mounted) {
      // Force rebuild on any controller changes
      setState(() {});

      // Only auto-scroll if the newest message is from the current user
      if (widget.controller.messageScrollController.hasClients &&
          widget.controller.selectedConversation?.messages.isNotEmpty == true &&
          widget.controller.selectedConversation?.messages.first.senderId ==
              'current') {
        widget.controller.messageScrollController.animateTo(
          0.0, // Position 0 for newest message
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    }
  }

  void _scrollToFirstUnreadMessage() {
    if (widget.conversation.messages.isEmpty) return;

    if (widget.conversation.unreadCount > 0) {
      int unreadPosition = widget.conversation.unreadCount;

      if (unreadPosition < widget.conversation.messages.length) {
        widget.controller.messageScrollController.jumpTo(
          unreadPosition * 80.0, // Approximate height per message
        );
      }
    } else {
      widget.controller.messageScrollController.jumpTo(0);
    }
  }

  void _startRecording() {
    setState(() {
      _isRecording = true;
      _recordDuration = 0;
    });

    _recordTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _recordDuration++;
      });
    });
  }

  void _stopRecording() {
    _recordTimer?.cancel();
    if (_isRecording) {
      setState(() {
        _isRecording = false;
      });

      if (_recordDuration >= 1) {
        widget.controller.sendVoiceMessage(_recordDuration);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(TextStrings.recordingCancelled),
            duration: const Duration(seconds: 1),
          ),
        );
      }
    }
  }

  String _formatDuration(int seconds) {
    final minutes = (seconds / 60).floor();
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    // More reliable key to ensure list rebuilds properly
    final messageListKey = ValueKey(
        'messages_${widget.conversation.id}_${widget.conversation.messages.length}');

    // Use the most current conversation from the controller
    final currentConversation =
        widget.controller.selectedConversation ?? widget.conversation;

    return Column(
      children: [
        // Header with back button and conversation info
        if (widget.showHeader)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            decoration: BoxDecoration(
              color: isDarkMode
                  ? ThemeConstants.darkCardColor
                  : ThemeConstants.lightCardColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  offset: Offset(0, 1),
                  blurRadius: 3,
                ),
              ],
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: widget.onBackPressed,
                ),
                CircleAvatar(
                  backgroundImage: NetworkImage(widget.conversation.avatarUrl),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.conversation.displayName,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (widget.conversation.isOnline &&
                          !widget.conversation.isGroup)
                        Text(
                          TextStrings.online,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: const Color.fromARGB(255, 128, 227, 15),
                          ),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.more_vert),
                  onPressed: () => _showConversationActions(context),
                ),
              ],
            ),
          ),

        // Messages list
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: isDarkMode
                  ? ThemeConstants.darkBackgroundColor
                  : ThemeConstants.lightBackgroundColor,
            ),
            child: ListView.builder(
              key: messageListKey,
              controller: widget.controller.messageScrollController,
              reverse: true,
              padding: const EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: 30,
              ),
              itemCount: currentConversation.messages.length,
              itemBuilder: (context, index) {
                final message = currentConversation.messages[index];

                final isFromCurrentUser = message.senderId == 'current';
                final showAvatar = !isFromCurrentUser;
                final showName =
                    currentConversation.isGroup && !isFromCurrentUser;

                final showDateHeader = _shouldShowDateHeader(
                  index,
                  currentConversation.messages,
                );

                return Column(
                  children: [
                    if (showDateHeader)
                      _buildDateHeader(
                          currentConversation.messages[index].timestamp, theme),
                    MessageBubble(
                      message: message,
                      showAvatar: showAvatar,
                      showName: showName,
                      onLongPress: () => _showMessageActions(context, message),
                      onSwipeReply: (msg) {
                        widget.controller.setReplyToMessage(msg);
                      },
                      onReplyTap: (originalMessageId) {
                        // When a reply is tapped, navigate to original message
                        widget.controller.scrollToMessage(originalMessageId);
                      },
                    ),
                  ],
                );
              },
            ),
          ),
        ),

        // Reply UI - show when replying to a message
        if (widget.controller.replyToMessage != null)
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isDarkMode
                  ? ThemeConstants.darkCardColor
                  : ThemeConstants.lightCardColor,
              border: Border(
                top: BorderSide(
                  color: isDarkMode ? Colors.grey[800]! : Colors.grey[300]!,
                  width: 1,
                ),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "${TextStrings.replyingTo} ${widget.controller.replyToMessage!.senderName}",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: ThemeConstants.primaryColor,
                            ),
                          ),
                          Text(
                            widget.controller.replyToMessage!.messageType ==
                                    MessageType.voice
                                ? TextStrings.voiceMessage
                                : _truncateText(
                                    widget.controller.replyToMessage!.content,
                                    50),
                            style: const TextStyle(
                              fontSize: 14,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        widget.controller.cancelReply();
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),

        // Edit UI - show when editing a message
        if (widget.controller.editingMessage != null)
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isDarkMode
                  ? ThemeConstants.darkCardColor.withOpacity(0.7)
                  : ThemeConstants.lightCardColor.withOpacity(0.7),
              border: Border(
                top: BorderSide(
                  color: isDarkMode ? Colors.grey[800]! : Colors.grey[300]!,
                  width: 1,
                ),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            TextStrings.editMessage,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: ThemeConstants.orange,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        widget.controller.cancelEditing();
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),

        // Recording UI - with improved compact design
        if (_isRecording)
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.85,
                minWidth: 300,
              ),
              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: isDarkMode
                    ? ThemeConstants.darkCardColor
                    : ThemeConstants.lightCardColor,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AnimatedBuilder(
                          animation: _pulseController,
                          builder: (context, child) {
                            return Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: ThemeConstants.red.withOpacity(
                                  0.2 + (_pulseController.value * 0.3),
                                ),
                              ),
                              child: Icon(
                                Icons.mic,
                                color: ThemeConstants.red,
                                size: 28 + (_pulseController.value * 4),
                              ),
                            );
                          },
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              TextStrings.recording,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              _formatDuration(_recordDuration),
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: ThemeConstants.primaryColor,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Audio waveform visualization
                    SizedBox(
                      height: 30,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          12, // Fewer bars = more compact
                          (index) => AnimatedBuilder(
                            animation: _pulseController,
                            builder: (context, _) {
                              final random = (index % 3) * 0.2 + 0.2;
                              final height = 8.0 +
                                  (14.0 *
                                      (_pulseController.value * random + 0.5));
                              return Container(
                                width: 3,
                                height: height,
                                margin:
                                    const EdgeInsets.symmetric(horizontal: 2),
                                decoration: BoxDecoration(
                                  color: ThemeConstants.primaryColor
                                      .withOpacity(0.7),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        // Cancel button
                        ElevatedButton.icon(
                          onPressed: () {
                            _recordTimer?.cancel();
                            setState(() {
                              _isRecording = false;
                              _recordDuration = 0;
                            });
                          },
                          icon: const Icon(Icons.close),
                          label: Text(TextStrings.cancel),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isDarkMode
                                ? ThemeConstants.darkBackgroundColor
                                : ThemeConstants.lightBackgroundColor,
                            foregroundColor: isDarkMode
                                ? ThemeConstants.lightBackgroundColor
                                : Colors.black87,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                        ),
                        // Send button
                        ElevatedButton.icon(
                          onPressed: _stopRecording,
                          icon: const Icon(
                            Icons.send,
                            color: Colors.white,
                          ),
                          label: Text(TextStrings.send),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: ThemeConstants.primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

        // Message input box
        if (!_isRecording)
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 8,
            ),
            decoration: BoxDecoration(
              color: isDarkMode
                  ? ThemeConstants.darkCardColor
                  : ThemeConstants.lightCardColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  offset: Offset(0, -1),
                  blurRadius: 3,
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  GestureDetector(
                    onLongPress: _startRecording,
                    child: IconButton(
                      icon: const Icon(Icons.mic),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(TextStrings.holdToRecord),
                            duration: Duration(seconds: 1),
                            backgroundColor: ThemeConstants.primaryColor,
                          ),
                        );
                      },
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.attach_file),
                    onPressed: () {
                      // TODO: Implement file attachment
                    },
                  ),
                  Expanded(
                    child: TextField(
                      controller: widget.controller.messageController,
                      decoration: InputDecoration(
                        hintText: widget.controller.editingMessage != null
                            ? TextStrings.editMessage
                            : TextStrings.typeMessage,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: isDarkMode
                            ? ThemeConstants.darkBackgroundColor
                            : ThemeConstants.lightBackgroundColor,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                      ),
                      textCapitalization: TextCapitalization.sentences,
                      minLines: 1,
                      maxLines: 5,
                      onSubmitted: (text) {
                        if (text.trim().isNotEmpty) {
                          widget.controller.sendMessage(text.trim());
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: ThemeConstants.primaryColor,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: Icon(
                        widget.controller.editingMessage != null
                            ? Icons.check
                            : Icons.send,
                        color: Colors.white,
                      ),
                      onPressed: () {
                        final text =
                            widget.controller.messageController.text.trim();
                        if (text.isNotEmpty) {
                          widget.controller.sendMessage(text);
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  bool _shouldShowDateHeader(int index, List messages) {
    if (index == messages.length - 1) {
      return true;
    }

    final currentDate = messages[index].timestamp;
    final previousDate = messages[index + 1].timestamp;

    return !_isSameDay(currentDate, previousDate);
  }

  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }

  Widget _buildDateHeader(DateTime date, ThemeData theme) {
    final today = DateTime.now();
    final yesterday = today.subtract(const Duration(days: 1));

    String text;
    if (_isSameDay(date, today)) {
      text = TextStrings.today;
    } else if (_isSameDay(date, yesterday)) {
      text = TextStrings.yesterday;
    } else {
      text = '${date.day}/${date.month}/${date.year}';
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface.withOpacity(0.7),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 1,
              ),
            ],
          ),
          child: Text(
            text,
            style: theme.textTheme.bodySmall,
          ),
        ),
      ),
    );
  }

  void _showMessageActions(BuildContext context, Message message) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        final isDarkMode = Theme.of(context).brightness == Brightness.dark;

        // Determine which actions are available based on message type
        final bool canCopy = message.messageType != MessageType.voice;
        final bool canEdit = message.senderId == 'current' &&
            message.messageType != MessageType.voice;

        // Create the list of actions that will be displayed
        final List<ActionItem> actions = [
          // Always available
          ActionItem(
            icon: Icons.reply,
            label: TextStrings.reply,
            color: ThemeConstants.primaryColor,
            onTap: () {
              Navigator.pop(context);
              widget.controller.setReplyToMessage(message);
            },
          ),

          // Forward action - always available
          ActionItem(
            icon: Icons.forward,
            label: TextStrings.forward,
            color: ThemeConstants.primaryColor,
            onTap: () {
              Navigator.pop(context);
              _showForwardOptions(context, message);
            },
          ),

          // Delete action - always available
          ActionItem(
            icon: Icons.delete_outline,
            label: TextStrings.delete,
            color: ThemeConstants.red,
            onTap: () {
              Navigator.pop(context);
              widget.controller.deleteMessage(message);
            },
          ),

          // Copy action - only for text messages
          if (canCopy)
            ActionItem(
              icon: Icons.content_copy,
              label: TextStrings.copy,
              color: ThemeConstants.primaryColor,
              onTap: () {
                widget.controller.copyToClipboard(message.content, context);
                Navigator.pop(context);
              },
            ),

          // Edit action - only for current user's text messages
          if (canEdit)
            ActionItem(
              icon: Icons.edit,
              label: TextStrings.edit,
              color: ThemeConstants.orange,
              onTap: () {
                Navigator.pop(context);
                widget.controller.setEditingMessage(message);
              },
            ),
        ];

        return Container(
          decoration: BoxDecoration(
            color: isDarkMode ? Color(0xFF2D2D2D) : Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          margin: EdgeInsets.only(left: 10, right: 10, top: 10),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle bar at top
                Container(
                  margin: EdgeInsets.symmetric(vertical: 10),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[400],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                // Preview of message
                Container(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundImage: NetworkImage(
                            'https://ui-avatars.com/api/?name=${Uri.encodeComponent(message.senderName)}'),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: message.messageType == MessageType.voice
                            ? Row(
                                children: [
                                  Icon(Icons.mic, size: 16, color: Colors.grey),
                                  SizedBox(width: 4),
                                  Text(
                                    "Voice message (${_formatDuration(message.voiceDuration ?? 0)})",
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                ],
                              )
                            : Text(
                                _truncateText(message.content, 100),
                                style: const TextStyle(fontSize: 14),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                      ),
                    ],
                  ),
                ),

                // Action buttons grid
                Padding(
                  padding:
                      const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      // Calculate how many actions to show per row
                      final double screenWidth = constraints.maxWidth;
                      final int itemsPerRow = screenWidth > 300 ? 3 : 2;

                      // Create rows of actions
                      final List<Widget> actionRows = [];
                      for (int i = 0; i < actions.length; i += itemsPerRow) {
                        final rowItems = actions.sublist(
                            i,
                            i + itemsPerRow > actions.length
                                ? actions.length
                                : i + itemsPerRow);

                        actionRows.add(
                          Padding(
                            padding: const EdgeInsets.only(bottom: 24),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: rowItems
                                  .map((action) => _buildCircularAction(
                                        icon: action.icon,
                                        label: action.label,
                                        color: action.color,
                                        onTap: action.onTap,
                                      ))
                                  .toList(),
                            ),
                          ),
                        );
                      }

                      return Column(children: actionRows);
                    },
                  ),
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showConversationActions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        final isDarkMode = Theme.of(context).brightness == Brightness.dark;

        // Create list of actions
        final List<ActionItem> actions = [
          // Mute/Unmute action
          ActionItem(
            icon: widget.conversation.isMuted
                ? Icons.volume_up
                : Icons.volume_off,
            label: widget.conversation.isMuted
                ? TextStrings.unmute
                : TextStrings.mute,
            color: ThemeConstants.primaryColor,
            onTap: () {
              widget.controller.toggleMute(widget.conversation);
              Navigator.pop(context);
            },
          ),

          // Search action
          ActionItem(
            icon: Icons.search,
            label: TextStrings.searchInConversation,
            color: ThemeConstants.green,
            onTap: () {
              // Search in conversation feature
              Navigator.pop(context);
            },
          ),

          // Archive/Unarchive action
          ActionItem(
            icon: widget.conversation.isArchived
                ? Icons.unarchive
                : Icons.archive,
            label: widget.conversation.isArchived
                ? TextStrings.unarchive
                : TextStrings.archive,
            color: ThemeConstants.grey,
            onTap: () {
              widget.controller.toggleArchive(widget.conversation);
              Navigator.pop(context);
            },
          ),

          // Delete action
          ActionItem(
            icon: Icons.delete_outline,
            label: TextStrings.delete,
            color: ThemeConstants.red,
            onTap: () {
              Navigator.pop(context);
              _confirmDeleteConversation(context);
            },
          ),

          // Group members action - only for group conversations
          if (widget.conversation.isGroup)
            ActionItem(
              icon: Icons.group,
              label: TextStrings.viewGroupMembers,
              color: ThemeConstants.orange,
              onTap: () {
                Navigator.pop(context);
                // View group members feature
              },
            ),
        ];

        return Container(
          decoration: BoxDecoration(
            color: isDarkMode ? Color(0xFF2D2D2D) : Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          margin: EdgeInsets.only(left: 10, right: 10, top: 10),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle bar at top
                Container(
                  margin: EdgeInsets.symmetric(vertical: 10),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[400],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                // Conversation preview
                Container(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundImage:
                            NetworkImage(widget.conversation.avatarUrl),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.conversation.displayName,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (!widget.conversation.isGroup &&
                                widget.conversation.isOnline)
                              Text(
                                TextStrings.online,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: ThemeConstants.green,
                                ),
                              )
                            else if (widget.conversation.isGroup)
                              Text(
                                '${widget.conversation.participants.length} participants',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: isDarkMode
                                      ? Colors.grey[300]
                                      : Colors.grey[600],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Action buttons grid
                Padding(
                  padding:
                      const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      // Calculate how many actions to show per row
                      final double screenWidth = constraints.maxWidth;
                      final int itemsPerRow = screenWidth > 300 ? 3 : 2;

                      // Create rows of actions
                      final List<Widget> actionRows = [];
                      for (int i = 0; i < actions.length; i += itemsPerRow) {
                        final rowItems = actions.sublist(
                            i,
                            i + itemsPerRow > actions.length
                                ? actions.length
                                : i + itemsPerRow);

                        actionRows.add(
                          Padding(
                            padding: const EdgeInsets.only(bottom: 24),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: rowItems
                                  .map((action) => _buildCircularAction(
                                        icon: action.icon,
                                        label: action.label,
                                        color: action.color,
                                        onTap: action.onTap,
                                      ))
                                  .toList(),
                            ),
                          ),
                        );
                      }

                      return Column(children: actionRows);
                    },
                  ),
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        );
      },
    );
  }

  void _confirmDeleteConversation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(TextStrings.deleteConversation),
        content: Text(TextStrings.deleteConversationConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(TextStrings.cancel),
          ),
          TextButton(
            onPressed: () {
              widget.controller.deleteConversation(widget.conversation);
              Navigator.pop(context);
              widget.onBackPressed();
            },
            child: Text(
              TextStrings.delete,
              style: TextStyle(color: ThemeConstants.red),
            ),
          ),
        ],
      ),
    );
  }

  // Add the missing helper method
  String _truncateText(String text, int maxLength) {
    if (text.length <= maxLength) {
      return text;
    }
    return '${text.substring(0, maxLength)}...';
  }

  // Add method for forward options
  void _showForwardOptions(BuildContext context, Message message) {
    // Store the context in a local variable to avoid using invalid contexts
    final currentContext = context;
    // Create a controller for the search field
    final TextEditingController searchController = TextEditingController();
    // Track filtered conversations
    List<Conversation> filteredConversations =
        List.from(widget.controller.conversations);

    if (widget.controller.conversations.isEmpty) {
      ScaffoldMessenger.of(currentContext).showSnackBar(
          SnackBar(content: Text(TextStrings.noConversationsForward)));
      return;
    }

    showModalBottomSheet(
      context: currentContext,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) {
        return StatefulBuilder(
          builder: (builderContext, setState) {
            // Safe filter function
            void filterConversations(String query) {
              setState(() {
                if (query.isEmpty) {
                  filteredConversations =
                      List.from(widget.controller.conversations);
                } else {
                  filteredConversations =
                      widget.controller.conversations.where((convo) {
                    return convo.displayName
                        .toLowerCase()
                        .contains(query.toLowerCase());
                  }).toList();
                }
              });
            }

            return GestureDetector(
              onTap: () => FocusScope.of(builderContext)
                  .unfocus(), // Safe way to dismiss keyboard
              child: Container(
                height: MediaQuery.of(builderContext).size.height * 0.7,
                decoration: BoxDecoration(
                  color: Theme.of(builderContext).brightness == Brightness.dark
                      ? Color(0xFF2D2D2D)
                      : Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                margin: EdgeInsets.only(left: 10, right: 10, top: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Handle bar at top for drag UX
                    Center(
                      child: Container(
                        margin: EdgeInsets.symmetric(vertical: 10),
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey[400],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),

                    // Title section with message preview
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                      child: Row(
                        children: [
                          Icon(Icons.forward,
                              color: ThemeConstants.primaryColor),
                          const SizedBox(width: 8),
                          Text(
                            TextStrings.forwardMessage,
                            style: Theme.of(builderContext)
                                .textTheme
                                .titleLarge
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                          ),
                        ],
                      ),
                    ),

                    // Preview of message being forwarded
                    Container(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 16,
                            backgroundImage: NetworkImage(
                                'https://ui-avatars.com/api/?name=${message.senderName}'),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  message.senderName,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold),
                                ),
                                message.messageType == MessageType.voice
                                    ? Text(TextStrings.voiceMessage)
                                    : Text(
                                        _truncateText(message.content, 100),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    Divider(),

                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                      child: Text(
                        TextStrings.selectConversation,
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: Colors.grey[700],
                        ),
                      ),
                    ),

                    // Search field with proper null handling
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      child: TextField(
                        controller: searchController,
                        onChanged: filterConversations,
                        decoration: InputDecoration(
                          hintText: TextStrings.searchConversations,
                          prefixIcon: const Icon(Icons.search),
                          filled: true,
                          fillColor: Colors.grey.withOpacity(0.1),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ),

                    Expanded(
                      child: filteredConversations.isEmpty
                          ? Center(child: Text('No matching conversations'))
                          : ListView.builder(
                              itemCount: filteredConversations.length,
                              itemBuilder: (listContext, index) {
                                final conversation =
                                    filteredConversations[index];
                                // Don't show current conversation in the list
                                if (conversation.id == widget.conversation.id) {
                                  return const SizedBox.shrink();
                                }

                                return ListTile(
                                  leading: CircleAvatar(
                                    backgroundImage:
                                        NetworkImage(conversation.avatarUrl),
                                  ),
                                  title: Text(conversation.displayName),
                                  subtitle: Text(
                                    conversation.isGroup
                                        ? "${conversation.participants.length} participants"
                                        : conversation.isOnline
                                            ? TextStrings.online
                                            : "",
                                    style: TextStyle(
                                        color: conversation.isOnline
                                            ? ThemeConstants.green
                                            : null),
                                  ),
                                  onTap: () {
                                    Navigator.pop(bottomSheetContext);

                                    // Handle forwarding but avoid context errors
                                    widget.controller
                                        .forwardMessage(message, conversation)
                                        .then((_) {
                                      if (currentContext.mounted) {
                                        ScaffoldMessenger.of(currentContext)
                                            .showSnackBar(SnackBar(
                                          content: Text(
                                              "${TextStrings.messageSaved} ${conversation.displayName}"),
                                        ));
                                      }
                                    });
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // Helper method to build circular action buttons
  Widget _buildCircularAction({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(35),
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Icon(icon, color: color, size: 28),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
