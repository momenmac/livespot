import 'package:flutter/material.dart';
import 'package:flutter_application_2/constants/text_strings.dart';
import 'package:flutter_application_2/constants/theme_constants.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_application_2/ui/pages/notification/notification_model.dart';
import 'package:flutter_application_2/services/api/notification_api_service.dart';
import 'package:flutter_application_2/services/api/account/api_urls.dart';
import 'package:flutter_application_2/ui/profile/other_user_profile_page.dart';
import 'package:flutter_application_2/services/notifications/notification_event_bus.dart';
import 'package:flutter_application_2/ui/pages/home/components/post_detail/post_detail_page.dart';
import 'package:flutter_application_2/providers/posts_provider.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import 'notification_filter.dart';
import 'package:flutter_application_2/services/utils/global_notification_service.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage>
    with TickerProviderStateMixin {
  bool _showBanner = true;
  bool _notificationsEnabled = false;
  NotificationFilter _selectedFilter = NotificationFilter.all;
  late AnimationController _animationController;

  // Real notification data from backend
  List<NotificationModel> notifications = [];
  bool _isLoading = true;
  bool _isLoadingMore = false; // Separate state for pagination loading
  bool _isRefreshing = false;
  String? _errorMessage;
  int _currentPage = 1;
  bool _hasMoreData = true;
  final ScrollController _scrollController = ScrollController();

  List<NotificationModel> _getFilteredNotifications() {
    return _selectedFilter.filterNotifications(notifications);
  }

  // Get notification count for a specific filter
  int _getFilterCount(NotificationFilter filter) {
    return filter.filterNotifications(notifications).length;
  }

  @override
  void initState() {
    super.initState();
    _checkNotificationStatus();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _loadNotifications();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _animationController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 300) {
      // Increased trigger distance
      if (!_isLoading && !_isLoadingMore && _hasMoreData) {
        _loadMoreNotifications();
      }
    }
  }

  Future<void> _loadNotifications() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final notificationData =
          await NotificationApiService.getNotificationHistory(
        page: 1,
        pageSize: 20,
      );

      if (!mounted) return;

      final convertedNotifications = notificationData
          .map((data) => _convertToNotificationModel(data))
          .toList();

      setState(() {
        notifications = convertedNotifications;
        _currentPage = 1;
        _hasMoreData = notificationData.length >= 20;
        _isLoading = false;
      });

      // Refresh notification count after loading notifications
      _refreshNotificationCount();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Failed to load notifications: ${e.toString()}';
        _isLoading = false;
      });
      debugPrint('Error loading notifications: $e');
    }
  }

  Future<void> _loadMoreNotifications() async {
    if (_isLoading || _isLoadingMore || !_hasMoreData) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      final nextPage = _currentPage + 1;
      debugPrint('🔄 Loading more notifications - Page $nextPage');

      final notificationData =
          await NotificationApiService.getNotificationHistory(
        page: nextPage,
        pageSize: 20,
      );

      if (!mounted) return;

      final convertedNotifications = notificationData
          .map((data) => _convertToNotificationModel(data))
          .toList();

      setState(() {
        notifications.addAll(convertedNotifications);
        _currentPage = nextPage;
        _hasMoreData = notificationData.length >= 20;
        _isLoadingMore = false;
      });

      debugPrint(
          '✅ Loaded ${convertedNotifications.length} more notifications. Total: ${notifications.length}');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingMore = false;
      });
      debugPrint('❌ Error loading more notifications: $e');
    }
  }

  NotificationModel _convertToNotificationModel(Map<String, dynamic> data) {
    // Convert Django notification data to NotificationModel
    final notificationData = data['data'] as Map<String, dynamic>? ?? {};

    // Extract user avatar from Django notification data structure
    String? userAvatar;

    // For follow notifications, check followerUserAvatar
    if (notificationData.containsKey('followerUserAvatar')) {
      userAvatar = notificationData['followerUserAvatar'] as String?;
    }

    // For other notification types, try user_data
    if (userAvatar == null && notificationData.containsKey('user_data')) {
      final userData =
          notificationData['user_data'] as Map<String, dynamic>? ?? {};
      userAvatar = userData['profile_image'] as String? ??
          userData['profileImage'] as String? ??
          userData['avatar'] as String? ??
          userData['image_url'] as String?;
    }

    // Try other common avatar field names
    userAvatar ??= notificationData['profile_image'] as String? ??
        notificationData['profileImage'] as String? ??
        notificationData['avatar'] as String? ??
        notificationData['user_image'] as String? ??
        notificationData['image_url'] as String?;

    return NotificationModel(
      id: data['id']?.toString() ?? '',
      title: data['title'] ?? 'Notification',
      body: data['body'] ?? '',
      timestamp: DateTime.tryParse(data['created_at'] ?? '') ?? DateTime.now(),
      read: data['read'] ?? false,
      type: data['notification_type'] ?? 'general',
      data: Map<String, dynamic>.from(data['data'] ?? {}),
      // Legacy fields for UI compatibility
      message: data['body'] ?? '',
      dateTime: DateTime.tryParse(data['created_at'] ?? '') ?? DateTime.now(),
      icon: _getIconForNotificationType(data['notification_type'] ?? 'general'),
      imageUrl: userAvatar,
      isRead: data['read'] ?? false,
    );
  }

  IconData _getIconForNotificationType(String type) {
    switch (type) {
      case 'friend_request':
        return Icons.person_add;
      case 'friend_request_accepted':
        return Icons.person_add_alt_1;
      case 'new_follower':
        return Icons.favorite_outline; // Changed to heart icon for followers
      case 'unfollowed':
        return Icons.heart_broken_outlined;
      case 'new_event':
      case 'event_update':
        return Icons.event;
      case 'event_cancelled':
        return Icons.event_busy;
      case 'still_there':
        return Icons.location_on;
      case 'nearby_event':
        return Icons.location_on_outlined;
      case 'reminder':
        return Icons.notifications_active;
      case 'system':
        return Icons.info;
      default:
        return Icons.notifications;
    }
  }

  Color _getIconColor(String type, BuildContext context) {
    switch (type) {
      case 'new_follower':
        return Colors.pink; // Pink for new followers
      case 'friend_request':
        return Colors.blue; // Blue for friend requests
      case 'friend_request_accepted':
        return Colors.green; // Green for accepted requests
      case 'unfollowed':
        return Colors.red; // Red for unfollows
      case 'new_event':
      case 'event_update':
        return Colors.orange; // Orange for events
      case 'event_cancelled':
        return Colors.red;
      case 'still_there':
      case 'nearby_event':
        return Colors.purple; // Purple for location-based
      case 'reminder':
        return Colors.amber; // Amber for reminders
      case 'system':
        return Colors.grey;
      default:
        return Theme.of(context).colorScheme.primary;
    }
  }

  String _getFixedImageUrl(String? url) {
    if (url == null || url.isEmpty) return '';
    if (url.startsWith('http://localhost:8000')) {
      return ApiUrls.baseUrl + url.substring('http://localhost:8000'.length);
    }
    if (url.startsWith('http://127.0.0.1:8000')) {
      return ApiUrls.baseUrl + url.substring('http://127.0.0.1:8000'.length);
    }
    if (url.startsWith('/')) {
      return ApiUrls.baseUrl + url;
    }
    return url;
  }

  Future<void> _refreshNotifications() async {
    setState(() {
      _isRefreshing = true;
    });

    await _loadNotifications();

    setState(() {
      _isRefreshing = false;
    });
  }

  Future<void> _markAsRead(NotificationModel notification) async {
    final currentlyRead = notification.isRead ?? notification.read;
    if (currentlyRead) return;

    try {
      final success =
          await NotificationApiService.markNotificationAsRead(notification.id);
      if (success && mounted) {
        setState(() {
          final index =
              notifications.indexWhere((n) => n.id == notification.id);
          if (index != -1) {
            notifications[index] =
                notification.copyWith(read: true, isRead: true);
          }
        });
      }
    } catch (e) {
      debugPrint('Error marking notification as read: $e');
    }
  }

  void _navigateToUserProfile(Map<String, dynamic> notificationData) {
    // Handle Django notification data structure for follow notifications
    Map<String, dynamic>? userData;

    // Check if it's a follow notification with follower data
    if (notificationData.containsKey('followerUserId')) {
      userData = {
        'id': notificationData['followerUserId'],
        'username': notificationData['followerUserName'],
        'profile_picture_url': notificationData['followerUserAvatar'],
        // Add any other required fields for OtherUserProfilePage
      };
    } else if (notificationData.containsKey('user_data')) {
      // Handle other notification types with user_data
      userData = notificationData['user_data'] as Map<String, dynamic>?;
    }

    if (userData != null && userData['id'] != null) {
      // Convert user data to the format expected by OtherUserProfilePage
      // CRITICAL FIX: Convert string user ID to integer
      int userId;
      try {
        userId = userData['id'] is String
            ? int.parse(userData['id'] as String)
            : userData['id'] as int;
      } catch (e) {
        debugPrint('Error parsing user ID: ${userData['id']}, error: $e');
        return;
      }

      final profileData = {
        'id': userId, // Now properly converted to integer
        'username': userData['username'] ?? 'Unknown User',
        'email': userData['email'] ?? '',
        'first_name': userData['first_name'] ?? '',
        'last_name': userData['last_name'] ?? '',
        'profile_picture_url': userData['profile_picture_url'] ??
            userData['profileImage'] ??
            userData['avatar'] ??
            '',
        'bio': userData['bio'] ?? '',
        'location': userData['location'] ?? '',
        'honesty_score': userData['honesty_score'] ?? 0,
        'is_verified': userData['is_verified'] ?? false,
      };

      debugPrint('Navigating to profile with data: $profileData');

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => OtherUserProfilePage(userData: profileData),
        ),
      );
    } else {
      debugPrint(
          'No valid user data found for profile navigation: $notificationData');
    }
  }

  bool _isFollowRelatedNotification(String type) {
    return type == 'friend_request' ||
        type == 'friend_request_accepted' ||
        type == 'new_follower' ||
        type == 'unfollowed';
  }

  bool _isPostRelatedNotification(String type) {
    return type == 'still_happening' ||
        type == 'still_there' ||
        type == 'new_event' ||
        type == 'event_update';
  }

  Future<void> _navigateToPostDetail(
      Map<String, dynamic> notificationData) async {
    debugPrint('=== POST NAVIGATION DEBUG ===');
    debugPrint('Notification data received: $notificationData');

    // Extract post ID from notification data
    int? postId;

    try {
      // Try different possible field names for post ID
      if (notificationData.containsKey('post_id')) {
        postId = notificationData['post_id'] is String
            ? int.parse(notificationData['post_id'])
            : notificationData['post_id'] as int?;
        debugPrint('Found post_id: $postId');
      } else if (notificationData.containsKey('postId')) {
        postId = notificationData['postId'] is String
            ? int.parse(notificationData['postId'])
            : notificationData['postId'] as int?;
        debugPrint('Found postId: $postId');
      } else if (notificationData.containsKey('id')) {
        postId = notificationData['id'] is String
            ? int.parse(notificationData['id'])
            : notificationData['id'] as int?;
        debugPrint('Found id: $postId');
      }

      debugPrint('Extracted post ID: $postId');
      debugPrint(
          'All notification data keys: ${notificationData.keys.toList()}');

      if (postId == null) {
        debugPrint('No post ID found in notification data: $notificationData');
        // Show error to user
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Cannot find post ID in notification data'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('Loading post...'),
            ],
          ),
        ),
      );

      // Fetch post details using PostsProvider
      final postsProvider = Provider.of<PostsProvider>(context, listen: false);
      final post = await postsProvider.fetchPostDetails(postId);

      // Dismiss loading dialog
      if (mounted) Navigator.pop(context);

      if (post != null && mounted) {
        // Navigate to PostDetailPage with the fetched post data
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PostDetailPage(
              title: post.title,
              description: post.content,
              imageUrl: post.imageUrl,
              location: post.location.address ??
                  '${post.location.latitude}, ${post.location.longitude}',
              time: post.createdAt.toString(),
              honesty: post.honestyScore,
              upvotes: post.upvotes,
              comments: 0, // Comments count not available in Post model
              isVerified: post.isVerifiedLocation,
              post: post,
              authorName: post.authorName,
              downvotes: post.downvotes,
            ),
          ),
        );
      } else if (mounted) {
        // Show error message if post not found
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Post not found or no longer available'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      // Dismiss loading dialog if still showing
      if (mounted) Navigator.pop(context);

      debugPrint('Error navigating to post detail: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading post: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Helper method to extract thumbnail URL from notification data
  String? _extractThumbnailUrl(Map<String, dynamic> notificationData) {
    // Try different possible field names for thumbnail/image
    if (notificationData.containsKey('thumbnail_url')) {
      return notificationData['thumbnail_url'] as String?;
    }
    if (notificationData.containsKey('image_url')) {
      return notificationData['image_url'] as String?;
    }
    if (notificationData.containsKey('post_image_url')) {
      return notificationData['post_image_url'] as String?;
    }
    if (notificationData.containsKey('post_image')) {
      return notificationData['post_image'] as String?;
    }
    if (notificationData.containsKey('image')) {
      return notificationData['image'] as String?;
    }
    // Check if there's a post object with image
    if (notificationData.containsKey('post') &&
        notificationData['post'] is Map) {
      final post = notificationData['post'] as Map<String, dynamic>;
      if (post.containsKey('image_url')) {
        return post['image_url'] as String?;
      }
      if (post.containsKey('imageUrl')) {
        return post['imageUrl'] as String?;
      }
    }
    return null;
  }

  // Build action buttons for post-related notifications
  Widget _buildNotificationActionButtons(NotificationModel notification) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          // Still Happening button
          Expanded(
            child: FutureBuilder<bool>(
              future: _checkUserProximityToPost(notification),
              builder: (context, snapshot) {
                final isNearPost = snapshot.data ?? false;
                final isEnded = _isPostEnded(notification);
                final isEnabled = isNearPost && !isEnded;

                debugPrint(
                    '🔘 Still Happening button: isNearPost=$isNearPost, isEnded=$isEnded, isEnabled=$isEnabled');

                return ElevatedButton.icon(
                  onPressed: isEnabled
                      ? () => _handleStillHappeningAction(notification)
                      : null,
                  icon: Icon(
                    Icons.check_circle,
                    size: 16,
                    color: isEnabled
                        ? Colors.white
                        : (isDark ? Colors.grey[600] : Colors.grey[500]),
                  ),
                  label: Text(
                    'Still Happening',
                    style: TextStyle(
                      fontSize: 12,
                      color: isEnabled
                          ? Colors.white
                          : (isDark ? Colors.grey[600] : Colors.grey[500]),
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isEnabled
                        ? Colors.green
                        : (isDark ? Colors.grey[850] : Colors.grey[300]),
                    foregroundColor: isEnabled
                        ? Colors.white
                        : (isDark ? Colors.grey[600] : Colors.grey[500]),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: const Size(0, 32),
                    elevation: isEnabled ? 2 : 0,
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: 8),
          // Ended button
          Expanded(
            child: FutureBuilder<bool>(
              future: _checkUserProximityToPost(notification),
              builder: (context, snapshot) {
                final isNearPost = snapshot.data ?? false;
                final isEnded = _isPostEnded(notification);
                final isEnabled = isNearPost && !isEnded;

                debugPrint(
                    '🔘 Ended button: isNearPost=$isNearPost, isEnded=$isEnded, isEnabled=$isEnabled');

                return ElevatedButton.icon(
                  onPressed:
                      isEnabled ? () => _handleEndedAction(notification) : null,
                  icon: Icon(
                    Icons.cancel,
                    size: 16,
                    color: isEnabled
                        ? Colors.white
                        : (isDark ? Colors.grey[600] : Colors.grey[500]),
                  ),
                  label: Text(
                    'Ended',
                    style: TextStyle(
                      fontSize: 12,
                      color: isEnabled
                          ? Colors.white
                          : (isDark ? Colors.grey[600] : Colors.grey[500]),
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isEnabled
                        ? Colors.red
                        : (isDark ? Colors.grey[850] : Colors.grey[300]),
                    foregroundColor: isEnabled
                        ? Colors.white
                        : (isDark ? Colors.grey[600] : Colors.grey[500]),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: const Size(0, 32),
                    elevation: isEnabled ? 2 : 0,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // Check if user is near the post location
  Future<bool> _checkUserProximityToPost(NotificationModel notification) async {
    try {
      // Extract post coordinates from notification data
      final notificationData = notification.data;
      double? postLat, postLng;

      // Try to get coordinates from different possible fields
      if (notificationData.containsKey('latitude') &&
          notificationData.containsKey('longitude')) {
        postLat = double.tryParse(notificationData['latitude'].toString());
        postLng = double.tryParse(notificationData['longitude'].toString());
      } else if (notificationData.containsKey('lat') &&
          notificationData.containsKey('lng')) {
        postLat = double.tryParse(notificationData['lat'].toString());
        postLng = double.tryParse(notificationData['lng'].toString());
      } else if (notificationData.containsKey('post') &&
          notificationData['post'] is Map) {
        final post = notificationData['post'] as Map<String, dynamic>;
        postLat = double.tryParse(post['latitude'].toString());
        postLng = double.tryParse(post['longitude'].toString());
      }

      if (postLat == null || postLng == null) {
        debugPrint(
            '❌ Proximity check: Cannot determine post location - DISABLING buttons');
        // Return false when coordinates are not available (disabled state)
        return false;
      }

      try {
        // Get user's current location
        final userPosition = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.best,
          timeLimit: const Duration(seconds: 10),
        );
        final distance = Geolocator.distanceBetween(
          userPosition.latitude,
          userPosition.longitude,
          postLat,
          postLng,
        );

        final isNear = distance <= 100; // 100 meters for production
        debugPrint(
            '📍 Proximity check: Distance = ${distance.toStringAsFixed(2)}m, isNear = $isNear');

        return isNear;
      } catch (locationError) {
        debugPrint(
            '❌ Proximity check: Location error - DISABLING buttons: $locationError');
        // Return false when location access fails (disabled state)
        return false;
      }
    } catch (e) {
      debugPrint('❌ Proximity check: General error - DISABLING buttons: $e');
      // Return false when any error occurs (disabled state)
      return false;
    }
  }

  // Check if the post has ended
  bool _isPostEnded(NotificationModel notification) {
    // Check if the notification data indicates the post has ended
    final notificationData = notification.data;

    if (notificationData.containsKey('is_ended')) {
      final isEnded = notificationData['is_ended'] == true;
      debugPrint('🔚 Post ended check: is_ended = $isEnded');
      return isEnded;
    }

    if (notificationData.containsKey('status')) {
      final status = notificationData['status'];
      final isEnded = status == 'ended';
      debugPrint('🔚 Post ended check: status = $status, isEnded = $isEnded');
      return isEnded;
    }

    if (notificationData.containsKey('post') &&
        notificationData['post'] is Map) {
      final post = notificationData['post'] as Map<String, dynamic>;
      if (post.containsKey('is_ended')) {
        final isEnded = post['is_ended'] == true;
        debugPrint('🔚 Post ended check: post.is_ended = $isEnded');
        return isEnded;
      }
      if (post.containsKey('status')) {
        final status = post['status'];
        final isEnded = status == 'ended';
        debugPrint(
            '🔚 Post ended check: post.status = $status, isEnded = $isEnded');
        return isEnded;
      }
    }

    // Check if event has been running for more than 24 hours (auto-expire)
    if (notificationData.containsKey('created_at')) {
      try {
        final createdAt =
            DateTime.tryParse(notificationData['created_at'].toString());
        if (createdAt != null) {
          final now = DateTime.now();
          final duration = now.difference(createdAt);
          final isExpired = duration.inHours > 24;
          debugPrint(
              '🔚 Post ended check: Auto-expire after 24h - created ${duration.inHours}h ago, isExpired = $isExpired');
          if (isExpired) return true;
        }
      } catch (e) {
        debugPrint('❌ Error checking auto-expire: $e');
      }
    }

    // Default to not ended but log it
    debugPrint(
        '🔚 Post ended check: No end indicator found, assuming NOT ended');
    return false;
  }

  // Handle "Still Happening" action
  Future<void> _handleStillHappeningAction(
      NotificationModel notification) async {
    try {
      // Extract post ID
      int? postId = _extractPostId(notification.data);
      if (postId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cannot find post ID'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('Confirming...'),
            ],
          ),
        ),
      );

      // Call API to confirm "still happening"
      // Note: You'll need to implement this in your API service
      // await NotificationApiService.confirmStillHappening(postId);

      if (mounted) Navigator.pop(context); // Dismiss loading

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Confirmed: Still Happening'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (mounted) Navigator.pop(context); // Dismiss loading
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Handle "Ended" action
  Future<void> _handleEndedAction(NotificationModel notification) async {
    try {
      // Extract post ID
      int? postId = _extractPostId(notification.data);
      if (postId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cannot find post ID'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('Reporting...'),
            ],
          ),
        ),
      );

      // Call API to report "ended"
      // Note: You'll need to implement this in your API service
      // await NotificationApiService.reportEnded(postId);

      if (mounted) Navigator.pop(context); // Dismiss loading

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Reported: Event Ended'),
          backgroundColor: Colors.orange,
        ),
      );
    } catch (e) {
      if (mounted) Navigator.pop(context); // Dismiss loading
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Helper to extract post ID from notification data
  int? _extractPostId(Map<String, dynamic> notificationData) {
    if (notificationData.containsKey('post_id')) {
      return notificationData['post_id'] is String
          ? int.tryParse(notificationData['post_id'])
          : notificationData['post_id'] as int?;
    }
    if (notificationData.containsKey('postId')) {
      return notificationData['postId'] is String
          ? int.tryParse(notificationData['postId'])
          : notificationData['postId'] as int?;
    }
    if (notificationData.containsKey('id')) {
      return notificationData['id'] is String
          ? int.tryParse(notificationData['id'])
          : notificationData['id'] as int?;
    }
    if (notificationData.containsKey('post') &&
        notificationData['post'] is Map) {
      final post = notificationData['post'] as Map<String, dynamic>;
      if (post.containsKey('id')) {
        return post['id'] is String
            ? int.tryParse(post['id'])
            : post['id'] as int?;
      }
    }
    return null;
  }

  Future<void> _checkNotificationStatus() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _notificationsEnabled = prefs.getBool('notifications_enabled') ?? false;
      _showBanner = !_notificationsEnabled;
    });
  }

  Future<void> _enableNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notifications_enabled', true);

    setState(() {
      _showBanner = false;
      _notificationsEnabled = true;
    });
  }

  void _hideBanner() {
    setState(() {
      _showBanner = false;
    });
  }

  Future<void> _markAsUnread(NotificationModel notification) async {
    final currentlyRead = notification.isRead ?? notification.read;
    if (!currentlyRead) return;

    try {
      // Call the backend API to mark as unread
      final success = await NotificationApiService.markNotificationAsUnread(
          notification.id);

      if (success && mounted) {
        setState(() {
          final index =
              notifications.indexWhere((n) => n.id == notification.id);
          if (index != -1) {
            notifications[index] =
                notification.copyWith(read: false, isRead: false);
          }
        });

        // Update notification count via event bus
        _refreshNotificationCount();

        GlobalNotificationService().showSuccess('Marked as unread');
      } else {
        // Fallback to local update if API call fails
        setState(() {
          final index =
              notifications.indexWhere((n) => n.id == notification.id);
          if (index != -1) {
            notifications[index] =
                notification.copyWith(read: false, isRead: false);
          }
        });

        // Update local notification count
        _refreshNotificationCount();

        GlobalNotificationService()
            .showWarning('Marked as unread (local only)');
      }
    } catch (e) {
      debugPrint('Error marking notification as unread: $e');

      // Fallback to local update
      setState(() {
        final index = notifications.indexWhere((n) => n.id == notification.id);
        if (index != -1) {
          notifications[index] =
              notification.copyWith(read: false, isRead: false);
        }
      });

      GlobalNotificationService().showWarning('Marked as unread (local only)');
    }
  }

  Future<void> _deleteNotification(NotificationModel notification) async {
    try {
      // Show confirmation dialog
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Delete Notification'),
          content:
              const Text('Are you sure you want to delete this notification?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete'),
            ),
          ],
        ),
      );

      if (confirm == true) {
        // Call the backend API to delete the notification
        final success =
            await NotificationApiService.deleteNotification(notification.id);

        if (success && mounted) {
          setState(() {
            notifications.removeWhere((n) => n.id == notification.id);
          });

          // Update notification count via event bus
          _refreshNotificationCount();

          GlobalNotificationService().showSuccess('Notification deleted');
        } else {
          // Fallback to local deletion if API call fails
          setState(() {
            notifications.removeWhere((n) => n.id == notification.id);
          });

          // Update local notification count
          _refreshNotificationCount();

          GlobalNotificationService()
              .showWarning('Notification deleted (local only)');
        }
      }
    } catch (e) {
      debugPrint('Error deleting notification: $e');

      // Fallback to local deletion
      setState(() {
        notifications.removeWhere((n) => n.id == notification.id);
      });

      GlobalNotificationService()
          .showWarning('Notification deleted (local only)');
    }
  }

  void _showNotificationOptions(NotificationModel notification) {
    final isRead = notification.isRead ?? notification.read;

    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading:
                  Icon(isRead ? Icons.mark_as_unread : Icons.mark_email_read),
              title: Text(isRead ? 'Mark as unread' : 'Mark as read'),
              onTap: () {
                Navigator.pop(context);
                if (isRead) {
                  _markAsUnread(notification);
                } else {
                  _markAsRead(notification);
                }
              },
            ),
            if (_isFollowRelatedNotification(notification.type))
              ListTile(
                leading: const Icon(Icons.person),
                title: const Text('View profile'),
                onTap: () {
                  Navigator.pop(context);
                  _navigateToUserProfile(notification.data);
                },
              ),
            if (_isPostRelatedNotification(notification.type))
              ListTile(
                leading: const Icon(Icons.article),
                title: const Text('View post'),
                onTap: () {
                  Navigator.pop(context);
                  _navigateToPostDetail(notification.data);
                },
              ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('Delete'),
              onTap: () {
                Navigator.pop(context);
                _deleteNotification(notification);
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _markAllAsRead() async {
    try {
      // Call the backend API to mark all notifications as read
      final success = await NotificationApiService.markAllNotificationsAsRead();

      if (success && mounted) {
        setState(() {
          for (int i = 0; i < notifications.length; i++) {
            notifications[i] =
                notifications[i].copyWith(read: true, isRead: true);
          }
        });

        // Update notification count via event bus (should be 0 after marking all as read)
        _refreshNotificationCount();

        GlobalNotificationService()
            .showSuccess('All notifications marked as read');
      } else {
        // Fallback to local update if API call fails
        setState(() {
          for (int i = 0; i < notifications.length; i++) {
            notifications[i] =
                notifications[i].copyWith(read: true, isRead: true);
          }
        });

        // Update local notification count
        _refreshNotificationCount();

        GlobalNotificationService()
            .showWarning('All notifications marked as read (local only)');
      }
    } catch (e) {
      debugPrint('Error marking all notifications as read: $e');

      // Fallback to local update
      setState(() {
        for (int i = 0; i < notifications.length; i++) {
          notifications[i] =
              notifications[i].copyWith(read: true, isRead: true);
        }
      });

      // Update local notification count
      _refreshNotificationCount();

      GlobalNotificationService()
          .showWarning('All notifications marked as read (local only)');
    }
  }

  void _showAppBarMenu() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.mark_email_read),
              title: const Text('Mark all as read'),
              onTap: () {
                Navigator.pop(context);
                _markAllAsRead();
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('Notification settings'),
              onTap: () {
                Navigator.pop(context);
                // TODO: Navigate to notification settings
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  String _getDateHeader(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final notificationDate = DateTime(date.year, date.month, date.day);

    if (notificationDate == today) {
      return TextStrings.today;
    } else if (notificationDate == yesterday) {
      return TextStrings.yesterday;
    } else {
      return DateFormat('MMM dd, yyyy').format(date);
    }
  }

  Widget _buildEmptyState() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 80,
              color: Colors.grey.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              "Error loading notifications",
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.grey,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _refreshNotifications,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.notifications_none_outlined,
            size: 80,
            color: Colors.grey.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            "No notifications yet",
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.grey,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            "We'll notify you when something arrives",
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationsList() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final filteredNotifications = _getFilteredNotifications();

    if (filteredNotifications.isEmpty) {
      return _buildEmptyState();
    }

    // Group notifications by date
    final groupedNotifications = <String, List<NotificationModel>>{};

    for (var notification in filteredNotifications) {
      final notificationDate = notification.dateTime ?? notification.timestamp;
      final dateHeader = _getDateHeader(notificationDate);
      groupedNotifications.putIfAbsent(dateHeader, () => []);
      groupedNotifications[dateHeader]!.add(notification);
    }

    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: _refreshNotifications,
          child: ListView.builder(
            controller: _scrollController,
            itemCount: groupedNotifications.length +
                (_isLoadingMore || (_isLoading && notifications.isEmpty)
                    ? 1
                    : 0) +
                (!_hasMoreData && notifications.isNotEmpty ? 1 : 0),
            itemBuilder: (context, index) {
              // Show end reached message
              if (!_hasMoreData &&
                  notifications.isNotEmpty &&
                  index ==
                      groupedNotifications.length + (_isLoadingMore ? 1 : 0)) {
                return Container(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.check_circle_outline,
                        size: 16,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'You\'re all caught up!',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                );
              }

              // Show loading indicator at the end
              if (index >= groupedNotifications.length) {
                if (_isLoadingMore) {
                  return Container(
                    padding: const EdgeInsets.all(20),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(width: 12),
                        Text(
                          'Loading more notifications...',
                          style: TextStyle(fontSize: 14, color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                } else {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
              }

              final dateHeader = groupedNotifications.keys.elementAt(index);
              final notificationsForDate = groupedNotifications[dateHeader]!;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Text(
                      dateHeader,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                  ...notificationsForDate.map((notification) =>
                      _buildNotificationItem(notification, isDark)),
                ],
              );
            },
          ),
        ),
        // Show refresh indicator overlay
        if (_isRefreshing)
          Container(
            color: Colors.black.withOpacity(0.1),
            child: const Center(
              child: CircularProgressIndicator(),
            ),
          ),
      ],
    );
  }

  Widget _buildNotificationItem(NotificationModel notification, bool isDark) {
    final isRead = notification.isRead ?? notification.read;
    final message = notification.message ?? notification.body;
    final dateTime = notification.dateTime ?? notification.timestamp;
    final icon = notification.icon ?? Icons.notifications;
    final isFollowNotification =
        _isFollowRelatedNotification(notification.type);
    final isPostRelated = _isPostRelatedNotification(notification.type);

    // Get thumbnail or avatar URL
    String? imageUrl = notification.imageUrl;
    String? thumbnailUrl = _extractThumbnailUrl(notification.data);

    // Use thumbnail if available for post-related notifications, otherwise use avatar
    String? displayImageUrl =
        isPostRelated && thumbnailUrl != null ? thumbnailUrl : imageUrl;

    if (displayImageUrl != null && displayImageUrl.isNotEmpty) {
      displayImageUrl = _getFixedImageUrl(displayImageUrl);
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Dismissible(
        key: Key(notification.id),
        background: Container(
          decoration: BoxDecoration(
            color: Colors.green,
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: const Icon(
            Icons.mark_email_read,
            color: Colors.white,
          ),
        ),
        secondaryBackground: Container(
          decoration: BoxDecoration(
            color: Colors.red,
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: const Icon(
            Icons.delete,
            color: Colors.white,
          ),
        ),
        confirmDismiss: (direction) async {
          if (direction == DismissDirection.startToEnd) {
            if (isRead) {
              _markAsUnread(notification);
            } else {
              _markAsRead(notification);
            }
            return false;
          } else {
            return await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Delete Notification'),
                    content: const Text(
                        'Are you sure you want to delete this notification?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Delete'),
                      ),
                    ],
                  ),
                ) ??
                false;
          }
        },
        onDismissed: (direction) {
          if (direction == DismissDirection.endToStart) {
            _deleteNotification(notification);
          }
        },
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: isRead
                ? Colors.transparent
                : Theme.of(context).colorScheme.primary.withOpacity(0.1),
          ),
          child: Column(
            children: [
              ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: GestureDetector(
                  onTap: isFollowNotification
                      ? () {
                          debugPrint('Avatar tap - navigating to user profile');
                          _navigateToUserProfile(notification.data);
                        }
                      : isPostRelated
                          ? () {
                              debugPrint(
                                  'Avatar tap - navigating to post detail');
                              _navigateToPostDetail(notification.data);
                            }
                          : null,
                  child: Stack(
                    children: [
                      // Use Container with ClipRRect for better thumbnail display
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          borderRadius:
                              BorderRadius.circular(isPostRelated ? 8 : 24),
                          color: isRead
                              ? Colors.grey.withOpacity(0.3)
                              : Theme.of(context)
                                  .colorScheme
                                  .primary
                                  .withOpacity(0.2),
                        ),
                        child: ClipRRect(
                          borderRadius:
                              BorderRadius.circular(isPostRelated ? 8 : 24),
                          child: (displayImageUrl != null &&
                                  displayImageUrl.isNotEmpty)
                              ? Image.network(
                                  displayImageUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    // Fallback to icon if image fails to load
                                    return Icon(
                                      icon,
                                      color: isRead
                                          ? Colors.grey
                                          : _getIconColor(
                                              notification.type, context),
                                      size: 20,
                                    );
                                  },
                                )
                              : Icon(
                                  icon,
                                  color: isRead
                                      ? Colors.grey
                                      : _getIconColor(
                                          notification.type, context),
                                  size: 20,
                                ),
                        ),
                      ),
                      // Show notification type icon overlay
                      if (isFollowNotification &&
                          displayImageUrl != null &&
                          displayImageUrl.isNotEmpty)
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            width: 16,
                            height: 16,
                            decoration: BoxDecoration(
                              color: _getIconColor(notification.type, context),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 1),
                            ),
                            child: Icon(
                              icon,
                              size: 10,
                              color: Colors.white,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                title: notification.title.isNotEmpty
                    ? Text(
                        notification.title,
                        style: TextStyle(
                          fontWeight:
                              isRead ? FontWeight.normal : FontWeight.w600,
                          fontSize: 14,
                          color: isRead ? Colors.grey : null,
                        ),
                      )
                    : null,
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      message,
                      style: TextStyle(
                        color: isRead ? Colors.grey : null,
                        fontWeight:
                            isRead ? FontWeight.normal : FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatDateTime(dateTime),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey,
                          ),
                    ),
                  ],
                ),
                trailing: !isRead
                    ? Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      )
                    : null,
                onTap: () {
                  // Debug logging for notification taps
                  debugPrint('=== NOTIFICATION TAP DEBUG ===');
                  debugPrint('Notification type: ${notification.type}');
                  debugPrint('Notification data: ${notification.data}');
                  debugPrint('Is follow notification: $isFollowNotification');
                  debugPrint('Is post related: $isPostRelated');
                  debugPrint(
                      'Notification message: ${notification.message ?? notification.body}');
                  debugPrint('==============================');

                  _markAsRead(notification);
                  if (isFollowNotification) {
                    debugPrint('Navigating to user profile');
                    _navigateToUserProfile(notification.data);
                  } else if (isPostRelated) {
                    debugPrint('Navigating to post detail');
                    _navigateToPostDetail(notification.data);
                  } else {
                    debugPrint(
                        'No navigation action for this notification type');
                  }
                },
                onLongPress: () => _showNotificationOptions(notification),
              ),
              // Add action buttons for post-related notifications
              if (isPostRelated) _buildNotificationActionButtons(notification),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return DateFormat('MMM dd').format(dateTime);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? ThemeConstants.darkBackgroundColor
          : ThemeConstants.lightBackgroundColor,
      appBar: AppBar(
        backgroundColor: isDark
            ? ThemeConstants.darkBackgroundColor
            : ThemeConstants.lightBackgroundColor,
        elevation: 0,
        title: const Text(
          TextStrings.notifications,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 24,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshNotifications,
          ),
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: _showAppBarMenu,
          ),
        ],
      ),
      body: Column(
        children: [
          if (_showBanner) _buildNotificationBanner(),
          _buildFilterBar(),
          Expanded(child: _buildNotificationsList()),
        ],
      ),
    );
  }

  Widget _buildNotificationBanner() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      height: _showBanner ? null : 0,
      child: Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              Icons.notifications_none,
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Enable Notifications',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                  Text(
                    'Stay updated with the latest news and updates',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: _enableNotifications,
              child: Text(
                'Enable',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            IconButton(
              onPressed: _hideBanner,
              icon: Icon(
                Icons.close,
                size: 20,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      height: 50, // Reduced height for more compact look
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: NotificationFilter.values.map((filter) {
          final isSelected = _selectedFilter == filter;
          return Padding(
            padding: const EdgeInsets.only(
                right: 8), // Reduced spacing between filters
            child: Material(
              borderRadius: BorderRadius.circular(16), // Smaller border radius
              color: isSelected
                  ? Theme.of(context).colorScheme.primary
                  : Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () {
                  setState(() {
                    _selectedFilter = filter;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6), // Reduced padding
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context)
                              .colorScheme
                              .outline
                              .withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        filter.label,
                        style: TextStyle(
                          color: isSelected
                              ? Theme.of(context).colorScheme.onPrimary
                              : Theme.of(context).colorScheme.onSurface,
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.normal,
                          fontSize: 11, // Smaller font size
                        ),
                      ),
                      if (_getFilterCount(filter) > 0) ...[
                        const SizedBox(width: 4), // Reduced spacing
                        Container(
                          constraints: const BoxConstraints(
                            minWidth: 16,
                            minHeight: 16,
                          ),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Theme.of(context).colorScheme.onPrimary
                                : Theme.of(context).colorScheme.primary,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            // Explicitly center the text
                            child: Text(
                              '${_getFilterCount(filter)}',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: isSelected
                                    ? Theme.of(context).colorScheme.primary
                                    : Theme.of(context).colorScheme.onPrimary,
                                fontWeight: FontWeight.w600,
                                fontSize: 9, // Smaller badge text
                                height: 1.0,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  /// Refresh notification count from server and notify event bus
  Future<void> _refreshNotificationCount() async {
    try {
      final count = await NotificationApiService.getUnreadNotificationCount();
      NotificationEventBus().notifyUnreadCountChanged(count);
      debugPrint('🔔 NotificationsPage: Refreshed unread count to $count');
    } catch (e) {
      debugPrint('❌ Error refreshing notification count: $e');
      // Calculate local unread count as fallback
      final localCount =
          notifications.where((n) => !(n.isRead ?? n.read)).length;
      NotificationEventBus().notifyUnreadCountChanged(localCount);
      debugPrint(
          '🔔 NotificationsPage: Using local count fallback: $localCount');
    }
  }
}
