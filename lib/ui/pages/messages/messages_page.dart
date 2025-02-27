import 'package:flutter/material.dart';
import 'package:flutter_application_2/core/constants/text_strings.dart';
import 'package:flutter_application_2/core/constants/theme_constants.dart';
import 'package:flutter_application_2/ui/pages/messages/messages_controller.dart';
import 'package:flutter_application_2/ui/pages/messages/widgets/conversation_list.dart';
import 'package:flutter_application_2/ui/widgets/responsive_snackbar.dart';

class MessagesPage extends StatefulWidget {
  const MessagesPage({super.key});

  @override
  State<MessagesPage> createState() => _MessagesPageState();
}

class _MessagesPageState extends State<MessagesPage> {
  late MessagesController _controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _controller = MessagesController();
    _loadMessages();
  }

  Future<void> _loadMessages() async {
    try {
      await _controller.loadConversations();

      // Add the controller reference to each conversation
      for (final conversation in _controller.conversations) {
        conversation.controller = _controller;
      }

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ResponsiveSnackBar.showError(
          context: context,
          message: TextStrings.errorLoadingConversations,
        );
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final backgroundColor = isDarkMode
        ? ThemeConstants.darkBackgroundColor
        : ThemeConstants.lightBackgroundColor;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: backgroundColor,
        body: Center(
          child: CircularProgressIndicator(
            color: ThemeConstants.primaryColor,
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text(
          TextStrings.messages,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              _controller.toggleSearchMode();
              setState(() {});
            },
            tooltip: TextStrings.searchMessages,
          ),
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () {
              _showFilterOptions(context);
            },
            tooltip: TextStrings.filterMessages,
          ),
        ],
      ),
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          // Display just the conversation list
          return ConversationList(
            controller: _controller,
            onConversationSelected: (conversation) {
              _controller.selectConversation(conversation);
              setState(() {});
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: ThemeConstants.primaryColor,
        child: const Icon(Icons.add_comment, color: Colors.white),
        onPressed: () {
          _showNewConversationDialog(context);
        },
      ),
    );
  }

  void _showFilterOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading:
                    Icon(Icons.all_inbox, color: ThemeConstants.primaryColor),
                title: Text(TextStrings.allMessages),
                onTap: () {
                  _controller.setFilterMode(FilterMode.all);
                  Navigator.pop(context);
                  setState(() {});
                },
              ),
              ListTile(
                leading: Icon(Icons.mark_unread_chat_alt,
                    color: ThemeConstants.orange),
                title: Text(TextStrings.unreadOnly),
                onTap: () {
                  _controller.setFilterMode(FilterMode.unread);
                  Navigator.pop(context);
                  setState(() {});
                },
              ),
              ListTile(
                leading: Icon(Icons.archive, color: ThemeConstants.grey),
                title: Text(TextStrings.archived),
                onTap: () {
                  _controller.setFilterMode(FilterMode.archived);
                  Navigator.pop(context);
                  setState(() {});
                },
              ),
              ListTile(
                leading: Icon(Icons.group, color: ThemeConstants.green),
                title: Text(TextStrings.groups),
                onTap: () {
                  _controller.setFilterMode(FilterMode.groups);
                  Navigator.pop(context);
                  setState(() {});
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showNewConversationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        final TextEditingController _searchController = TextEditingController();
        return AlertDialog(
          title: Text(TextStrings.newConversation),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: TextStrings.searchUsers,
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  TextStrings.recentContacts,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                // Mock recent contacts list
                SizedBox(
                  height: 200,
                  child: ListView.builder(
                    itemCount: 5,
                    itemBuilder: (context, index) {
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: ThemeConstants.primaryColor,
                          child: Text("U${index + 1}"),
                        ),
                        title: Text("User ${index + 1}"),
                        subtitle: Text("user${index + 1}@example.com"),
                        onTap: () {
                          // TODO: Create new conversation with this user
                          ResponsiveSnackBar.showInfo(
                            context: context,
                            message:
                                "${TextStrings.startingConversationWith} User ${index + 1}",
                          );
                          Navigator.pop(context);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(TextStrings.cancel),
            ),
          ],
        );
      },
    );
  }
}
