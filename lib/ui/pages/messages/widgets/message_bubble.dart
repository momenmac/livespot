import 'package:flutter/material.dart';
import 'package:flutter_application_2/constants/text_strings.dart';
import 'package:flutter_application_2/constants/theme_constants.dart';
import 'package:flutter_application_2/ui/pages/messages/messages_controller.dart';
import 'package:flutter_application_2/ui/pages/messages/models/conversation.dart';
import 'package:flutter_application_2/ui/pages/messages/models/message.dart';
import 'package:intl/intl.dart';
import 'package:flutter_application_2/ui/pages/messages/widgets/voice_message_bubble.dart';
import 'package:flutter_application_2/ui/widgets/responsive_snackbar.dart';
import 'package:flutter_application_2/ui/pages/messages/widgets/image_message_bubble.dart';

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
    // Remove the post-frame callback as it was causing the unmounting error
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
                                color:
                                    isDarkMode ? Colors.white : Colors.black87,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                TextStrings.forwarded,
                                style: TextStyle(
                                  fontWeight: FontWeight.w500,
                                  fontStyle: FontStyle.italic,
                                  fontSize: 11,
                                  color: isDarkMode
                                      ? Colors.white
                                      : Colors.black87,
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
                        child: _buildMessageContentByType(
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

  // New helper method to build the appropriate message content based on type
  Widget _buildMessageContentByType(BuildContext context, ThemeData theme,
      bool isSent, Color bubbleColor, Color? textColor) {
    switch (widget.message.messageType) {
      case MessageType.voice:
        return VoiceMessageBubble(
          message: widget.message,
          isSent: isSent,
          onLongPress: widget.onLongPress,
          onReply: widget.onSwipeReply,
        );

      case MessageType.image:
        return ImageMessageBubble(
          message: widget.message,
          isSent: isSent,
          onLongPress: widget.onLongPress,
          onReply: widget.onSwipeReply,
        );

      case MessageType.text:
      default:
        return _buildMessageBubble(
            context, theme, isSent, bubbleColor, textColor);
    }
  }

  Widget _buildOptionsButton(BuildContext context, bool isSent) {
    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      clipBehavior: Clip.hardEdge,
      child: InkWell(
        onTap: () {
          _showOptionsPopup(context, isSent);
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

  void _showOptionsPopup(BuildContext context, bool isSent) {
    // Check if widget is still mounted before showing menu
    if (!mounted) return;

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
    ];

    // Add message-type specific options
    if (widget.message.messageType != MessageType.voice) {
      items.add(
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
      );
    }

    // Add edit option only for user's own text messages
    if (widget.message.senderId == 'current' &&
        widget.message.messageType != MessageType.voice) {
      items.add(
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
      );
    }

    // Add delete option
    items.add(
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
    );

    // Show the popup at the current pointer position
    final RenderBox overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;
    final RenderBox button = context.findRenderObject() as RenderBox;
    final position = RelativeRect.fromRect(
      Rect.fromPoints(
        button.localToGlobal(
            isSent ? Offset.zero : button.size.bottomRight(Offset.zero),
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
      // Check if widget is still mounted before proceeding
      if (!mounted || value == null) return;

      print("Selected option: $value"); // Debug log

      // Get the controller from the message
      final controller = widget.message.controller;

      switch (value) {
        case 'reply':
          print("Replying to message: ${widget.message.id}");
          if (controller != null) {
            controller.setReplyToMessage(widget.message);
          } else if (widget.onSwipeReply != null) {
            widget.onSwipeReply!(widget.message);
          }
          break;

        case 'forward':
          print("Forwarding message: ${widget.message.id}");
          if (controller != null) {
            _showForwardSheet(context, widget.message, controller);
          }
          break;

        case 'copy':
          print("Copying message: ${widget.message.content}");
          if (controller != null) {
            controller.copyToClipboard(widget.message.content, context);
          }
          break;

        case 'edit':
          print("Editing message: ${widget.message.id}");
          if (controller != null) {
            controller.setEditingMessage(widget.message);
          }
          break;

        case 'delete':
          print("Deleting message: ${widget.message.id}");
          if (controller != null) {
            controller.deleteMessage(widget.message);
          }
          break;
      }
    });
  }

  void _showForwardSheet(
      BuildContext context, Message message, MessagesController controller) {
    // Store context in local variable to avoid issues with context after unmounting
    final currentContext = context;

    if (!mounted) return;

    // Get the current context which will be used to show the bottom sheet

    // Create a controller for the search field
    final TextEditingController searchController = TextEditingController();

    // Track filtered conversations
    List<Conversation> filteredConversations =
        List.from(controller.conversations);

    if (controller.conversations.isEmpty) {
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
                                message.messageType == MessageType.voice
                                    ? const Text(TextStrings.voiceMessage)
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

  // Helper method to truncate text for preview
  String _truncateText(String text, int maxLength) {
    if (text.length <= maxLength) {
      return text;
    }
    return '${text.substring(0, maxLength)}...';
  }

  // Helper method to find the MessagesController from context
  MessagesController? findMessagesController(BuildContext context) {
    try {
      // Try to find a reference to the controller in the widget tree
      // Check for InheritedWidgets or use other methods to get controller
      return null; // Fallback if not found
    } catch (e) {
      print('Error finding controller: $e');
      return null;
    }
  }

// Update _showForwardOptions to accept an optional controller parameter
  void _showForwardOptions(BuildContext context, Message message,
      [MessagesController? providedController]) {
    final controller = providedController ?? message.controller;
    if (controller == null) return;

    // ...existing code for forward options...
  }

  // Add this method to handle forwarding directly from the message bubble

  // Helper method to truncate text for preview

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
    return GestureDetector(
      onTap: () {
        // Navigate to the original message when tapped
        if (widget.onReplyTap != null && widget.message.replyToId != null) {
          widget.onReplyTap!(widget.message.replyToId!);
        }
      },
      child: Container(
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
                  Row(
                    mainAxisSize: MainAxisSize.min,
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
                      // Add indicator to show it's tappable
                      const SizedBox(width: 4),
                      Icon(
                        Icons.touch_app,
                        size: 10,
                        color: isSent
                            ? Colors.white70
                            : Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.color
                                ?.withOpacity(0.7),
                      ),
                    ],
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
      case MessageStatus.failed:
        // TODO: Handle this case.
        throw UnimplementedError();
    }
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
