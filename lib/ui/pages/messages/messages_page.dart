import 'package:flutter/material.dart';
import 'package:flutter_application_2/constants/text_strings.dart';
import 'package:flutter_application_2/constants/theme_constants.dart';
import 'package:flutter_application_2/services/user_service.dart';
import 'package:flutter_application_2/ui/pages/messages/messages_controller.dart';
import 'package:flutter_application_2/ui/pages/messages/widgets/conversation_list.dart';
import 'package:flutter_application_2/ui/widgets/responsive_snackbar.dart';
// Add this import for RecommendedRoomsSection
import 'package:flutter_application_2/ui/pages/home/components/sections/recommended_rooms_section.dart';

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

    // Ensure all messages have controller references
    _controller.ensureMessageControllerReferences();
  }

  Future<void> _loadMessages() async {
    try {
      await _controller.loadConversations();

      // Ensure all messages have controller references
      _controller.ensureMessageControllerReferences();

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
            icon: Icon(_controller.isSearchMode ? Icons.close : Icons.search),
            onPressed: () {
              // Toggle search mode and refresh the UI
              setState(() {
                _controller.toggleSearchMode();
              });
            },
            tooltip: _controller.isSearchMode
                ? TextStrings.cancel
                : TextStrings.searchMessages,
          ),
          // Only show filter when not in search mode
          if (!_controller.isSearchMode)
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
          // Replace with a scrollable layout that includes both sections
          return ListView(
            children: [
              // Add RecommendedRoomsSection that will scroll with the list
              const RecommendedRoomsSection(),

              // Add a divider between sections
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.0),
                child: Divider(height: 1),
              ),

              // Wrap ConversationList in a Container with fixed height
              // This allows it to be part of the ListView
              SizedBox(
                // Set a reasonable height or use MediaQuery to calculate it
                // Subtracting space for the RecommendedRoomsSection and padding
                height: MediaQuery.of(context).size.height - 300,
                child: ConversationList(
                  controller: _controller,
                  onConversationSelected: (conversation) {
                    _controller.selectConversation(conversation);
                    setState(() {});
                  },
                ),
              ),
            ],
          );
        },
      ),
      // Only show FAB when not in search mode
      floatingActionButton: _controller.isSearchMode
          ? null
          : FloatingActionButton(
              heroTag: 'messagesPageFAB', // Add this unique hero tag
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
    final TextEditingController searchController = TextEditingController();
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    // Create user dialog with mock data
    showDialog(
      context: context,
      builder: (context) {
        return _SearchableContactsDialog(
          searchController: searchController,
          theme: theme,
          isDarkMode: isDarkMode,
        );
      },
    );
  }
}

class _SearchableContactsDialog extends StatefulWidget {
  final TextEditingController searchController;
  final ThemeData theme;
  final bool isDarkMode;

  const _SearchableContactsDialog({
    required this.searchController,
    required this.theme,
    required this.isDarkMode,
  });

  @override
  State<_SearchableContactsDialog> createState() =>
      _SearchableContactsDialogState();
}

class _SearchableContactsDialogState extends State<_SearchableContactsDialog> {
  List<UserWithEmail> users = [];
  List<UserWithEmail> filteredUsers = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    // Load users from mock data
    _loadUsers();

    // Add listener to the controller for immediate search response
    widget.searchController.addListener(_handleSearchChange);
  }

  Future<void> _loadUsers() async {
    // TODO: Replace with Firebase auth and Firestore in the future

    try {
      final userService = UserService();

      // Load all users as UserWithEmail objects directly
      final loadedUsers = await userService.getUsers();

      if (mounted) {
        setState(() {
          // Make sure we're working with the proper types
          users = loadedUsers.whereType<UserWithEmail>().toList();

          // If there are no users after filtering, try manual casting
          if (users.isEmpty && loadedUsers.isNotEmpty) {
            users = loadedUsers.map((user) {
              // Try to convert regular User to UserWithEmail
              if (user is! UserWithEmail) {
                return UserWithEmail(
                  id: user.id,
                  name: user.name,
                  avatarUrl: user.avatarUrl,
                  email:
                      '${user.name.toLowerCase().replaceAll(' ', '.')}@example.com',
                  isOnline: user.isOnline,
                );
              }
              return user;
            }).toList();
          }

          filteredUsers = List.from(users);
          isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading users: $e');
      // Create some fallback users if loading fails
      if (mounted) {
        setState(() {
          // Create some default users as fallback
          users = [
            UserWithEmail(
              id: 'user1',
              name: 'John Smith',
              email: 'john.smith@example.com',
              avatarUrl: 'https://ui-avatars.com/api/?name=John+Smith',
              isOnline: true,
            ),
            UserWithEmail(
              id: 'user2',
              name: 'Sarah Johnson',
              email: 'sarah.j@example.com',
              avatarUrl: 'https://ui-avatars.com/api/?name=Sarah+Johnson',
              isOnline: false,
            ),
          ];
          filteredUsers = List.from(users);
          isLoading = false;
        });
      }
    }
  }

  // Search handler triggered by controller changes
  void _handleSearchChange() {
    final query = widget.searchController.text;
    _filterUsers(query);
  }

  // Explicit method to filter users
  void _filterUsers(String query) {
    setState(() {
      if (query.isEmpty) {
        filteredUsers = List.from(users);
      } else {
        filteredUsers = users.where((user) {
          final name = user.name.toLowerCase();
          final email = user.email.toLowerCase();
          final searchLower = query.toLowerCase();
          return name.contains(searchLower) || email.contains(searchLower);
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.0),
      ),
      // Apply constraints for better responsive width
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 500, // Maximum width for the dialog
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title with theme-adaptive color
              Text(
                TextStrings.newConversation,
                style: widget.theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: widget.theme.textTheme.titleLarge?.color,
                ),
              ),
              const SizedBox(height: 16),

              // Search field - using both onChanged and controller
              TextField(
                controller: widget.searchController,
                decoration: InputDecoration(
                  hintText: TextStrings.searchUsers,
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: widget.searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            widget.searchController.clear();
                            // This will trigger the listener
                          },
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onChanged:
                    _filterUsers, // Direct connection for web compatibility
                autofocus: true,
              ),

              const SizedBox(height: 20),

              // Header with count
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    filteredUsers.length == users.length
                        ? TextStrings.recentContacts
                        : '${filteredUsers.length} ${TextStrings.recentContacts}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: widget.theme.textTheme.titleMedium?.color,
                    ),
                  ),
                  if (filteredUsers.length != users.length)
                    TextButton(
                      onPressed: () {
                        widget.searchController.clear();
                      },
                      child: const Text('Show All'),
                    ),
                ],
              ),

              const SizedBox(height: 10),

              // Results list with loading state and error handling
              Flexible(
                child: isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : filteredUsers.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.person_off,
                                  size: 48,
                                  color: Colors.grey[400],
                                ),
                                const SizedBox(height: 16),
                                Padding(
                                  padding: const EdgeInsets.all(20.0),
                                  child: Text(
                                    widget.searchController.text.isEmpty
                                        ? 'No contacts found.\nTry adding some contacts first.'
                                        : 'No users found matching "${widget.searchController.text}"',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: Colors.grey[600]),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            shrinkWrap: true,
                            itemCount: filteredUsers.length,
                            itemBuilder: (context, index) {
                              final user = filteredUsers[index];
                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundImage: NetworkImage(user.avatarUrl),
                                  backgroundColor: ThemeConstants.primaryColor,
                                  onBackgroundImageError: (_, __) {
                                    // Handle image loading errors silently
                                  },
                                  child: user.avatarUrl.isEmpty
                                      ? Text(user.name[0])
                                      : null,
                                ),
                                title: Text(user.name),
                                subtitle: Text(user.email),
                                // Online status indicator
                                trailing: user.isOnline
                                    ? Container(
                                        width: 12,
                                        height: 12,
                                        decoration: BoxDecoration(
                                          color: ThemeConstants.green,
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: Colors.white,
                                            width: 2,
                                          ),
                                        ),
                                      )
                                    : null,
                                onTap: () {
                                  // TODO: Create new conversation in Firebase
                                  // - Create or get conversation document in Firestore
                                  // - Use transaction to ensure consistency
                                  // - Add conversation reference to both users
                                  // - Navigate to chat detail page with new conversation

                                  ResponsiveSnackBar.showInfo(
                                    context: context,
                                    message:
                                        "${TextStrings.startingConversationWith} ${user.name}",
                                  );
                                  Navigator.pop(context);
                                },
                              );
                            },
                          ),
              ),

              const SizedBox(height: 10),

              // Cancel button
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    TextStrings.cancel,
                    style: TextStyle(
                      color: widget.isDarkMode
                          ? Colors.white70
                          : ThemeConstants.primaryColor,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
