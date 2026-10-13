import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import '../../../core/config/map_config.dart';
import '../models/geoapify_place.dart';

/// Categories supported by Geoapify Places API v2
class GeoapifyCategories {
  static const String hotels = 'accommodation,accommodation.hotel,accommodation.motel,accommodation.guest_house,accommodation.hostel';
  static const String sightseeing = 'tourism,tourism.sights,tourism.attraction,entertainment.museum,leisure.park,heritage,religion.place_of_worship';
  static const String restaurants = 'catering,catering.restaurant,catering.cafe,catering.fast_food,catering.bar';
  static const String transit = 'airport,public_transport,public_transport.train,public_transport.subway,public_transport.bus';
  static const String health = 'healthcare,healthcare.hospital,healthcare.pharmacy';
  static const String shopping = 'commercial.shopping_mall,commercial.marketplace,commercial.supermarket';
}

/// Result wrapper for Geoapify API responses with typed errors
class GeoapifyResult<T> {
  final bool success;
  final T? data;
  final String? errorMessage;
  final bool isRateLimited;
  final bool isKeyMissingOrInvalid;

  const GeoapifyResult.success(this.data)
      : success = true,
        errorMessage = null,
        isRateLimited = false,
        isKeyMissingOrInvalid = false;

  const GeoapifyResult.error(
    this.errorMessage, {
    this.isRateLimited = false,
    this.isKeyMissingOrInvalid = false,
  })  : success = false,
        data = null;
}

/// Service providing Public Place Search, Autocomplete, Categories, and Reverse Geocoding
/// via Geoapify free-tier APIs (https://api.geoapify.com)
class GeoapifyService {
  final http.Client _client;

  GeoapifyService({http.Client? client}) : _client = client ?? http.Client();

  /// Autocomplete address and place search as user types
  Future<GeoapifyResult<List<GeoapifyPlace>>> autocomplete({
    required String query,
    LatLng? proximity,
    int limit = 8,
  }) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      return const GeoapifyResult.success([]);
    }

    final apiKey = MapConfig.geoapifyApiKey;
    if (apiKey.isEmpty) {
      return const GeoapifyResult.error(
        'Geoapify API key is not configured. Add GEOAPIFY_API_KEY in .env file.',
        isKeyMissingOrInvalid: true,
      );
    }

    try {
      final queryParams = {
        'text': trimmed,
        'limit': limit.toString(),
        'apiKey': apiKey,
      };

      if (proximity != null && _isValidCoordinate(proximity.latitude, proximity.longitude)) {
        // Geoapify format: proximity:lon,lat
        queryParams['bias'] = 'proximity:${proximity.longitude},${proximity.latitude}';
      }

      final uri = Uri.https('api.geoapify.com', '/v1/geocode/autocomplete', queryParams);
      final response = await _client.get(
        uri,
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      return _handlePlacesResponse(response);
    } catch (e) {
      debugPrint('[GeoapifyService] Autocomplete error: $e');
      return GeoapifyResult.error('Network connection error: ${e.toString()}');
    }
  }

  /// Search places by category around a center point (Places API v2)
  Future<GeoapifyResult<List<GeoapifyPlace>>> searchPlacesByCategory({
    required String categories,
    required LatLng center,
    double radiusMeters = 5000,
    int limit = 20,
  }) async {
    final apiKey = MapConfig.geoapifyApiKey;
    if (apiKey.isEmpty) {
      return const GeoapifyResult.error(
        'Geoapify API key is not configured. Add GEOAPIFY_API_KEY in .env file.',
        isKeyMissingOrInvalid: true,
      );
    }

    if (!_isValidCoordinate(center.latitude, center.longitude)) {
      return const GeoapifyResult.error('Invalid search coordinates provided.');
    }

    try {
      final queryParams = {
        'categories': categories,
        'filter': 'circle:${center.longitude},${center.latitude},${radiusMeters.round()}',
        'bias': 'proximity:${center.longitude},${center.latitude}',
        'limit': limit.toString(),
        'apiKey': apiKey,
      };

      final uri = Uri.https('api.geoapify.com', '/v2/places', queryParams);
      final response = await _client.get(
        uri,
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 12));

      return _handlePlacesResponse(response);
    } catch (e) {
      debugPrint('[GeoapifyService] Places by category error: $e');
      return GeoapifyResult.error('Network connection error: ${e.toString()}');
    }
  }

  /// Search places by text / place name (Geocoding Search API v1)
  Future<GeoapifyResult<List<GeoapifyPlace>>> searchByText({
    required String text,
    LatLng? proximity,
    int limit = 10,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      return const GeoapifyResult.success([]);
    }

    final apiKey = MapConfig.geoapifyApiKey;
    if (apiKey.isEmpty) {
      return const GeoapifyResult.error(
        'Geoapify API key is not configured. Add GEOAPIFY_API_KEY in .env file.',
        isKeyMissingOrInvalid: true,
      );
    }

    try {
      final queryParams = {
        'text': trimmed,
        'limit': limit.toString(),
        'apiKey': apiKey,
      };

      if (proximity != null && _isValidCoordinate(proximity.latitude, proximity.longitude)) {
        queryParams['bias'] = 'proximity:${proximity.longitude},${proximity.latitude}';
      }

      final uri = Uri.https('api.geoapify.com', '/v1/geocode/search', queryParams);
      final response = await _client.get(
        uri,
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      return _handlePlacesResponse(response);
    } catch (e) {
      debugPrint('[GeoapifyService] Search by text error: $e');
      return GeoapifyResult.error('Network connection error: ${e.toString()}');
    }
  }

  /// Reverse geocode coordinates to place details and formatted address
  Future<GeoapifyResult<GeoapifyPlace?>> reverseGeocode(LatLng point) async {
    final apiKey = MapConfig.geoapifyApiKey;
    if (apiKey.isEmpty) {
      return const GeoapifyResult.error(
        'Geoapify API key is not configured. Add GEOAPIFY_API_KEY in .env file.',
        isKeyMissingOrInvalid: true,
      );
    }

    if (!_isValidCoordinate(point.latitude, point.longitude)) {
      return const GeoapifyResult.error('Invalid coordinates for reverse geocoding.');
    }

    try {
      final queryParams = {
        'lat': point.latitude.toString(),
        'lon': point.longitude.toString(),
        'apiKey': apiKey,
      };

      final uri = Uri.https('api.geoapify.com', '/v1/geocode/reverse', queryParams);
      final response = await _client.get(
        uri,
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final Map<String, dynamic> body = jsonDecode(response.body);
        final features = body['features'] as List<dynamic>?;
        if (features != null && features.isNotEmpty) {
          final top = features.first as Map<String, dynamic>;
          return GeoapifyResult.success(GeoapifyPlace.fromFeature(top));
        }
        return const GeoapifyResult.success(null);
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        return const GeoapifyResult.error(
          'Invalid or unauthorized Geoapify API key.',
          isKeyMissingOrInvalid: true,
        );
      } else if (response.statusCode == 429) {
        return const GeoapifyResult.error(
          'Geoapify free rate limit reached. Please wait a moment.',
          isRateLimited: true,
        );
      } else {
        return GeoapifyResult.error('Reverse geocode error (${response.statusCode})');
      }
    } catch (e) {
      debugPrint('[GeoapifyService] Reverse geocode error: $e');
      return GeoapifyResult.error('Network error: ${e.toString()}');
    }
  }

  /// Shared handler for feature collections
  GeoapifyResult<List<GeoapifyPlace>> _handlePlacesResponse(http.Response response) {
    if (response.statusCode == 200) {
      try {
        final Map<String, dynamic> body = jsonDecode(response.body);
        final features = body['features'] as List<dynamic>? ?? [];

        final List<GeoapifyPlace> places = [];
        for (final item in features) {
          if (item is Map<String, dynamic>) {
            final place = GeoapifyPlace.fromFeature(item);
            // Safely filter out places with invalid or 0.0 coordinates
            if (_isValidCoordinate(place.latitude, place.longitude)) {
              places.add(place);
            }
          }
        }
        return GeoapifyResult.success(places);
      } catch (e) {
        return GeoapifyResult.error('Error parsing place search response: $e');
      }
    } else if (response.statusCode == 401 || response.statusCode == 403) {
      return const GeoapifyResult.error(
        'Invalid or unauthorized Geoapify API key. Check GEOAPIFY_API_KEY in .env.',
        isKeyMissingOrInvalid: true,
      );
    } else if (response.statusCode == 429) {
      return const GeoapifyResult.error(
        'Geoapify free rate limit reached. Please wait a moment.',
        isRateLimited: true,
      );
    } else {
      return GeoapifyResult.error('Geoapify returned HTTP ${response.statusCode}');
    }
  }

  bool _isValidCoordinate(double lat, double lon) {
    return lat >= -90.0 && lat <= 90.0 && lon >= -180.0 && lon <= 180.0 && (lat != 0.0 || lon != 0.0);
  }
}
