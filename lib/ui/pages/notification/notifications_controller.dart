import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'notification_model.dart';
import 'notification_popup.dart';

// TODO: Add Firebase imports when ready:
// import 'package:firebase_messaging/firebase_messaging.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationsController extends ChangeNotifier {
  List<NotificationModel> _notifications = [];
  bool _isPermissionGranted = false;

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
    // TODO: Implement FCM token handling for push notifications

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

  // Global key for accessing navigator
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();
  static void showNotification({
    required String title,
    required String message,
    IconData? icon,
    VoidCallback? onTap,
  }) {
    print('🚀🚀🚀 SHOW NOTIFICATION CALLED! 🚀🚀🚀');
    print('📞 NotificationsController.showNotification() invoked');
    print('📝 Title: "$title"');
    print('💬 Message: "$message"');
    print('🏷️ Icon: ${icon?.codePoint ?? 'null'}');
    print('🗂️ onTap callback: ${onTap != null ? 'provided' : 'null'}');

    print('🔍 Checking navigator key...');
    print('🔗 navigatorKey: ${navigatorKey.toString()}');
    print('🎯 navigatorKey.currentContext: ${navigatorKey.currentContext}');
    print('🏗️ navigatorKey.currentState: ${navigatorKey.currentState}');

    if (navigatorKey.currentContext == null) {
      print('❌❌❌ CRITICAL: Navigator context is NULL!');
      print('❌ Cannot show notification - no context available');
      print(
          '❌ This means the navigatorKey is not properly connected to MaterialApp');
      return;
    }

    print('✅✅✅ SUCCESS: Navigator context found!');
    print('✅ Context type: ${navigatorKey.currentContext.runtimeType}');
    print('✅ Context hashCode: ${navigatorKey.currentContext.hashCode}');
    try {
      print('🎨 Getting overlay state...');
      // Get overlay state directly from the navigator state
      final NavigatorState? navigatorState = navigatorKey.currentState;
      print('📊 Navigator state: ${navigatorState.toString()}');

      if (navigatorState == null) {
        print('❌❌❌ CRITICAL: Navigator state is NULL!');
        print('❌ Cannot show notification - navigator not ready');
        return;
      }

      // Get the overlay from the navigator state
      final OverlayState? overlayState = navigatorState.overlay;
      print('🎯 Overlay state from navigator: ${overlayState.toString()}');

      if (overlayState == null) {
        print('❌❌❌ CRITICAL: Overlay state is NULL!');
        print('❌ Cannot show notification - overlay not available');
        return;
      }

      print('✅✅✅ SUCCESS: Overlay state obtained successfully!');

      OverlayEntry? entry;
      print('🏗️ Creating overlay entry...');

      entry = OverlayEntry(
        builder: (context) {
          print(
              '🎯 OverlayEntry builder called - creating NotificationPopup widget');
          return NotificationPopup(
            title: title,
            message: message,
            icon: icon,
            backgroundColor: Theme.of(context).cardColor,
            textColor:
                Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black87,
            onTap: () {
              print('🎯🎯🎯 NOTIFICATION TAPPED! 🎯🎯🎯');
              print('🎯 Notification popup tapped: $title');
              print('🗑️ Removing overlay entry...');
              entry?.remove();
              print('📞 Calling onTap callback...');
              onTap?.call();
              print('✅ onTap callback completed');
            },
            onDismiss: () {
              print('❌ NOTIFICATION DISMISSED: $title');
              print('🗑️ Removing overlay entry...');
              entry?.remove();
              print('✅ Dismiss completed');
            },
          );
        },
      );

      print('📌 Inserting overlay entry into overlay state...');
      overlayState.insert(entry);
      print('✅✅✅ SUCCESS: Notification popup inserted into overlay!');
      print('🎉 Notification should now be visible on screen');

      // Auto dismiss after 4 seconds
      print('⏰ Setting up auto-dismiss timer (4 seconds)...');
      Future.delayed(const Duration(seconds: 4), () {
        print('⏰ Auto-dismiss timer triggered');
        print('Auto-dismissing notification: $title');
        entry?.remove();
        print('✅ Auto-dismiss completed');
      });
    } catch (e) {
      print('❌❌❌ ERROR showing notification: $e');
      print('🔍 Error details: ${e.toString()}');
    }
  }

  @override
  void dispose() {
    // TODO: Clean up Firebase listeners
    // _messaging.deleteToken();
    super.dispose();
  }
}
