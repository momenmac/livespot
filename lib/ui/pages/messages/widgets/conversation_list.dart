import 'package:flutter/material.dart';
import 'package:flutter_application_2/constants/text_strings.dart';
import 'package:flutter_application_2/constants/theme_constants.dart';
import 'package:flutter_application_2/ui/pages/messages/chat_detail_page.dart';
import 'package:flutter_application_2/ui/pages/messages/messages_controller.dart';
import 'package:flutter_application_2/ui/pages/messages/models/conversation.dart';
import 'package:flutter_application_2/ui/pages/messages/models/message.dart';
import 'package:intl/intl.dart';
import 'package:flutter_application_2/ui/widgets/responsive_snackbar.dart';
import 'package:flutter_application_2/ui/widgets/safe_network_image.dart'; // Add this import
import 'package:flutter_application_2/services/api/account/api_urls.dart'; // Add this import

// Simple class to hold action button data
class ActionItem {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  ActionItem({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });
}

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

    return Column(
      children: [
        // Always show search bar when search mode is active
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
                // Add a clear button for easier search resetting
                suffixIcon: controller.searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          controller.searchController.clear();
                          // This will trigger the listener and refresh results
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                contentPadding: EdgeInsets.zero,
              ),
              autofocus: true,
            ),
          ),

        // Expanded widget for the list (or empty state)
        Expanded(
          child: _buildConversationListContent(context, theme, isDarkMode),
        ),
      ],
    );
  }

  // Helper method to build the appropriate content based on state
  Widget _buildConversationListContent(
      BuildContext context, ThemeData theme, bool isDarkMode) {
    // If there are no conversations (either in general or after filtering)
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
              // Show different messages based on whether we're searching or not
              controller.isSearchMode
                  ? "No conversations match your search"
                  : controller.filterMode == FilterMode.all
                      ? TextStrings.noConversationsYet
                      : TextStrings.noConversationsMatchFilter,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge,
            ),
            // Add a button to clear search if we're in search mode with no results
            if (controller.isSearchMode &&
                controller.searchController.text.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: TextButton.icon(
                  icon: const Icon(Icons.clear),
                  label: const Text("Clear search"),
                  onPressed: () {
                    controller.searchController.clear();
                    // This will trigger the listener and refresh results
                  },
                ),
              ),
          ],
        ),
      );
    }

    // Otherwise, show the conversation list
    return ListView.builder(
      controller: controller.listScrollController,
      itemCount: controller.conversations.length + 1, // +1 for bottom spacing
      itemBuilder: (context, index) {
        if (index == controller.conversations.length) {
          // Add extra spacing at the bottom
          return const SizedBox(height: 32);
        }
        final conversation = controller.conversations[index];

        // Make sure conversation has a reference to controller
        conversation.controller = controller;

        // You can fetch messages for this conversation here if needed
        // For example, if you want to show the latest message from Firestore:
        // (Assuming you have a method to fetch messages for a conversation)
        // await controller.fetchMessagesForConversation(conversation);

        return Dismissible(
          key: Key(conversation.id),
          // Allow swipes in both directions
          direction: DismissDirection.horizontal,

          // Background for left-to-right swipe (mark read/unread)
          background: Container(
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.only(left: 20.0),
            color: ThemeConstants.green,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  conversation.unreadCount > 0
                      ? Icons.done_all
                      : Icons.mark_email_unread,
                  color: Colors.white,
                ),
                const SizedBox(height: 4),
                Text(
                  conversation.unreadCount > 0
                      ? TextStrings.markAsRead
                      : TextStrings.markAsUnread,
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),

          // Background for right-to-left swipe (archive)
          secondaryBackground: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20.0),
            color: ThemeConstants.orange,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  conversation.isArchived ? Icons.unarchive : Icons.archive,
                  color: Colors.white,
                ),
                const SizedBox(height: 4),
                Text(
                  conversation.isArchived
                      ? TextStrings.unarchive
                      : TextStrings.archive,
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),

          // Confirmation thresholds
          confirmDismiss: (direction) async {
            if (direction == DismissDirection.endToStart) {
              // Archive/unarchive (right to left swipe)
              controller.toggleArchive(conversation);

              // Show a snackbar confirmation
              ResponsiveSnackBar.showInfo(
                context: context,
                message: conversation.isArchived
                    ? TextStrings.conversationArchived
                    : TextStrings.conversationUnarchived,
              );

              // Return false to keep the item in the list
              return false;
            } else if (direction == DismissDirection.startToEnd) {
              // Mark as read/unread (left to right swipe)
              if (conversation.unreadCount > 0) {
                // Mark as read
                controller.markConversationAsRead(conversation);
              } else {
                // Mark as unread
                controller.markConversationAsUnread(conversation);
              }

              // Show a snackbar confirmation
              ResponsiveSnackBar.showInfo(
                context: context,
                message: conversation.unreadCount > 0
                    ? TextStrings.markedAsUnread
                    : TextStrings.markedAsRead,
              );

              // Return false to keep the item in the list
              return false;
            }
            return false;
          },

          child: _ConversationTile(
            conversation: conversation,
            isSelected: false,
            controller: controller,
            onTap: () => onConversationSelected(conversation),
            onLongPress: () => _showConversationActions(context, conversation),
          ),
        );
      },
    );
  }

  void _showConversationActions(
      BuildContext context, Conversation conversation) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        final isDarkMode = Theme.of(context).brightness == Brightness.dark;

        // Create list of actions
        final List<ActionItem> actions = [
          // Mute/Unmute action
          ActionItem(
            icon: conversation.isMuted ? Icons.volume_up : Icons.volume_off,
            label: conversation.isMuted ? TextStrings.unmute : TextStrings.mute,
            color: ThemeConstants.primaryColor,
            onTap: () {
              controller.toggleMute(conversation);
              Navigator.pop(context);
            },
          ),

          // Mark as read/unread
          ActionItem(
            icon: conversation.unreadCount > 0
                ? Icons.done_all
                : Icons.mark_email_unread,
            label: conversation.unreadCount > 0
                ? TextStrings.markAsRead
                : TextStrings.markAsUnread,
            color: ThemeConstants.green,
            onTap: () {
              if (conversation.unreadCount > 0) {
                controller.markConversationAsRead(conversation);
              } else {
                controller.markConversationAsUnread(conversation);
              }
              Navigator.pop(context);

              ResponsiveSnackBar.showInfo(
                context: context,
                message: conversation.unreadCount > 0
                    ? TextStrings.markedAsRead
                    : TextStrings.markedAsUnread,
              );
            },
          ),

          // Archive/Unarchive action
          ActionItem(
            icon: conversation.isArchived ? Icons.unarchive : Icons.archive,
            label: conversation.isArchived
                ? TextStrings.unarchive
                : TextStrings.archive,
            color: ThemeConstants.orange,
            onTap: () {
              controller.toggleArchive(conversation);
              Navigator.pop(context);

              // Show a snackbar confirmation
              ResponsiveSnackBar.showInfo(
                context: context,
                message: conversation.isArchived
                    ? TextStrings.conversationUnarchived
                    : TextStrings.conversationArchived,
              );
            },
          ),

          // Delete action
          ActionItem(
            icon: Icons.delete_outline,
            label: TextStrings.delete,
            color: ThemeConstants.red,
            onTap: () {
              Navigator.pop(context);
              _confirmDeleteConversation(context, conversation);
            },
          ),
        ];

        return Container(
          decoration: BoxDecoration(
            color: isDarkMode ? Color(0xFF2D2D2D) : Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          margin: EdgeInsets.only(left: 10, right: 10, top: 10),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle bar at top
                Container(
                  margin: EdgeInsets.symmetric(vertical: 10),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[400],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                // Conversation preview
                Container(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundImage: NetworkImage(conversation.avatarUrl),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              conversation.displayName,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (!conversation.isGroup && conversation.isOnline)
                              Text(
                                TextStrings.online,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: ThemeConstants.green,
                                ),
                              )
                            else if (conversation.isGroup)
                              Text(
                                '${conversation.participants.length} participants',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: isDarkMode
                                      ? Colors.grey[300]
                                      : Colors.grey[600],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Action buttons grid
                Padding(
                  padding:
                      const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      // Calculate how many actions to show per row
                      final double screenWidth = constraints.maxWidth;
                      final int itemsPerRow = screenWidth > 300 ? 3 : 2;

                      // Create rows of actions
                      final List<Widget> actionRows = [];
                      for (int i = 0; i < actions.length; i += itemsPerRow) {
                        final rowItems = actions.sublist(
                            i,
                            i + itemsPerRow > actions.length
                                ? actions.length
                                : i + itemsPerRow);

                        actionRows.add(
                          Padding(
                            padding: const EdgeInsets.only(bottom: 24),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: rowItems
                                  .map((action) => _buildCircularAction(
                                        icon: action.icon,
                                        label: action.label,
                                        color: action.color,
                                        onTap: action.onTap,
                                      ))
                                  .toList(),
                            ),
                          ),
                        );
                      }

                      return Column(children: actionRows);
                    },
                  ),
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        );
      },
    );
  }

  // Helper method to build circular action buttons
  Widget _buildCircularAction({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(35),
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Icon(icon, color: color, size: 28),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteConversation(
      BuildContext context, Conversation conversation) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          TextStrings.deleteConversation,
          style: Theme.of(context).textTheme.headlineMedium,
        ),
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

// Convert _ConversationTile from StatelessWidget to StatefulWidget to track hover state
class _ConversationTile extends StatefulWidget {
  final Conversation conversation;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final MessagesController controller;

  const _ConversationTile({
    required this.conversation,
    required this.isSelected,
    required this.onTap,
    required this.onLongPress,
    required this.controller,
  });

  @override
  State<_ConversationTile> createState() => _ConversationTileState();
}

class _ConversationTileState extends State<_ConversationTile> {
  bool _isHovering = false;

  String _absoluteAvatarUrl(String url) {
    if (url.isEmpty) return url;
    if (url.startsWith('http')) return url;
    // Always prepend base URL for non-absolute URLs
    final fixedUrl = url.startsWith('/') ? url : '/$url';
    return '${ApiUrls.baseUrl}$fixedUrl';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    final formattedTime =
        _formatMessageTime(widget.conversation.lastMessage.timestamp);

    // --- FIX: Show last message content even if messages list is empty ---
    final lastMessage = widget.conversation.lastMessage;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: Container(
        color: Colors.transparent,
        child: Stack(
          children: [
            ListTile(
              onTap: () {
                // Set controller on conversation and all its messages before navigating
                widget.conversation.controller = widget.controller;

                // Set controller on ALL messages in the conversation
                for (final message in widget.conversation.messages) {
                  message.controller = widget.controller;
                }

                // --- FIX: Select the conversation in the controller before navigating ---
                widget.controller.selectConversation(widget.conversation);

                // Now navigate to the chat detail page
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ChatDetailPage(
                      controller: widget.controller,
                      conversation: widget.conversation,
                    ),
                  ),
                ).then((_) {
                  // Force refresh when returning
                  if (widget.controller.selectedConversation?.id ==
                      widget.conversation.id) {
                    widget.controller.selectConversation(widget.conversation);
                  }
                  widget.controller.notifyListeners();
                });
              },
              onLongPress: widget.onLongPress,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              leading: Stack(
                children: [
                  SafeNetworkImage(
                    imageUrl: _absoluteAvatarUrl(widget.conversation.avatarUrl),
                    size: 48,
                    fallbackText: widget.conversation.displayName,
                  ),
                  if (widget.conversation.isOnline)
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
                      widget.conversation.displayName,
                      style: TextStyle(
                        fontWeight: widget.conversation.unreadCount > 0
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
                      fontWeight: widget.conversation.unreadCount > 0
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                ],
              ),
              subtitle: Row(
                children: [
                  if (widget.conversation.isMuted)
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
                      _formatLastMessageFromLastMessage(
                          lastMessage, widget.conversation),
                      style: TextStyle(
                        fontWeight: widget.conversation.unreadCount > 0
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: widget.conversation.unreadCount > 0
                            ? theme.textTheme.bodyLarge?.color
                            : theme.textTheme.bodySmall?.color,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),

            // Fix the hover menu with unread badge
            if (_isHovering)
              Positioned(
                top: 28, // More visually centered position
                right: 8, // Consistent padding
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Always show the unread badge here if it exists
                    if (widget.conversation.unreadCount > 0)
                      Container(
                        margin: const EdgeInsets.only(right: 8), // More spacing
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: ThemeConstants.primaryColor,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          widget.conversation.unreadCount.toString(),
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    _buildOptionsButton(context),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionsButton(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => _showOptionsPopup(context),
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.grey[800]
                : Colors.grey[200],
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.more_vert,
            size: 18,
          ),
        ),
      ),
    );
  }

  void _showOptionsPopup(BuildContext context) {
    final conversation = widget.conversation;
    final controller = widget.controller;
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    final RenderBox button = context.findRenderObject() as RenderBox;
    final RenderBox overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;
    final RelativeRect position = RelativeRect.fromRect(
      Rect.fromPoints(
        button.localToGlobal(Offset.zero, ancestor: overlay),
        button.localToGlobal(button.size.bottomRight(Offset.zero),
            ancestor: overlay),
      ),
      Offset.zero & overlay.size,
    );

    showMenu<String>(
      context: context,
      position: position,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 8,
      items: [
        // Mute/Unmute action
        PopupMenuItem<String>(
          value: 'mute',
          child: Row(
            children: [
              Icon(
                conversation.isMuted ? Icons.volume_up : Icons.volume_off,
                color: ThemeConstants.primaryColor,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                  conversation.isMuted ? TextStrings.unmute : TextStrings.mute),
            ],
          ),
        ),

        // Mark as read/unread
        PopupMenuItem<String>(
          value: 'read',
          child: Row(
            children: [
              Icon(
                conversation.unreadCount > 0
                    ? Icons.done_all
                    : Icons.mark_email_unread,
                color: ThemeConstants.green,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(conversation.unreadCount > 0
                  ? TextStrings.markAsRead
                  : TextStrings.markAsUnread),
            ],
          ),
        ),

        // Archive/Unarchive action
        PopupMenuItem<String>(
          value: 'archive',
          child: Row(
            children: [
              Icon(
                conversation.isArchived ? Icons.unarchive : Icons.archive,
                color: ThemeConstants.orange,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(conversation.isArchived
                  ? TextStrings.unarchive
                  : TextStrings.archive),
            ],
          ),
        ),

        // Delete action
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
      ],
    ).then((value) {
      if (value == null) return;

      switch (value) {
        case 'mute':
          // Store the state BEFORE toggling so we know what message to show
          final willBeMuted = !conversation.isMuted;

          // TODO: When implementing Firebase, add async handling here
          controller.toggleMute(conversation);

          ResponsiveSnackBar.showInfo(
            context: context,
            message: willBeMuted
                ? TextStrings.conversationMuted
                : TextStrings.conversationUnmuted,
          );
          break;

        case 'read':
          // TODO: When implementing Firebase, add async handling for marking read/unread
          if (conversation.unreadCount > 0) {
            controller.markConversationAsRead(conversation);
            ResponsiveSnackBar.showInfo(
              context: context,
              message: TextStrings.markedAsRead,
            );
          } else {
            controller.markConversationAsUnread(conversation);
            ResponsiveSnackBar.showInfo(
              context: context,
              message: TextStrings.markedAsUnread,
            );
          }
          break;

        case 'archive':
          // Store the state BEFORE toggling so we know what message to show
          final willBeArchived = !conversation.isArchived;

          // TODO: When implementing Firebase, add async handling here
          controller.toggleArchive(conversation);

          ResponsiveSnackBar.showInfo(
            context: context,
            message: willBeArchived
                ? TextStrings.conversationArchived
                : TextStrings.conversationUnarchived,
          );
          break;

        case 'delete':
          _confirmDeleteConversation(context, conversation);
          break;
      }
    });
  }

  void _confirmDeleteConversation(
      BuildContext context, Conversation conversation) {
    // TODO: When implementing Firebase, add confirmation that deletion was successful
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          TextStrings.deleteConversation,
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        content: Text(TextStrings.deleteConversationConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(TextStrings.cancel),
          ),
          TextButton(
            onPressed: () {
              widget.controller.deleteConversation(conversation);
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
    final sender = message.senderId == 'current' ? TextStrings.sentByYou : '';

    if (message.content.isEmpty) {
      return conversation.isGroup && message.senderId != 'current'
          ? '${message.senderName}: ${TextStrings.noMessage}'
          : TextStrings.noMessage;
    }

    // Handle voice messages
    if (message.messageType == MessageType.voice) {
      return conversation.isGroup && message.senderId != 'current'
          ? '${message.senderName}: ${TextStrings.voiceMessage}'
          : '$sender${TextStrings.voiceMessage}';
    }

    return conversation.isGroup && message.senderId != 'current'
        ? '${message.senderName}: ${message.content}'
        : '$sender${message.content}';
  }

  // Show last message content from the lastMessage field (not from messages list)
  String _formatLastMessageFromLastMessage(
      Message message, Conversation conversation) {
    final sender = message.senderId == 'current' ? TextStrings.sentByYou : '';
    if (message.content.isEmpty) {
      return conversation.isGroup && message.senderId != 'current'
          ? '${message.senderName}: ${TextStrings.noMessage}'
          : TextStrings.noMessage;
    }
    if (message.messageType == MessageType.voice) {
      return conversation.isGroup && message.senderId != 'current'
          ? '${message.senderName}: ${TextStrings.voiceMessage}'
          : '$sender${TextStrings.voiceMessage}';
    }
    return conversation.isGroup && message.senderId != 'current'
        ? '${message.senderName}: ${message.content}'
        : '$sender${message.content}';
  }
}
