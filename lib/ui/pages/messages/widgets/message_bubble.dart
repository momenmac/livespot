import 'package:flutter/material.dart';
import 'package:flutter_application_2/core/constants/text_strings.dart';
import 'package:flutter_application_2/core/constants/theme_constants.dart';
import 'package:flutter_application_2/ui/pages/messages/models/message.dart';
import 'package:intl/intl.dart';
import 'package:flutter_application_2/ui/pages/messages/widgets/voice_message_bubble.dart';

class MessageBubble extends StatelessWidget {
  final Message message;
  final bool showAvatar;
  final bool showName;
  final VoidCallback? onLongPress;
  final Function(Message)? onSwipeReply;
  final Function(String)?
      onReplyTap; // Add callback for tapping on reply preview

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
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final isSent = message.senderId == 'current';
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
            : showAvatar
                ? 0
                : 8,
        right: isSent ? 8 : 60,
      ),
      child: Row(
        mainAxisAlignment:
            isSent ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (showAvatar && !isSent)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: CircleAvatar(
                radius: 16,
                backgroundImage: NetworkImage(
                    'https://ui-avatars.com/api/?name=${Uri.encodeComponent(message.senderName)}'),
              ),
            ),
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isSent ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (showName && !isSent) _buildSenderName(),

                // Forwarded badge - shows above any message type
                if (message.isForwarded)
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
                          // Use much higher contrast color for better visibility
                          color: isSent
                              ? Colors.white
                              : Colors.black87, // Much darker in light mode
                        ),
                        const SizedBox(width: 4),
                        Text(
                          // Only show "Forwarded" without mentioning sender
                          TextStrings.forwarded,
                          style: TextStyle(
                            fontWeight: FontWeight.w500, // Make slightly bolder
                            fontStyle: FontStyle.italic,
                            fontSize: 11, // Slightly larger
                            // Higher contrast color
                            color: isSent
                                ? Colors.white
                                : Colors.black87, // Much darker in light mode
                          ),
                        ),
                      ],
                    ),
                  ),

                // Reply preview - tappable to navigate to original message
                if (message.isReply)
                  GestureDetector(
                    onTap: () {
                      if (onReplyTap != null) {
                        onReplyTap!(message.replyToId!);
                      }
                    },
                    child: _buildReplyPreview(context, isSent, isDarkMode),
                  ),

                // Handle both message types with Dismissible
                Dismissible(
                  key: Key("dismissible_${message.id}"),
                  direction: isSent
                      ? DismissDirection.startToEnd
                      : DismissDirection.endToStart,
                  background: _buildSwipeBackground(isSent),
                  confirmDismiss: (direction) async {
                    if (onSwipeReply != null) {
                      onSwipeReply!(message);
                    }
                    return false;
                  },
                  child: message.messageType == MessageType.voice
                      ? VoiceMessageBubble(
                          message: message,
                          isSent: isSent,
                          onLongPress:
                              onLongPress, // Pass the long press handler
                        )
                      : _buildMessageBubble(
                          context, theme, isSent, bubbleColor, textColor),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSenderName() {
    return Padding(
      padding: const EdgeInsets.only(left: 12, bottom: 4),
      child: Text(
        message.senderName,
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
                  "${TextStrings.replyingTo} ${message.replyToSenderName}",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                    color: isSent
                        ? Colors.white70
                        : Theme.of(context).textTheme.bodySmall?.color,
                  ),
                ),
                Text(
                  message.replyToMessageType == MessageType.voice
                      ? TextStrings.voiceMessage
                      : message.replyToContent ?? "",
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

  Widget _buildMessageBubble(BuildContext context, ThemeData theme, bool isSent,
      Color bubbleColor, Color? textColor) {
    return InkWell(
      onLongPress: onLongPress,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              _cleanMessageContent(message.content),
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
                  DateFormat('HH:mm').format(message.timestamp),
                  style: TextStyle(
                    color: isSent
                        ? Colors.white.withOpacity(0.7)
                        : theme.textTheme.bodySmall?.color,
                    fontSize: 11,
                  ),
                ),
                if (message.isEdited == true)
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
                if (isSent && message.status != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: _buildStatusIcon(message.status!),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // New method to clean up message content
  String _cleanMessageContent(String content) {
    // Remove any message number prefix like "1: " or "20: "
    if (RegExp(r'^\d+:\s').hasMatch(content)) {
      return content.replaceFirst(RegExp(r'^\d+:\s'), '');
    }

    // Remove sender name prefix if exists
    if (content.startsWith("${message.senderName}: ")) {
      return content.substring(message.senderName.length + 2);
    }

    return content;
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
}
