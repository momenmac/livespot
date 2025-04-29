import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application_2/constants/text_strings.dart';
import 'package:flutter_application_2/constants/theme_constants.dart';
import 'package:flutter_application_2/services/user_service.dart';
import 'package:flutter_application_2/ui/pages/messages/messages_controller.dart';
import 'package:flutter_application_2/ui/pages/messages/models/conversation.dart';
import 'package:flutter_application_2/ui/pages/messages/widgets/conversation_list.dart';
import 'package:flutter_application_2/ui/widgets/responsive_snackbar.dart';
// Add this import for RecommendedRoomsSection
import 'package:flutter_application_2/ui/pages/messages/recommended_rooms_section.dart';
// Add this import for ApiUrls
import 'package:flutter_application_2/services/api/account/api_urls.dart';
// Add this import for CachedNetworkImage
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
// Add this import for ChatDetailPage
import 'package:flutter_application_2/ui/pages/messages/chat_detail_page.dart';
import 'package:flutter_application_2/ui/pages/messages/models/user.dart'; // <-- Add this import
import 'package:flutter_application_2/ui/pages/messages/models/message.dart'; // <-- Add this import

class MessagesPage extends StatefulWidget {
  const MessagesPage({super.key});

  @override
  State<MessagesPage> createState() => _MessagesPageState();
}

class _MessagesPageState extends State<MessagesPage>
    with WidgetsBindingObserver {
  late MessagesController _controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = MessagesController();
    _loadMessages();

    // Ensure all messages have controller references
    _controller.ensureMessageControllerReferences();

    // Set user online status to true
    _setUserOnlineStatus(true);
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

  Future<void> _setUserOnlineStatus(bool isOnline) async {
    final currentUserId = _controller.currentUserId;
    await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUserId)
        .update({'isOnline': isOnline});
    }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _setUserOnlineStatus(false); // Set user offline status
    _controller.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _setUserOnlineStatus(true); // Set user online status
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _setUserOnlineStatus(false); // Set user offline status
    }
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
          // Add AI Assistant chat button
          IconButton(
            icon: const Icon(Icons.smart_toy_outlined),
            onPressed: () {
              _startAIConversation(context);
            },
            tooltip: 'Chat with AI',
          ),
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

  // Method to start a conversation with AI assistant
  void _startAIConversation(BuildContext context) {
    ResponsiveSnackBar.showInfo(
      context: context,
      message: "Starting conversation with AI Assistant...",
    );

    // TODO: Navigate to AI chat interface
    // For example:
    // Navigator.push(
    //   context,
    //   MaterialPageRoute(
    //     builder: (context) => AIChatPage(),
    //   ),
    // );
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

    showDialog(
      context: context,
      builder: (context) {
        return _SearchableContactsDialog(
          searchController: searchController,
          theme: theme,
          isDarkMode: isDarkMode,
          controller: _controller,
          onConversationCreated: (conversation) async {
            _controller.selectConversation(conversation);
            setState(() {});
            Navigator.of(context).pop(); // Close the dialog first
            await Future.delayed(const Duration(milliseconds: 100));
            if (mounted) {
              // Navigate to chat detail page
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ChatDetailPage(
                    controller: _controller,
                    conversation: conversation,
                  ),
                ),
              );
            }
          },
        );
      },
    );
  }
}

class _SearchableContactsDialog extends StatefulWidget {
  final TextEditingController searchController;
  final ThemeData theme;
  final bool isDarkMode;
  final MessagesController controller;
  final void Function(Conversation conversation)? onConversationCreated;

  const _SearchableContactsDialog({
    required this.searchController,
    required this.theme,
    required this.isDarkMode,
    required this.controller,
    this.onConversationCreated,
  });

  @override
  State<_SearchableContactsDialog> createState() =>
      _SearchableContactsDialogState();
}

class _SearchableContactsDialogState extends State<_SearchableContactsDialog> {
  static List<UserWithEmail>? _cachedUsers; // Static cache for dialog session
  List<UserWithEmail> users = [];
  List<UserWithEmail> filteredUsers = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    if (_cachedUsers != null) {
      users = List.from(_cachedUsers!);
      filteredUsers = List.from(_cachedUsers!);
      isLoading = false;
    } else {
      _loadUsersFromDjango();
    }
    widget.searchController.addListener(_handleSearchChange);
  }

  // Fetch all users from Django backend and merge with online status from Firestore
  Future<void> _loadUsersFromDjango() async {
    setState(() {
      isLoading = true;
    });

    try {
      final baseUrl = ApiUrls.baseUrl;
      final url = Uri.parse('$baseUrl/accounts/all-users/');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final List<dynamic> userList = jsonDecode(response.body);

        // Fetch online status for all users from Firestore
        final firestore = FirebaseFirestore.instance;
        final statusSnapshot = await firestore.collection('users').get();
        final statusMap = <String, bool>{};
        for (final doc in statusSnapshot.docs) {
          final data = doc.data();
          final id = (data['id'] ?? doc.id).toString();
          statusMap[id] = data['isOnline'] ?? false;
        }

        final currentUserId = widget.controller.currentUserId.toString();
        final loadedUsers = userList
            .map((user) {
              final id = user['id'].toString();
              if (id == currentUserId) return null;
              final name = user['name'] ?? '';
              String avatarUrl = user['avatarUrl'] ?? '';
              if (avatarUrl.isNotEmpty && !avatarUrl.startsWith('http')) {
                avatarUrl = '$baseUrl$avatarUrl';
              }
              final email = user['email'] ?? '';
              return UserWithEmail(
                id: id,
                name: name,
                avatarUrl: avatarUrl,
                email: email,
                isOnline: statusMap[id] ?? false,
              );
            })
            .whereType<UserWithEmail>()
            .toList();

        // Cache the loaded users for this session
        _cachedUsers = List.from(loadedUsers);

        setState(() {
          users = loadedUsers;
          filteredUsers = List.from(users);
          isLoading = false;
        });
      } else {
        print('Failed to fetch users from Django: ${response.statusCode}');
        setState(() {
          users = [];
          filteredUsers = [];
          isLoading = false;
        });
      }
    } catch (e, stack) {
      print('Error loading users from Django: $e');
      print(stack);
      setState(() {
        users = [];
        filteredUsers = [];
        isLoading = false;
      });
    }
  }

  // Optionally, add a method to clear cache if needed
  static void clearUserCache() {
    _cachedUsers = null;
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

  // Helper to create or get a conversation with a user
  Future<Conversation> _createOrGetConversation(UserWithEmail user) async {
    final firestore = FirebaseFirestore.instance;
    final currentUserId = widget.controller.currentUserId;

    // Query for existing conversation between current user and selected user
    final query = await firestore
        .collection('conversations')
        .where('isGroup', isEqualTo: false)
        .where('participants', arrayContains: currentUserId)
        .get();

    for (final doc in query.docs) {
      final data = doc.data();
      final participants = List<String>.from(data['participants'] ?? []);
      if (participants.contains(user.id) && participants.length == 2) {
        // Conversation exists, return from Firestore doc (not mock)
        // Build a Conversation object with minimal info for navigation
        return Conversation(
          id: doc.id,
          participants: [
            User(
              id: currentUserId.toString(),
              name: "Me",
              avatarUrl: "",
              isOnline: true,
            ),
            User(
              id: user.id,
              name: user.name,
              avatarUrl: user.avatarUrl,
              isOnline: user.isOnline,
            ),
          ],
          messages: [],
          lastMessage: Message(
            id: data['lastMessage']?['id'] ?? '',
            senderId: data['lastMessage']?['senderId'] ?? '',
            senderName: data['lastMessage']?['senderName'] ?? '',
            content: data['lastMessage']?['content'] ?? '',
            timestamp:
                DateTime.tryParse(data['lastMessage']?['timestamp'] ?? '') ??
                    DateTime.now(),
            conversationId: doc.id, // Add the conversation ID
          ),
          unreadCount: data['unreadCount'] ?? 0,
          isGroup: false,
          groupName: null,
          isMuted: data['isMuted'] ?? false,
          isArchived: data['isArchived'] ?? false,
        );
      }
    }

    // Create new conversation in Firestore
    final newDoc = firestore.collection('conversations').doc();
    final now = DateTime.now();
    final conversationData = {
      'id': newDoc.id,
      'participants': [currentUserId, user.id],
      'isGroup': false,
      'groupName': null,
      'unreadCount': 0,
      'isMuted': false,
      'isArchived': false,
      'lastMessage': {
        'id': 'empty',
        'senderId': '',
        'senderName': '',
        'content': 'No messages',
        'timestamp': now.toIso8601String(),
      },
      'lastMessageTimestamp': now,
    };
    await newDoc.set(conversationData);

    // Build a Conversation object for navigation
    return Conversation(
      id: newDoc.id,
      participants: [
        User(
          id: currentUserId.toString(),
          name: "Me",
          avatarUrl: "",
          isOnline: true,
        ),
        User(
          id: user.id,
          name: user.name,
          avatarUrl: user.avatarUrl,
          isOnline: user.isOnline,
        ),
      ],
      messages: [],
      lastMessage: Message(
        id: 'empty',
        senderId: '',
        senderName: '',
        content: 'No messages',
        timestamp: now,
        conversationId: newDoc.id, // Add the conversation ID
      ),
      unreadCount: 0,
      isGroup: false,
      groupName: null,
      isMuted: false,
      isArchived: false,
    );
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
                                  backgroundColor: ThemeConstants.primaryColor,
                                  foregroundImage: user.avatarUrl.isNotEmpty
                                      ? CachedNetworkImageProvider(
                                          user.avatarUrl)
                                      : null,
                                  child: user.avatarUrl.isEmpty
                                      ? Text(user.name[0])
                                      : null,
                                ),
                                title: Text(user.name),
                                subtitle: Text(user.email),
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
                                onTap: () async {
                                  ResponsiveSnackBar.showInfo(
                                    context: context,
                                    message:
                                        "${TextStrings.startingConversationWith} ${user.name}",
                                  );
                                  // Create or get conversation, then notify parent and close dialog
                                  final conversation =
                                      await _createOrGetConversation(user);
                                  if (widget.onConversationCreated != null) {
                                    widget.onConversationCreated!(conversation);
                                  }
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
