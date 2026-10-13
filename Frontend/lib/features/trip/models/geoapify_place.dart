import 'package:flutter/material.dart';
import 'trip_location.dart';

/// Represents a place returned by the Geoapify Places, Autocomplete, or Geocoding APIs.
class GeoapifyPlace {
  final String placeId;
  final String name;
  final String formatted;
  final String? addressLine1;
  final String? addressLine2;
  final String? street;
  final String? city;
  final String? state;
  final String? country;
  final String? postcode;
  final double latitude;
  final double longitude;
  final List<String> categories;
  final String? phone;
  final String? website;
  final String? openingHours;
  final double? distanceMeters;
  final String? dataSource;
  final Map<String, dynamic> rawProperties;

  const GeoapifyPlace({
    required this.placeId,
    required this.name,
    required this.formatted,
    this.addressLine1,
    this.addressLine2,
    this.street,
    this.city,
    this.state,
    this.country,
    this.postcode,
    required this.latitude,
    required this.longitude,
    this.categories = const [],
    this.phone,
    this.website,
    this.openingHours,
    this.distanceMeters,
    this.dataSource,
    this.rawProperties = const {},
  });

  factory GeoapifyPlace.fromFeature(Map<String, dynamic> feature) {
    final props = feature['properties'] as Map<String, dynamic>? ?? {};
    final geom = feature['geometry'] as Map<String, dynamic>? ?? {};
    final coords = geom['coordinates'] as List<dynamic>?;

    double lat = 0.0;
    double lon = 0.0;

    if (props['lat'] != null && props['lon'] != null) {
      lat = (props['lat'] as num).toDouble();
      lon = (props['lon'] as num).toDouble();
    } else if (coords != null && coords.length >= 2) {
      lon = (coords[0] as num).toDouble();
      lat = (coords[1] as num).toDouble();
    }

    final cats = (props['categories'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        [];

    final contact = props['contact'] as Map<String, dynamic>?;
    final phone = contact?['phone']?.toString() ?? props['phone']?.toString();
    final website = contact?['website']?.toString() ?? props['website']?.toString();

    // Extract opening hours only when genuinely available from data source
    String? openingHours = props['opening_hours']?.toString();
    if (openingHours == null && props['datasource'] is Map) {
      final raw = props['datasource']['raw'];
      if (raw is Map && raw['opening_hours'] != null) {
        openingHours = raw['opening_hours'].toString();
      }
    }

    final formattedStr = props['formatted']?.toString() ?? '';
    final nameStr = props['name']?.toString() ??
        props['address_line1']?.toString() ??
        (formattedStr.isNotEmpty ? formattedStr.split(',').first.trim() : 'Place');

    return GeoapifyPlace(
      placeId: props['place_id']?.toString() ??
          props['osm_id']?.toString() ??
          '${lat}_$lon',
      name: nameStr,
      formatted: formattedStr.isNotEmpty ? formattedStr : nameStr,
      addressLine1: props['address_line1']?.toString(),
      addressLine2: props['address_line2']?.toString(),
      street: props['street']?.toString(),
      city: props['city']?.toString(),
      state: props['state']?.toString(),
      country: props['country']?.toString(),
      postcode: props['postcode']?.toString(),
      latitude: lat,
      longitude: lon,
      categories: cats,
      phone: phone,
      website: website,
      openingHours: openingHours,
      distanceMeters: (props['distance'] as num?)?.toDouble(),
      dataSource: (props['datasource'] is Map ? props['datasource']['sourcename'] : null)?.toString(),
      rawProperties: props,
    );
  }

  /// Human-friendly primary category label
  String get categoryLabel {
    for (final cat in categories) {
      final lower = cat.toLowerCase();
      if (lower.contains('hotel') || lower.contains('accommodation') || lower.contains('motel')) {
        return 'Hotel & Lodging';
      }
      if (lower.contains('restaurant') || lower.contains('cafe') || lower.contains('catering')) {
        return 'Restaurant & Dining';
      }
      if (lower.contains('sights') || lower.contains('attraction') || lower.contains('tourism')) {
        return 'Sightseeing';
      }
      if (lower.contains('airport') || lower.contains('flight')) {
        return 'Airport';
      }
      if (lower.contains('railway') || lower.contains('train') || lower.contains('subway')) {
        return 'Railway Station';
      }
      if (lower.contains('bus') || lower.contains('public_transport')) {
        return 'Bus / Transit Station';
      }
      if (lower.contains('hospital') || lower.contains('pharmacy') || lower.contains('healthcare')) {
        return 'Health & Medical';
      }
      if (lower.contains('shopping') || lower.contains('mall') || lower.contains('supermarket')) {
        return 'Shopping & Market';
      }
      if (lower.contains('museum')) {
        return 'Museum';
      }
      if (lower.contains('park') || lower.contains('garden')) {
        return 'Park & Recreation';
      }
      if (lower.contains('worship') || lower.contains('temple') || lower.contains('church') || lower.contains('mosque')) {
        return 'Place of Worship';
      }
    }
    return 'Point of Interest';
  }

  /// Visual icon for this place based on its category
  IconData get categoryIcon {
    for (final cat in categories) {
      final lower = cat.toLowerCase();
      if (lower.contains('hotel') || lower.contains('accommodation')) return Icons.hotel_rounded;
      if (lower.contains('restaurant') || lower.contains('cafe') || lower.contains('catering')) return Icons.restaurant_rounded;
      if (lower.contains('sights') || lower.contains('attraction') || lower.contains('tourism')) return Icons.photo_camera_rounded;
      if (lower.contains('airport')) return Icons.local_airport_rounded;
      if (lower.contains('railway') || lower.contains('train') || lower.contains('subway')) return Icons.train_rounded;
      if (lower.contains('bus') || lower.contains('public_transport')) return Icons.directions_bus_rounded;
      if (lower.contains('hospital') || lower.contains('pharmacy')) return Icons.local_hospital_rounded;
      if (lower.contains('shopping') || lower.contains('mall')) return Icons.shopping_bag_rounded;
      if (lower.contains('museum')) return Icons.museum_rounded;
      if (lower.contains('park')) return Icons.park_rounded;
      if (lower.contains('worship') || lower.contains('temple')) return Icons.account_balance_rounded;
    }
    return Icons.place_rounded;
  }

  /// Theme color for this category
  Color get categoryColor {
    for (final cat in categories) {
      final lower = cat.toLowerCase();
      if (lower.contains('hotel') || lower.contains('accommodation')) return const Color(0xFF20C060); // Emerald green
      if (lower.contains('restaurant') || lower.contains('cafe') || lower.contains('catering')) return const Color(0xFFF59E0B); // Amber
      if (lower.contains('sights') || lower.contains('attraction') || lower.contains('tourism')) return const Color(0xFF0EA5E9); // Cyan / Blue
      if (lower.contains('airport') || lower.contains('flight')) return const Color(0xFFEA580C); // Orange
      if (lower.contains('railway') || lower.contains('train') || lower.contains('bus') || lower.contains('transport')) return const Color(0xFF6366F1); // Indigo
      if (lower.contains('hospital') || lower.contains('pharmacy')) return const Color(0xFFEF4444); // Red
      if (lower.contains('shopping')) return const Color(0xFFEC4899); // Pink
      if (lower.contains('museum') || lower.contains('park')) return const Color(0xFF10B981); // Mint
    }
    return const Color(0xFF3B82F6);
  }

  /// Converts this Geoapify place into a TripLocation model
  TripLocation toTripLocation() {
    LocationType locType = LocationType.general;
    for (final cat in categories) {
      final lower = cat.toLowerCase();
      if (lower.contains('hotel') || lower.contains('accommodation')) {
        locType = LocationType.hotel;
        break;
      }
      if (lower.contains('restaurant') || lower.contains('cafe') || lower.contains('catering')) {
        locType = LocationType.restaurant;
        break;
      }
      if (lower.contains('sights') || lower.contains('attraction') || lower.contains('tourism') || lower.contains('museum') || lower.contains('park')) {
        locType = LocationType.sightseeing;
        break;
      }
      if (lower.contains('airport') || lower.contains('flight')) {
        locType = LocationType.airport;
        break;
      }
      if (lower.contains('bus') || lower.contains('train') || lower.contains('transport')) {
        locType = LocationType.airport;
        break;
      }
    }

    return TripLocation(
      id: placeId,
      title: name,
      latitude: latitude,
      longitude: longitude,
      type: locType,
      description: formatted,
      address: formatted,
      isPublicPlace: true,
      placeDetails: this,
    );
  }
}
