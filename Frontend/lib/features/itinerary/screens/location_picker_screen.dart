import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/config/map_config.dart';
import '../../trip/services/geoapify_service.dart';

class LocationPickerScreen extends StatefulWidget {
  final LatLng? initialLocation;
  final String? initialLocationName;

  const LocationPickerScreen({
    super.key,
    this.initialLocation,
    this.initialLocationName,
  });

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();
  final GeoapifyService _geoapifyService = GeoapifyService();

  late LatLng _selectedLocation;
  String _placeTitle = '';
  String _placeSubtitle = '';

  bool _isDraggingMap = false;
  bool _isLoadingGps = false;
  bool _isSearching = false;
  bool _isReverseGeocoding = false;

  Timer? _searchDebounceTimer;
  Timer? _dragDebounceTimer;
  List<Map<String, dynamic>> _searchResults = [];

  // Default coordinate: Ahmedabad / Gujarat fallback
  static const LatLng _fallbackLocation = LatLng(23.0225, 72.5714);

  @override
  void initState() {
    super.initState();
    _selectedLocation = widget.initialLocation ?? _fallbackLocation;
    _placeTitle = widget.initialLocationName?.trim().isNotEmpty == true
        ? widget.initialLocationName!.trim()
        : 'Selected Location';

    if (widget.initialLocation != null) {
      _reverseGeocode(_selectedLocation);
    } else {
      _detectInitialUserPosition();
    }
  }

  @override
  void dispose() {
    _searchDebounceTimer?.cancel();
    _dragDebounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _detectInitialUserPosition() async {
    try {
      final pos = await Geolocator.getLastKnownPosition();
      if (pos != null && mounted) {
        final loc = LatLng(pos.latitude, pos.longitude);
        setState(() {
          _selectedLocation = loc;
        });
        _mapController.move(loc, 15.5);
        _reverseGeocode(loc);
      } else {
        _reverseGeocode(_selectedLocation);
      }
    } catch (_) {
      _reverseGeocode(_selectedLocation);
    }
  }

  Future<void> _jumpToCurrentGps() async {
    setState(() => _isLoadingGps = true);
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Location permission is needed to detect your current position.'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );

      final newPoint = LatLng(position.latitude, position.longitude);
      if (mounted) {
        setState(() {
          _selectedLocation = newPoint;
          _searchResults = [];
        });
        _mapController.move(newPoint, 16.5);
        _reverseGeocode(newPoint);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not fetch current GPS location: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingGps = false);
    }
  }

  void _onSearchChanged(String query) {
    _searchDebounceTimer?.cancel();
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    _searchDebounceTimer = Timer(const Duration(milliseconds: 400), () {
      _searchPlace(query);
    });
  }

  Future<void> _searchPlace(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;

    setState(() => _isSearching = true);
    try {
      final res = await _geoapifyService.autocomplete(
        query: trimmed,
        proximity: _selectedLocation,
        limit: 6,
      );

      if (res.success && res.data != null && res.data!.isNotEmpty) {
        if (mounted) {
          setState(() {
            _searchResults = res.data!.map((place) {
              return {
                'title': place.name,
                'subtitle': place.formatted,
                'lat': place.latitude,
                'lon': place.longitude,
              };
            }).toList();
          });
        }
      } else {
        // Fallback to nominatim if geoapify key is missing
        await _fallbackSearchPlace(trimmed);
      }
    } catch (e) {
      debugPrint('Error searching location: $e');
      await _fallbackSearchPlace(trimmed);
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  Future<void> _fallbackSearchPlace(String trimmed) async {
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(trimmed)}&format=json&limit=6&addressdetails=1',
      );
      final response = await http.get(url, headers: {
        'User-Agent': 'TripSyncApp/1.0 (com.tripsync.app)',
      });

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            _searchResults = data.map((item) {
              final displayName = item['display_name']?.toString() ?? '';
              final name = item['name']?.toString() ?? displayName.split(',').first;
              return {
                'title': name.isNotEmpty ? name : displayName.split(',').first,
                'subtitle': displayName,
                'lat': double.tryParse(item['lat']?.toString() ?? '') ?? 0.0,
                'lon': double.tryParse(item['lon']?.toString() ?? '') ?? 0.0,
              };
            }).where((item) => item['lat'] != 0.0 && item['lon'] != 0.0).toList();
          });
        }
      }
    } catch (_) {}
  }

  void _selectSearchResult(Map<String, dynamic> item) {
    final lat = item['lat'] as double;
    final lon = item['lon'] as double;
    final point = LatLng(lat, lon);

    setState(() {
      _selectedLocation = point;
      _placeTitle = item['title'] as String;
      _placeSubtitle = item['subtitle'] as String;
      _searchResults = [];
      _searchController.text = _placeTitle;
    });

    FocusScope.of(context).unfocus();
    _mapController.move(point, 16.5);
  }

  Future<void> _reverseGeocode(LatLng point) async {
    setState(() => _isReverseGeocoding = true);
    try {
      final res = await _geoapifyService.reverseGeocode(point);
      if (res.success && res.data != null) {
        final place = res.data!;
        if (mounted) {
          setState(() {
            _placeTitle = place.name;
            _placeSubtitle = place.formatted;
          });
        }
        return;
      }

      // Fallback reverse geocoding if Geoapify key is unconfigured
      await _fallbackReverseGeocode(point);
    } catch (e) {
      debugPrint('Error reverse geocoding: $e');
      await _fallbackReverseGeocode(point);
    } finally {
      if (mounted) setState(() => _isReverseGeocoding = false);
    }
  }

  Future<void> _fallbackReverseGeocode(LatLng point) async {
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?lat=${point.latitude}&lon=${point.longitude}&format=json&addressdetails=1',
      );
      final response = await http.get(url, headers: {
        'User-Agent': 'TripSyncApp/1.0 (com.tripsync.app)',
      });

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final displayName = data['display_name']?.toString() ?? '';
        final address = data['address'] as Map<String, dynamic>? ?? {};

        final title = address['tourism'] ??
            address['amenity'] ??
            address['building'] ??
            address['road'] ??
            address['suburb'] ??
            address['city'] ??
            address['town'] ??
            displayName.split(',').first.trim();

        if (mounted) {
          setState(() {
            _placeTitle = title.toString().isNotEmpty ? title.toString() : 'Selected Pin';
            _placeSubtitle = displayName;
          });
        }
      }
    } catch (_) {}
  }

  void _onPositionChanged(MapCamera camera, bool hasGesture) {
    setState(() {
      _selectedLocation = camera.center;
      if (hasGesture) {
        _isDraggingMap = true;
      }
    });

    // Debounce reverse geocoding after user stops moving the map
    _dragDebounceTimer?.cancel();
    _dragDebounceTimer = Timer(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() {
          _isDraggingMap = false;
        });
        _reverseGeocode(camera.center);
      }
    });
  }

  void _confirmAndReturn() {
    Navigator.pop(context, {
      'latitude': _selectedLocation.latitude,
      'longitude': _selectedLocation.longitude,
      'address': _placeTitle.isNotEmpty ? _placeTitle : 'Pinned Location',
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // 1. Full Screen Interactive Map with Smooth Drag & Pan
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _selectedLocation,
              initialZoom: 15.5,
              minZoom: 3.0,
              maxZoom: 18.0,
              onPositionChanged: _onPositionChanged,
              onTap: (_, point) {
                FocusScope.of(context).unfocus();
                setState(() {
                  _searchResults = [];
                });
                _mapController.move(point, _mapController.camera.zoom);
              },
            ),
            children: [
              TileLayer(
                urlTemplate: MapConfig.tileUrlTemplate,
                userAgentPackageName: MapConfig.userAgentPackageName,
              ),
              RichAttributionWidget(
                attributions: const [
                  TextSourceAttribution(
                    MapConfig.osmAttribution,
                  ),
                ],
              ),
            ],
          ),

          // 2. Center Pickup Pin (Like Uber / Swiggy / Google Maps)
          // Always anchored in the center of the viewport
          Center(
            child: IgnorePointer(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 42.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Floating Badge during movement
                    AnimatedOpacity(
                      duration: const Duration(milliseconds: 200),
                      opacity: _isDraggingMap ? 1.0 : 0.0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        margin: const EdgeInsets.only(bottom: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                        child: const Text(
                          'Release to set pin',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),

                    // Pickup Pin Icon with Lift Animation
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      transform: Matrix4.translationValues(0, _isDraggingMap ? -10 : 0, 0),
                      child: Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE11D48),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2.5),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFE11D48).withOpacity(0.4),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.location_on,
                          size: 26,
                          color: Colors.white,
                        ),
                      ),
                    ),

                    // Pin Needle Target Shadow / Dot
                    Container(
                      margin: const EdgeInsets.only(top: 2),
                      width: 8,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 3. Top Header Bar & Search Box
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Row(
                    children: [
                      // Back Button
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.12),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.arrow_back_ios_new, size: 18, color: Color(0xFF0F172A)),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ),
                      const SizedBox(width: 10),

                      // Search Input Box
                      Expanded(
                        child: Container(
                          height: 48,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.12),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: TextField(
                            controller: _searchController,
                            textInputAction: TextInputAction.search,
                            onChanged: _onSearchChanged,
                            onSubmitted: (val) {
                              FocusScope.of(context).unfocus();
                              _searchPlace(val);
                            },
                            decoration: InputDecoration(
                              hintText: 'Search city, landmark or address...',
                              hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                              prefixIcon: IconButton(
                                icon: const Icon(Icons.search, color: Color(0xFF0072FF), size: 20),
                                onPressed: () {
                                  FocusScope.of(context).unfocus();
                                  _searchPlace(_searchController.text);
                                },
                              ),
                              suffixIcon: _searchController.text.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear, size: 18, color: Color(0xFF94A3B8)),
                                      onPressed: () {
                                        _searchController.clear();
                                        setState(() => _searchResults = []);
                                      },
                                    )
                                  : null,
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Live Search Loading Spinner
                if (_isSearching)
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0072FF)),
                        ),
                        SizedBox(width: 12),
                        Text('Searching places...', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                      ],
                    ),
                  ),

                // Search Results Dropdown List
                if (_searchResults.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    constraints: const BoxConstraints(maxHeight: 240),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.15),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      shrinkWrap: true,
                      itemCount: _searchResults.length,
                      separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                      itemBuilder: (context, idx) {
                        final item = _searchResults[idx];
                        return ListTile(
                          dense: true,
                          leading: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0072FF).withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.location_on, color: Color(0xFF0072FF), size: 18),
                          ),
                          title: Text(
                            item['title'] as String,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                          ),
                          subtitle: Text(
                            item['subtitle'] as String,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                          ),
                          onTap: () => _selectSearchResult(item),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),

          // 4. Floating Action Controls (Zoom In, Zoom Out, Live GPS Button)
          Positioned(
            right: 16,
            bottom: 20,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Zoom In Button
                FloatingActionButton.small(
                  heroTag: 'btnZoomIn',
                  backgroundColor: Colors.white,
                  elevation: 4,
                  onPressed: () {
                    final zoom = _mapController.camera.zoom + 1.0;
                    _mapController.move(_selectedLocation, zoom.clamp(3.0, 18.0));
                  },
                  child: const Icon(Icons.add, color: Color(0xFF0F172A), size: 20),
                ),
                const SizedBox(height: 8),

                // Zoom Out Button
                FloatingActionButton.small(
                  heroTag: 'btnZoomOut',
                  backgroundColor: Colors.white,
                  elevation: 4,
                  onPressed: () {
                    final zoom = _mapController.camera.zoom - 1.0;
                    _mapController.move(_selectedLocation, zoom.clamp(3.0, 18.0));
                  },
                  child: const Icon(Icons.remove, color: Color(0xFF0F172A), size: 20),
                ),
                const SizedBox(height: 8),

                // Live GPS "My Location" Button
                FloatingActionButton(
                  heroTag: 'btnGps',
                  backgroundColor: Colors.white,
                  elevation: 6,
                  onPressed: _isLoadingGps ? null : _jumpToCurrentGps,
                  child: _isLoadingGps
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0072FF)),
                        )
                      : const Icon(Icons.my_location, color: Color(0xFF0072FF), size: 24),
                ),
              ],
            ),
          ),
        ],
      ),

      // 5. Always Visible Bottom Navigation Bar / Confirmation Card
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 16,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Location Info Row
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 2),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE11D48).withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.pin_drop, color: Color(0xFFE11D48), size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                _placeTitle.isNotEmpty ? _placeTitle : 'Pinned Location',
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0F172A),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (_isReverseGeocoding)
                              const Padding(
                                padding: EdgeInsets.only(left: 6.0),
                                child: SizedBox(
                                  width: 12,
                                  height: 12,
                                  child: CircularProgressIndicator(strokeWidth: 1.5, color: Color(0xFF0072FF)),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _placeSubtitle.isNotEmpty
                              ? _placeSubtitle
                              : '${_selectedLocation.latitude.toStringAsFixed(5)}, ${_selectedLocation.longitude.toStringAsFixed(5)}',
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: Color(0xFF64748B),
                            height: 1.25,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Coordinates Tag & Confirm Button
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${_selectedLocation.latitude.toStringAsFixed(4)}, ${_selectedLocation.longitude.toStringAsFixed(4)}',
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF334155),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      height: 46,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF00C6FF), Color(0xFF0072FF)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF0072FF).withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: ElevatedButton.icon(
                        onPressed: _confirmAndReturn,
                        icon: const Icon(Icons.check_circle_outline, size: 18, color: Colors.white),
                        label: const Text(
                          'Confirm Location',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
