import 'package:flutter/material.dart';
import 'package:flutter_application_2/core/constants/text_strings.dart';
import 'package:flutter_application_2/core/constants/theme_constants.dart';
import 'package:flutter_application_2/ui/pages/messages/messages_controller.dart';
import 'package:flutter_application_2/ui/pages/messages/models/conversation.dart';
import 'package:flutter_application_2/ui/pages/messages/widgets/message_bubble.dart';
import 'dart:async';

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
                    ),
                  ],
                );
              },
            ),
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
                padding: const EdgeInsets.all(16.0),
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
                              'Recording...',
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
                          label: const Text('Cancel'),
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
                          label: const Text('Send'),
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
                        hintText: TextStrings.typeMessage,
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
                      icon: const Icon(
                        Icons.send,
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

  void _showMessageActions(BuildContext context, message) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.content_copy,
                    color: ThemeConstants.primaryColor),
                title: Text(TextStrings.copy),
                onTap: () {
                  Navigator.pop(context);
                },
              ),
              if (message.isSent)
                ListTile(
                  leading: Icon(Icons.edit, color: ThemeConstants.orange),
                  title: Text(TextStrings.edit),
                  onTap: () {
                    Navigator.pop(context);
                  },
                ),
              ListTile(
                leading: Icon(Icons.delete_outline, color: ThemeConstants.red),
                title: Text(TextStrings.delete),
                onTap: () {
                  Navigator.pop(context);
                  widget.controller.deleteMessage(message);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showConversationActions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(
                  widget.conversation.isMuted
                      ? Icons.volume_up
                      : Icons.volume_off,
                  color: ThemeConstants.primaryColor,
                ),
                title: Text(
                  widget.conversation.isMuted
                      ? TextStrings.unmute
                      : TextStrings.mute,
                ),
                onTap: () {
                  widget.controller.toggleMute(widget.conversation);
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: Icon(Icons.search, color: ThemeConstants.green),
                title: Text(TextStrings.searchInConversation),
                onTap: () {
                  // Search in conversation
                  Navigator.pop(context);
                },
              ),
              if (widget.conversation.isGroup)
                ListTile(
                  leading: Icon(Icons.group, color: ThemeConstants.orange),
                  title: Text(TextStrings.viewGroupMembers),
                  onTap: () {
                    // View group members
                    Navigator.pop(context);
                  },
                ),
              ListTile(
                leading: Icon(
                  widget.conversation.isArchived
                      ? Icons.unarchive
                      : Icons.archive,
                  color: ThemeConstants.grey,
                ),
                title: Text(
                  widget.conversation.isArchived
                      ? TextStrings.unarchive
                      : TextStrings.archive,
                ),
                onTap: () {
                  widget.controller.toggleArchive(widget.conversation);
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: Icon(Icons.delete_outline, color: ThemeConstants.red),
                title: Text(TextStrings.delete),
                onTap: () {
                  Navigator.pop(context);
                  _confirmDeleteConversation(context);
                },
              ),
            ],
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
}
