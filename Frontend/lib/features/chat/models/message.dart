enum MessageType {
  text,
  system,
  image,
  location,
  announcement,
}

class Message {
  final String id;
  final String senderName;
  final String senderAvatar;
  final String content;
  final DateTime timestamp;
  final bool isMe;
  final MessageType type;
  final String? attachmentUrl;
  final double? latitude;
  final double? longitude;
  final bool isLeader;

  Message({
    required this.id,
    required this.senderName,
    required this.senderAvatar,
    required this.content,
    required this.timestamp,
    required this.isMe,
    this.type = MessageType.text,
    this.attachmentUrl,
    this.latitude,
    this.longitude,
    this.isLeader = false,
  });

  factory Message.fromJson(Map<String, dynamic> json, {String? currentUserId}) {
    MessageType msgType = MessageType.text;
    final typeStr = (json['type'] ?? json['messageType'] ?? '').toString();
    if (typeStr == 'announcement') {
      msgType = MessageType.announcement;
    } else if (typeStr == 'system') {
      msgType = MessageType.system;
    } else if (typeStr == 'image') {
      msgType = MessageType.image;
    } else if (typeStr == 'location') {
      msgType = MessageType.location;
    }

    DateTime ts;
    if (json['timestamp'] != null) {
      ts = (DateTime.tryParse(json['timestamp'].toString()) ?? DateTime.now()).toLocal();
    } else if (json['createdAt'] != null) {
      ts = (DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()).toLocal();
    } else {
      ts = DateTime.now().toLocal();
    }


    final isMeFlag = json['isMe'] == true ||
        (currentUserId != null && json['senderId']?.toString() == currentUserId);

    return Message(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      senderName: json['senderName'] ?? 'User',
      senderAvatar: json['senderAvatar'] ?? '',
      content: json['content'] ?? json['message'] ?? '',
      timestamp: ts,
      isMe: isMeFlag,
      type: msgType,
      attachmentUrl: json['fileUrl'] ?? json['attachmentUrl'],
      isLeader: json['isLeader'] == true || json['senderRole'] == 'tripLeader',
    );
  }
}

