import 'package:flutter/material.dart';
import 'package:flutter_application_2/constants/theme_constants.dart';
import 'package:flutter_application_2/providers/user_profile_provider.dart';
import 'package:flutter_application_2/services/api/account/api_urls.dart';
import 'package:flutter_application_2/ui/pages/home/components/post_detail/post_detail_page.dart';
import 'package:flutter_application_2/ui/profile/suggested_people_section.dart';
import 'package:flutter_application_2/ui/widgets/responsive_snackbar.dart';
import 'package:provider/provider.dart';
import 'dart:developer' as developer;
// Add new imports for messaging functionality
import 'package:flutter_application_2/ui/pages/messages/messages_controller.dart';
import 'package:flutter_application_2/ui/pages/messages/chat_detail_page.dart';
import 'package:flutter_application_2/ui/pages/messages/models/conversation.dart';
import 'package:flutter_application_2/ui/pages/messages/models/message.dart';
import 'package:flutter_application_2/ui/pages/messages/models/user.dart';
import 'package:flutter_application_2/models/user_profile.dart';
import 'package:flutter_application_2/models/account.dart';
import 'package:flutter_application_2/services/user_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_application_2/providers/posts_provider.dart';
import 'package:flutter_application_2/models/post.dart';
// Add the missing imports
import 'package:flutter_application_2/constants/category_utils.dart';
import 'package:flutter_application_2/utils/time_formatter.dart';
import 'package:share_plus/share_plus.dart';

class OtherUserProfilePage extends StatefulWidget {
  final Map<String, dynamic> userData;

  const OtherUserProfilePage({
    super.key,
    required this.userData,
  });

  @override
  State<OtherUserProfilePage> createState() => _OtherUserProfilePageState();
}

class _OtherUserProfilePageState extends State<OtherUserProfilePage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isFollowing = false;
  bool _isLoading = false;
  bool _showDiscoverPeople = true;
  Map<String, dynamic> _userData = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _userData = Map.from(widget.userData);

    // If the follow status is already known from a previous screen, use it
    if (_userData.containsKey('isFollowing')) {
      _isFollowing = _userData['isFollowing'] == true;
    }

    // Always check the follow status to be sure
    _checkFollowingStatus();

    // Fetch complete profile data if we only have basic data
    _fetchCompleteProfileData();
  }

  // Fetch more complete profile data
  Future<void> _fetchCompleteProfileData() async {
    final int userId = _userData['id'] as int;
    final profileProvider =
        Provider.of<UserProfileProvider>(context, listen: false);

    try {
      // Store the original profile image before fetching new data
      final originalProfileImage = _userData['profileImage'];
      developer.log(
          'Original profile image before update: $originalProfileImage',
          name: 'OtherUserProfilePage');

      // Fetch the complete user profile data
      final completeProfileData =
          await profileProvider.fetchUserProfile(userId);

      if (completeProfileData != null && mounted) {
        setState(() {
          // Preserve the following status
          final wasFollowing = _isFollowing;

          // Handle profile image URL format differences
          String? updatedProfileImage;
          final newProfileImage = completeProfileData['profileImage'] ??
              completeProfileData['profile_picture'] ??
              completeProfileData['profile_picture_url'];

          // If we have a new profile image and it's a relative path (starts with /)
          if (newProfileImage != null &&
              newProfileImage.toString().isNotEmpty) {
            if (newProfileImage.toString().startsWith('/')) {
              // Convert relative path to absolute URL if needed
              updatedProfileImage = '${ApiUrls.baseUrl}$newProfileImage';
            } else {
              updatedProfileImage = newProfileImage.toString();
            }
          } else {
            // Keep the original if no new valid image URL
            updatedProfileImage = originalProfileImage;
          }

          // Create updated user data
          _userData = {
            ...completeProfileData, // Add complete profile data
            'isFollowing': wasFollowing, // Preserve follow status
            'profileImage':
                updatedProfileImage, // Use properly formatted image URL
          };

          developer.log(
              'Updated profile with complete data: ${_userData.toString().substring(0, _userData.toString().length > 100 ? 100 : _userData.toString().length)}...',
              name: 'OtherUserProfilePage');
          developer.log(
              'Profile image after update: ${_userData['profileImage']}',
              name: 'OtherUserProfilePage');
        });
      }
    } catch (e) {
      developer.log('Error fetching complete profile data: $e',
          name: 'OtherUserProfilePage');
      // Continue with the basic profile data we already have
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _checkFollowingStatus() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    final int userId = _userData['id'] as int;
    final profileProvider =
        Provider.of<UserProfileProvider>(context, listen: false);

    try {
      final isFollowing = await profileProvider.checkFollowing(userId);

      // Debug log to track follow status check
      developer.log('User $userId follow status check: $isFollowing',
          name: 'OtherUserProfilePage');

      if (mounted) {
        setState(() {
          _isFollowing = isFollowing;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        developer.log('Error checking follow status: $e',
            name: 'OtherUserProfilePage');
      }
    }
  }

  Future<void> _toggleFollow() async {
    if (_isLoading || !mounted) return;

    setState(() {
      _isLoading = true;
    });

    final int userId = _userData['id'] as int;
    final profileProvider =
        Provider.of<UserProfileProvider>(context, listen: false);

    try {
      bool success;
      if (_isFollowing) {
        // Unfollow user
        success = await profileProvider.unfollowUser(userId);
        if (success && mounted) {
          setState(() {
            _isFollowing = false;
            // Update followers count
            _userData['followers'] = (_userData['followers'] ?? 1) - 1;
          });
          developer.log('Unfollowed user: $userId',
              name: 'OtherUserProfilePage');
        }
      } else {
        // Follow user
        success = await profileProvider.followUser(userId);
        if (success && mounted) {
          setState(() {
            _isFollowing = true;
            // Update followers count
            _userData['followers'] = (_userData['followers'] ?? 0) + 1;
          });
          developer.log('Followed user: $userId', name: 'OtherUserProfilePage');
        }
      }

      if (!success && mounted) {
        ResponsiveSnackBar.showError(
          context: context,
          message: profileProvider.error ?? 'Failed to update follow status',
        );
      }
    } catch (e) {
      if (mounted) {
        ResponsiveSnackBar.showError(
          context: context,
          message: 'Error: ${e.toString()}',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Open message conversation with this user
  void _openMessageConversation() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Extract user information to create conversation
      final int userId = _userData['id'] as int;
      final String username = _userData['username'] ?? '';
      final String? profileImage = _userData['profileImage'];
      final String displayName = _userData['name'] ?? username;
      final String email = _userData['email'] ?? '';

      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: SizedBox(
            height: 100,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Creating conversation...'),
                ],
              ),
            ),
          ),
        ),
      );

      // Get current user information from SharedPreferences or another source
      final firestore = FirebaseFirestore.instance;
      final currentUserId = await _getCurrentUserId();

      if (currentUserId.isEmpty) {
        throw Exception('Current user ID is not available');
      }

      // First try to find existing conversation
      final query = await firestore
          .collection('conversations')
          .where('isGroup', isEqualTo: false)
          .where('participants', arrayContains: currentUserId)
          .get();

      // Check each conversation for the target user
      String? existingConversationId;
      for (final doc in query.docs) {
        final data = doc.data();
        final List<dynamic> participantsRaw = data['participants'] ?? [];
        final Set<String> participants =
            participantsRaw.map((p) => p.toString()).toSet();

        if (participants.length == 2 &&
            participants.contains(currentUserId) &&
            participants.contains(userId.toString())) {
          existingConversationId = doc.id;
          break;
        }
      }

      // Create conversation object
      Conversation conversation;

      if (existingConversationId != null) {
        // Get existing conversation
        final docSnapshot = await firestore
            .collection('conversations')
            .doc(existingConversationId)
            .get();
        final data = docSnapshot.data() ?? {};

        // Get last message data safely
        final lastMessageData =
            data['lastMessage'] as Map<String, dynamic>? ?? {};

        conversation = Conversation(
          id: existingConversationId,
          participants: [
            User(
              id: currentUserId,
              name: "Me",
              avatarUrl: "",
              isOnline: true,
            ),
            User(
              id: userId.toString(),
              name: displayName,
              avatarUrl: profileImage ?? "",
              isOnline: false, // We don't know their status
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
            conversationId: existingConversationId,
          ),
          unreadCount: (data['unreadCount'] as num?)?.toInt() ?? 0,
          isGroup: data['isGroup'] ?? false,
          groupName: data['groupName']?.toString(),
          isMuted: data['isMuted'] ?? false,
          isArchived: data['isArchived'] ?? false,
        );
      } else {
        // Create new conversation
        final newDoc = firestore.collection('conversations').doc();
        final now = DateTime.now();

        // Store all IDs as strings in the document
        final conversationData = {
          'id': newDoc.id,
          'participants': [currentUserId, userId.toString()],
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

        conversation = Conversation(
          id: newDoc.id,
          participants: [
            User(
              id: currentUserId,
              name: "Me",
              avatarUrl: "",
              isOnline: true,
            ),
            User(
              id: userId.toString(),
              name: displayName,
              avatarUrl: profileImage ?? "",
              isOnline: false,
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
      }

      // Close loading dialog
      Navigator.pop(context);

      // Create a new controller instance for ChatDetailPage
      final messagesController = MessagesController();
      messagesController.selectConversation(conversation);

      // Navigate directly to ChatDetailPage
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChatDetailPage(
            conversation: conversation,
            controller: messagesController,
          ),
        ),
      );
    } catch (e) {
      // Log error and show error message
      developer.log('Error creating conversation: $e',
          name: 'OtherUserProfilePage', error: e);

      // Close loading dialog if it's open
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      if (mounted) {
        ResponsiveSnackBar.showError(
          context: context,
          message: 'Error: Could not start conversation.',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Helper method to get current user ID from provider or shared preferences
  Future<String> _getCurrentUserId() async {
    try {
      // Get the current user ID from the provider
      final profileProvider =
          Provider.of<UserProfileProvider>(context, listen: false);
      final currentUserProfile = profileProvider.currentUserProfile;
      if (currentUserProfile != null) {
        return currentUserProfile.account.id.toString();
      }
      return '';
    } catch (e) {
      developer.log('Error getting current user ID: $e',
          name: 'OtherUserProfilePage');
      return '';
    }
  }

  // Format join date string to Month Year format
  String _formatJoinDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) {
      return ''; // Return empty string if null or empty
    }

    try {
      // Try to parse the date from ISO format
      DateTime? date;

      // Since we've confirmed dateStr is not null, we now have a non-nullable String
      String nonNullDateStr = dateStr;

      // Remove time part if present
      if (nonNullDateStr.contains('T')) {
        nonNullDateStr = nonNullDateStr.split('T')[0];
      }

      // Try to parse different date formats
      try {
        date = DateTime.parse(nonNullDateStr);
      } catch (e) {
        // Try to parse other formats like "2025-05-06"
        final parts = nonNullDateStr.split('-');
        if (parts.length == 3) {
          date = DateTime(
              int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
        }
      }

      if (date != null) {
        final months = [
          'January',
          'February',
          'March',
          'April',
          'May',
          'June',
          'July',
          'August',
          'September',
          'October',
          'November',
          'December'
        ];
        return '${months[date.month - 1]} ${date.year}';
      }

      // If we couldn't parse it, just return the original string
      return nonNullDateStr;
    } catch (e) {
      developer.log('Error formatting join date: $e',
          name: 'OtherUserProfilePage');
      // Use the non-nullable version which we know is valid at this point
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverAppBar(
              expandedHeight: 0,
              floating: true,
              pinned: true,
              title: Text('@${_userData['username'] ?? 'Profile'}'),
            ),
            SliverToBoxAdapter(
              child: Column(
                children: [
                  _buildUserInfoSection(),
                  const SizedBox(height: 16),
                  if (_showDiscoverPeople) const SuggestedPeopleSection(),
                ],
              ),
            ),
            SliverPersistentHeader(
              delegate: _SliverAppBarDelegate(
                TabBar(
                  controller: _tabController,
                  labelColor: ThemeConstants.primaryColor,
                  unselectedLabelColor: ThemeConstants.grey,
                  indicatorColor: ThemeConstants.primaryColor,
                  indicatorWeight: 3,
                  tabs: const [
                    Tab(text: 'Posts', icon: Icon(Icons.article_outlined)),
                    Tab(text: 'Saved', icon: Icon(Icons.bookmark_border)),
                    Tab(text: 'Upvoted', icon: Icon(Icons.thumb_up_outlined)),
                  ],
                ),
                Theme.of(context).brightness == Brightness.dark,
              ),
              pinned: true,
            ),
          ];
        },
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildPostsTab(),
            _buildSavedTab(),
            _buildUpvotedTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildUserInfoSection() {
    // Log the userData for debugging purposes
    developer.log(
        'Building user info with data: ${_userData.toString().substring(0, _userData.toString().length > 150 ? 150 : _userData.toString().length)}...',
        name: 'OtherUserProfilePage');

    // Log specific fields of interest for debugging
    developer.log('Raw honesty data: ${_userData['honesty']}',
        name: 'OtherUserProfilePage');
    developer.log('Raw honesty_score data: ${_userData['honesty_score']}',
        name: 'OtherUserProfilePage');

    // Existing code to extract user data
    final String? profileImage = _userData['profileImage'];
    final String? name = _userData['name'];
    final String? username = _userData['username'];
    final String? bio = _userData['bio'];
    // We're not using isAdmin anymore since we're forcing the badge to show
    final int followersCount = _userData['followers'] ?? 0;
    final int followingCount = _userData['following'] ?? 0;
    final String? activityStatus = _userData['activityStatus'];

    // Ensure we get location regardless of the field name
    final String location = _userData['location'] ?? '';

    // Format join date properly using our helper method
    final String formattedJoinDate =
        _formatJoinDate(_userData['joinDate'] ?? _userData['join_date'] ?? '');

    // Get website if available
    final String website = _userData['website'] ?? '';

    // Handle honesty score from different possible field names - with improved parsing
    int honestyScore = 0;
    if (_userData['honesty'] is int) {
      honestyScore = _userData['honesty'];
    } else if (_userData['honesty_score'] is int) {
      honestyScore = _userData['honesty_score'];
    } else if (_userData['honesty'] is String &&
        _userData['honesty'].toString().isNotEmpty) {
      honestyScore = int.tryParse(_userData['honesty'].toString()) ?? 0;
    } else if (_userData['honesty_score'] is String &&
        _userData['honesty_score'].toString().isNotEmpty) {
      honestyScore = int.tryParse(_userData['honesty_score'].toString()) ?? 0;
    }

    // Debug log to see if honesty score is being properly detected
    developer.log('Final parsed honesty score: $honestyScore',
        name: 'OtherUserProfilePage');

    // Debug log to see if admin status is being properly detected
    developer.log('Admin status: ${_userData['is_admin']}',
        name: 'OtherUserProfilePage');
    developer.log('Admin status type: ${_userData['is_admin']?.runtimeType}',
        name: 'OtherUserProfilePage');
    developer.log('Admin badge condition: ${_userData['is_admin'] == true}',
        name: 'OtherUserProfilePage');

    // Print the entire user data for debugging
    developer.log('Full user data: ${_userData.toString()}',
        name: 'OtherUserProfilePage');

    return Padding(
      padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  Stack(
                    children: [
                      Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: ThemeConstants.primaryColorLight,
                            width: 3,
                          ),
                        ),
                        child: ClipOval(
                          child: profileImage != null && profileImage.isNotEmpty
                              ? Image.network(
                                  profileImage,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                    color: ThemeConstants.greyLight,
                                    child: const Icon(Icons.person,
                                        size: 50, color: ThemeConstants.grey),
                                  ),
                                )
                              : Container(
                                  color: ThemeConstants.greyLight,
                                  child: const Icon(Icons.person,
                                      size: 50, color: ThemeConstants.grey),
                                ),
                        ),
                      ),
                      if (activityStatus != null)
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              color: _getStatusColor(activityStatus),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color:
                                    Theme.of(context).scaffoldBackgroundColor,
                                width: 3,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          name ?? 'No Name',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Clean admin badge without text or shadow
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade700,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.verified_user,
                            size: 16,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      '@${username ?? 'username'}',
                      style: TextStyle(
                        fontSize: 16,
                        color: ThemeConstants.grey,
                      ),
                    ),
                    const SizedBox(height: 4),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (bio != null && bio.isNotEmpty)
            Text(
              bio,
              style: const TextStyle(fontSize: 15),
            ),
          const SizedBox(height: 12),

          // Location and Join Date row - make it more flexible with null checks
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              if (location.isNotEmpty)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.location_on,
                        size: 16, color: ThemeConstants.grey),
                    const SizedBox(width: 4),
                    Text(
                      location,
                      style: TextStyle(
                        fontSize: 14,
                        color: ThemeConstants.grey,
                      ),
                    ),
                  ],
                ),
              if (formattedJoinDate.isNotEmpty)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.calendar_today,
                        size: 14, color: ThemeConstants.grey),
                    const SizedBox(width: 4),
                    Text(
                      'Joined $formattedJoinDate',
                      style: TextStyle(
                        fontSize: 14,
                        color: ThemeConstants.grey,
                      ),
                    ),
                  ],
                ),
              if (website.isNotEmpty)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.link, size: 14, color: ThemeConstants.grey),
                    const SizedBox(width: 4),
                    Text(
                      website,
                      style: TextStyle(
                        fontSize: 14,
                        color: ThemeConstants.primaryColor,
                      ),
                    ),
                  ],
                ),
            ],
          ),

          const SizedBox(height: 16),
          Row(
            children: [
              Column(
                children: [
                  Text(
                    followersCount.toString(),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: ThemeConstants.primaryColor,
                    ),
                  ),
                  Text(
                    'Followers',
                    style: TextStyle(
                      fontSize: 14,
                      color: ThemeConstants.grey,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 24),
              Column(
                children: [
                  Text(
                    followingCount.toString(),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Following',
                    style: TextStyle(
                      fontSize: 14,
                      color: ThemeConstants.grey,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              // Always show honesty rating, even if it's 0
              _buildHonestyRating(honestyScore),
              const SizedBox(width: 16),
              IconButton(
                icon: Icon(
                  Icons.person_outline,
                  color: _showDiscoverPeople
                      ? ThemeConstants.primaryColor
                      : Theme.of(context).iconTheme.color,
                ),
                onPressed: () {
                  setState(() {
                    _showDiscoverPeople = !_showDiscoverPeople;
                  });
                },
                tooltip: 'Toggle Discover People',
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _toggleFollow,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isFollowing
                        ? Colors.grey[200]
                        : ThemeConstants.primaryColor,
                    foregroundColor:
                        _isFollowing ? ThemeConstants.grey : Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    minimumSize: const Size(0, 36),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(_isFollowing ? "Following" : "Follow"),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 36,
                child: AspectRatio(
                  aspectRatio: 1.2,
                  child: OutlinedButton(
                    onPressed: _openMessageConversation,
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.zero,
                      side: BorderSide(color: ThemeConstants.primaryColor),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Icon(
                      Icons.chat_outlined,
                      color: ThemeConstants.primaryColor,
                      size: 20,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHonestyRating(int rating) {
    Color color;
    if (rating >= 80) {
      color = ThemeConstants.green;
    } else if (rating >= 60) {
      color = ThemeConstants.orange;
    } else {
      color = ThemeConstants.red;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(51),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.verified_user,
            size: 14,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            '$rating% Honesty',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPostsTab() {
    final int userId = _userData['id'];

    return FutureBuilder<List<Post>>(
      future: Provider.of<PostsProvider>(context, listen: false)
          .getUserPosts(userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 64,
                  color: ThemeConstants.grey.withAlpha(51),
                ),
                const SizedBox(height: 16),
                Text(
                  'Failed to load posts',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: ThemeConstants.grey,
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    setState(() {}); // Refresh
                  },
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        // Get all posts and filter out anonymous posts (since we're viewing another user's profile)
        final allPosts = snapshot.data ?? [];
        final publicPosts =
            allPosts.where((post) => !post.isAnonymous).toList();

        if (publicPosts.isEmpty) {
          return _buildEmptyStateWithCount(
            icon: Icons.article_outlined,
            message: 'No Public Posts',
            count: 0,
          );
        }

        return _buildPostsList(publicPosts);
      },
    );
  }

  Widget _buildSavedTab() {
    final int userId = _userData['id'];

    return FutureBuilder<List<Post>>(
      future: Provider.of<PostsProvider>(context, listen: false)
          .getSavedPosts(userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 64,
                  color: ThemeConstants.grey.withAlpha(51),
                ),
                const SizedBox(height: 16),
                Text(
                  'Failed to load saved posts',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: ThemeConstants.grey,
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    setState(() {}); // Refresh
                  },
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        // Get all saved posts and filter out anonymous posts
        final allPosts = snapshot.data ?? [];
        final publicPosts =
            allPosts.where((post) => !post.isAnonymous).toList();

        if (publicPosts.isEmpty) {
          return _buildEmptyStateWithCount(
            icon: Icons.bookmark_border,
            message: 'No Public Saved Posts',
            count: 0,
          );
        }

        return _buildPostsList(publicPosts);
      },
    );
  }

  Widget _buildUpvotedTab() {
    final int userId = _userData['id'];

    return FutureBuilder<List<Post>>(
      future: Provider.of<PostsProvider>(context, listen: false)
          .getUpvotedPosts(userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 64,
                  color: ThemeConstants.grey.withAlpha(51),
                ),
                const SizedBox(height: 16),
                Text(
                  'Failed to load upvoted posts',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: ThemeConstants.grey,
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    setState(() {}); // Refresh
                  },
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        // Get all upvoted posts and filter out anonymous posts
        final allPosts = snapshot.data ?? [];
        final publicPosts =
            allPosts.where((post) => !post.isAnonymous).toList();

        if (publicPosts.isEmpty) {
          return _buildEmptyStateWithCount(
            icon: Icons.thumb_up_outlined,
            message: 'No Public Upvoted Posts',
            count: 0,
          );
        }

        return _buildPostsList(publicPosts);
      },
    );
  }

  // Helper method to build a list of posts
  Widget _buildPostsList(List<Post> posts) {
    return RefreshIndicator(
      onRefresh: () async {
        // Use Future.delayed to avoid setState during build
        return Future.delayed(Duration.zero, () {
          if (mounted) {
            setState(() {}); // This will refresh the FutureBuilder
          }
        });
      },
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: posts.length,
        itemBuilder: (context, index) {
          final post = posts[index];
          return _buildPostCard(post);
        },
      ),
    );
  }

  // Helper method to build a post card with the new design
  Widget _buildPostCard(Post post) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final cardBackground = isDarkMode ? Colors.grey.shade900 : Colors.white;
    final textColor = isDarkMode ? Colors.white : Colors.black87;
    final subtitleColor =
        isDarkMode ? Colors.grey.shade300 : Colors.grey.shade700;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 3,
      shadowColor: Colors.black38,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Author section with gradient background
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  _getCategoryColor(post.category).withOpacity(0.1),
                  cardBackground,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor:
                      _getCategoryColor(post.category).withOpacity(0.2),
                  child: CircleAvatar(
                    radius: 20,
                    backgroundImage:
                        post.author.profilePictureUrl?.isNotEmpty == true
                            ? NetworkImage(post.author.profilePictureUrl!)
                            : null,
                    backgroundColor: cardBackground,
                    child: post.author.profilePictureUrl?.isEmpty ?? true
                        ? Icon(Icons.person,
                            color: _getCategoryColor(post.category))
                        : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            post.isAnonymous
                                ? 'Anonymous'
                                : (post.author.fullName ?? post.author.name),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: textColor,
                            ),
                          ),
                          if (post.author.isAdmin && !post.isAnonymous)
                            Padding(
                              padding: const EdgeInsets.only(left: 4),
                              child: Icon(
                                Icons.verified_user,
                                size: 20,
                                color: Colors.blue.shade700,
                              ),
                            ),
                        ],
                      ),
                      Row(
                        children: [
                          Icon(Icons.access_time,
                              size: 12, color: subtitleColor),
                          const SizedBox(width: 4),
                          Text(
                            _getTimeAgo(post.createdAt),
                            style: TextStyle(
                              fontSize: 12,
                              color: subtitleColor,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Category badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: _getCategoryColor(post.category).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _capitalizeFirstLetter(post.category),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: _getCategoryColor(post.category),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Post content - make the InkWell cover content section
          InkWell(
            onTap: () => _navigateToPostDetail(post),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Media content
                if (post.mediaUrls.isNotEmpty)
                  ClipRRect(
                    borderRadius: const BorderRadius.all(Radius.circular(0)),
                    child: Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        AspectRatio(
                          aspectRatio: 16 / 9,
                          child: Image.network(
                            post.mediaUrls.first,
                            fit: BoxFit.cover,
                            errorBuilder: (context, url, error) => Container(
                              color: Colors.grey.shade200,
                              child: Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.image_not_supported,
                                        size: 40, color: Colors.grey),
                                    const SizedBox(height: 8),
                                    Text('Image not available',
                                        style: TextStyle(color: subtitleColor)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        // Honesty badge on image
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: _buildHonestyBadge(post.honestyScore),
                        ),
                      ],
                    ),
                  ),

                // Post content
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title with custom styling
                      Text(
                        post.title,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),

                      // Content with better contrast
                      Text(
                        post.content,
                        style: TextStyle(
                          fontSize: 14,
                          color: subtitleColor,
                          height: 1.3,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 16),

                      // Location with cleaner display
                      if (post.location.address != null)
                        Row(
                          children: [
                            Icon(
                              Icons.location_on,
                              size: 14,
                              color: _getCategoryColor(post.category)
                                  .withOpacity(0.8),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                post.location.address ?? 'Unknown location',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: subtitleColor,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),

                      // Tags with nicer styling
                      if (post.tags.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: post.tags.map((tag) {
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: _getCategoryColor(post.category)
                                      .withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: _getCategoryColor(post.category)
                                        .withOpacity(0.2),
                                    width: 1,
                                  ),
                                ),
                                child: Text(
                                  '#$tag',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: _getCategoryColor(post.category)
                                        .withOpacity(0.8),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Divider before actions
          Divider(height: 1, thickness: 1, color: Colors.grey.withOpacity(0.1)),

          // Redesigned action buttons - All are non-interactive stats display, except share
          Container(
            decoration: BoxDecoration(
              color: isDarkMode ? Colors.black12 : Colors.grey.shade50,
              borderRadius:
                  const BorderRadius.vertical(bottom: Radius.circular(16)),
            ),
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                // Upvotes display - non-interactive
                _buildInfoButton(
                  icon: Icons.arrow_upward,
                  label: post.upvotes.toString(),
                  color: Colors.grey,
                  onTap: () => _navigateToPostDetail(post),
                ),
                // Downvotes display - non-interactive
                _buildInfoButton(
                  icon: Icons.arrow_downward,
                  label: post.downvotes.toString(),
                  color: Colors.grey,
                  onTap: () => _navigateToPostDetail(post),
                ),
                // Save status - non-interactive
                _buildInfoButton(
                  icon: post.isSaved == true
                      ? Icons.bookmark
                      : Icons.bookmark_outline,
                  color: post.isSaved == true ? Colors.amber : Colors.grey,
                  onTap: () => _navigateToPostDetail(post),
                ),
                // Comments - navigate to detail
                _buildInfoButton(
                  icon: Icons.mode_comment_outlined,
                  color: Colors.grey,
                  onTap: () => _navigateToPostDetail(post),
                ),
                // Share - this one can be interactive
                _buildInfoButton(
                  icon: Icons.ios_share,
                  color: Colors.grey,
                  onTap: () => Share.share(
                    'Check out this post: ${post.title}',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Info button builder for post actions
  Widget _buildInfoButton({
    required IconData icon,
    String? label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 22,
                color: color,
              ),
              if (label != null) const SizedBox(height: 4),
              if (label != null)
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyStateWithCount({
    required IconData icon,
    required String message,
    required int count,
  }) {
    return SingleChildScrollView(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 32.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 64,
                color: ThemeConstants.grey.withAlpha(51),
              ),
              const SizedBox(height: 16),
              Text(
                message,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: ThemeConstants.grey,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'This user has $count ${message.toLowerCase()}',
                style: TextStyle(
                  fontSize: 14,
                  color: ThemeConstants.grey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'online':
        return ThemeConstants.green;
      case 'do not disturb':
      case 'donotdisturb':
      case 'do_not_disturb':
        return ThemeConstants.red;
      case 'away':
        return ThemeConstants.orange;
      case 'offline':
      default:
        return ThemeConstants.grey;
    }
  }

  Color _getCategoryColor(String category) {
    return CategoryUtils.getCategoryColor(category);
  }

  String _capitalizeFirstLetter(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1).toLowerCase();
  }

  String _getTimeAgo(DateTime dateTime) {
    return TimeFormatter.getFormattedTime(dateTime);
  }

  // Navigate to post detail page
  void _navigateToPostDetail(Post post) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PostDetailPage(
          title: post.title,
          description: post.content,
          imageUrl: post.mediaUrls.isNotEmpty ? post.mediaUrls[0] : '',
          location: post.location.address ?? 'Unknown location',
          time: TimeFormatter.getFormattedTime(post.createdAt),
          honesty: post.honestyScore,
          upvotes: post.upvotes,
          comments: 0, // This would come from a threads count
          isVerified: post.author.isAdmin,
          post: post, // Pass the whole post object
        ),
      ),
    );
  }

  // Build a honesty score badge with appropriate color based on score
  Widget _buildHonestyBadge(int score) {
    Color color;

    if (score >= 80) {
      color = ThemeConstants.green;
    } else if (score >= 60) {
      color = ThemeConstants.primaryColor;
    } else if (score >= 40) {
      color = Colors.amber; // Changed from ThemeConstants.amber to Colors.amber
    } else {
      color = ThemeConstants.red;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.9),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.verified, color: Colors.white, size: 14),
          const SizedBox(width: 4),
          Text(
            '$score%',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar _tabBar;
  final bool isDarkMode;

  _SliverAppBarDelegate(this._tabBar, this.isDarkMode);

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: _tabBar,
    );
  }

  @override
  double get minExtent => _tabBar.preferredSize.height;

  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  bool shouldRebuild(covariant _SliverAppBarDelegate oldDelegate) {
    return oldDelegate.isDarkMode != isDarkMode;
  }
}
