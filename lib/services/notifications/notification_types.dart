/// Enumeration of all notification types supported by the app
enum NotificationType {
  friendRequest('friend_request'),
  friendRequestAccepted('friend_request_accepted'),
  newEvent('new_event'),
  stillThere('still_there'),
  eventUpdate('event_update'),
  eventCancelled('event_cancelled'),
  nearbyEvent('nearby_event'),
  reminder('reminder'),
  system('system');

  const NotificationType(this.value);
  final String value;

  static NotificationType fromString(String value) {
    return NotificationType.values.firstWhere(
      (type) => type.value == value,
      orElse: () => NotificationType.system,
    );
  }
}

/// Base class for all notification data
abstract class NotificationData {
  final NotificationType type;
  final String title;
  final String body;
  final Map<String, dynamic> data;
  final DateTime timestamp;

  const NotificationData({
    required this.type,
    required this.title,
    required this.body,
    required this.data,
    required this.timestamp,
  });

  Map<String, dynamic> toMap();
  factory NotificationData.fromMap(Map<String, dynamic> map) {
    final type = NotificationType.fromString(map['type'] ?? 'system');

    switch (type) {
      case NotificationType.friendRequest:
        return FriendRequestNotificationData.fromMap(map);
      case NotificationType.friendRequestAccepted:
        return FriendRequestAcceptedNotificationData.fromMap(map);
      case NotificationType.newEvent:
        return NewEventNotificationData.fromMap(map);
      case NotificationType.stillThere:
        return StillThereNotificationData.fromMap(map);
      case NotificationType.eventUpdate:
        return EventUpdateNotificationData.fromMap(map);
      case NotificationType.eventCancelled:
        return EventCancelledNotificationData.fromMap(map);
      case NotificationType.nearbyEvent:
        return NearbyEventNotificationData.fromMap(map);
      case NotificationType.reminder:
        return ReminderNotificationData.fromMap(map);
      case NotificationType.system:
        return SystemNotificationData.fromMap(map);
    }
  }
}

/// Friend request notification data
class FriendRequestNotificationData extends NotificationData {
  final String fromUserId;
  final String fromUserName;
  final String fromUserAvatar;
  final String requestId;

  const FriendRequestNotificationData({
    required this.fromUserId,
    required this.fromUserName,
    required this.fromUserAvatar,
    required this.requestId,
    required super.title,
    required super.body,
    required super.timestamp,
    Map<String, dynamic>? additionalData,
  }) : super(
          type: NotificationType.friendRequest,
          data: additionalData ?? const {},
        );

  @override
  Map<String, dynamic> toMap() {
    return {
      'type': type.value,
      'title': title,
      'body': body,
      'timestamp': timestamp.toIso8601String(),
      'from_user_id': fromUserId,
      'from_user_name': fromUserName,
      'from_user_avatar': fromUserAvatar,
      'request_id': requestId,
      ...data,
    };
  }

  factory FriendRequestNotificationData.fromMap(Map<String, dynamic> map) {
    return FriendRequestNotificationData(
      fromUserId: map['from_user_id'] ?? '',
      fromUserName: map['from_user_name'] ?? 'Unknown User',
      fromUserAvatar: map['from_user_avatar'] ?? '',
      requestId: map['request_id'] ?? '',
      title: map['title'] ?? 'Friend Request',
      body: map['body'] ?? 'Someone wants to be your friend',
      timestamp: DateTime.tryParse(map['timestamp'] ?? '') ?? DateTime.now(),
      additionalData: Map<String, dynamic>.from(map)
        ..removeWhere((key, value) => [
              'type',
              'title',
              'body',
              'timestamp',
              'from_user_id',
              'from_user_name',
              'from_user_avatar',
              'request_id'
            ].contains(key)),
    );
  }
}

/// Friend request accepted notification data
class FriendRequestAcceptedNotificationData extends NotificationData {
  final String fromUserId;
  final String fromUserName;
  final String fromUserAvatar;

  const FriendRequestAcceptedNotificationData({
    required this.fromUserId,
    required this.fromUserName,
    required this.fromUserAvatar,
    required super.title,
    required super.body,
    required super.timestamp,
    Map<String, dynamic>? additionalData,
  }) : super(
          type: NotificationType.friendRequestAccepted,
          data: additionalData ?? const {},
        );

  @override
  Map<String, dynamic> toMap() {
    return {
      'type': type.value,
      'title': title,
      'body': body,
      'timestamp': timestamp.toIso8601String(),
      'from_user_id': fromUserId,
      'from_user_name': fromUserName,
      'from_user_avatar': fromUserAvatar,
      ...data,
    };
  }

  factory FriendRequestAcceptedNotificationData.fromMap(
      Map<String, dynamic> map) {
    return FriendRequestAcceptedNotificationData(
      fromUserId: map['from_user_id'] ?? '',
      fromUserName: map['from_user_name'] ?? 'Unknown User',
      fromUserAvatar: map['from_user_avatar'] ?? '',
      title: map['title'] ?? 'Friend Request Accepted',
      body: map['body'] ?? 'Someone accepted your friend request',
      timestamp: DateTime.tryParse(map['timestamp'] ?? '') ?? DateTime.now(),
      additionalData: Map<String, dynamic>.from(map)
        ..removeWhere((key, value) => [
              'type',
              'title',
              'body',
              'timestamp',
              'from_user_id',
              'from_user_name',
              'from_user_avatar'
            ].contains(key)),
    );
  }
}

/// New event notification data
class NewEventNotificationData extends NotificationData {
  final String eventId;
  final String eventTitle;
  final String eventDescription;
  final String eventLocation;
  final String eventImageUrl;
  final DateTime eventDate;
  final String creatorUserId;
  final String creatorUserName;
  final double? latitude;
  final double? longitude;

  const NewEventNotificationData({
    required this.eventId,
    required this.eventTitle,
    required this.eventDescription,
    required this.eventLocation,
    required this.eventImageUrl,
    required this.eventDate,
    required this.creatorUserId,
    required this.creatorUserName,
    this.latitude,
    this.longitude,
    required super.title,
    required super.body,
    required super.timestamp,
    Map<String, dynamic>? additionalData,
  }) : super(
          type: NotificationType.newEvent,
          data: additionalData ?? const {},
        );

  @override
  Map<String, dynamic> toMap() {
    return {
      'type': type.value,
      'title': title,
      'body': body,
      'timestamp': timestamp.toIso8601String(),
      'event_id': eventId,
      'event_title': eventTitle,
      'event_description': eventDescription,
      'event_location': eventLocation,
      'event_image_url': eventImageUrl,
      'event_date': eventDate.toIso8601String(),
      'creator_user_id': creatorUserId,
      'creator_user_name': creatorUserName,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      ...data,
    };
  }

  factory NewEventNotificationData.fromMap(Map<String, dynamic> map) {
    return NewEventNotificationData(
      eventId: map['event_id'] ?? '',
      eventTitle: map['event_title'] ?? 'New Event',
      eventDescription: map['event_description'] ?? '',
      eventLocation: map['event_location'] ?? '',
      eventImageUrl: map['event_image_url'] ?? '',
      eventDate: DateTime.tryParse(map['event_date'] ?? '') ?? DateTime.now(),
      creatorUserId: map['creator_user_id'] ?? '',
      creatorUserName: map['creator_user_name'] ?? 'Unknown User',
      latitude: map['latitude']?.toDouble(),
      longitude: map['longitude']?.toDouble(),
      title: map['title'] ?? 'New Event',
      body: map['body'] ?? 'A new event is happening nearby',
      timestamp: DateTime.tryParse(map['timestamp'] ?? '') ?? DateTime.now(),
      additionalData: Map<String, dynamic>.from(map)
        ..removeWhere((key, value) => [
              'type',
              'title',
              'body',
              'timestamp',
              'event_id',
              'event_title',
              'event_description',
              'event_location',
              'event_image_url',
              'event_date',
              'creator_user_id',
              'creator_user_name',
              'latitude',
              'longitude'
            ].contains(key)),
    );
  }
}

/// Still there confirmation notification data
class StillThereNotificationData extends NotificationData {
  final String eventId;
  final String eventTitle;
  final String eventImageUrl;
  final String confirmationId;
  final DateTime originalEventDate;

  const StillThereNotificationData({
    required this.eventId,
    required this.eventTitle,
    required this.eventImageUrl,
    required this.confirmationId,
    required this.originalEventDate,
    required super.title,
    required super.body,
    required super.timestamp,
    Map<String, dynamic>? additionalData,
  }) : super(
          type: NotificationType.stillThere,
          data: additionalData ?? const {},
        );

  @override
  Map<String, dynamic> toMap() {
    return {
      'type': type.value,
      'title': title,
      'body': body,
      'timestamp': timestamp.toIso8601String(),
      'event_id': eventId,
      'event_title': eventTitle,
      'event_image_url': eventImageUrl,
      'confirmation_id': confirmationId,
      'original_event_date': originalEventDate.toIso8601String(),
      'dialog_title': 'Event Confirmation',
      'dialog_description': 'Is this event still happening?',
      ...data,
    };
  }

  factory StillThereNotificationData.fromMap(Map<String, dynamic> map) {
    return StillThereNotificationData(
      eventId: map['event_id'] ?? '',
      eventTitle: map['event_title'] ?? 'Event',
      eventImageUrl: map['event_image_url'] ?? '',
      confirmationId: map['confirmation_id'] ?? '',
      originalEventDate:
          DateTime.tryParse(map['original_event_date'] ?? '') ?? DateTime.now(),
      title: map['title'] ?? 'Still There?',
      body: map['body'] ?? 'Is this event still happening?',
      timestamp: DateTime.tryParse(map['timestamp'] ?? '') ?? DateTime.now(),
      additionalData: Map<String, dynamic>.from(map)
        ..removeWhere((key, value) => [
              'type',
              'title',
              'body',
              'timestamp',
              'event_id',
              'event_title',
              'event_image_url',
              'confirmation_id',
              'original_event_date'
            ].contains(key)),
    );
  }
}

/// Event update notification data
class EventUpdateNotificationData extends NotificationData {
  final String eventId;
  final String eventTitle;
  final String
      updateType; // 'time_changed', 'location_changed', 'details_updated'
  final String updateDescription;

  const EventUpdateNotificationData({
    required this.eventId,
    required this.eventTitle,
    required this.updateType,
    required this.updateDescription,
    required super.title,
    required super.body,
    required super.timestamp,
    Map<String, dynamic>? additionalData,
  }) : super(
          type: NotificationType.eventUpdate,
          data: additionalData ?? const {},
        );

  @override
  Map<String, dynamic> toMap() {
    return {
      'type': type.value,
      'title': title,
      'body': body,
      'timestamp': timestamp.toIso8601String(),
      'event_id': eventId,
      'event_title': eventTitle,
      'update_type': updateType,
      'update_description': updateDescription,
      ...data,
    };
  }

  factory EventUpdateNotificationData.fromMap(Map<String, dynamic> map) {
    return EventUpdateNotificationData(
      eventId: map['event_id'] ?? '',
      eventTitle: map['event_title'] ?? 'Event',
      updateType: map['update_type'] ?? 'details_updated',
      updateDescription: map['update_description'] ?? 'Event has been updated',
      title: map['title'] ?? 'Event Updated',
      body: map['body'] ?? 'An event you\'re interested in has been updated',
      timestamp: DateTime.tryParse(map['timestamp'] ?? '') ?? DateTime.now(),
      additionalData: Map<String, dynamic>.from(map)
        ..removeWhere((key, value) => [
              'type',
              'title',
              'body',
              'timestamp',
              'event_id',
              'event_title',
              'update_type',
              'update_description'
            ].contains(key)),
    );
  }
}

/// Event cancelled notification data
class EventCancelledNotificationData extends NotificationData {
  final String eventId;
  final String eventTitle;
  final String cancellationReason;

  const EventCancelledNotificationData({
    required this.eventId,
    required this.eventTitle,
    required this.cancellationReason,
    required super.title,
    required super.body,
    required super.timestamp,
    Map<String, dynamic>? additionalData,
  }) : super(
          type: NotificationType.eventCancelled,
          data: additionalData ?? const {},
        );

  @override
  Map<String, dynamic> toMap() {
    return {
      'type': type.value,
      'title': title,
      'body': body,
      'timestamp': timestamp.toIso8601String(),
      'event_id': eventId,
      'event_title': eventTitle,
      'cancellation_reason': cancellationReason,
      ...data,
    };
  }

  factory EventCancelledNotificationData.fromMap(Map<String, dynamic> map) {
    return EventCancelledNotificationData(
      eventId: map['event_id'] ?? '',
      eventTitle: map['event_title'] ?? 'Event',
      cancellationReason:
          map['cancellation_reason'] ?? 'Event has been cancelled',
      title: map['title'] ?? 'Event Cancelled',
      body: map['body'] ?? 'An event you were interested in has been cancelled',
      timestamp: DateTime.tryParse(map['timestamp'] ?? '') ?? DateTime.now(),
      additionalData: Map<String, dynamic>.from(map)
        ..removeWhere((key, value) => [
              'type',
              'title',
              'body',
              'timestamp',
              'event_id',
              'event_title',
              'cancellation_reason'
            ].contains(key)),
    );
  }
}

/// Nearby event notification data
class NearbyEventNotificationData extends NotificationData {
  final String eventId;
  final String eventTitle;
  final String eventLocation;
  final double latitude;
  final double longitude;
  final double distanceKm;

  const NearbyEventNotificationData({
    required this.eventId,
    required this.eventTitle,
    required this.eventLocation,
    required this.latitude,
    required this.longitude,
    required this.distanceKm,
    required super.title,
    required super.body,
    required super.timestamp,
    Map<String, dynamic>? additionalData,
  }) : super(
          type: NotificationType.nearbyEvent,
          data: additionalData ?? const {},
        );

  @override
  Map<String, dynamic> toMap() {
    return {
      'type': type.value,
      'title': title,
      'body': body,
      'timestamp': timestamp.toIso8601String(),
      'event_id': eventId,
      'event_title': eventTitle,
      'event_location': eventLocation,
      'latitude': latitude,
      'longitude': longitude,
      'distance_km': distanceKm,
      ...data,
    };
  }

  factory NearbyEventNotificationData.fromMap(Map<String, dynamic> map) {
    return NearbyEventNotificationData(
      eventId: map['event_id'] ?? '',
      eventTitle: map['event_title'] ?? 'Nearby Event',
      eventLocation: map['event_location'] ?? '',
      latitude: map['latitude']?.toDouble() ?? 0.0,
      longitude: map['longitude']?.toDouble() ?? 0.0,
      distanceKm: map['distance_km']?.toDouble() ?? 0.0,
      title: map['title'] ?? 'Event Nearby',
      body: map['body'] ?? 'There\'s an event happening near you',
      timestamp: DateTime.tryParse(map['timestamp'] ?? '') ?? DateTime.now(),
      additionalData: Map<String, dynamic>.from(map)
        ..removeWhere((key, value) => [
              'type',
              'title',
              'body',
              'timestamp',
              'event_id',
              'event_title',
              'event_location',
              'latitude',
              'longitude',
              'distance_km'
            ].contains(key)),
    );
  }
}

/// Reminder notification data
class ReminderNotificationData extends NotificationData {
  final String reminderId;
  final String reminderType; // 'event_starting', 'friend_birthday', 'custom'
  final String targetId; // event_id, user_id, etc.

  const ReminderNotificationData({
    required this.reminderId,
    required this.reminderType,
    required this.targetId,
    required super.title,
    required super.body,
    required super.timestamp,
    Map<String, dynamic>? additionalData,
  }) : super(
          type: NotificationType.reminder,
          data: additionalData ?? const {},
        );

  @override
  Map<String, dynamic> toMap() {
    return {
      'type': type.value,
      'title': title,
      'body': body,
      'timestamp': timestamp.toIso8601String(),
      'reminder_id': reminderId,
      'reminder_type': reminderType,
      'target_id': targetId,
      ...data,
    };
  }

  factory ReminderNotificationData.fromMap(Map<String, dynamic> map) {
    return ReminderNotificationData(
      reminderId: map['reminder_id'] ?? '',
      reminderType: map['reminder_type'] ?? 'custom',
      targetId: map['target_id'] ?? '',
      title: map['title'] ?? 'Reminder',
      body: map['body'] ?? 'You have a reminder',
      timestamp: DateTime.tryParse(map['timestamp'] ?? '') ?? DateTime.now(),
      additionalData: Map<String, dynamic>.from(map)
        ..removeWhere((key, value) => [
              'type',
              'title',
              'body',
              'timestamp',
              'reminder_id',
              'reminder_type',
              'target_id'
            ].contains(key)),
    );
  }
}

/// System notification data
class SystemNotificationData extends NotificationData {
  final String messageType; // 'maintenance', 'update_available', 'general'
  final String? actionUrl;

  const SystemNotificationData({
    required this.messageType,
    this.actionUrl,
    required super.title,
    required super.body,
    required super.timestamp,
    Map<String, dynamic>? additionalData,
  }) : super(
          type: NotificationType.system,
          data: additionalData ?? const {},
        );

  @override
  Map<String, dynamic> toMap() {
    return {
      'type': type.value,
      'title': title,
      'body': body,
      'timestamp': timestamp.toIso8601String(),
      'message_type': messageType,
      if (actionUrl != null) 'action_url': actionUrl,
      ...data,
    };
  }

  factory SystemNotificationData.fromMap(Map<String, dynamic> map) {
    return SystemNotificationData(
      messageType: map['message_type'] ?? 'general',
      actionUrl: map['action_url'],
      title: map['title'] ?? 'System Notification',
      body: map['body'] ?? 'System message',
      timestamp: DateTime.tryParse(map['timestamp'] ?? '') ?? DateTime.now(),
      additionalData: Map<String, dynamic>.from(map)
        ..removeWhere((key, value) => [
              'type',
              'title',
              'body',
              'timestamp',
              'message_type',
              'action_url'
            ].contains(key)),
    );
  }
}
