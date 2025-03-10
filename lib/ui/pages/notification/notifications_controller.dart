import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'notification_model.dart';

// TODO: Add Firebase imports when ready:
// import 'package:firebase_messaging/firebase_messaging.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationsController extends ChangeNotifier {
  // TODO: Add Firebase instances
  // final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  // final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<NotificationModel> _notifications = [];
  bool _isPermissionGranted = false;
  String? _fcmToken;

  List<NotificationModel> get notifications => _notifications;
  bool get isPermissionGranted => _isPermissionGranted;

  // TODO: Initialize Firebase listeners and permissions
  Future<void> initializeNotifications() async {
    // Request permission
    // NotificationSettings settings = await _messaging.requestPermission(
    //   alert: true,
    //   badge: true,
    //   sound: true,
    // );
    // _isPermissionGranted = settings.authorizationStatus == AuthorizationStatus.authorized;

    // Get FCM token
    // _fcmToken = await _messaging.getToken();

    // Save token to Firestore
    // if (_fcmToken != null) {
    //   await _saveTokenToFirestore(_fcmToken!);
    // }

    // Listen for token refresh
    // _messaging.onTokenRefresh.listen(_saveTokenToFirestore);

    // Set up message handlers
    // FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    // FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);
    // FirebaseMessaging.onBackgroundMessage(_handleBackgroundMessage);
  }

  // TODO: Save FCM token to Firestore
  // Future<void> _saveTokenToFirestore(String token) async {
  //   await _firestore
  //     .collection('users')
  //     .doc(currentUserId)
  //     .update({
  //       'fcmTokens': FieldValue.arrayUnion([token])
  //     });
  // }

  // TODO: Handle foreground messages
  // void _handleForegroundMessage(RemoteMessage message) {
  //   final notification = NotificationModel.fromFirebaseMessage(message);
  //   _notifications.insert(0, notification);
  //   notifyListeners();
  // }

  // TODO: Handle when app is opened from notification
  // void _handleMessageOpenedApp(RemoteMessage message) {
  //   // Navigate to relevant screen based on notification data
  // }

  // TODO: Handle background messages
  // Future<void> _handleBackgroundMessage(RemoteMessage message) async {
  //   // Process background message
  // }

  Future<void> loadNotifications() async {
    // TODO: Replace with Firestore fetch
    // try {
    //   final snapshot = await _firestore
    //     .collection('users')
    //     .doc(currentUserId)
    //     .collection('notifications')
    //     .orderBy('timestamp', descending: true)
    //     .get();
    //
    //   _notifications = snapshot.docs
    //     .map((doc) => NotificationModel.fromFirestore(doc))
    //     .toList();
    //
    //   notifyListeners();
    // } catch (e) {
    //   print('Error loading notifications: $e');
    // }

    // For now, use mock data
    _notifications = [
      NotificationModel(
        message: "New message from John Doe",
        dateTime: DateTime.now(),
        icon: Icons.message,
      ),
      // ...add more mock notifications as needed
    ];
    notifyListeners();
  }

  Future<void> enableNotifications() async {
    // TODO: Implement Firebase notification permission request
    // try {
    //   NotificationSettings settings = await _messaging.requestPermission(
    //     alert: true,
    //     badge: true,
    //     sound: true,
    //   );
    //
    //   _isPermissionGranted = settings.authorizationStatus == AuthorizationStatus.authorized;
    //
    //   if (_isPermissionGranted) {
    //     _fcmToken = await _messaging.getToken();
    //     await _saveTokenToFirestore(_fcmToken!);
    //   }
    //
    //   final prefs = await SharedPreferences.getInstance();
    //   await prefs.setBool('notifications_enabled', _isPermissionGranted);
    //
    //   notifyListeners();
    // } catch (e) {
    //   print('Error enabling notifications: $e');
    //   throw Exception('Failed to enable notifications');
    // }

    // For now, just update SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notifications_enabled', true);
    _isPermissionGranted = true;
    notifyListeners();
  }

  Future<void> disableNotifications() async {
    // TODO: Implement Firebase notification disable
    // try {
    //   if (_fcmToken != null) {
    //     await _firestore
    //       .collection('users')
    //       .doc(currentUserId)
    //       .update({
    //         'fcmTokens': FieldValue.arrayRemove([_fcmToken])
    //       });
    //   }
    //
    //   final prefs = await SharedPreferences.getInstance();
    //   await prefs.setBool('notifications_enabled', false);
    //
    //   _isPermissionGranted = false;
    //   notifyListeners();
    // } catch (e) {
    //   print('Error disabling notifications: $e');
    //   throw Exception('Failed to disable notifications');
    // }

    // For now, just update SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notifications_enabled', false);
    _isPermissionGranted = false;
    notifyListeners();
  }

  void markAsRead(String notificationId) {
    // TODO: Update read status in Firestore
    // try {
    //   await _firestore
    //     .collection('users')
    //     .doc(currentUserId)
    //     .collection('notifications')
    //     .doc(notificationId)
    //     .update({'isRead': true});
    // } catch (e) {
    //   print('Error marking notification as read: $e');
    // }
  }

  void clearAll() {
    // TODO: Clear notifications in Firestore
    // try {
    //   final batch = _firestore.batch();
    //   final notifications = await _firestore
    //     .collection('users')
    //     .doc(currentUserId)
    //     .collection('notifications')
    //     .get();
    //
    //   for (var doc in notifications.docs) {
    //     batch.delete(doc.reference);
    //   }
    //
    //   await batch.commit();
    //   _notifications.clear();
    //   notifyListeners();
    // } catch (e) {
    //   print('Error clearing notifications: $e');
    // }

    _notifications.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    // TODO: Clean up Firebase listeners
    // _messaging.deleteToken();
    super.dispose();
  }
}
