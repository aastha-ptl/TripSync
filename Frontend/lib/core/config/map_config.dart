import 'package:latlong2/latlong.dart';
import '../constants/app_constants.dart';

/// Centralized configuration for Map rendering, tile provider, and Geoapify services.
/// Keeps map tile URL and API keys replaceable so alternate providers (e.g., MapTiler, Stadia)
/// can be configured without modifying the map screens.
class MapConfig {
  /// OpenStreetMap tile URL template.
  /// Replaceable via .env (MAP_TILE_URL).
  static String get tileUrlTemplate {
    final configured = AppConstants.mapTileUrl;
    if (configured.trim().isNotEmpty) {
      return configured.trim();
    }
    return 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
  }

  /// Package name identifying TripSync to adhere to OpenStreetMap usage policy.
  static const String userAgentPackageName = 'com.tripsync.app';

  /// Geoapify Places & Geocoding API Key.
  /// Sourced from .env (GEOAPIFY_API_KEY).
  static String get geoapifyApiKey {
    final key = AppConstants.geoapifyApiKey;
    if (key.trim().isNotEmpty) {
      return key.trim();
    }
    return '804f2db71d3c48daa9a5dc662f0ca8c3';
  }

  /// Whether a Geoapify API key is configured.
  static bool get hasGeoapifyKey => geoapifyApiKey.isNotEmpty;

  /// Default center coordinates (e.g. before GPS is acquired).
  static const LatLng defaultCenter = LatLng(20.5937, 78.9629);

  /// Default zoom levels.
  static const double initialZoomWithGps = 15.5;
  static const double initialZoomWithoutGps = 10.0;
  static const double minZoom = 3.0;
  static const double maxZoom = 18.5;

  /// Attributions required by OpenStreetMap and Geoapify free tiers.
  static const String osmAttribution = '© OpenStreetMap contributors';
  static const String geoapifyAttribution = 'Powered by Geoapify';
}
