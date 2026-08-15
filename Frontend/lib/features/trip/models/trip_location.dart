enum LocationType {
  hotel,
  airport,
  activity,
  general,
}

class TripLocation {
  final String id;
  final String title;
  final double latitude;
  final double longitude;
  final LocationType type;
  final String description;

  const TripLocation({
    required this.id,
    required this.title,
    required this.latitude,
    required this.longitude,
    required this.type,
    required this.description,
  });
}
