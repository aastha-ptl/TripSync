enum MessageType {
  text,
  system,
  image,
  location,
  announcement,
}

class Message {
  final String id;
  final String? senderId;
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
  final bool isEdited;

  Message({
    required this.id,
    this.senderId,
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
    this.isEdited = false,
  });

  Message copyWith({
    String? id,
    String? senderId,
    String? senderName,
    String? senderAvatar,
    String? content,
    DateTime? timestamp,
    bool? isMe,
    MessageType? type,
    String? attachmentUrl,
    double? latitude,
    double? longitude,
    bool? isLeader,
    bool? isEdited,
  }) {
    return Message(
      id: id ?? this.id,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      senderAvatar: senderAvatar ?? this.senderAvatar,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
      isMe: isMe ?? this.isMe,
      type: type ?? this.type,
      attachmentUrl: attachmentUrl ?? this.attachmentUrl,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      isLeader: isLeader ?? this.isLeader,
      isEdited: isEdited ?? this.isEdited,
    );
  }

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

    final String senderIdStr = (json['senderId'] is Map
            ? json['senderId']['_id']
            : (json['senderId'] ?? json['sender']?['_id'] ?? json['sender']?['id'] ?? ''))
        ?.toString() ?? '';

    bool isMeFlag;
    if (currentUserId != null && currentUserId.isNotEmpty && senderIdStr.isNotEmpty) {
      isMeFlag = (senderIdStr == currentUserId);
    } else {
      isMeFlag = json['isMe'] == true;
    }

    return Message(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      senderId: senderIdStr.isNotEmpty ? senderIdStr : null,
      senderName: json['senderName'] ?? 'User',
      senderAvatar: json['senderAvatar'] ?? '',
      content: json['content'] ?? json['message'] ?? '',
      timestamp: ts,
      isMe: isMeFlag,
      type: msgType,
      attachmentUrl: json['fileUrl'] ?? json['attachmentUrl'],
      isLeader: json['isLeader'] == true || json['senderRole'] == 'tripLeader',
      isEdited: json['isEdited'] == true,
    );
  }
}

