import 'package:flutter/material.dart';
import 'package:flutter_application_2/core/constants/text_strings.dart';
import 'package:flutter_application_2/core/constants/theme_constants.dart';
import 'package:flutter_application_2/ui/pages/messages/models/conversation.dart';
import 'package:flutter_application_2/ui/pages/messages/models/message.dart';
import 'package:intl/intl.dart';
import 'package:flutter_application_2/ui/pages/messages/widgets/voice_message_bubble.dart';
import 'package:flutter_application_2/ui/pages/messages/widgets/highlighted_message_container.dart';

class MessageBubble extends StatefulWidget {
  final Message message;
  final bool showAvatar;
  final bool showName;
  final VoidCallback? onLongPress;
  final Function(Message)? onSwipeReply;
  final Function(String)? onReplyTap;

  const MessageBubble({
    super.key,
    required this.message,
    this.showAvatar = false,
    this.showName = false,
    this.onLongPress,
    this.onSwipeReply,
    this.onReplyTap,
  });

  @override
  State<MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<MessageBubble> {
  bool _isHovering = false;
  final GlobalKey _popupMenuKey = GlobalKey();

  @override
  void dispose() {
    // Ensure any menu is dismissed to prevent context errors
    if (mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // This safely dismisses any open menu when the widget is disposed
        if (context.mounted) {
          Navigator.of(context, rootNavigator: true).popUntil((route) {
            return route is! PopupRoute;
          });
        }
      });
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final isSent = widget.message.senderId == 'current';
    final bubbleColor = isSent
        ? ThemeConstants.primaryColor
        : isDarkMode
            ? ThemeConstants.darkCardColor
            : ThemeConstants.lightCardColor;
    final textColor = isSent ? Colors.white : theme.textTheme.bodyLarge?.color;

    return Padding(
      padding: EdgeInsets.only(
        bottom: 8,
        left: isSent
            ? 60
            : widget.showAvatar
                ? 0
                : 8,
        right: isSent ? 8 : 60,
      ),
      child: Row(
        mainAxisAlignment:
            isSent ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (widget.showAvatar && !isSent)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: CircleAvatar(
                radius: 16,
                backgroundImage: NetworkImage(
                    'https://ui-avatars.com/api/?name=${Uri.encodeComponent(widget.message.senderName)}'),
              ),
            ),
          Flexible(
            child: MouseRegion(
              onEnter: (_) => setState(() => _isHovering = true),
              onExit: (_) => setState(() => _isHovering = false),
              child: Stack(
                children: [
                  Column(
                    crossAxisAlignment: isSent
                        ? CrossAxisAlignment.end
                        : CrossAxisAlignment.start,
                    children: [
                      if (widget.showName && !isSent) _buildSenderName(),

                      // Forwarded badge - shows above any message type
                      if (widget.message.isForwarded)
                        Container(
                          margin: EdgeInsets.only(
                            bottom: 4,
                            left: isSent ? 0 : 12,
                            right: isSent ? 12 : 0,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.forward,
                                size: 12,
                                color: isSent ? Colors.white : Colors.black87,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                TextStrings.forwarded,
                                style: TextStyle(
                                  fontWeight: FontWeight.w500,
                                  fontStyle: FontStyle.italic,
                                  fontSize: 11,
                                  color: isSent ? Colors.white : Colors.black87,
                                ),
                              ),
                            ],
                          ),
                        ),

                      // Reply preview - tappable to navigate to original message
                      if (widget.message.isReply)
                        GestureDetector(
                          onTap: () {
                            if (widget.onReplyTap != null) {
                              widget.onReplyTap!(widget.message.replyToId!);
                            }
                          },
                          child:
                              _buildReplyPreview(context, isSent, isDarkMode),
                        ),

                      // Handle both message types with Dismissible
                      Dismissible(
                        key: Key("dismissible_${widget.message.id}"),
                        direction: isSent
                            ? DismissDirection.startToEnd
                            : DismissDirection.endToStart,
                        background: _buildSwipeBackground(isSent),
                        confirmDismiss: (direction) async {
                          if (widget.onSwipeReply != null) {
                            widget.onSwipeReply!(widget.message);
                          }
                          return false;
                        },
                        child: widget.message.messageType == MessageType.voice
                            ? VoiceMessageBubble(
                                message: widget.message,
                                isSent: isSent,
                                onLongPress: widget.onLongPress,
                                onReply: widget.onSwipeReply,
                              )
                            : _buildMessageBubble(
                                context, theme, isSent, bubbleColor, textColor),
                      ),
                    ],
                  ),

                  // Options button (three dots) that appears on hover
                  if (_isHovering)
                    Positioned(
                      top: (widget.showName && !isSent) ? 24 : 2,
                      // Position based on message direction
                      right: isSent ? null : -4,
                      left: isSent ? -4 : null,
                      child: _buildOptionsButton(context, isSent),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionsButton(BuildContext context, bool isSent) {
    return Container(
      width: 32, // Slightly increased size
      height: 32,
      margin: const EdgeInsets.only(
          top: 4, right: 4, left: 4), // Add margin to prevent cropping
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF383838)
            : const Color(0xFFFFFFFF), // Pure white for better contrast
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15), // Slightly darker shadow
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: PopupMenuButton<String>(
          key: _popupMenuKey,
          padding: EdgeInsets.zero,
          tooltip: "Message options",
          icon: Icon(
            Icons.more_horiz,
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white70
                : const Color(0xFF444444), // Darker color for better visibility
            size: 18, // Slightly larger
          ),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          position: PopupMenuPosition.under,
          onCanceled: () {
            if (mounted) setState(() {}); // Update state only if mounted
          },
          itemBuilder: (context) => [
            // Reply option
            PopupMenuItem<String>(
              value: 'reply',
              child: Row(
                children: [
                  Icon(Icons.reply,
                      color: ThemeConstants.primaryColor, size: 18),
                  const SizedBox(width: 8),
                  Text(TextStrings.reply),
                ],
              ),
            ),

            // Forward option
            PopupMenuItem<String>(
              value: 'forward',
              child: Row(
                children: [
                  Icon(Icons.forward,
                      color: ThemeConstants.primaryColor, size: 18),
                  const SizedBox(width: 8),
                  Text(TextStrings.forward),
                ],
              ),
            ),

            // Copy option - only for text messages
            if (widget.message.messageType != MessageType.voice)
              PopupMenuItem<String>(
                value: 'copy',
                child: Row(
                  children: [
                    Icon(Icons.content_copy, color: Colors.grey[700], size: 18),
                    const SizedBox(width: 8),
                    Text(TextStrings.copy),
                  ],
                ),
              ),

            // Edit option - only for current user's text messages
            if (widget.message.senderId == 'current' &&
                widget.message.messageType != MessageType.voice)
              PopupMenuItem<String>(
                value: 'edit',
                child: Row(
                  children: [
                    Icon(Icons.edit, color: ThemeConstants.orange, size: 18),
                    const SizedBox(width: 8),
                    Text(TextStrings.edit),
                  ],
                ),
              ),

            // Delete option
            PopupMenuItem<String>(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete_outline,
                      color: ThemeConstants.red, size: 18),
                  const SizedBox(width: 8),
                  Text(TextStrings.delete),
                ],
              ),
            ),
          ],
          onSelected: (value) {
            if (!mounted) return; // Skip if widget is unmounted

            // Get the controller directly from the message
            final controller = widget.message.controller;

            switch (value) {
              case 'reply':
                // First try to use direct controller method
                if (controller != null) {
                  controller.setReplyToMessage(widget.message);
                }
                // Fallback to the callback if controller isn't available
                else if (widget.onSwipeReply != null) {
                  widget.onSwipeReply!(widget.message);
                }
                break;

              case 'forward':
                if (controller != null) {
                  _showForwardOptions(context, widget.message);
                } else if (widget.onLongPress != null) {
                  widget.onLongPress!();
                }
                break;

              case 'copy':
                if (controller != null) {
                  controller.copyToClipboard(widget.message.content, context);
                } else if (widget.onLongPress != null) {
                  widget.onLongPress!();
                }
                break;

              case 'edit':
                if (controller != null) {
                  controller.setEditingMessage(widget.message);
                } else if (widget.onLongPress != null) {
                  widget.onLongPress!();
                }
                break;

              case 'delete':
                if (controller != null) {
                  controller.deleteMessage(widget.message);
                } else if (widget.onLongPress != null) {
                  widget.onLongPress!();
                }
                break;
            }
          },
        ),
      ),
    );
  }

  // Add this method to handle forwarding directly from the message bubble
  void _showForwardOptions(BuildContext context, Message message) {
    final controller = message.controller;
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
                          ? Center(child: Text('No matching conversations'))
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

                                    // Forward the message
                                    controller
                                        .forwardMessage(message, conversation)
                                        .then((_) {
                                      if (currentContext.mounted) {
                                        ScaffoldMessenger.of(currentContext)
                                            .showSnackBar(
                                          SnackBar(
                                            content: Text(
                                                "${TextStrings.messageSaved} ${conversation.displayName}"),
                                          ),
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

  // Helper method to truncate text for preview
  String _truncateText(String text, int maxLength) {
    if (text.length <= maxLength) {
      return text;
    }
    return '${text.substring(0, maxLength)}...';
  }

  Widget _buildSenderName() {
    return Padding(
      padding: const EdgeInsets.only(left: 12, bottom: 4),
      child: Text(
        widget.message.senderName,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 12,
          color: Colors.grey[700],
        ),
      ),
    );
  }

  Widget _buildReplyPreview(
      BuildContext context, bool isSent, bool isDarkMode) {
    return Container(
      margin: EdgeInsets.only(
        bottom: 4,
        left: isSent ? 0 : 12,
        right: isSent ? 12 : 0,
      ),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isSent
            ? ThemeConstants.primaryColor.withOpacity(0.3)
            : (isDarkMode ? Colors.grey[800] : Colors.grey[200]),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: ThemeConstants.primaryColor.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.reply,
            size: 14,
            color: isSent
                ? Colors.white70
                : Theme.of(context).textTheme.bodySmall?.color,
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "${TextStrings.replyingTo} ${widget.message.replyToSenderName}",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                    color: isSent
                        ? Colors.white70
                        : Theme.of(context).textTheme.bodySmall?.color,
                  ),
                ),
                Text(
                  widget.message.replyToMessageType == MessageType.voice
                      ? TextStrings.voiceMessage
                      : widget.message.replyToContent ?? "",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: isSent
                        ? Colors.white70
                        : Theme.of(context).textTheme.bodySmall?.color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Fixed: Corrected the previously corrupted swipe background method
  Widget _buildSwipeBackground(bool isSent) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      color: ThemeConstants.green.withOpacity(0.3),
      alignment: isSent ? Alignment.centerLeft : Alignment.centerRight,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.reply, color: ThemeConstants.green),
          Text(
            TextStrings.reply,
            style: TextStyle(
              color: ThemeConstants.green,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // Fixed: Completely rewrote the message bubble builder with proper syntax
  Widget _buildMessageBubble(BuildContext context, ThemeData theme, bool isSent,
      Color bubbleColor, Color? textColor) {
    return InkWell(
      onLongPress: widget.onLongPress,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06), // Slightly heavier shadow
              blurRadius: 3,
              offset: const Offset(0, 1),
            ),
          ],
          // Add a subtle border to improve definition in light mode
          border: !isSent && theme.brightness == Brightness.light
              ? Border.all(color: Colors.grey.withOpacity(0.2), width: 0.5)
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              _cleanMessageContent(widget.message.content),
              style: TextStyle(
                color: textColor,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 2),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  DateFormat('HH:mm').format(widget.message.timestamp),
                  style: TextStyle(
                    color: isSent
                        ? Colors.white.withOpacity(0.7)
                        : theme.textTheme.bodySmall?.color,
                    fontSize: 11,
                  ),
                ),
                if (widget.message.isEdited == true)
                  Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Text(
                      TextStrings.messageEdited,
                      style: TextStyle(
                        color: isSent
                            ? Colors.white.withOpacity(0.7)
                            : theme.textTheme.bodySmall?.color,
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                if (isSent && widget.message.status != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: _buildStatusIcon(widget.message.status!),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Fixed: Corrected the method to clean message content
  String _cleanMessageContent(String content) {
    // Remove any message number prefix like "1: " or "20: "
    if (RegExp(r'^\d+:\s').hasMatch(content)) {
      return content.replaceFirst(RegExp(r'^\d+:\s'), '');
    }

    // Remove sender name prefix if exists
    if (content.startsWith("${widget.message.senderName}: ")) {
      return content.substring(widget.message.senderName.length + 2);
    }

    return content;
  }

  // Fixed: Removed duplicated method and kept just this one
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
}
