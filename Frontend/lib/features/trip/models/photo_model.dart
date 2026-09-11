class Photo {
  final String id;
  final String tripId;
  final PhotoUploader uploader;
  final String photoUrl;
  final String visibility;
  final List<String> permittedUsers;
  final DateTime createdAt;

  Photo({
    required this.id,
    required this.tripId,
    required this.uploader,
    required this.photoUrl,
    required this.visibility,
    required this.permittedUsers,
    required this.createdAt,
  });

  factory Photo.fromJson(Map<String, dynamic> json) {
    return Photo(
      id: json['_id']?.toString() ?? '',
      tripId: json['tripId']?.toString() ?? '',
      uploader: json['uploaderId'] is Map<String, dynamic> 
          ? PhotoUploader.fromJson(json['uploaderId']) 
          : PhotoUploader(id: json['uploaderId']?.toString() ?? '', name: 'Unknown', email: ''),
      photoUrl: json['photoUrl']?.toString() ?? '',
      visibility: json['visibility']?.toString() ?? 'Everyone',
      permittedUsers: json['permittedUsers'] != null ? List<String>.from(json['permittedUsers'].map((x) => x.toString())) : [],
      createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now() : DateTime.now(),
    );
  }
}

class PhotoUploader {
  final String id;
  final String name;
  final String email;
  final String? profilePhoto;

  PhotoUploader({
    required this.id,
    required this.name,
    required this.email,
    this.profilePhoto,
  });

  factory PhotoUploader.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return PhotoUploader(id: '', name: 'Unknown', email: '');
    }
    
    String fullName = 'Unknown User';
    if (json['name'] != null) {
      fullName = json['name'].toString();
    } else if (json['firstName'] != null || json['lastName'] != null) {
      fullName = '${json['firstName'] ?? ''} ${json['lastName'] ?? ''}'.trim();
      if (fullName.isEmpty) fullName = 'Unknown User';
    }

    return PhotoUploader(
      id: json['_id']?.toString() ?? '',
      name: fullName,
      email: json['email']?.toString() ?? '',
      profilePhoto: json['profilePhoto']?.toString(),
    );
  }
}
