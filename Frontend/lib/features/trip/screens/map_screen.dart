import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/theme/app_colors.dart';
import '../models/member_location.dart';
import '../models/trip_location.dart';
import '../data/dummy_map_data.dart';
import '../widgets/member_map_marker.dart';
import '../widgets/location_info_card.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();
  String _activeFilter = 'All'; // 'All', 'Members', 'Activities', 'Hotels'
  String _searchQuery = '';

  MemberLocation? _selectedMember;
  TripLocation? _selectedLocation;

  // Center coordinate of Paris (our dummy trip location)
  final LatLng _mapCenter = const LatLng(48.8566, 2.3522);

  List<MemberLocation> get _filteredMembers {
    return dummyMembers.where((m) {
      final matchesFilter = _activeFilter == 'All' || _activeFilter == 'Members';
      final matchesSearch = _searchQuery.isEmpty ||
          m.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          m.familyName.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesFilter && matchesSearch;
    }).toList();
  }

  List<TripLocation> get _filteredLocations {
    return dummyLocations.where((l) {
      final matchesFilter = _activeFilter == 'All' ||
          (_activeFilter == 'Hotels' && l.type == LocationType.hotel) ||
          (_activeFilter == 'Activities' && l.type == LocationType.activity);
      final matchesSearch = _searchQuery.isEmpty ||
          l.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          l.description.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesFilter && matchesSearch;
    }).toList();
  }

  void _centerOn(LatLng point) {
    _mapController.move(point, 15.0);
  }

  @override
  Widget build(BuildContext context) {
    final filteredMembersList = _filteredMembers;
    final filteredLocationsList = _filteredLocations;

    return Scaffold(
      body: Stack(
        children: [
          // OpenStreetMap Tile Layer using flutter_map
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _mapCenter,
              initialZoom: 14.0,
              minZoom: 3.0,
              maxZoom: 18.0,
              onTap: (_, __) {
                setState(() {
                  _selectedMember = null;
                  _selectedLocation = null;
                });
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.tripsync.app',
              ),
              // Trip POI Locations Markers Layer
              MarkerLayer(
                markers: filteredLocationsList.map((loc) {
                  final isSelected = _selectedLocation?.id == loc.id;
                  return Marker(
                    point: LatLng(loc.latitude, loc.longitude),
                    width: 48,
                    height: 48,
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedLocation = loc;
                          _selectedMember = null;
                        });
                        _centerOn(LatLng(loc.latitude, loc.longitude));
                      },
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isSelected ? AppColors.primary : Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.15),
                              blurRadius: 6,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Icon(
                          _getLocationIcon(loc.type),
                          color: isSelected ? Colors.white : _getLocationColor(loc.type),
                          size: 20,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              // Member Location Markers Layer
              MarkerLayer(
                markers: filteredMembersList.map((member) {
                  final isCurrentUser = member.id == 'm1'; // Aastha Patel is current user
                  return Marker(
                    point: LatLng(member.latitude, member.longitude),
                    width: 70,
                    height: 75,
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedMember = member;
                          _selectedLocation = null;
                        });
                        _centerOn(LatLng(member.latitude, member.longitude));
                      },
                      child: MemberMapMarker(
                        member: member,
                        isCurrentUser: isCurrentUser,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),

          // Custom Header Overlay with Search Input
          Positioned(
            top: 50,
            left: 16,
            right: 16,
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.06),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: const Icon(Icons.arrow_back, color: Color(0xFF0F172A), size: 20),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.06),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: TextField(
                      onChanged: (val) {
                        setState(() {
                          _searchQuery = val;
                        });
                      },
                      style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A)),
                      decoration: InputDecoration(
                        hintText: 'Search members, hotels, activities...',
                        hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                        prefixIcon: const Icon(Icons.search, color: Color(0xFF64748B), size: 20),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Filter Chips Panel
          Positioned(
            top: 110,
            left: 16,
            right: 16,
            child: SizedBox(
              height: 38,
              child: ListView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                children: [
                  _buildFilterChip('All'),
                  _buildFilterChip('Members'),
                  _buildFilterChip('Activities'),
                  _buildFilterChip('Hotels'),
                ],
              ),
            ),
          ),

          // Zoom Controls Panel
          Positioned(
            right: 16,
            bottom: (_selectedMember != null || _selectedLocation != null) ? 220 : 100,
            child: Column(
              children: [
                // Center Map Button
                GestureDetector(
                  onTap: () => _centerOn(_mapCenter),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: const Icon(Icons.my_location, color: AppColors.primary, size: 22),
                  ),
                ),
                // Zoom controls
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      GestureDetector(
                        onTap: () {
                          _mapController.move(
                            _mapController.camera.center,
                            _mapController.camera.zoom + 1,
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: const BoxDecoration(
                            border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
                          ),
                          child: const Icon(Icons.add, color: Color(0xFF0F172A), size: 20),
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          _mapController.move(
                            _mapController.camera.center,
                            _mapController.camera.zoom - 1,
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          child: const Icon(Icons.remove, color: Color(0xFF0F172A), size: 20),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Interactive Bottom Sheet Details Card
          if (_selectedMember != null || _selectedLocation != null)
            Positioned(
              left: 16,
              right: 16,
              bottom: 30,
              child: LocationInfoCard(
                member: _selectedMember,
                tripLocation: _selectedLocation,
                onClose: () {
                  setState(() {
                    _selectedMember = null;
                    _selectedLocation = null;
                  });
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label) {
    final isSelected = _activeFilter == label;
    return GestureDetector(
      onTap: () {
        setState(() {
          _activeFilter = label;
          _selectedMember = null;
          _selectedLocation = null;
        });
      },
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.white : const Color(0xFF64748B),
          ),
        ),
      ),
    );
  }

  IconData _getLocationIcon(LocationType type) {
    switch (type) {
      case LocationType.hotel:
        return Icons.hotel;
      case LocationType.airport:
        return Icons.local_airport;
      case LocationType.activity:
        return Icons.local_activity;
      case LocationType.general:
        return Icons.location_on;
    }
  }

  Color _getLocationColor(LocationType type) {
    switch (type) {
      case LocationType.hotel:
        return const Color(0xFF20C060);
      case LocationType.airport:
        return const Color(0xFFEA580C);
      case LocationType.activity:
        return const Color(0xFF9333EA);
      case LocationType.general:
        return const Color(0xFF1E5AE6);
    }
  }
}
