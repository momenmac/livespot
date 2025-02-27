import 'package:flutter/material.dart';
import 'package:flutter_application_2/core/constants/text_strings.dart';
import 'package:flutter_application_2/core/constants/theme_constants.dart';
import 'package:flutter_application_2/ui/pages/messages/messages_controller.dart';
import 'package:flutter_application_2/ui/pages/messages/models/conversation.dart';
import 'package:flutter_application_2/ui/pages/messages/widgets/message_bubble.dart';

class MessageDetail extends StatelessWidget {
  final MessagesController controller;
  final Conversation conversation;
  final VoidCallback onBackPressed;

  const MessageDetail({
    super.key,
    required this.controller,
    required this.conversation,
    required this.onBackPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return Column(
      children: [
        // Header with back button and conversation info - Always show in chat detail page
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
                onPressed: onBackPressed,
              ),
              CircleAvatar(
                backgroundImage: NetworkImage(conversation.avatarUrl),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      conversation.displayName,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (conversation.isOnline && !conversation.isGroup)
                      Text(
                        TextStrings.online,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: ThemeConstants.green,
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
              // image: DecorationImage(
              //   image: AssetImage(
              //     isDarkMode
              //         ? "assets/images/chat_bg_dark.png"
              //         : "assets/images/chat_bg_light.png",
              //   ),
              //   repeat: ImageRepeat.repeat,
              //   opacity: 0.1,
              // ),
            ),
            child: ListView.builder(
              controller: controller.messageScrollController,
              reverse: true,
              padding: const EdgeInsets.all(16),
              itemCount: conversation.messages.length,
              itemBuilder: (context, index) {
                final message = conversation.messages[index];
                final showAvatar = conversation.isGroup && !message.isSent;
                final showName = conversation.isGroup && !message.isSent;

                // Determine if we should show timestamp header
                final showDateHeader = _shouldShowDateHeader(
                  index,
                  conversation.messages,
                );

                return Column(
                  children: [
                    if (showDateHeader)
                      _buildDateHeader(
                          conversation.messages[index].timestamp, theme),
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

        // Message input box
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
                IconButton(
                  icon: const Icon(Icons.attach_file),
                  onPressed: () {
                    // TODO: Implement file attachment
                  },
                ),
                Expanded(
                  child: TextField(
                    controller: controller.messageController,
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
                      if (controller.messageController.text.trim().isNotEmpty) {
                        controller.sendMessage(
                          controller.messageController.text.trim(),
                        );
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
                  // Copy message content to clipboard
                  Navigator.pop(context);
                },
              ),
              if (message.isSent)
                ListTile(
                  leading: Icon(Icons.edit, color: ThemeConstants.orange),
                  title: Text(TextStrings.edit),
                  onTap: () {
                    // Edit message
                    Navigator.pop(context);
                  },
                ),
              ListTile(
                leading: Icon(Icons.delete_outline, color: ThemeConstants.red),
                title: Text(TextStrings.delete),
                onTap: () {
                  Navigator.pop(context);
                  controller.deleteMessage(message);
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
                  conversation.isMuted ? Icons.volume_up : Icons.volume_off,
                  color: ThemeConstants.primaryColor,
                ),
                title: Text(
                  conversation.isMuted ? TextStrings.unmute : TextStrings.mute,
                ),
                onTap: () {
                  controller.toggleMute(conversation);
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
              if (conversation.isGroup)
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
                  conversation.isArchived ? Icons.unarchive : Icons.archive,
                  color: ThemeConstants.grey,
                ),
                title: Text(
                  conversation.isArchived
                      ? TextStrings.unarchive
                      : TextStrings.archive,
                ),
                onTap: () {
                  controller.toggleArchive(conversation);
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
              controller.deleteConversation(conversation);
              Navigator.pop(context);
              onBackPressed();
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
