enum MessageType {
  text,
  system,
  image,
  location,
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
  });
}
