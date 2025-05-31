# Firebase Console Configuration Guide for Professional Notifications

This guide will help you configure Firebase Console to support all notification types in your Flutter application.

## 📋 Prerequisites

- Firebase project created and linked to your Flutter app
- Firebase Admin SDK service account key downloaded
- Flutter app with Firebase SDK integrated

## 🔧 Firebase Console Setup

### 1. Cloud Messaging Configuration

#### 1.1 Enable Cloud Messaging API
1. Go to [Firebase Console](https://console.firebase.google.com)
2. Select your project
3. Navigate to **Project Settings** > **Cloud Messaging**
4. Note your **Server Key** and **Sender ID**

#### 1.2 Configure App Registration
1. In **Project Settings** > **General**
2. Ensure your Android/iOS apps are registered
3. Download the latest `google-services.json` (Android) and `GoogleService-Info.plist` (iOS)

### 2. Firestore Database Setup

#### 2.1 Create Collections for Notifications
```javascript
// Collection: users/{userId}/notifications
{
  id: "string",
  type: "friend_request|new_event|still_there|event_update|etc",
  title: "string",
  body: "string", 
  data: {
    // Type-specific data
  },
  timestamp: "timestamp",
  isRead: "boolean",
  priority: "high|normal|low"
}

// Collection: users/{userId}/fcmTokens
{
  token: "string",
  deviceId: "string",
  platform: "android|ios",
  lastUpdated: "timestamp",
  isActive: "boolean"
}

// Collection: events/{eventId}/notifications
{
  type: "still_there|event_update|reminder",
  sentTo: ["userId1", "userId2"],
  sentAt: "timestamp",
  data: {
    // Event-specific data
  }
}
```

#### 2.2 Set Firestore Security Rules
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Users can read/write their own notifications
    match /users/{userId}/notifications/{notificationId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
    
    // Users can manage their own FCM tokens
    match /users/{userId}/fcmTokens/{tokenId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
    
    // Event notifications (read-only for participants)
    match /events/{eventId}/notifications/{notificationId} {
      allow read: if request.auth != null;
      allow write: if request.auth != null && 
        exists(/databases/$(database)/documents/events/$(eventId)) &&
        get(/databases/$(database)/documents/events/$(eventId)).data.creatorId == request.auth.uid;
    }
  }
}
```

### 3. Cloud Functions Setup (Optional but Recommended)

#### 3.1 Install Firebase CLI
```bash
npm install -g firebase-tools
firebase login
```

#### 3.2 Initialize Functions
```bash
firebase init functions
```

#### 3.3 Create Notification Triggers
```javascript
// functions/index.js
const functions = require('firebase-functions');
const admin = require('firebase-admin');

admin.initializeApp();

// Send notification when friend request is created
exports.sendFriendRequestNotification = functions.firestore
  .document('friendRequests/{requestId}')
  .onCreate(async (snap, context) => {
    const request = snap.data();
    const toUserId = request.toUserId;
    
    // Get user's FCM tokens
    const tokensSnapshot = await admin.firestore()
      .collection('users')
      .doc(toUserId)
      .collection('fcmTokens')
      .where('isActive', '==', true)
      .get();
    
    const tokens = tokensSnapshot.docs.map(doc => doc.data().token);
    
    if (tokens.length === 0) return;
    
    const message = {
      notification: {
        title: 'Friend Request',
        body: `${request.fromUserName} wants to be your friend`
      },
      data: {
        type: 'friend_request',
        fromUserId: request.fromUserId,
        fromUserName: request.fromUserName,
        fromUserAvatar: request.fromUserAvatar || '',
        requestId: context.params.requestId
      },
      tokens: tokens
    };
    
    return admin.messaging().sendMulticast(message);
  });

// Send event reminders
exports.sendEventReminders = functions.pubsub
  .schedule('every 5 minutes')
  .onRun(async (context) => {
    const now = admin.firestore.Timestamp.now();
    const reminderTime = new Date(now.toDate().getTime() + 30 * 60000); // 30 minutes from now
    
    // Query events starting in 30 minutes
    const eventsSnapshot = await admin.firestore()
      .collection('events')
      .where('startTime', '>=', now)
      .where('startTime', '<=', admin.firestore.Timestamp.fromDate(reminderTime))
      .where('reminderSent', '==', false)
      .get();
    
    const batch = admin.firestore().batch();
    
    for (const eventDoc of eventsSnapshot.docs) {
      const event = eventDoc.data();
      const participants = event.participants || [];
      
      // Get FCM tokens for all participants
      const tokenPromises = participants.map(async (userId) => {
        const tokensSnapshot = await admin.firestore()
          .collection('users')
          .doc(userId)
          .collection('fcmTokens')
          .where('isActive', '==', true)
          .get();
        return tokensSnapshot.docs.map(doc => doc.data().token);
      });
      
      const tokenArrays = await Promise.all(tokenPromises);
      const allTokens = tokenArrays.flat();
      
      if (allTokens.length > 0) {
        const message = {
          notification: {
            title: 'Event Reminder',
            body: `${event.title} starts in 30 minutes`
          },
          data: {
            type: 'reminder',
            eventId: eventDoc.id,
            eventTitle: event.title,
            reminderType: 'event_starting',
            timeUntil: '30 minutes',
            eventLocation: event.location || ''
          },
          tokens: allTokens
        };
        
        await admin.messaging().sendMulticast(message);
      }
      
      // Mark reminder as sent
      batch.update(eventDoc.ref, { reminderSent: true });
    }
    
    return batch.commit();
  });
```

## 📱 Android Configuration

### 1. Update android/app/build.gradle
```gradle
android {
    compileSdkVersion 34
    
    defaultConfig {
        applicationId "com.yourcompany.yourapp"
        minSdkVersion 21
        targetSdkVersion 34
        // ... other configs
    }
}

dependencies {
    implementation 'com.google.firebase:firebase-messaging:23.4.0'
    implementation 'androidx.work:work-runtime:2.9.0'
}
```

### 2. Update AndroidManifest.xml
```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    
    <!-- Permissions -->
    <uses-permission android:name="android.permission.INTERNET" />
    <uses-permission android:name="android.permission.WAKE_LOCK" />
    <uses-permission android:name="android.permission.VIBRATE" />
    <uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED" />
    
    <application
        android:name="${applicationName}"
        android:exported="true"
        android:icon="@mipmap/ic_launcher"
        android:label="LiveSpot">
        
        <!-- Firebase Messaging default notification icon -->
        <meta-data
            android:name="com.google.firebase.messaging.default_notification_icon"
            android:resource="@drawable/ic_notification" />
            
        <!-- Firebase Messaging default notification color -->
        <meta-data
            android:name="com.google.firebase.messaging.default_notification_color"
            android:resource="@color/notification_color" />
            
        <!-- Firebase Messaging default channel ID -->
        <meta-data
            android:name="com.google.firebase.messaging.default_notification_channel_id"
            android:value="high_importance_channel" />
            
        <!-- Firebase Messaging service -->
        <service
            android:name="io.flutter.plugins.firebase.messaging.FlutterFirebaseMessagingService"
            android:directBootAware="true"
            android:exported="false">
            <intent-filter>
                <action android:name="com.google.firebase.MESSAGING_EVENT" />
            </intent-filter>
        </service>
        
        <!-- Main Activity -->
        <activity
            android:name=".MainActivity"
            android:exported="true"
            android:launchMode="singleTop"
            android:theme="@style/LaunchTheme"
            android:configChanges="orientation|keyboardHidden|keyboard|screenSize|smallestScreenSize|locale|layoutDirection|fontScale|screenLayout|density|uiMode"
            android:hardwareAccelerated="true"
            android:windowSoftInputMode="adjustResize">
            
            <meta-data
                android:name="io.flutter.embedding.android.NormalTheme"
                android:resource="@style/NormalTheme" />
                
            <intent-filter android:autoVerify="true">
                <action android:name="android.intent.action.MAIN"/>
                <category android:name="android.intent.category.LAUNCHER"/>
            </intent-filter>
        </activity>
    </application>
</manifest>
```

## 🍎 iOS Configuration

### 1. Update ios/Runner/Info.plist
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <!-- Existing keys... -->
    
    <!-- Firebase Configuration -->
    <key>UIBackgroundModes</key>
    <array>
        <string>remote-notification</string>
        <string>background-processing</string>
    </array>
    
    <!-- Push Notification Capability -->
    <key>aps-environment</key>
    <string>development</string> <!-- Use 'production' for release -->
</dict>
</plist>
```

### 2. Enable Push Notifications in Xcode
1. Open `ios/Runner.xcworkspace` in Xcode
2. Select the **Runner** project
3. Go to **Signing & Capabilities**
4. Click **+ Capability**
5. Add **Push Notifications**
6. Add **Background Modes** and enable:
   - Remote notifications
   - Background processing

## 🧪 Testing Setup

### 1. Get FCM Token
Run your Flutter app and check the console for the FCM token:
```dart
String? token = await FirebaseMessagingService.getToken();
print('FCM Token: $token');
```

### 2. Test Notifications
Use the comprehensive test script:
```bash
# Test all notification types
python test_comprehensive_notifications.py --token YOUR_FCM_TOKEN --all

# Test specific notification type
python test_comprehensive_notifications.py --token YOUR_FCM_TOKEN --type friend_request
```

### 3. Available Notification Types
- `friend_request` - Friend request notifications
- `friend_request_accepted` - Friend request accepted
- `new_event` - New event nearby
- `still_there` - Event confirmation request
- `event_update` - Event details updated
- `event_cancelled` - Event cancelled
- `nearby_event` - Event happening nearby
- `reminder` - Event reminders
- `system` - System announcements

## 📊 Monitoring and Analytics

### 1. Firebase Console Monitoring
- Go to **Cloud Messaging** > **Reports**
- Monitor delivery rates, open rates
- Track notification performance

### 2. Custom Analytics Events
Add to your Flutter app:
```dart
await FirebaseAnalytics.instance.logEvent(
  name: 'notification_received',
  parameters: {
    'notification_type': notificationType,
    'notification_id': notificationId,
    'user_id': userId,
  },
);
```

## 🚀 Production Deployment

### 1. Environment Configuration
- Use production FCM server key
- Update iOS `aps-environment` to `production`
- Configure production Firestore security rules

### 2. Performance Optimization
- Implement token management and cleanup
- Set up notification batching for multiple recipients
- Configure notification scheduling for optimal delivery times

### 3. User Preferences
- Implement notification settings in your app
- Allow users to customize notification types
- Respect do-not-disturb settings

## 🔧 Troubleshooting

### Common Issues
1. **Notifications not received**: Check FCM token validity
2. **iOS simulator issues**: Use physical device for testing
3. **Permission denied**: Ensure notification permissions are granted
4. **Background notifications**: Verify background modes are enabled

### Debug Tools
- Firebase Console message logs
- FCM diagnostics in your app
- Device notification settings verification

---

For more detailed Firebase documentation, visit:
- [Firebase Cloud Messaging](https://firebase.google.com/docs/cloud-messaging)
- [Flutter Firebase Setup](https://firebase.flutter.dev/docs/overview)
- [Firebase Admin SDK](https://firebase.google.com/docs/admin/setup)
