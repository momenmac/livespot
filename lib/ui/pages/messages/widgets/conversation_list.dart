import 'package:flutter/material.dart';
import 'package:flutter_application_2/core/constants/text_strings.dart';
import 'package:flutter_application_2/core/constants/theme_constants.dart';
import 'package:flutter_application_2/ui/pages/messages/chat_detail_page.dart';
import 'package:flutter_application_2/ui/pages/messages/messages_controller.dart';
import 'package:flutter_application_2/ui/pages/messages/models/conversation.dart';
import 'package:intl/intl.dart';

class ConversationList extends StatelessWidget {
  final MessagesController controller;
  final Function(Conversation) onConversationSelected;

  const ConversationList({
    super.key,
    required this.controller,
    required this.onConversationSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    if (controller.conversations.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.forum_outlined,
              size: 60,
              color: ThemeConstants.grey.withOpacity(0.6),
            ),
            const SizedBox(height: 16),
            Text(
              controller.filterMode == FilterMode.all
                  ? TextStrings.noConversationsYet
                  : TextStrings.noConversationsMatchFilter,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge,
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        if (controller.isSearchMode)
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: controller.searchController,
              decoration: InputDecoration(
                filled: true,
                fillColor: isDarkMode
                    ? ThemeConstants.darkCardColor
                    : ThemeConstants.lightCardColor,
                hintText: TextStrings.searchConversations,
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                contentPadding: EdgeInsets.zero,
              ),
              autofocus: true,
            ),
          ),
        Expanded(
          child: ListView.builder(
            controller: controller.listScrollController,
            itemCount: controller.conversations.length,
            itemBuilder: (context, index) {
              final conversation = controller.conversations[index];
              final isSelected =
                  controller.selectedConversation?.id == conversation.id;

              return _ConversationTile(
                conversation: conversation,
                isSelected: isSelected,
                onTap: () => onConversationSelected(conversation),
                onLongPress: () =>
                    _showConversationActions(context, conversation),
              );
            },
          ),
        ),
      ],
    );
  }

  void _showConversationActions(
      BuildContext context, Conversation conversation) {
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
                leading: Icon(
                  conversation.isArchived ? Icons.unarchive : Icons.archive,
                  color: ThemeConstants.orange,
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
                leading: Icon(
                  Icons.delete_outline,
                  color: ThemeConstants.red,
                ),
                title: Text(TextStrings.delete),
                onTap: () {
                  Navigator.pop(context);
                  _confirmDeleteConversation(context, conversation);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _confirmDeleteConversation(
      BuildContext context, Conversation conversation) {
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

class _ConversationTile extends StatelessWidget {
  final Conversation conversation;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _ConversationTile({
    required this.conversation,
    required this.isSelected,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    final formattedTime =
        _formatMessageTime(conversation.lastMessage.timestamp);

    return Container(
      color: isSelected
          ? ThemeConstants.primaryColor.withOpacity(0.1)
          : Colors.transparent,
      child: ListTile(
        onTap: () {
          // Instead of just calling the passed onTap handler,
          // navigate to the full-screen chat detail page
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ChatDetailPage(
                controller: conversation.controller ??
                    // If conversation somehow doesn't have controller reference
                    // Try to get it through closure
                    MessagesController(),
                conversation: conversation,
              ),
            ),
          );
        },
        onLongPress: onLongPress,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Stack(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundImage: NetworkImage(conversation.avatarUrl),
            ),
            if (conversation.isOnline)
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: ThemeConstants.green,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isDarkMode
                          ? ThemeConstants.darkBackgroundColor
                          : ThemeConstants.lightBackgroundColor,
                      width: 2,
                    ),
                  ),
                ),
              ),
          ],
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                conversation.displayName,
                style: TextStyle(
                  fontWeight: conversation.unreadCount > 0
                      ? FontWeight.bold
                      : FontWeight.normal,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              formattedTime,
              style: TextStyle(
                fontSize: 12,
                color: theme.textTheme.bodySmall?.color,
                fontWeight: conversation.unreadCount > 0
                    ? FontWeight.bold
                    : FontWeight.normal,
              ),
            ),
          ],
        ),
        subtitle: Row(
          children: [
            if (conversation.isMuted)
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Icon(
                  Icons.volume_off,
                  size: 14,
                  color: ThemeConstants.grey,
                ),
              ),
            Expanded(
              child: Text(
                _formatLastMessage(conversation),
                style: TextStyle(
                  color: conversation.unreadCount > 0
                      ? theme.textTheme.bodyLarge?.color
                      : theme.textTheme.bodySmall?.color,
                  fontWeight: conversation.unreadCount > 0
                      ? FontWeight.bold
                      : FontWeight.normal,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (conversation.unreadCount > 0)
              Container(
                margin: const EdgeInsets.only(left: 4),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: ThemeConstants.primaryColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  conversation.unreadCount.toString(),
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _formatMessageTime(DateTime time) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final messageDate = DateTime(time.year, time.month, time.day);

    if (messageDate == today) {
      return DateFormat('HH:mm').format(time);
    } else if (messageDate == yesterday) {
      return TextStrings.yesterday;
    } else if (now.difference(time).inDays < 7) {
      return DateFormat('EEEE').format(time); // Day name
    } else {
      return DateFormat('MM/dd').format(time); // MM/dd format
    }
  }

  String _formatLastMessage(Conversation conversation) {
    final message = conversation.lastMessage;
    final sender = message.senderId == 'current' ? 'You: ' : '';

    if (message.content.isEmpty) {
      return conversation.isGroup
          ? '${message.senderName}: ${TextStrings.noMessage}'
          : TextStrings.noMessage;
    }

    return conversation.isGroup && message.senderId != 'current'
        ? '${message.senderName}: ${message.content}'
        : '$sender${message.content}';
  }
}
