import 'package:flutter/material.dart';
import 'package:flutter_application_2/core/constants/text_strings.dart';
import 'package:flutter_application_2/core/constants/theme_constants.dart';
import 'package:flutter_application_2/ui/pages/messages/messages_controller.dart';
import 'package:flutter_application_2/ui/pages/messages/models/conversation.dart';
import 'package:flutter_application_2/ui/pages/messages/widgets/message_detail.dart';

class ChatDetailPage extends StatefulWidget {
  final MessagesController controller;
  final Conversation conversation;

  const ChatDetailPage({
    Key? key,
    required this.controller,
    required this.conversation,
  }) : super(key: key);

  @override
  State<ChatDetailPage> createState() => _ChatDetailPageState();
}

class _ChatDetailPageState extends State<ChatDetailPage> {
  @override
  void initState() {
    super.initState();
    // Pass controller reference to conversation object
    widget.conversation.controller = widget.controller;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        // Always reselect conversation when page opens
        widget.controller.selectConversation(widget.conversation);
      }
    });
  }

  @override
  void dispose() {
    // Don't clear the selected conversation when leaving the page
    // This allows the conversation to remain selected for seamless return
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: isDarkMode
            ? ThemeConstants.darkCardColor
            : ThemeConstants.lightCardColor,
        elevation: 2,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            widget.controller.clearSelectedConversationUI();
            Navigator.pop(context);
          },
        ),
        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(
              backgroundImage: NetworkImage(widget.conversation.avatarUrl),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.conversation.displayName,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (widget.conversation.isOnline &&
                      !widget.conversation.isGroup)
                    Text(
                      TextStrings.online,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: ThemeConstants.green,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.call),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.videocam),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () => _showConversationActions(context),
          ),
        ],
      ),
      body: MessageDetail(
        controller: widget.controller,
        conversation: widget.conversation,
        onBackPressed: () {
          widget.controller.clearSelectedConversationUI();
          Navigator.pop(context);
        },
        showHeader: false, // Don't show the custom header
      ),
      backgroundColor: isDarkMode
          ? ThemeConstants.darkBackgroundColor
          : ThemeConstants.lightBackgroundColor,
      bottomNavigationBar: null,
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
              Navigator.pop(context); // close dialog
              Navigator.pop(context); // back to conversation list
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
