import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_application_2/core/constants/text_strings.dart';
import 'package:flutter_application_2/core/constants/theme_constants.dart';
import 'package:flutter_application_2/ui/pages/messages/messages_controller.dart';
import 'package:flutter_application_2/ui/pages/messages/models/conversation.dart';
import 'package:flutter_application_2/ui/pages/messages/models/message.dart';
import 'package:intl/intl.dart';
import 'package:flutter_application_2/ui/widgets/responsive_snackbar.dart';

class VoiceMessageBubble extends StatefulWidget {
  final Message message;
  final bool isSent;
  final VoidCallback? onLongPress;
  final Function(Message)? onReply;

  const VoiceMessageBubble({
    super.key,
    required this.message,
    required this.isSent,
    this.onLongPress,
    this.onReply,
  });

  @override
  State<VoiceMessageBubble> createState() => _VoiceMessageBubbleState();
}

class _VoiceMessageBubbleState extends State<VoiceMessageBubble> {
  bool _isPlaying = false;
  double _playbackProgress = 0;
  bool _isHovering = false;
  // Add a key to better control popup menu state
  final GlobalKey _popupMenuKey = GlobalKey();

  @override
  void dispose() {
    // Ensure any menu is dismissed to prevent context errors
    if (mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // This safely dismisses any open menu when the widget is disposed
        Navigator.of(context, rootNavigator: true).popUntil((route) {
          return route is! PopupRoute;
        });
      });
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final bubbleColor = widget.isSent
        ? ThemeConstants.primaryColor
        : isDarkMode
            ? ThemeConstants.darkCardColor
            : ThemeConstants.lightCardColor;
    final textColor =
        widget.isSent ? Colors.white : theme.textTheme.bodyLarge?.color;

    // Format the audio duration
    final audioDuration = widget.message.voiceDuration ?? 0; // seconds
    final formattedDuration = _formatDuration(audioDuration);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: Stack(
        children: [
          InkWell(
            onLongPress: widget.onLongPress,
            borderRadius: BorderRadius.circular(18),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: bubbleColor,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              constraints: const BoxConstraints(maxWidth: 300),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Play/Pause button
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: widget.isSent
                              ? Colors.white.withOpacity(0.2)
                              : ThemeConstants.primaryColor.withOpacity(0.1),
                        ),
                        child: IconButton(
                          icon: Icon(
                            _isPlaying ? Icons.pause : Icons.play_arrow,
                            color: widget.isSent
                                ? Colors.white
                                : ThemeConstants.primaryColor,
                            size: 20,
                          ),
                          onPressed: _togglePlayback,
                          padding: EdgeInsets.zero,
                          splashRadius: 20,
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Audio waveform visualization
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Waveform visualization
                            SizedBox(
                              height: 24,
                              child: Stack(
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: List.generate(
                                      15,
                                      (index) {
                                        // Create a pattern of bars with varying heights
                                        final height = 4 +
                                            (index % 3 == 0
                                                ? 12.0
                                                : index % 2 == 0
                                                    ? 8.0
                                                    : 4.0);
                                        return Container(
                                          width: 2.5,
                                          height: height,
                                          decoration: BoxDecoration(
                                            color: _getBarColor(index),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Progress slider
                            SliderTheme(
                              data: SliderThemeData(
                                trackHeight: 2,
                                thumbShape: const RoundSliderThumbShape(
                                    enabledThumbRadius: 4),
                                overlayShape: const RoundSliderOverlayShape(
                                    overlayRadius: 8),
                                activeTrackColor: widget.isSent
                                    ? Colors.white
                                    : ThemeConstants.primaryColor,
                                inactiveTrackColor: widget.isSent
                                    ? Colors.white.withOpacity(0.3)
                                    : ThemeConstants.primaryColor
                                        .withOpacity(0.3),
                                thumbColor: widget.isSent
                                    ? Colors.white
                                    : ThemeConstants.primaryColor,
                                overlayColor: widget.isSent
                                    ? Colors.white.withOpacity(0.2)
                                    : ThemeConstants.primaryColor
                                        .withOpacity(0.2),
                              ),
                              child: Slider(
                                value: _playbackProgress,
                                onChanged: (value) {
                                  setState(() {
                                    _playbackProgress = value;
                                  });
                                  // TODO: Implement seek functionality
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Duration
                      Text(
                        formattedDuration,
                        style: TextStyle(
                          color: widget.isSent
                              ? Colors.white.withOpacity(0.7)
                              : textColor?.withOpacity(0.7),
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(width: 4),
                      // Timestamp
                      Text(
                        DateFormat('HH:mm').format(widget.message.timestamp),
                        style: TextStyle(
                          color: widget.isSent
                              ? Colors.white.withOpacity(0.7)
                              : theme.textTheme.bodySmall?.color,
                          fontSize: 11,
                        ),
                      ),
                      // Status indicators
                      if (widget.isSent && widget.message.status != null)
                        Padding(
                          padding: const EdgeInsets.only(left: 4),
                          child: _buildStatusIcon(widget.message.status!),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Options button (three dots) that appears on hover
          if (_isHovering)
            Positioned(
              top: 2,
              // Position based on message direction
              right: widget.isSent ? null : -4,
              left: widget.isSent ? -4 : null,
              child: _buildOptionsButton(context),
            ),
        ],
      ),
    );
  }

  Widget _buildOptionsButton(BuildContext context) {
    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      clipBehavior: Clip.hardEdge,
      child: InkWell(
        onTap: () {
          _showOptionsPopup(context);
        },
        child: Container(
          width: 32,
          height: 32,
          margin: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF383838)
                : const Color(0xFFFFFFFF),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(
            Icons.more_horiz,
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white70
                : const Color(0xFF444444),
            size: 18,
          ),
        ),
      ),
    );
  }

  void _showOptionsPopup(BuildContext context) {
    // Create menu options
    final List<PopupMenuEntry<String>> items = [
      PopupMenuItem<String>(
        value: 'reply',
        child: Row(
          children: [
            Icon(Icons.reply, color: ThemeConstants.primaryColor, size: 18),
            const SizedBox(width: 8),
            Text(TextStrings.reply),
          ],
        ),
      ),
      PopupMenuItem<String>(
        value: 'forward',
        child: Row(
          children: [
            Icon(Icons.forward, color: ThemeConstants.primaryColor, size: 18),
            const SizedBox(width: 8),
            Text(TextStrings.forward),
          ],
        ),
      ),
      PopupMenuItem<String>(
        value: 'delete',
        child: Row(
          children: [
            Icon(Icons.delete_outline, color: ThemeConstants.red, size: 18),
            const SizedBox(width: 8),
            Text(TextStrings.delete),
          ],
        ),
      ),
    ];

    // Show the popup at the current pointer position
    final RenderBox overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;
    final RenderBox button = context.findRenderObject() as RenderBox;
    final position = RelativeRect.fromRect(
      Rect.fromPoints(
        button.localToGlobal(
            widget.isSent ? Offset.zero : button.size.bottomRight(Offset.zero),
            ancestor: overlay),
        button.localToGlobal(button.size.bottomRight(Offset.zero),
            ancestor: overlay),
      ),
      Offset.zero & overlay.size,
    );

    // Show the popup and handle selection
    showMenu<String>(
      context: context,
      position: position,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 8,
      items: items,
    ).then((value) {
      // Handle selection
      if (value == null) return;

      print("Selected voice option: $value"); // Debug log

      // Get the controller from the message
      final controller = widget.message.controller;

      switch (value) {
        case 'reply':
          print("Replying to voice message: ${widget.message.id}");
          if (controller != null) {
            controller.setReplyToMessage(widget.message);
          } else if (widget.onReply != null) {
            widget.onReply!(widget.message);
          }
          break;

        case 'forward':
          print("Forwarding voice message: ${widget.message.id}");
          if (controller != null) {
            _showForwardSheet(context, widget.message, controller);
          }
          break;

        case 'delete':
          print("Deleting voice message: ${widget.message.id}");
          if (controller != null) {
            controller.deleteMessage(widget.message);
          }
          break;
      }
    });
  }

  void _showForwardSheet(
      BuildContext context, Message message, MessagesController controller) {
    // Get the current context which will be used to show the bottom sheet
    final currentContext = context;

    // Create a controller for the search field
    final TextEditingController searchController = TextEditingController();

    // Track filtered conversations
    List<Conversation> filteredConversations =
        List.from(controller.conversations);

    if (controller.conversations.isEmpty) {
      // Replace with ResponsiveSnackbar
      ResponsiveSnackBar.showInfo(
        context: context,
        message: TextStrings.noConversationsForward,
      );
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
                  filteredConversations = List.from(controller.conversations);
                } else {
                  filteredConversations =
                      controller.conversations.where((convo) {
                    return convo.displayName
                        .toLowerCase()
                        .contains(query.toLowerCase());
                  }).toList();
                }
              });
            }

            return GestureDetector(
              onTap: () => FocusScope.of(builderContext).unfocus(),
              child: Container(
                height: MediaQuery.of(builderContext).size.height * 0.7,
                decoration: BoxDecoration(
                  color: Theme.of(builderContext).brightness == Brightness.dark
                      ? const Color(0xFF2D2D2D)
                      : Colors.white,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(20)),
                ),
                margin: const EdgeInsets.only(left: 10, right: 10, top: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Handle bar at top for drag UX
                    Center(
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 10),
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey[400],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),

                    // Title section
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
                                const Text(TextStrings.voiceMessage),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const Divider(),

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

                    // Search field
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

                    // Conversation list
                    Expanded(
                      child: filteredConversations.isEmpty
                          ? const Center(
                              child: Text('No matching conversations'))
                          : ListView.builder(
                              itemCount: filteredConversations.length,
                              itemBuilder: (listContext, index) {
                                final conversation =
                                    filteredConversations[index];

                                // Don't allow forwarding to the current conversation
                                if (controller.selectedConversation?.id ==
                                    conversation.id) {
                                  return const SizedBox.shrink();
                                }

                                // Replace standard ListTile with HoverListTile
                                return _HoverListTile(
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

                                    // Forward the message
                                    controller
                                        .forwardMessage(message, conversation)
                                        .then((_) {
                                      if (currentContext.mounted) {
                                        // Replace with ResponsiveSnackbar
                                        ResponsiveSnackBar.showSuccess(
                                          context: currentContext,
                                          message:
                                              "${TextStrings.messageSaved} ${conversation.displayName}",
                                        );
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

  Color _getBarColor(int index) {
    // Determine if this bar is part of the played section
    final isPlayed = index / 15 <= _playbackProgress;

    if (widget.isSent) {
      return isPlayed ? Colors.white : Colors.white.withOpacity(0.4);
    } else {
      return isPlayed
          ? ThemeConstants.primaryColor
          : ThemeConstants.primaryColor.withOpacity(0.4);
    }
  }

  void _togglePlayback() {
    // Mock playback functionality
    setState(() {
      _isPlaying = !_isPlaying;
      if (_isPlaying) {
        // Start animation for progress
        _animatePlayback();
      }
    });
  }

  void _animatePlayback() {
    // Mock playback progress
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted && _isPlaying) {
        setState(() {
          _playbackProgress += 0.01;
          if (_playbackProgress >= 1.0) {
            _playbackProgress = 0.0;
            _isPlaying = false;
          } else {
            _animatePlayback();
          }
        });
      }
    });
  }

  String _formatDuration(int seconds) {
    final minutes = (seconds / 60).floor();
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  Widget _buildStatusIcon(MessageStatus status) {
    switch (status) {
      case MessageStatus.sending:
        return const Icon(
          Icons.access_time,
          size: 12,
          color: Colors.white70,
        );
      case MessageStatus.sent:
        return const Icon(
          Icons.check,
          size: 12,
          color: Colors.white70,
        );
      case MessageStatus.delivered:
        return const Icon(
          Icons.done_all,
          size: 12,
          color: Colors.white70,
        );
      case MessageStatus.read:
        return const Icon(
          Icons.done_all,
          size: 12,
          color: Colors.lightBlueAccent,
        );
    }
  }

  void _showForwardOptions(BuildContext context, Message message,
      [MessagesController? providedController]) {
    final controller = providedController ?? message.controller;
    if (controller == null) return;

    // Get the current context which will be used to show the bottom sheet
    final currentContext = context;

    // Create a controller for the search field
    final TextEditingController searchController = TextEditingController();

    // Track filtered conversations
    List<Conversation> filteredConversations =
        List.from(controller.conversations);

    if (controller.conversations.isEmpty) {
      ScaffoldMessenger.of(currentContext).showSnackBar(
          SnackBar(content: Text(TextStrings.noConversationsForward)));
      return;
    }

    // Show modal bottom sheet with forward options
    // ...copy the implementation from MessageBubble...
  }

  String _truncateText(String text, int maxLength) {
    if (text.length <= maxLength) {
      return text;
    }
    return '${text.substring(0, maxLength)}...';
  }
}

// Add this new widget for hover effect
class _HoverListTile extends StatefulWidget {
  final Widget leading;
  final Widget title;
  final Widget subtitle;
  final VoidCallback onTap;

  const _HoverListTile({
    required this.leading,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  State<_HoverListTile> createState() => _HoverListTileState();
}

class _HoverListTileState extends State<_HoverListTile> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: Container(
        color: _isHovering
            ? (isDarkMode
                ? ThemeConstants.primaryColor.withOpacity(0.1)
                : ThemeConstants.primaryColor.withOpacity(0.05))
            : Colors.transparent,
        child: ListTile(
          leading: widget.leading,
          title: widget.title,
          subtitle: widget.subtitle,
          onTap: widget.onTap,
        ),
      ),
    );
  }
}
