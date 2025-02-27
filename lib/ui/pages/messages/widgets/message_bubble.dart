import 'package:flutter/material.dart';
import 'package:flutter_application_2/core/constants/theme_constants.dart';
import 'package:flutter_application_2/ui/pages/messages/models/message.dart';
import 'package:intl/intl.dart';

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
    final isSent = message.isSent;

    final bubbleColor = isSent
        ? ThemeConstants.primaryColor
        : isDarkMode
            ? ThemeConstants.darkCardColor
            : ThemeConstants.lightCardColor;

    final textColor = isSent ? Colors.white : theme.textTheme.bodyLarge!.color;

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
          // Avatar for received messages in group chats
          if (showAvatar && !isSent)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: CircleAvatar(
                radius: 16,
                backgroundImage: NetworkImage(
                    'https://ui-avatars.com/api/?name=${Uri.encodeComponent(message.senderName)}'),
              ),
            ),

          // Message content
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isSent ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                // Sender name for group chats
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

                // Message bubble
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
                          message.content,
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
    }
  }
}
