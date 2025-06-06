import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../action_confirmation_service.dart';
import '../database/notification_database_service.dart';
import '../api/notification_api_service.dart';
import 'notification_types.dart';
import '../../ui/pages/friends/friend_request_dialog.dart';
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
        },
      );

      _localNotificationsInitialized = true;
      debugPrint('✅ Local notifications initialized successfully');
    } catch (e) {
      debugPrint('❌ Error initializing local notifications: $e');
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

    // For background notifications, we typically just store them or show local notifications
    await _showLocalNotification(notificationData);
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
      // Show local notification for foreground
      debugPrint('👥 Showing local notification...');
      await _showLocalNotification(data);
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
      await _showLocalNotification(data);
      _showSnackBar('${data.fromUserName} accepted your friend request! 🎉');
    }
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
      await _showLocalNotification(data);
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
      await _showLocalNotification(data);
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
      await _showLocalNotification(data);
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
      await _showLocalNotification(data);
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
      await _showLocalNotification(data);
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
      await _showLocalNotification(data);
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
      await _showLocalNotification(data);
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
