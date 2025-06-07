import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../action_confirmation_service.dart';
import '../database/notification_database_service.dart';
import '../api/notification_api_service.dart';
import 'notification_types.dart';
import '../../ui/pages/friends/friend_request_dialog.dart';
import '../../ui/profile/other_user_profile_page.dart';
import '../../routes/app_routes.dart';
import '../utils/navigation_service.dart';

/// Comprehensive notification handler for all app notification types
class NotificationHandler {
  static final NotificationHandler _instance = NotificationHandler._internal();
  factory NotificationHandler() => _instance;
  NotificationHandler._internal();

  static GlobalKey<NavigatorState>? _navigatorKey;
  static bool _initialized = false;
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  static bool _localNotificationsInitialized = false;

  /// Initialize the notification handler
  static Future<void> initialize(GlobalKey<NavigatorState> navigatorKey) async {
    _navigatorKey = navigatorKey;
    _initialized = true;
    debugPrint('🔧 NotificationHandler: Initialized with navigator key');

    // Initialize local notifications if not already done
    if (!_localNotificationsInitialized) {
      await _initializeLocalNotifications();
    }
  }

  /// Initialize local notifications
  static Future<void> _initializeLocalNotifications() async {
    try {
      debugPrint('🔧 Initializing local notifications...');

      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('ic_notification');

      const DarwinInitializationSettings initializationSettingsiOS =
          DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const InitializationSettings initializationSettings =
          InitializationSettings(
        android: initializationSettingsAndroid,
        iOS: initializationSettingsiOS,
      );

      await _localNotifications.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          debugPrint('📱 Local notification tapped: ${response.payload}');
          _handleNotificationAction(response);
        },
      );

      // Create notification channels for Android
      await _createNotificationChannels();

      _localNotificationsInitialized = true;
      debugPrint('✅ Local notifications initialized successfully');
    } catch (e) {
      debugPrint('❌ Error initializing local notifications: $e');
    }
  }

  /// Create notification channels for Android
  static Future<void> _createNotificationChannels() async {
    if (_localNotifications.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>() !=
        null) {
      // Messages channel
      await _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()!
          .createNotificationChannel(
            const AndroidNotificationChannel(
              'messages',
              'Messages',
              description: 'Notifications for new messages',
              importance: Importance.high,
              enableVibration: true,
              enableLights: true,
              ledColor: Colors.blue,
            ),
          );

      debugPrint('📱 Android notification channels created');
    }
  }

  /// Handle notification action responses
  static void _handleNotificationAction(NotificationResponse response) {
    final actionId = response.actionId;
    final payload = response.payload;

    debugPrint('🎯 Notification action: $actionId, Payload: $payload');

    switch (actionId) {
      case 'reply':
        // Handle reply action
        _handleReplyAction(payload);
        break;
      case 'mark_read':
        // Handle mark as read action
        _handleMarkReadAction(payload);
        break;
      default:
        // Handle regular tap
        if (_initialized && _navigatorKey?.currentContext != null) {
          if (payload != null && payload.contains('conversation_id')) {
            // Navigate to specific conversation
            final conversationId = _extractConversationId(payload);
            if (conversationId != null) {
              NavigationService().navigateTo('/messages/$conversationId');
            } else {
              NavigationService().navigateTo(AppRoutes.messages);
            }
          } else {
            NavigationService().navigateTo(AppRoutes.notifications);
          }
        }
        break;
    }
  }

  /// Handle reply action
  static void _handleReplyAction(String? payload) {
    debugPrint('💬 Reply action triggered');
    // TODO: Implement quick reply functionality
    // For now, navigate to the conversation
    if (payload != null && payload.contains('conversation_id')) {
      final conversationId = _extractConversationId(payload);
      if (conversationId != null) {
        NavigationService().navigateTo('/messages/$conversationId');
      }
    }
  }

  /// Handle mark as read action
  static void _handleMarkReadAction(String? payload) {
    debugPrint('✅ Mark as read action triggered');
    // TODO: Implement mark as read functionality
    // This would typically make an API call to mark the message as read
  }

  /// Extract conversation ID from payload
  static String? _extractConversationId(String payload) {
    try {
      // Assuming payload is JSON-like or contains conversation_id
      final regex = RegExp(r'conversation_id["\s]*[:=]["\s]*([^"\s,}]+)');
      final match = regex.firstMatch(payload);
      return match?.group(1);
    } catch (e) {
      debugPrint('❌ Error extracting conversation ID: $e');
      return null;
    }
  }

  /// Handle incoming notification when app is in foreground
  static Future<void> handleForegroundNotification(
      RemoteMessage message) async {
    debugPrint(
        '🔥 === NOTIFICATION HANDLER: handleForegroundNotification STARTED ===');
    debugPrint(
        '📱 Handling foreground notification: ${message.notification?.title}');
    debugPrint('📱 Message ID: ${message.messageId}');
    debugPrint('📱 Message data: ${message.data}');
    debugPrint('📱 Handler initialized: $_initialized');
    debugPrint('📱 Navigator key exists: ${_navigatorKey != null}');
    debugPrint(
        '📱 Navigator context exists: ${_navigatorKey?.currentContext != null}');

    final notificationData = _parseNotificationData(message);
    if (notificationData == null) {
      debugPrint('❌ Failed to parse notification data');
      return;
    }

    debugPrint(
        '✅ Notification data parsed successfully: ${notificationData.type}');
    debugPrint('🔄 Calling _processNotification...');
    await _processNotification(notificationData, isFromTap: false);
    debugPrint(
        '✅ === NOTIFICATION HANDLER: handleForegroundNotification COMPLETED ===');
  }

  /// Handle notification tap (when user taps on notification)
  static Future<void> handleNotificationTap(RemoteMessage message) async {
    debugPrint('👆 Handling notification tap: ${message.notification?.title}');

    final notificationData = _parseNotificationData(message);
    if (notificationData == null) return;

    await _processNotification(notificationData, isFromTap: true);
  }

  /// Handle background notification
  static Future<void> handleBackgroundNotification(
      RemoteMessage message) async {
    debugPrint(
        '🔔 Handling background notification: ${message.notification?.title}');

    final notificationData = _parseNotificationData(message);
    if (notificationData == null) return;

    // For background notifications, show local notifications with action buttons for messages
    if (notificationData.type == NotificationType.message) {
      await _showMessageLocalNotification(
          notificationData as MessageNotificationData);
    } else {
      await _showLocalNotification(notificationData);
    }
  }

  /// Show local notification for messages with action buttons (background only)
  static Future<void> _showMessageLocalNotification(
      MessageNotificationData data) async {
    try {
      debugPrint(
          '📱 Showing background message local notification with actions');

      // Ensure local notifications are initialized
      if (!_localNotificationsInitialized) {
        await _initializeLocalNotifications();
      }

      // Create payload with conversation data
      final payload = {
        'type': 'message',
        'conversation_id': data.conversationId,
        'message_id': data.messageId,
        'from_user_id': data.fromUserId,
      };

      // Create notification body based on message type
      String notificationBody = data.body;
      if (data.messageType == 'image') {
        notificationBody = '📷 Sent a photo';
      } else if (data.messageType == 'file') {
        notificationBody = '📎 Sent a file';
      }

      // Generate unique notification ID based on conversation to enable grouping
      final notificationId = data.conversationId.hashCode.abs();
      final tag = 'message_${data.messageId}';

      final AndroidNotificationDetails androidPlatformChannelSpecifics =
          AndroidNotificationDetails(
        'messages', // Use the correct channel ID
        'Messages',
        channelDescription: 'Notifications for new messages',
        importance: Importance.high,
        priority: Priority.high,
        groupKey: 'message_notifications',
        tag: tag, // Unique tag per message
        setAsGroupSummary: false,
        enableVibration: true,
        enableLights: true,
        icon: 'ic_notification',
        actions: const [
          AndroidNotificationAction(
            'reply',
            'Reply',
            icon: DrawableResourceAndroidBitmap('ic_reply'),
            inputs: [
              AndroidNotificationActionInput(
                label: 'Type a message...',
                allowFreeFormInput: true,
              ),
            ],
          ),
          AndroidNotificationAction(
            'mark_read',
            'Mark as Read',
            icon: DrawableResourceAndroidBitmap('ic_check'),
          ),
        ],
      );

      const DarwinNotificationDetails iosPlatformChannelSpecifics =
          DarwinNotificationDetails(
        categoryIdentifier: 'MESSAGE_CATEGORY',
        threadIdentifier: 'messages',
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      await _localNotifications.show(
        notificationId,
        '${data.fromUserName}', // Show sender name as title
        notificationBody,
        NotificationDetails(
          android: androidPlatformChannelSpecifics,
          iOS: iosPlatformChannelSpecifics,
        ),
        payload: payload.toString(),
      );

      debugPrint('✅ Background message local notification shown with actions');
      debugPrint('📱 Notification ID: $notificationId, Tag: $tag');
    } catch (e) {
      debugPrint('❌ Error showing background message local notification: $e');
    }
  }

  /// Parse notification data from Firebase message
  static NotificationData? _parseNotificationData(RemoteMessage message) {
    debugPrint('🔍 === PARSING NOTIFICATION DATA ===');
    try {
      final data = Map<String, dynamic>.from(message.data);
      data['title'] = message.notification?.title ?? 'Notification';
      data['body'] = message.notification?.body ?? '';
      data['timestamp'] = DateTime.now().toIso8601String();

      debugPrint('🔍 Raw data: $data');
      debugPrint('🔍 Notification type: ${data['type']}');

      final parsedData = NotificationData.fromMap(data);
      debugPrint('✅ Successfully parsed notification data: ${parsedData.type}');
      return parsedData;
    } catch (e) {
      debugPrint('❌ Error parsing notification data: $e');
      debugPrint('❌ Stack trace: ${StackTrace.current}');
      return null;
    }
  }

  /// Process notification based on type
  static Future<void> _processNotification(
    NotificationData notificationData, {
    required bool isFromTap,
  }) async {
    debugPrint('🔄 === PROCESSING NOTIFICATION ===');
    debugPrint('🔄 Type: ${notificationData.type}');
    debugPrint('🔄 Title: ${notificationData.title}');
    debugPrint('🔄 Body: ${notificationData.body}');
    debugPrint('🔄 IsFromTap: $isFromTap');
    debugPrint('🔄 Initialized: $_initialized');
    debugPrint('🔄 Navigator key: ${_navigatorKey != null}');
    debugPrint('🔄 Current context: ${_navigatorKey?.currentContext != null}');

    if (!_initialized || _navigatorKey?.currentContext == null) {
      debugPrint(
          '⚠️ NotificationHandler not initialized or no context available');
      return;
    }

    debugPrint('✅ Validation passed, saving notification to database...');
    // Save notification to database for history
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      await NotificationDatabaseService.saveNotification(
        userId: currentUser.uid,
        notificationData: notificationData,
        rawData: notificationData.toMap(),
      );

      // Also mark as read in Django backend if notification has an ID
      if (notificationData.toMap().containsKey('notification_id')) {
        final notificationId = notificationData.toMap()['notification_id'];
        if (notificationId != null) {
          await NotificationApiService.markNotificationAsRead(notificationId);
        }
      }
    }

    debugPrint('🔄 Processing notification type: ${notificationData.type}');

    // If tapped, navigate to notifications page for all notification types
    if (isFromTap) {
      debugPrint('👆 Notification tapped - navigating to notifications page');
      NavigationService().navigateTo(AppRoutes.notifications);
      return;
    }

    // For non-tap events (foreground notifications), handle type-specific logic
    switch (notificationData.type) {
      case NotificationType.friendRequest:
        await _handleFriendRequest(
            notificationData as FriendRequestNotificationData, isFromTap);
        break;
      case NotificationType.friendRequestAccepted:
        await _handleFriendRequestAccepted(
            notificationData as FriendRequestAcceptedNotificationData,
            isFromTap);
        break;
      case NotificationType.newFollower:
        await _handleNewFollower(
            notificationData as NewFollowerNotificationData, isFromTap);
        break;
      case NotificationType.unfollowed:
        await _handleUnfollowed(
            notificationData as UnfollowedNotificationData, isFromTap);
        break;
      case NotificationType.newEvent:
        await _handleNewEvent(
            notificationData as NewEventNotificationData, isFromTap);
        break;
      case NotificationType.stillThere:
        await _handleStillThere(
            notificationData as StillThereNotificationData, isFromTap);
        break;
      case NotificationType.eventUpdate:
        await _handleEventUpdate(
            notificationData as EventUpdateNotificationData, isFromTap);
        break;
      case NotificationType.eventCancelled:
        await _handleEventCancelled(
            notificationData as EventCancelledNotificationData, isFromTap);
        break;
      case NotificationType.nearbyEvent:
        await _handleNearbyEvent(
            notificationData as NearbyEventNotificationData, isFromTap);
        break;
      case NotificationType.reminder:
        await _handleReminder(
            notificationData as ReminderNotificationData, isFromTap);
        break;
      case NotificationType.system:
        await _handleSystemNotification(
            notificationData as SystemNotificationData, isFromTap);
        break;
      case NotificationType.message:
        await _handleMessage(
            notificationData as MessageNotificationData, isFromTap);
        break;
    }
  }

  /// Handle friend request notification
  static Future<void> _handleFriendRequest(
    FriendRequestNotificationData data,
    bool isFromTap,
  ) async {
    debugPrint('👥 === HANDLING FRIEND REQUEST ===');
    debugPrint('👥 From user: ${data.fromUserName} (${data.fromUserId})');
    debugPrint('👥 Request ID: ${data.requestId}');
    debugPrint('👥 IsFromTap: $isFromTap');

    if (isFromTap) {
      // Show friend request dialog
      debugPrint('👥 Showing friend request dialog...');
      await _showFriendRequestDialog(data);
    } else {
      // For foreground notifications, only show snackbar (push notification already shown by system)
      _showSnackBar('${data.fromUserName} wants to be your friend! 👥');
    }
    debugPrint('✅ Friend request handling completed');
  }

  /// Handle friend request accepted notification
  static Future<void> _handleFriendRequestAccepted(
    FriendRequestAcceptedNotificationData data,
    bool isFromTap,
  ) async {
    if (isFromTap) {
      // Navigate to messages page (friends functionality)
      NavigationService().navigateTo(AppRoutes.messages);
    } else {
      // For foreground notifications, only show snackbar (push notification already shown by system)
      _showSnackBar('${data.fromUserName} accepted your friend request! 🎉');
    }
  }

  /// Handle new follower notification
  static Future<void> _handleNewFollower(
    NewFollowerNotificationData data,
    bool isFromTap,
  ) async {
    debugPrint('👤 === HANDLING NEW FOLLOWER ===');
    debugPrint(
        '👤 Follower: ${data.followerUserName} (${data.followerUserId})');
    debugPrint('👤 IsFromTap: $isFromTap');

    if (isFromTap) {
      // Navigate to the follower's profile by using MaterialPageRoute directly
      if (_navigatorKey?.currentContext != null) {
        Navigator.push(
          _navigatorKey!.currentContext!,
          MaterialPageRoute(
            builder: (context) => OtherUserProfilePage(
              userData: {
                'id': int.parse(data.followerUserId),
                'username': data.followerUserName,
                'profileImage': data.followerUserAvatar,
                'name': data.followerUserName,
              },
            ),
          ),
        );
      }
    } else {
      // For foreground notifications, only show snackbar (push notification already shown by system)
      _showSnackBar('${data.followerUserName} started following you! 👤');
    }
    debugPrint('✅ New follower handling completed');
  }

  /// Handle unfollowed notification
  static Future<void> _handleUnfollowed(
    UnfollowedNotificationData data,
    bool isFromTap,
  ) async {
    debugPrint('💔 === HANDLING UNFOLLOWED ===');
    debugPrint(
        '💔 Unfollower: ${data.unfollowerUserName} (${data.unfollowerUserId})');
    debugPrint('💔 IsFromTap: $isFromTap');

    if (isFromTap) {
      // Navigate to the unfollower's profile by using MaterialPageRoute directly
      if (_navigatorKey?.currentContext != null) {
        Navigator.push(
          _navigatorKey!.currentContext!,
          MaterialPageRoute(
            builder: (context) => OtherUserProfilePage(
              userData: {
                'id': int.parse(data.unfollowerUserId),
                'username': data.unfollowerUserName,
                'profileImage': data.unfollowerUserAvatar,
                'name': data.unfollowerUserName,
              },
            ),
          ),
        );
      }
    } else {
      // For foreground notifications, only show snackbar (push notification already shown by system)
      _showSnackBar('${data.unfollowerUserName} unfollowed you');
    }
    debugPrint('✅ Unfollowed handling completed');
  }

  /// Handle new event notification
  static Future<void> _handleNewEvent(
    NewEventNotificationData data,
    bool isFromTap,
  ) async {
    if (isFromTap) {
      // Navigate to map or home page (event detail not implemented yet)
      NavigationService().navigateTo(AppRoutes.map);
    } else {
      // For foreground notifications, only show snackbar (push notification already shown by system)
      _showSnackBar('New event: ${data.eventTitle}');
    }
  }

  /// Handle still there confirmation notification
  static Future<void> _handleStillThere(
    StillThereNotificationData data,
    bool isFromTap,
  ) async {
    if (isFromTap) {
      // Show action confirmation dialog
      await ActionConfirmationService.processNotification(
        data: data.toMap(),
        title: data.title,
        body: data.body,
      );
    } else {
      // For foreground notifications, only show snackbar (push notification already shown by system)
      _showSnackBar('${data.title}: ${data.body}');
    }
  }

  /// Handle event update notification
  static Future<void> _handleEventUpdate(
    EventUpdateNotificationData data,
    bool isFromTap,
  ) async {
    if (isFromTap) {
      NavigationService().navigateTo(AppRoutes.map);
    } else {
      // For foreground notifications, only show snackbar (push notification already shown by system)
      _showSnackBar('Event "${data.eventTitle}" has been updated');
    }
  }

  /// Handle event cancelled notification
  static Future<void> _handleEventCancelled(
    EventCancelledNotificationData data,
    bool isFromTap,
  ) async {
    if (isFromTap) {
      _showSnackBar(
          'Event "${data.eventTitle}" has been cancelled: ${data.cancellationReason}');
    } else {
      // For foreground notifications, only show snackbar (push notification already shown by system)
      _showSnackBar(
          'Event "${data.eventTitle}" has been cancelled: ${data.cancellationReason}');
    }
  }

  /// Handle nearby event notification
  static Future<void> _handleNearbyEvent(
    NearbyEventNotificationData data,
    bool isFromTap,
  ) async {
    if (isFromTap) {
      NavigationService().navigateTo(AppRoutes.map);
    } else {
      // For foreground notifications, only show snackbar (push notification already shown by system)
      _showSnackBar('New event nearby: ${data.eventTitle}');
    }
  }

  /// Handle reminder notification
  static Future<void> _handleReminder(
    ReminderNotificationData data,
    bool isFromTap,
  ) async {
    if (isFromTap) {
      switch (data.reminderType) {
        case 'event_starting':
          NavigationService().navigateTo(AppRoutes.map);
          break;
        case 'friend_birthday':
          NavigationService().navigateTo(AppRoutes.messages);
          break;
        default:
          _showSnackBar(data.body);
      }
    } else {
      // For foreground notifications, only show snackbar (push notification already shown by system)
      _showSnackBar('Reminder: ${data.body}');
    }
  }

  /// Handle system notification
  static Future<void> _handleSystemNotification(
    SystemNotificationData data,
    bool isFromTap,
  ) async {
    if (isFromTap) {
      if (data.actionUrl != null) {
        // Handle system notification action
        _showSnackBar(data.body);
      }
    } else {
      // For foreground notifications, only show snackbar (push notification already shown by system)
      _showSnackBar('System: ${data.body}');
    }
  }

  /// Handle message notification
  static Future<void> _handleMessage(
    MessageNotificationData data,
    bool isFromTap,
  ) async {
    debugPrint('💬 === HANDLING MESSAGE NOTIFICATION ===');
    debugPrint('💬 From: ${data.fromUserName} (${data.fromUserId})');
    debugPrint('💬 Conversation: ${data.conversationId}');
    debugPrint('💬 Message Type: ${data.messageType}');
    debugPrint('💬 Message ID: ${data.messageId}');
    debugPrint('💬 IsFromTap: $isFromTap');

    if (isFromTap) {
      // Navigate to messages page and specific conversation
      if (data.conversationId.isNotEmpty) {
        NavigationService().navigateTo('/messages/${data.conversationId}');
      } else {
        NavigationService().navigateTo(AppRoutes.messages);
      }
    } else {
      // For foreground notifications, only show snackbar (FCM system notification already shown)
      // Don't show local notification to avoid duplicates
      String notificationBody = data.body;
      if (data.messageType == 'image') {
        notificationBody = '📷 Sent a photo';
      } else if (data.messageType == 'file') {
        notificationBody = '📎 Sent a file';
      }
      _showSnackBar('${data.fromUserName}: $notificationBody');
    }
  }

  /// Show friend request dialog
  static Future<void> _showFriendRequestDialog(
      FriendRequestNotificationData data) async {
    final context = _navigatorKey?.currentContext;
    if (context == null) return;

    await showDialog(
      context: context,
      builder: (context) => FriendRequestDialog(
        fromUserId: data.fromUserId,
        fromUserName: data.fromUserName,
        fromUserAvatar: data.fromUserAvatar,
        requestId: data.requestId,
      ),
    );
  }

  /// Show local notification
  static Future<void> _showLocalNotification(NotificationData data) async {
    try {
      debugPrint('📱 Showing local notification: ${data.title}');

      // Ensure local notifications are initialized
      if (!_localNotificationsInitialized) {
        debugPrint(
            '⚠️ Local notifications not initialized, initializing now...');
        await _initializeLocalNotifications();
      }

      // Android notification details
      const AndroidNotificationDetails androidNotificationDetails =
          AndroidNotificationDetails(
        'firebase_notifications',
        'Firebase Notifications',
        channelDescription: 'Notifications received from Firebase',
        importance: Importance.max,
        priority: Priority.high,
        showWhen: true,
        icon: 'ic_notification',
      );

      // iOS notification details
      const DarwinNotificationDetails iosNotificationDetails =
          DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const NotificationDetails notificationDetails = NotificationDetails(
        android: androidNotificationDetails,
        iOS: iosNotificationDetails,
      );

      // Show the notification using the initialized plugin
      await _localNotifications.show(
        DateTime.now().millisecondsSinceEpoch ~/ 1000, // Unique ID
        data.title,
        data.body,
        notificationDetails,
        payload: data.toMap().toString(),
      );

      debugPrint('✅ Local notification shown successfully');
    } catch (e) {
      debugPrint('❌ Error showing local notification: $e');
      debugPrint('❌ Stack trace: ${StackTrace.current}');
    }
  }

  /// Show snackbar message
  static void _showSnackBar(String message) {
    final context = _navigatorKey?.currentContext;
    if (context == null) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  /// Test method to simulate different notification types
  static Future<void> testNotification(NotificationType type) async {
    late NotificationData testData;

    switch (type) {
      case NotificationType.friendRequest:
        testData = FriendRequestNotificationData(
          fromUserId: 'test_user_123',
          fromUserName: 'John Doe',
          fromUserAvatar: 'https://via.placeholder.com/100',
          requestId: 'req_123',
          title: 'Friend Request',
          body: 'John Doe wants to be your friend',
          timestamp: DateTime.now(),
        );
        break;
      case NotificationType.newEvent:
        testData = NewEventNotificationData(
          eventId: 'event_123',
          eventTitle: 'Test Event',
          eventDescription: 'This is a test event',
          eventLocation: 'Test Location',
          eventImageUrl: 'https://via.placeholder.com/300x200',
          eventDate: DateTime.now().add(const Duration(hours: 2)),
          creatorUserId: 'creator_123',
          creatorUserName: 'Event Creator',
          title: 'New Event Nearby',
          body: 'Test Event is happening near you',
          timestamp: DateTime.now(),
        );
        break;
      case NotificationType.stillThere:
        testData = StillThereNotificationData(
          eventId: 'event_123',
          eventTitle: 'Test Event',
          eventImageUrl: 'https://via.placeholder.com/300x200',
          confirmationId: 'conf_123',
          originalEventDate: DateTime.now().subtract(const Duration(hours: 1)),
          title: 'Still There?',
          body: 'Is this event still happening?',
          timestamp: DateTime.now(),
        );
        break;
      default:
        return;
    }

    await _processNotification(testData, isFromTap: true);
  }
}
