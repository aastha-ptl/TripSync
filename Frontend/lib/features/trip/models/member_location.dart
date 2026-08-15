class MemberLocation {
  final String id;
  final String name;
  final String profileImage;
  final double latitude;
  final double longitude;
  final String familyName;
  final bool isOnline;
  final DateTime lastUpdated;

  const MemberLocation({
    required this.id,
    required this.name,
    required this.profileImage,
    required this.latitude,
    required this.longitude,
    required this.familyName,
    required this.isOnline,
    required this.lastUpdated,
  });
}
