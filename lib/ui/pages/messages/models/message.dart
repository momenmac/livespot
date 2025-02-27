enum MessageStatus {
  sending,
  sent,
  delivered,
}

class Message {
  final String id;
  final String senderId;
  final String senderName;
  final String content;
  final DateTime timestamp;
  final MessageStatus? status; // Only for sent messages
  final bool isRead;

  Message({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.content,
    required this.timestamp,
    this.status,
    this.isRead = false,
  });

  bool get isSent => senderId == 'current';

  Message copyWith({
    String? id,
    String? senderId,
    String? senderName,
    String? content,
    DateTime? timestamp,
    MessageStatus? status,
    bool? isRead,
  }) {
    return Message(
      id: id ?? this.id,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
      status: status ?? this.status,
      isRead: isRead ?? this.isRead,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'senderId': senderId,
      'senderName': senderName,
      'content': content,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'status': status?.index,
      'isRead': isRead,
    };
  }

  static Message fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'],
      senderId: json['senderId'],
      senderName: json['senderName'],
      content: json['content'],
      timestamp: DateTime.fromMillisecondsSinceEpoch(json['timestamp']),
      status:
          json['status'] != null ? MessageStatus.values[json['status']] : null,
      isRead: json['isRead'] ?? false,
    );
  }
}
