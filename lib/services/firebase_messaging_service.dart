import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';
import 'notifications/notification_handler.dart';
import 'notifications/fcm_token_service.dart';
import 'utils/navigation_service.dart';
import '../routes/app_routes.dart';

class FirebaseMessagingService {
  static final FirebaseMessaging _firebaseMessaging =
      FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  static final FCMTokenService _fcmTokenService = FCMTokenService();

  // Add initialization guard to prevent multiple listener setups
  static bool _isInitialized = false;

  static Future<void> initialize() async {
    // Prevent multiple initialization
    if (_isInitialized) {
      print(
          '🔄 FirebaseMessagingService already initialized, skipping duplicate setup');
      return;
    }

    print('🚀 Initializing FirebaseMessagingService for the first time...');
    // Request permission for notifications with more explicit approach
    NotificationSettings settings = await _firebaseMessaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    if (kDebugMode) {
      print('User granted permission: ${settings.authorizationStatus}');
    }

    // Check if permission was granted
    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('✅ Notification permissions granted');
    } else if (settings.authorizationStatus ==
        AuthorizationStatus.provisional) {
      print('⚠️ Provisional notification permissions granted');
    } else {
      print('❌ Notification permissions denied');
    }

    // Initialize local notifications
    await _initializeLocalNotifications();

    // Initialize FCM token service
    await _fcmTokenService.initialize();

    // Configure foreground message handler with enhanced debugging
    print('🔄 Setting up foreground message listener...');
    print('🔄 Firebase Messaging instance: ${_firebaseMessaging.hashCode}');
    print('🔄 Setting onMessage listener...');

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('📱 ===== FOREGROUND MESSAGE RECEIVED =====');
      print('📱 Message ID: ${message.messageId}');
      print('📱 From: ${message.from}');
      print('📱 CollapseKey: ${message.collapseKey}');
      print('📱 Category: ${message.category}');
      print('📱 Data: ${message.data}');
      print('📱 Notification Title: ${message.notification?.title}');
      print('📱 Notification Body: ${message.notification?.body}');
      print('📱 TTL: ${message.ttl}');
      print('📱 Sent Time: ${message.sentTime}');
      print('📱 ========================================');
      _handleForegroundMessage(message);
    }, onError: (error) {
      print('❌ FOREGROUND MESSAGE ERROR: $error');
    });

    // Configure background message handler
    print('🔄 Setting up background message handler...');
    FirebaseMessaging.onBackgroundMessage(_handleBackgroundMessage);

    // Configure notification tap handler
    print('🔄 Setting up notification tap handler...');
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('🎯 === onMessageOpenedApp TRIGGERED ===');
      print('🎯 User tapped notification while app was in background');
      print('🎯 Message ID: ${message.messageId}');
      print('🎯 Data: ${message.data}');
      print(
          '🎯 Android Click Action: ${message.notification?.android?.clickAction}');
      print('🎯 Calling _handleNotificationTap...');
      _handleNotificationTap(message);
    }, onError: (error) {
      print('❌ onMessageOpenedApp ERROR: $error');
    });

    // Handle notification tap when app is terminated
    print('🔄 Checking for initial message (app was terminated)...');
    RemoteMessage? initialMessage =
        await _firebaseMessaging.getInitialMessage();
    if (initialMessage != null) {
      print('🎯 === INITIAL MESSAGE FOUND ===');
      print('🎯 App was opened from notification while terminated');
      print('🎯 Message ID: ${initialMessage.messageId}');
      print('🎯 Data: ${initialMessage.data}');
      print('🎯 Calling _handleNotificationTap...');
      _handleNotificationTap(initialMessage);
    } else {
      print('🔄 No initial message found');
    }

    // Mark as initialized to prevent duplicate setups
    _isInitialized = true;
    print('✅ FirebaseMessagingService initialization completed');
  }

  static Future<void> _initializeLocalNotifications() async {
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
      onDidReceiveNotificationResponse: _onNotificationResponse,
    );

    // Create notification channel for Android
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        'messages',
        'Messages',
        description: 'Notifications for new messages',
        importance: Importance.high,
      );

      await _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);
    }
  }

  static void _onNotificationResponse(NotificationResponse response) {
    final payload = response.payload;
    if (payload != null) {
      final data = jsonDecode(payload);
      debugPrint('📱 Local notification tapped: ${data['title']}');

      // Handle local notification taps directly through NavigationService
      // to avoid creating duplicate RemoteMessage objects
      if (data.containsKey('conversation_id')) {
        NavigationService().navigateTo('/messages/${data['conversation_id']}');
      } else if (data.containsKey('route')) {
        NavigationService().navigateTo(data['route']);
      } else {
        NavigationService().navigateTo(AppRoutes.notifications);
      }
    }
  }

  static Future<void> _handleForegroundMessage(RemoteMessage message) async {
    print(
        '🎯 _handleForegroundMessage called with messageId: ${message.messageId}');
    print('🎯 Message data: ${message.data}');
    print(
        '🎯 Message notification: ${message.notification?.title} - ${message.notification?.body}');

    if (kDebugMode) {
      print('Handling foreground message: ${message.messageId}');
    }

    // Use the comprehensive NotificationHandler for foreground messages
    await NotificationHandler.handleForegroundNotification(message);
  }

  static void _handleNotificationTap(RemoteMessage message) async {
    print('🔥 === NOTIFICATION TAP DETECTED ===');
    print('🔥 Message ID: ${message.messageId}');
    print('🔥 Data: ${message.data}');
    print(
        '🔥 Notification: ${message.notification?.title} - ${message.notification?.body}');
    print('🔥 About to call NotificationHandler.handleNotificationTap...');

    if (kDebugMode) {
      print('Notification tapped: ${message.messageId}');
    }

    // Use the comprehensive NotificationHandler for notification taps
    await NotificationHandler.handleNotificationTap(message);
    print('🔥 === NOTIFICATION TAP HANDLING COMPLETED ===');
  }

  static void setOnNotificationTap(
      Function(String, String, Map<String, dynamic>) callback) {
    // This method is kept for backward compatibility but notifications
    // are now handled by the comprehensive NotificationHandler
    debugPrint(
        '📱 Legacy setOnNotificationTap called - notifications now handled by NotificationHandler');
  }

  static Future<String?> getToken() async {
    return await _fcmTokenService.getToken();
  }

  static Future<void> subscribeToTopic(String topic) async {
    await _firebaseMessaging.subscribeToTopic(topic);
    if (kDebugMode) {
      print('Subscribed to topic: $topic');
    }
  }

  static Future<void> unsubscribeFromTopic(String topic) async {
    await _firebaseMessaging.unsubscribeFromTopic(topic);
    if (kDebugMode) {
      print('Unsubscribed from topic: $topic');
    }
  }

  static Future<void> deactivateCurrentToken() async {
    await _fcmTokenService.deactivateCurrentToken();
  }

  static Future<AuthorizationStatus> getNotificationPermissionStatus() async {
    NotificationSettings settings =
        await _firebaseMessaging.getNotificationSettings();
    return settings.authorizationStatus;
  }

  static Future<bool> requestNotificationPermissions() async {
    NotificationSettings settings = await _firebaseMessaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    return settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
  }
}

// Top-level function for background message handling
@pragma('vm:entry-point')
Future<void> _handleBackgroundMessage(RemoteMessage message) async {
  print('🌙 BACKGROUND MESSAGE RECEIVED: ${message.messageId}');
  print('🌙 Background message data: ${message.data}');
  print(
      '🌙 Background message notification: ${message.notification?.title} - ${message.notification?.body}');

  if (kDebugMode) {
    print('Handling background message: ${message.messageId}');
  }

  // Use the comprehensive NotificationHandler for background messages
  await NotificationHandler.handleBackgroundNotification(message);
}
