import 'geoapify_place.dart';

enum LocationType {
  hotel,
  airport,
  restaurant,
  sightseeing,
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
  final String? address;
  final Map<String, dynamic>? rawActivity;
  final bool isPublicPlace;
  final GeoapifyPlace? placeDetails;

  const TripLocation({
    required this.id,
    required this.title,
    required this.latitude,
    required this.longitude,
    required this.type,
    required this.description,
    this.address,
    this.rawActivity,
    this.isPublicPlace = false,
    this.placeDetails,
  });
}
