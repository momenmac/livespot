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
import 'dart:developer' as developer;

class MessagesPage extends StatefulWidget {
  final MessagesController? controller;

  const MessagesPage({super.key, this.controller});

  @override
  State<MessagesPage> createState() => _MessagesPageState();
}

class _MessagesPageState extends State<MessagesPage>
    with WidgetsBindingObserver {
  late MessagesController _controller;
  late final bool _ownsController;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Use the controller provided via props or create a new one if not provided
    if (widget.controller != null) {
      _controller = widget.controller!;
      _ownsController = false;
    } else {
      _controller = MessagesController();
      _ownsController = true;
    }
    _loadMessages();
    _controller.ensureMessageControllerReferences();
    _safeSetUserOnlineStatus(true);
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

  // Safe method to update online status that checks for empty user ID
  Future<void> _safeSetUserOnlineStatus(bool isOnline) async {
    final String currentUserId = _controller.currentUserId;
    developer.log(
        'Setting user online status: $isOnline for ID: "$currentUserId"',
        name: 'MessagesPage');

    // Only update if we have a valid user ID
    if (currentUserId.isEmpty) {
      developer.log('Skipping online status update: empty user ID',
          name: 'MessagesPage');
      return;
    }

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId)
          .update({'isOnline': isOnline});
      developer.log('Online status updated successfully to $isOnline',
          name: 'MessagesPage');
    } catch (e) {
      developer.log('Error updating online status: $e', name: 'MessagesPage');
      // Silently fail - this is a non-critical operation
    }
  }

  @override
  void dispose() {
    developer.log('MessagesPage disposing', name: 'MessagesPage');
    WidgetsBinding.instance.removeObserver(this);

    // Set user offline status (with safety check)
    _safeSetUserOnlineStatus(false);

    if (_ownsController) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _safeSetUserOnlineStatus(true); // Set user online status
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _safeSetUserOnlineStatus(false); // Set user offline status
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
          // Show recommended rooms section at the top with conversation list below
          return Column(
            children: [
              // Recommended rooms section (taking up just the space it needs)
              const RecommendedRoomsSection(),

              // Conversation list (expanding to fill remaining space)
              Expanded(
                child: ConversationList(
                  controller: _controller,
                  onConversationSelected: (conversation) {
                    // Create a new controller instance for ChatDetailPage
                    // This prevents using a potentially disposed controller
                    final detailController = MessagesController();

                    // Copy the selected conversation to the new controller
                    detailController.selectConversation(conversation);

                    // Navigate to chat detail page when a conversation is selected
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ChatDetailPage(
                          controller: detailController,
                          conversation: conversation,
                        ),
                      ),
                    ).then((_) {
                      // Refresh conversations when returning from chat detail
                      if (mounted) {
                        developer.log(
                            'Returned from chat detail - refreshing conversations',
                            name: 'MessagesPage');
                        _loadMessages(); // Reload conversations to update unread status
                      }
                    });
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
              heroTag: 'messagesPageFAB',
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

    // Keep track of whether we're currently navigating
    bool isNavigating = false;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return _SearchableContactsDialog(
          searchController: searchController,
          theme: theme,
          isDarkMode: isDarkMode,
          controller: _controller,
          onConversationCreated: (conversation) {
            // Prevent multiple navigation attempts
            if (isNavigating) return;
            isNavigating = true;

            // First close the dialog safely
            if (Navigator.of(dialogContext).canPop()) {
              Navigator.of(dialogContext).pop();
            }

            // Use a delay to ensure dialog is dismissed before navigating
            Future.delayed(const Duration(milliseconds: 350), () {
              // Only navigate if parent context is still valid
              if (mounted) {
                try {
                  // Create a new controller for the chat detail page
                  final detailController = MessagesController();
                  detailController.selectConversation(conversation);

                  // Navigate to the chat detail page
                  Navigator.push(
                    context, // Use parent stable context
                    PageRouteBuilder(
                      pageBuilder: (context, animation1, animation2) =>
                          ChatDetailPage(
                        controller: detailController,
                        conversation: conversation,
                      ),
                      transitionDuration: const Duration(milliseconds: 200),
                      reverseTransitionDuration:
                          const Duration(milliseconds: 200),
                      transitionsBuilder:
                          (context, animation, secondaryAnimation, child) {
                        const begin = Offset(1.0, 0.0);
                        const end = Offset.zero;
                        const curve = Curves.easeInOut;
                        var tween = Tween(begin: begin, end: end)
                            .chain(CurveTween(curve: curve));
                        var offsetAnimation = animation.drive(tween);
                        return SlideTransition(
                            position: offsetAnimation, child: child);
                      },
                    ),
                  );
                } catch (e) {
                  print("Navigation error: $e");
                  // Show snackbar if navigation fails
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Error opening conversation")),
                  );
                }
              }
              // Reset navigation flag
              isNavigating = false;
            });
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

  @override
  void dispose() {
    // Remove the listener to prevent callbacks after disposal
    widget.searchController.removeListener(_handleSearchChange);
    // Note: Don't dispose the controller here as it's owned by the parent
    super.dispose();
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
    final currentUserId = widget.controller.currentUserId.toString();
    final targetUserId = user.id.toString();

    developer.log(
      'Attempting to find or create conversation between "$currentUserId" and "$targetUserId"',
      name: 'MessagesPage',
    );

    try {
      // First try to find existing conversation - using a more reliable filter with collection group query
      final query = await firestore
          .collection('conversations')
          .where('isGroup', isEqualTo: false)
          .where('participants', arrayContains: currentUserId)
          .get();

      // Check each conversation for the target user
      for (final doc in query.docs) {
        final data = doc.data();

        // Safely handle participants array and convert to Set<String>
        final List<dynamic> participantsRaw = data['participants'] ?? [];
        final Set<String> participants = participantsRaw
            .map((p) => p.toString()) // Convert each participant ID to string
            .toSet();

        developer.log(
          'Checking conversation ${doc.id} - participants: $participants',
          name: 'MessagesPage',
        );

        // Check for exact match of participants
        if (participants.length == 2 &&
            participants.contains(currentUserId) &&
            participants.contains(targetUserId)) {
          developer.log('Found matching conversation: ${doc.id}',
              name: 'MessagesPage');

          // Safely handle message data with null coalescing and type conversion
          final lastMessageData =
              data['lastMessage'] as Map<String, dynamic>? ?? {};

          return Conversation(
            id: doc.id,
            participants: [
              User(
                id: currentUserId,
                name: "Me",
                avatarUrl: "",
                isOnline: true,
              ),
              User(
                id: targetUserId,
                name: user.name,
                avatarUrl: user.avatarUrl,
                isOnline: user.isOnline,
              ),
            ],
            messages: [],
            lastMessage: Message(
              id: lastMessageData['id']?.toString() ?? '',
              senderId: lastMessageData['senderId']?.toString() ?? '',
              senderName: lastMessageData['senderName']?.toString() ?? '',
              content: lastMessageData['content']?.toString() ?? '',
              timestamp: DateTime.tryParse(
                      lastMessageData['timestamp']?.toString() ?? '') ??
                  DateTime.now(),
              conversationId: doc.id,
            ),
            unreadCount: (data['unreadCount'] as num?)?.toInt() ?? 0,
            isGroup: data['isGroup'] ?? false,
            groupName: data['groupName']?.toString(),
            isMuted: data['isMuted'] ?? false,
            isArchived: data['isArchived'] ?? false,
          );
        }
      }

      // No existing conversation found, create new one
      developer.log('No existing conversation found, creating new one',
          name: 'MessagesPage');

      final newDoc = firestore.collection('conversations').doc();
      final now = DateTime.now();

      // Store all IDs as strings in the document
      final conversationData = {
        'id': newDoc.id,
        'participants': [
          currentUserId,
          targetUserId
        ], // Both IDs are already strings
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
        'createdAt': now,
      };

      await newDoc.set(conversationData);

      developer.log('Created new conversation with ID: ${newDoc.id}',
          name: 'MessagesPage');

      return Conversation(
        id: newDoc.id,
        participants: [
          User(
            id: currentUserId,
            name: "Me",
            avatarUrl: "",
            isOnline: true,
          ),
          User(
            id: targetUserId,
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
          conversationId: newDoc.id,
        ),
        unreadCount: 0,
        isGroup: false,
        groupName: null,
        isMuted: false,
        isArchived: false,
      );
    } catch (e, stack) {
      developer.log(
        'Error in conversation lookup/creation: $e\n$stack',
        name: 'MessagesPage',
        error: e,
      );
      rethrow;
    }
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
                                  try {
                                    // Show loading indicator
                                    showDialog(
                                      context: context,
                                      barrierDismissible: false,
                                      builder: (BuildContext context) {
                                        return const Dialog(
                                          child: Padding(
                                            padding: EdgeInsets.all(20.0),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                CircularProgressIndicator(),
                                                SizedBox(width: 20),
                                                Text(
                                                    "Creating conversation..."),
                                              ],
                                            ),
                                          ),
                                        );
                                      },
                                    );

                                    // Create or get conversation
                                    final conversation =
                                        await _createOrGetConversation(user);

                                    // Dismiss loading dialog
                                    if (mounted && Navigator.canPop(context)) {
                                      Navigator.of(context).pop();
                                    }

                                    // First close the contacts dialog
                                    if (mounted && Navigator.canPop(context)) {
                                      Navigator.of(context).pop();
                                    }

                                    // Use a small delay to ensure animations complete
                                    await Future.delayed(
                                        const Duration(milliseconds: 150));

                                    // Only navigate if still mounted
                                    if (mounted) {
                                      // Create a new controller for the chat detail page
                                      // instead of using the widget's controller
                                      if (widget.onConversationCreated !=
                                          null) {
                                        widget.onConversationCreated!(
                                            conversation);
                                      }
                                    }
                                  } catch (e, stack) {
                                    developer.log(
                                      'Error navigating to conversation: $e\n$stack',
                                      name: 'MessagesPage',
                                      error: e,
                                    );

                                    // Dismiss loading dialog if still showing
                                    if (mounted && Navigator.canPop(context)) {
                                      Navigator.of(context).pop();
                                    }

                                    // Show error to user
                                    if (mounted) {
                                      ResponsiveSnackBar.showError(
                                          context: context,
                                          message:
                                              "Error creating conversation: ${e.toString().split('\n').first}");
                                    }
                                  }
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
