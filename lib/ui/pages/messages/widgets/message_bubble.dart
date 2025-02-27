import 'package:flutter/material.dart';
import 'package:flutter_application_2/core/constants/theme_constants.dart';
import 'package:flutter_application_2/ui/pages/messages/models/message.dart';
import 'package:intl/intl.dart';
import 'package:flutter_application_2/ui/pages/messages/widgets/voice_message_bubble.dart';

class MessageBubble extends StatelessWidget {
  final Message message;
  final bool showAvatar;
  final bool showName;
  final VoidCallback? onLongPress;

  const MessageBubble({
    super.key,
    required this.message,
    this.showAvatar = false,
    this.showName = false,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    // Explicitly check if the message is from the current user
    final isSent = message.senderId == 'current';

    final bubbleColor = isSent
        ? ThemeConstants.primaryColor
        : isDarkMode
            ? ThemeConstants.darkCardColor
            : ThemeConstants.lightCardColor;

    final textColor = isSent ? Colors.white : theme.textTheme.bodyLarge?.color;

    // Remove debug print that might be confusing

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
                if (showName && !isSent)
                  Padding(
                    padding: const EdgeInsets.only(left: 12, bottom: 4),
                    child: Text(
                      message.senderName,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: theme.textTheme.bodySmall?.color,
                      ),
                    ),
                  ),

                // Choose appropriate bubble type based on message type
                if (message.messageType == MessageType.voice)
                  VoiceMessageBubble(
                    message: message,
                    isSent: isSent,
                  )
                else
                  InkWell(
                    onLongPress: onLongPress,
                    borderRadius: BorderRadius.circular(18),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
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
                            // Clean up any message formatting (keep only the message content)
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
                  ),
              ],
            ),
          ),
        ],
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
