import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:tripsync/core/utils/image_utils.dart';

import '../../../core/constants/api_endpoints.dart';
import '../../../core/config/map_config.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_formatter.dart';
import '../../auth/services/auth_service.dart';
import '../../itinerary/screens/add_event_screen.dart';
import '../../itinerary/services/itinerary_service.dart';
import '../../profile/services/user_service.dart';
import '../models/member_location.dart';
import '../models/trip_location.dart';
import '../models/geoapify_place.dart';
import '../services/geoapify_service.dart';
import '../services/location_service.dart';
import '../services/trip_service.dart';
import '../widgets/location_info_card.dart';
import '../widgets/member_map_marker.dart';

class MapScreen extends StatefulWidget {
  final Map<String, dynamic>? tripData;

  const MapScreen({super.key, this.tripData});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with SingleTickerProviderStateMixin {
  final MapController _mapController = MapController();
  final LocationService _locationService = LocationService();
  final ItineraryService _itineraryService = ItineraryService();
  final TripService _tripService = TripService();
  final AuthService _authService = AuthService();
  final UserService _userService = UserService();
  final GeoapifyService _geoapifyService = GeoapifyService();

  final TextEditingController _searchController = TextEditingController();

  StreamSubscription<Position>? _positionStreamSubscription;

  // Active Category Filter: 'Members', 'Travel', 'Hotels', 'Sightseeing', 'Restaurants'
  String _activeFilter = 'Travel';
  String _searchQuery = '';
  bool _isSearchFocused = false;

  Timer? _searchDebounceTimer;
  int _searchRequestToken = 0;
  bool _isSearchingGeoapify = false;
  String? _searchErrorMessage;
  bool _isRateLimited = false;

  List<GeoapifyPlace> _geoapifyResults = [];
  List<GeoapifyPlace> _nearbyPoiPlaces = [];
  bool _isLoadingNearbyPois = false;

  MemberLocation? _selectedMember;
  TripLocation? _selectedLocation;

  // Real Mobile GPS coordinates
  LatLng _myLocation = MapConfig.defaultCenter;
  bool _hasAcquiredGps = false;
  bool _isLocationPermissionGranted = false;

  // Permission & live sharing state
  bool _isLocationSharingOn = false;
  bool _hasGrantedPermission = false;
  String? _tripId;
  String? _currentUserId;
  String? _currentUserName;
  String? _currentUserPhoto;

  // Real-time Socket
  io.Socket? _socket;

  // Trip Data
  List<MemberLocation> _membersList = [];
  List<TripLocation> _locationsList = [];
  TripLocation? _customPinnedLocation;
  bool _isTripLeader = false;

  /// Check whether the current date falls strictly within the trip's start and end dates
  bool get _isDuringTrip {
    if (widget.tripData == null) return false;
    final startStr = widget.tripData!['startDate']?.toString();
    final endStr = widget.tripData!['endDate']?.toString();
    if (startStr == null || endStr == null || startStr.trim().isEmpty || endStr.trim().isEmpty) {
      return false;
    }

    try {
      final start = TripInfoHelper.parseTripDate(startStr);
      final end = TripInfoHelper.parseTripDate(endStr);
      final now = DateTime.now();

      final startDay = DateTime(start.year, start.month, start.day, 0, 0, 0);
      final endDay = DateTime(end.year, end.month, end.day, 23, 59, 59);

      return !now.isBefore(startDay) && !now.isAfter(endDay);
    } catch (_) {
      return false;
    }
  }

  /// Available category filters:
  List<String> get _categoryFilters =>
      const ['Members', 'Travel', 'Hotels', 'Sightseeing', 'Restaurants'];

  /// Display "Find Nearby" only:
  /// 1. During active trip dates (never before or after trip)
  /// 2. For Hotels, Sightseeing, Restaurants (never for Travel, never for Members)
  /// 3. When location permission / GPS is enabled on device
  bool get _shouldDisplayFindNearbyButton {
    if (!_isDuringTrip) return false;
    if (_activeFilter == 'Members' || _activeFilter == 'Travel') return false;
    return _canShowFindNearby;
  }

  bool get _canShowFindNearby => _hasAcquiredGps || _isLocationPermissionGranted;

  bool _computeInitialIsTripLeader() {
    if (widget.tripData == null) return false;
    if (widget.tripData!['isTripLeader'] == true) return true;
    final rawRole = (widget.tripData!['role'] ??
            widget.tripData!['participantRole'] ??
            widget.tripData!['originalRole'] ??
            '')
        .toString()
        .toLowerCase();
    return rawRole == 'tripleader' ||
        rawRole == 'trip leader' ||
        rawRole == 'admin' ||
        rawRole == 'creator' ||
        rawRole == 'leader';
  }

  @override
  void initState() {
    super.initState();
    _tripId = (widget.tripData?['_id'] ?? widget.tripData?['id'])?.toString();
    _isTripLeader = _computeInitialIsTripLeader();

    // Set initial filter to Members so trip participants are visible
    _activeFilter = 'Members';

    _initUserDataAndSharing();
    _startDeviceLocationTracking();
    _loadActualTripMembers();
    _loadItineraryLocations();
    _initSocket();
  }

  @override
  void dispose() {
    _searchDebounceTimer?.cancel();
    _positionStreamSubscription?.cancel();
    _socket?.disconnect();
    _socket?.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _initUserDataAndSharing() async {
    _currentUserId = await _authService.getCurrentUserId();

    try {
      final profileRes = await _userService.getProfile();
      if (profileRes['success'] == true && profileRes['data'] != null) {
        final data = profileRes['data'];
        _currentUserName = '${data['firstName'] ?? ''} ${data['lastName'] ?? ''}'.trim();
        _currentUserPhoto = data['profilePhoto']?.toString() ?? '';
        _currentUserId ??= data['_id']?.toString();
      }
    } catch (_) {}

    // Check leadership via createdBy
    final cbObj = widget.tripData?['createdBy'];
    String? createdById;
    if (cbObj is Map && cbObj['_id'] != null) {
      createdById = cbObj['_id'].toString();
    } else if (cbObj != null) {
      createdById = cbObj.toString();
    }

    if (_currentUserId != null && createdById != null && _currentUserId == createdById) {
      _isTripLeader = true;
    }

    // Verify trip leadership via trip participants API if still not confirmed
    if (!_isTripLeader && _tripId != null && _tripId!.isNotEmpty) {
      try {
        final participantsRes = await _tripService.getTripParticipants(_tripId!);
        if (participantsRes['success'] == true && participantsRes['data'] is List) {
          for (var p in participantsRes['data']) {
            final pUserId = (p['userId'] is Map ? p['userId']['_id'] : p['userId'] ?? p['id'] ?? p['_id'])?.toString();
            if (pUserId == _currentUserId) {
              final role = (p['role'] ?? '').toString().toLowerCase();
              if (role == 'tripleader' || role == 'trip leader' || role == 'creator' || role == 'admin' || role == 'leader') {
                _isTripLeader = true;
                break;
              }
            }
          }
        }
      } catch (_) {}
    }

    final prefs = await SharedPreferences.getInstance();
    final prefKey = 'location_sharing_granted_${_tripId ?? 'default'}';
    _hasGrantedPermission = prefs.getBool(prefKey) ?? false;
    _isLocationSharingOn = _hasGrantedPermission;

    if (mounted) setState(() {});

    // Only prompt for live location sharing if currently during trip dates
    if (_isDuringTrip && !_hasGrantedPermission) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _showLocationPermissionDialog();
        }
      });
    }
  }

  /// Obtains the real GPS position of the mobile device
  Future<void> _startDeviceLocationTracking() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('[MapScreen] Location services are disabled on device');
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
        if (mounted) setState(() => _isLocationPermissionGranted = true);
      }

      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        debugPrint('[MapScreen] Device location permission denied');
        return;
      }

      // Initial GPS fix
      Position? initialPosition;
      try {
        initialPosition = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 10),
          ),
        );
      } catch (_) {
        try {
          initialPosition = await Geolocator.getLastKnownPosition();
        } catch (_) {}
      }

      if (initialPosition != null && mounted) {
        _hasAcquiredGps = true;
        _isLocationPermissionGranted = true;
        _updateMyLocationAndBroadcast(initialPosition);
        _mapController.move(_myLocation, MapConfig.initialZoomWithGps);
      }

      // Real-time GPS stream
      _positionStreamSubscription = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 5,
        ),
      ).listen((Position position) {
        if (mounted) {
          _hasAcquiredGps = true;
          _isLocationPermissionGranted = true;
          _updateMyLocationAndBroadcast(position);
        }
      });
    } catch (e) {
      debugPrint('[MapScreen] Error tracking device location: $e');
    }
  }

  void _updateMyLocationAndBroadcast(Position pos) {
    _myLocation = LatLng(pos.latitude, pos.longitude);

    // Only add or show member markers if currently during trip dates
    if (_isDuringTrip) {
      final meId = _currentUserId ?? 'me';
      final meIndex = _membersList.indexWhere((m) => m.id == meId);
      final meMarker = MemberLocation(
        id: meId,
        name: _currentUserName != null && _currentUserName!.isNotEmpty ? _currentUserName! : 'Me',
        profileImage: _currentUserPhoto ?? '',
        latitude: pos.latitude,
        longitude: pos.longitude,
        familyName: 'You',
        isOnline: true,
        lastUpdated: DateTime.now(),
      );

      if (meIndex != -1) {
        _membersList[meIndex] = meMarker;
      } else {
        _membersList.insert(0, meMarker);
      }

      if (_tripId != null && _tripId!.isNotEmpty) {
        _locationService.updateMyLocation(
          _tripId!,
          latitude: pos.latitude,
          longitude: pos.longitude,
          isSharing: _isLocationSharingOn,
          accuracy: pos.accuracy,
        );
      }
    }

    if (mounted) setState(() {});
  }

  void _initSocket() async {
    if (_tripId == null || _tripId!.isEmpty) return;
    try {
      final apiBaseUrl = await ApiEndpoints.getBaseUrl();
      final serverUrl = apiBaseUrl.replaceFirst(RegExp(r'/api/?$'), '');

      _socket = io.io(
        serverUrl,
        io.OptionBuilder()
            .setTransports(['websocket', 'polling'])
            .enableAutoConnect()
            .enableReconnection()
            .build(),
      );

      _socket!.onConnect((_) {
        _socket!.emit('join_trip_room', _tripId);
      });

      // Member location broadcast
      _socket!.on('member_location_updated', (data) {
        if (!mounted || data == null) return;
        try {
          final map = data is Map<String, dynamic> ? data : jsonDecode(data.toString());
          final uObj = map['userId'];
          final uId = (uObj is Map ? uObj['_id'] : uObj)?.toString();
          final lat = (map['latitude'] as num?)?.toDouble();
          final lng = (map['longitude'] as num?)?.toDouble();
          final isSharing = map['isSharing'] == true;

          if (uId != null && uId != _currentUserId) {
            setState(() {
              final idx = _membersList.indexWhere((m) => m.id == uId);
              if (!isSharing) {
                if (idx != -1) {
                  _membersList.removeAt(idx);
                }
                if (_selectedMember?.id == uId) {
                  _selectedMember = null;
                }
              } else if (lat != null && lng != null && lat != 0.0 && lng != 0.0) {
                final name = uObj is Map ? '${uObj['firstName']} ${uObj['lastName'] ?? ''}'.trim() : 'Trip Member';
                final photo = uObj is Map ? (uObj['profilePhoto'] ?? '') : '';
                final updatedMember = MemberLocation(
                  id: uId,
                  name: name,
                  profileImage: photo,
                  latitude: lat,
                  longitude: lng,
                  familyName: 'Sharing Live Location',
                  isOnline: true,
                  isSharing: true,
                  lastUpdated: DateTime.now(),
                );

                if (idx != -1) {
                  _membersList[idx] = updatedMember;
                } else {
                  _membersList.add(updatedMember);
                }
              }
            });
          }
        } catch (e) {
          debugPrint('Error parsing member_location_updated: $e');
        }
      });

      // Member location sharing toggled
      _socket!.on('member_location_sharing_toggled', (data) {
        if (!mounted || data == null) return;
        try {
          final map = data is Map<String, dynamic> ? data : jsonDecode(data.toString());
          final uId = map['userId']?.toString();
          final isSharing = map['isSharing'] == true;

          if (uId != null && uId != _currentUserId) {
            setState(() {
              final idx = _membersList.indexWhere((m) => m.id == uId);
              if (!isSharing) {
                if (idx != -1) {
                  _membersList.removeAt(idx);
                }
                if (_selectedMember?.id == uId) {
                  _selectedMember = null;
                }
              } else {
                final loc = map['location'];
                if (loc is Map) {
                  final lat = (loc['latitude'] as num?)?.toDouble();
                  final lng = (loc['longitude'] as num?)?.toDouble();
                  final uObj = loc['userId'];
                  final name = uObj is Map
                      ? '${uObj['firstName']} ${uObj['lastName'] ?? ''}'.trim()
                      : (idx != -1 ? _membersList[idx].name : 'Trip Member');
                  final photo = uObj is Map
                      ? (uObj['profilePhoto'] ?? '')
                      : (idx != -1 ? _membersList[idx].profileImage : '');

                  if (lat != null && lng != null && lat != 0.0 && lng != 0.0) {
                    final updatedMember = MemberLocation(
                      id: uId,
                      name: name,
                      profileImage: photo,
                      latitude: lat,
                      longitude: lng,
                      familyName: 'Sharing Live Location',
                      isOnline: true,
                      isSharing: true,
                      lastUpdated: DateTime.now(),
                    );
                    if (idx != -1) {
                      _membersList[idx] = updatedMember;
                    } else {
                      _membersList.add(updatedMember);
                    }
                  }
                } else if (idx != -1) {
                  final cur = _membersList[idx];
                  _membersList[idx] = MemberLocation(
                    id: cur.id,
                    name: cur.name,
                    profileImage: cur.profileImage,
                    latitude: cur.latitude,
                    longitude: cur.longitude,
                    familyName: 'Sharing Live Location',
                    isOnline: true,
                    isSharing: true,
                    lastUpdated: DateTime.now(),
                  );
                }
              }
            });
          }
        } catch (_) {}
      });

      // Itinerary events updated in real-time
      _socket!.on('itinerary_updated', (data) {
        if (!mounted || data == null) return;
        try {
          final map = data is Map<String, dynamic> ? data : jsonDecode(data.toString());
          final act = map['activity'];
          if (act is Map<String, dynamic>) {
            _handleSocketItineraryActivityUpdate(act);
          }
        } catch (e) {
          debugPrint('Error handling itinerary_updated socket: $e');
        }
      });

      // Itinerary event deleted in real-time
      _socket!.on('itinerary_deleted', (data) {
        if (!mounted || data == null) return;
        try {
          final map = data is Map<String, dynamic> ? data : jsonDecode(data.toString());
          final actId = map['activityId']?.toString();
          if (actId != null && actId.isNotEmpty) {
            setState(() {
              _locationsList.removeWhere((l) => l.id == actId);
              if (_selectedLocation?.id == actId) {
                _selectedLocation = null;
              }
            });
          }
        } catch (_) {}
      });

      _socket!.connect();
    } catch (_) {}
  }

  void _handleSocketItineraryActivityUpdate(Map<String, dynamic> act) {
    final actId = act['_id']?.toString();
    if (actId == null || actId.isEmpty) return;

    double? lat;
    double? lng;
    String title = act['title'] ?? 'Itinerary Activity';
    String desc = act['description'] ?? '';
    String address = '';

    if (act['location'] is Map) {
      lat = (act['location']['latitude'] as num?)?.toDouble();
      lng = (act['location']['longitude'] as num?)?.toDouble();
      address = act['location']['address']?.toString() ?? '';
      if (desc.isEmpty) desc = act['location']['name'] ?? '';
    } else if (act['latitude'] != null && act['longitude'] != null) {
      lat = (act['latitude'] as num?)?.toDouble();
      lng = (act['longitude'] as num?)?.toDouble();
    }

    if (lat == null || lng == null) {
      setState(() {
        _locationsList.removeWhere((l) => l.id == actId);
      });
      return;
    }

    final locType = _mapActivityTypeToLocationType(act['type']?.toString(), title);
    final updatedPin = TripLocation(
      id: actId,
      title: title,
      latitude: lat,
      longitude: lng,
      type: locType,
      description: desc.isNotEmpty ? desc : 'Itinerary Pinned Location',
      address: address.isNotEmpty ? address : desc,
      rawActivity: act,
    );

    setState(() {
      final existingIdx = _locationsList.indexWhere((l) => l.id == actId);
      if (existingIdx != -1) {
        _locationsList[existingIdx] = updatedPin;
      } else {
        _locationsList.add(updatedPin);
      }
    });
  }

  /// Loads actual trip participants and their live locations
  Future<void> _loadActualTripMembers() async {
    if (_tripId == null || _tripId!.isEmpty) return;
    try {
      final Map<String, MemberLocation> liveMembersMap = {};

      final locRes = await _locationService.getTripLocations(_tripId!);
      if (locRes['success'] == true && locRes['data'] is List) {
        for (var item in locRes['data']) {
          final u = item['userId'];
          if (u is Map) {
            final uId = u['_id']?.toString() ?? '';
            if (uId.isEmpty) continue;
            final firstName = u['firstName']?.toString() ?? 'Member';
            final lastName = u['lastName']?.toString() ?? '';
            final fullName = '$firstName $lastName'.trim();
            final photo = u['profilePhoto']?.toString() ?? '';
            final lat = (item['latitude'] as num?)?.toDouble() ?? 0.0;
            final lng = (item['longitude'] as num?)?.toDouble() ?? 0.0;
            final isSharing = item['isSharing'] == true;
            final isMe = uId == _currentUserId;

            if ((isSharing || isMe) && lat != 0.0 && lng != 0.0) {
              liveMembersMap[uId] = MemberLocation(
                id: uId,
                name: isMe ? 'Me' : fullName,
                profileImage: photo,
                latitude: isMe ? _myLocation.latitude : lat,
                longitude: isMe ? _myLocation.longitude : lng,
                familyName: isMe ? 'You' : (isSharing ? 'Sharing Live Location' : 'Trip Member'),
                isOnline: true,
                isSharing: isSharing,
                lastUpdated: item['updatedAt'] != null
                    ? DateTime.tryParse(item['updatedAt'].toString())?.toLocal() ?? DateTime.now()
                    : DateTime.now(),
              );
            }
          }
        }
      }

      final partRes = await _tripService.getTripParticipants(_tripId!);
      if (partRes['success'] == true && partRes['data'] != null) {
        final data = partRes['data'];
        final List allParticipants = [];
        if (data is Map) {
          if (data['participants'] is List) allParticipants.addAll(data['participants']);
          if (data['individuals'] is List) allParticipants.addAll(data['individuals']);
          if (data['families'] is List) {
            for (var fam in data['families']) {
              if (fam['leader'] != null) allParticipants.add(fam['leader']);
              if (fam['members'] is List) allParticipants.addAll(fam['members']);
            }
          }
        } else if (data is List) {
          allParticipants.addAll(data);
        }

        for (var p in allParticipants) {
          final uId = (p['userId'] is Map ? p['userId']['_id'] : p['userId'] ?? p['id'] ?? p['_id'])?.toString();
          if (uId == null || uId.isEmpty) continue;
          if (!liveMembersMap.containsKey(uId)) {
            final isMe = uId == _currentUserId;
            if (isMe) {
              liveMembersMap[uId] = MemberLocation(
                id: uId,
                name: 'Me',
                profileImage: _currentUserPhoto ?? '',
                latitude: _myLocation.latitude,
                longitude: _myLocation.longitude,
                familyName: 'You',
                isOnline: true,
                lastUpdated: DateTime.now(),
              );
            }
          }
        }
      }

      final myId = _currentUserId ?? 'me';
      if (!liveMembersMap.containsKey(myId)) {
        liveMembersMap[myId] = MemberLocation(
          id: myId,
          name: _currentUserName != null && _currentUserName!.isNotEmpty ? _currentUserName! : 'Me',
          profileImage: _currentUserPhoto ?? '',
          latitude: _myLocation.latitude,
          longitude: _myLocation.longitude,
          familyName: 'You',
          isOnline: true,
          lastUpdated: DateTime.now(),
        );
      }

      if (mounted) {
        setState(() {
          _membersList = liveMembersMap.values.toList();
        });
      }
    } catch (e) {
      debugPrint('[MapScreen] Error loading actual trip members: $e');
    }
  }

  /// Loads all existing itinerary events with valid coordinates
  Future<void> _loadItineraryLocations() async {
    if (_tripId == null || _tripId!.isEmpty) return;
    try {
      final res = await _itineraryService.getItinerary(_tripId!);
      if (res['success'] == true && res['data'] is List) {
        final List<TripLocation> itineraryPins = [];
        for (var day in res['data']) {
          final activities = day['activities'];
          if (activities is List) {
            for (var act in activities) {
              double? lat;
              double? lng;
              String title = act['title'] ?? 'Itinerary Activity';
              String desc = act['description'] ?? '';
              String address = '';

              if (act['location'] is Map) {
                lat = (act['location']['latitude'] as num?)?.toDouble();
                lng = (act['location']['longitude'] as num?)?.toDouble();
                address = act['location']['address']?.toString() ?? '';
                if (desc.isEmpty) desc = act['location']['name'] ?? '';
              } else if (act['latitude'] != null && act['longitude'] != null) {
                lat = (act['latitude'] as num?)?.toDouble();
                lng = (act['longitude'] as num?)?.toDouble();
              }

              if (lat != null && lng != null) {
                final locType = _mapActivityTypeToLocationType(act['type']?.toString(), title);

                itineraryPins.add(TripLocation(
                  id: act['_id']?.toString() ?? UniqueKey().toString(),
                  title: title,
                  latitude: lat,
                  longitude: lng,
                  type: locType,
                  description: desc.isNotEmpty ? desc : 'Itinerary Pinned Location',
                  address: address.isNotEmpty ? address : desc,
                  rawActivity: act is Map<String, dynamic> ? act : null,
                ));
              }
            }
          }
        }

        if (mounted) {
          setState(() {
            _locationsList = itineraryPins;
          });
        }
      }
    } catch (e) {
      debugPrint('[MapScreen] Error loading itinerary locations: $e');
    }
  }

  LocationType _mapActivityTypeToLocationType(String? typeStr, String title) {
    final t = (typeStr ?? '').toLowerCase();
    final name = title.toLowerCase();

    if (t.contains('lodging') || t.contains('hotel') || name.contains('hotel') || name.contains('resort') || name.contains('stay')) {
      return LocationType.hotel;
    }
    if (t.contains('food') || t.contains('restaurant') || t.contains('dining') || t.contains('cafe') || name.contains('restaurant') || name.contains('cafe')) {
      return LocationType.restaurant;
    }
    if (t.contains('transport') || t.contains('travel') || t.contains('airport') || t.contains('flight') || name.contains('airport') || name.contains('station') || name.contains('pickup') || name.contains('drop') || name.contains('train') || name.contains('bus')) {
      return LocationType.airport;
    }
    if (t.contains('sightseeing') || name.contains('museum') || name.contains('fort') || name.contains('temple') || name.contains('beach') || name.contains('park') || name.contains('palace')) {
      return LocationType.sightseeing;
    }
    return LocationType.activity;
  }

  // --- Search & Geoapify Integration ---

  void _onSearchChanged(String val) {
    setState(() {
      _searchQuery = val;
      _isSearchFocused = val.trim().isNotEmpty;
    });

    _searchDebounceTimer?.cancel();
    if (val.trim().isNotEmpty) {
      _searchDebounceTimer = Timer(const Duration(milliseconds: 350), () {
        _searchGeoapifyPlaces(val);
      });
    } else {
      setState(() {
        _geoapifyResults = [];
        _isSearchingGeoapify = false;
        _searchErrorMessage = null;
        _isRateLimited = false;
      });
    }
  }

  Future<void> _searchGeoapifyPlaces(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;

    final currentToken = ++_searchRequestToken;

    setState(() {
      _isSearchingGeoapify = true;
      _searchErrorMessage = null;
      _isRateLimited = false;
    });

    try {
      final centerBias = _hasAcquiredGps ? _myLocation : _getTripFallbackCenter();

      final res = await _geoapifyService.autocomplete(
        query: trimmed,
        proximity: centerBias,
        limit: 8,
      );

      if (currentToken != _searchRequestToken) return;

      if (mounted) {
        setState(() {
          if (res.success && res.data != null) {
            _geoapifyResults = res.data!;
            _searchErrorMessage = null;
          } else {
            _geoapifyResults = [];
            _searchErrorMessage = res.errorMessage;
            _isRateLimited = res.isRateLimited;
          }
        });
      }
    } catch (e) {
      if (currentToken == _searchRequestToken && mounted) {
        setState(() {
          _searchErrorMessage = 'Error querying places: ${e.toString()}';
        });
      }
    } finally {
      if (currentToken == _searchRequestToken && mounted) {
        setState(() => _isSearchingGeoapify = false);
      }
    }
  }

  /// Explore nearby places using Geoapify Places API v2 for a given category
  Future<void> _exploreNearbyCategory(String categoryKey) async {
    String geoapifyCategory;
    switch (categoryKey) {
      case 'Hotels':
        geoapifyCategory = GeoapifyCategories.hotels;
        break;
      case 'Sightseeing':
        geoapifyCategory = GeoapifyCategories.sightseeing;
        break;
      case 'Restaurants':
        geoapifyCategory = GeoapifyCategories.restaurants;
        break;
      case 'Travel':
        geoapifyCategory = GeoapifyCategories.transit;
        break;
      default:
        geoapifyCategory = GeoapifyCategories.sightseeing;
    }

    final searchCenter = _hasAcquiredGps ? _myLocation : _mapController.camera.center;

    setState(() => _isLoadingNearbyPois = true);

    try {
      final res = await _geoapifyService.searchPlacesByCategory(
        categories: geoapifyCategory,
        center: searchCenter,
        radiusMeters: 6000,
        limit: 15,
      );

      if (mounted) {
        if (res.success && res.data != null) {
          setState(() {
            _nearbyPoiPlaces = res.data!;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Found ${_nearbyPoiPlaces.length} nearby $categoryKey'),
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
            ),
          );
        } else if (res.errorMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(res.errorMessage!),
              backgroundColor: Colors.redAccent,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _isLoadingNearbyPois = false);
    }
  }

  LatLng _getTripFallbackCenter() {
    if (_locationsList.isNotEmpty) {
      return LatLng(_locationsList.first.latitude, _locationsList.first.longitude);
    }
    return MapConfig.defaultCenter;
  }

  /// Returns member locations
  List<MemberLocation> get _filteredMembers {
    if (!_isDuringTrip) {
      return [];
    }
    if (_activeFilter != 'Members' && _searchQuery.trim().isEmpty) {
      return [];
    }
    final sharingMembers = _membersList
        .where((m) => m.isSharing && m.id != 'me' && m.id != _currentUserId)
        .toList();

    if (_searchQuery.trim().isEmpty) {
      return sharingMembers;
    }
    return sharingMembers.where((m) {
      return m.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          m.familyName.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();
  }

  /// Filters itinerary locations based on the active selected filter
  List<TripLocation> get _filteredLocations {
    if (_activeFilter == 'Members' && _searchQuery.trim().isEmpty) {
      return [];
    }

    return _locationsList.where((l) {
      bool matchesFilter = false;
      if (_activeFilter == 'Travel' && l.type == LocationType.airport) {
        matchesFilter = true;
      } else if (_activeFilter == 'Hotels' && l.type == LocationType.hotel) {
        matchesFilter = true;
      } else if (_activeFilter == 'Sightseeing' &&
          (l.type == LocationType.sightseeing || l.type == LocationType.activity || l.type == LocationType.general)) {
        matchesFilter = true;
      } else if (_activeFilter == 'Restaurants' && l.type == LocationType.restaurant) {
        matchesFilter = true;
      }

      final matchesSearch = _searchQuery.isEmpty ||
          l.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          l.description.toLowerCase().contains(_searchQuery.toLowerCase());

      return matchesFilter && matchesSearch;
    }).toList();
  }

  List<MemberLocation> get _allMatchingMembers {
    if (!_isDuringTrip || _searchQuery.trim().isEmpty) return [];
    return _membersList.where((m) {
      if (m.id == 'me' || m.id == _currentUserId || !m.isSharing) return false;
      return m.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          m.familyName.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();
  }

  List<TripLocation> get _allMatchingActivities {
    if (_searchQuery.trim().isEmpty) return [];
    return _locationsList.where((l) {
      return l.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          l.description.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();
  }

  void _centerOn(LatLng point) {
    _mapController.move(point, 16.0);
  }

  void _fitAllDestinations() {
    final List<LatLng> allPoints = [];

    if (_hasAcquiredGps) {
      allPoints.add(_myLocation);
    }

    if (_isDuringTrip) {
      for (var m in _membersList) {
        if (m.isSharing && m.latitude != 0.0 && m.longitude != 0.0) {
          allPoints.add(LatLng(m.latitude, m.longitude));
        }
      }
    }

    for (var l in _locationsList) {
      if (l.latitude != 0.0 && l.longitude != 0.0) {
        allPoints.add(LatLng(l.latitude, l.longitude));
      }
    }

    for (var p in _nearbyPoiPlaces) {
      if (p.latitude != 0.0 && p.longitude != 0.0) {
        allPoints.add(LatLng(p.latitude, p.longitude));
      }
    }

    if (allPoints.isEmpty) {
      _mapController.move(_myLocation, 14.0);
      return;
    }

    if (allPoints.length == 1) {
      _mapController.move(allPoints.first, 15.5);
      return;
    }

    final bounds = LatLngBounds.fromPoints(allPoints);
    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: bounds,
        padding: const EdgeInsets.only(top: 140, bottom: 220, left: 60, right: 60),
      ),
    );
  }

  String _calculateDistanceText(LatLng targetPoint) {
    const distance = Distance();
    final meter = distance(_myLocation, targetPoint);
    final km = meter / 1000.0;
    final driveMins = (meter / 500.0).round().clamp(1, 999);
    final walkMins = (meter / 75.0).round().clamp(1, 999);

    if (km < 1.0) {
      return '${meter.round()} m • $walkMins min walk';
    } else {
      return '${km.toStringAsFixed(1)} km • $driveMins min drive';
    }
  }

  Future<void> _openExternalNavigation(LatLng destination, String label) async {
    final geoUri = Uri.parse(
      'geo:${destination.latitude},${destination.longitude}?q=${destination.latitude},${destination.longitude}(${Uri.encodeComponent(label)})',
    );

    final osmWebUri = Uri.parse(
      'https://www.openstreetmap.org/directions?engine=fossgis_osrm_car&route=${_myLocation.latitude}%2C${_myLocation.longitude}%3B${destination.latitude}%2C${destination.longitude}',
    );

    try {
      final launched = await launchUrl(geoUri, mode: LaunchMode.externalApplication);
      if (launched) return;
    } catch (_) {}

    try {
      await launchUrl(osmWebUri, mode: LaunchMode.externalApplication);
    } catch (_) {
      final fallbackWeb = Uri.parse(
        'https://maps.google.com/?q=${destination.latitude},${destination.longitude}',
      );
      await launchUrl(fallbackWeb, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _addPlaceToItinerary(TripLocation loc) async {
    if (!_isTripLeader) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Only the Trip Leader can add events to the itinerary.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    String initialCategory = 'sightseeing';
    if (loc.type == LocationType.hotel) initialCategory = 'lodging';
    if (loc.type == LocationType.restaurant) initialCategory = 'food';
    if (loc.type == LocationType.airport) initialCategory = 'transport';

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddEventScreen(
          tripData: widget.tripData,
          existingActivity: {
            'title': loc.title,
            'description': loc.description,
            'type': initialCategory,
            'location': {
              'name': loc.title,
              'address': loc.address ?? loc.description,
              'latitude': loc.latitude,
              'longitude': loc.longitude,
            },
          },
        ),
      ),
    );

    if (result == true || mounted) {
      _loadItineraryLocations();
    }
  }

  Future<void> _editItineraryEvent(TripLocation loc) async {
    if (!_isTripLeader) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Only the Trip Leader can edit itinerary events.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (loc.rawActivity == null) return;
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddEventScreen(
          tripData: widget.tripData,
          existingActivity: loc.rawActivity,
        ),
      ),
    );

    if (result == true || mounted) {
      _loadItineraryLocations();
    }
  }

  void _selectGeoapifyPlace(GeoapifyPlace place) {
    final tripLoc = place.toTripLocation();
    setState(() {
      _selectedLocation = tripLoc;
      _selectedMember = null;
      _customPinnedLocation = null;
      _isSearchFocused = false;
      _searchController.text = place.name;
    });

    FocusScope.of(context).unfocus();
    _centerOn(LatLng(place.latitude, place.longitude));
  }

  /// Handles tapping/long-pressing anywhere on the map to pin any custom location,
  /// reverse-geocode the place/city name, and display the location card.
  Future<void> _handlePinMapLocation(LatLng point) async {
    if (_isSearchFocused) {
      FocusScope.of(context).unfocus();
      setState(() => _isSearchFocused = false);
    }

    final tempId = 'pinned_${point.latitude.toStringAsFixed(5)}_${point.longitude.toStringAsFixed(5)}';
    final initialLoc = TripLocation(
      id: tempId,
      title: 'Pinned Location',
      latitude: point.latitude,
      longitude: point.longitude,
      type: LocationType.general,
      description: 'Resolving nearby address...',
      address: '${point.latitude.toStringAsFixed(4)}, ${point.longitude.toStringAsFixed(4)}',
      isPublicPlace: true,
    );

    setState(() {
      _selectedMember = null;
      _customPinnedLocation = initialLoc;
      _selectedLocation = initialLoc;
    });

    try {
      final res = await _geoapifyService.reverseGeocode(point);
      if (!mounted) return;

      final place = res.data;
      String placeName;
      String subtitle;
      LocationType locType = LocationType.general;

      if (place != null) {
        final rawName = place.rawProperties['name']?.toString().trim();
        final rawStreet = place.street ?? place.rawProperties['street']?.toString().trim();
        final rawCity = place.city ?? place.rawProperties['city']?.toString().trim() ?? place.rawProperties['county']?.toString().trim();
        final rawSuburb = place.rawProperties['suburb']?.toString().trim() ?? place.rawProperties['district']?.toString().trim();

        if (rawName != null && rawName.isNotEmpty && rawName.toLowerCase() != 'unnamed' && rawName.toLowerCase() != 'place') {
          placeName = rawName;
          subtitle = place.formatted.isNotEmpty ? place.formatted : (rawCity ?? '');
        } else if (rawStreet != null && rawStreet.isNotEmpty) {
          placeName = rawStreet;
          subtitle = (rawCity != null && rawCity.isNotEmpty)
              ? '$rawStreet, $rawCity'
              : (place.formatted.isNotEmpty ? place.formatted : rawStreet);
        } else if (rawSuburb != null && rawSuburb.isNotEmpty) {
          placeName = rawSuburb;
          subtitle = (rawCity != null && rawCity.isNotEmpty)
              ? '$rawSuburb, $rawCity'
              : (place.formatted.isNotEmpty ? place.formatted : rawSuburb);
        } else if (rawCity != null && rawCity.isNotEmpty) {
          placeName = rawCity;
          subtitle = place.formatted.isNotEmpty ? place.formatted : (place.state ?? place.country ?? rawCity);
        } else if (place.name.isNotEmpty && place.name.toLowerCase() != 'place') {
          placeName = place.name;
          subtitle = place.formatted.isNotEmpty ? place.formatted : '';
        } else if (place.formatted.isNotEmpty) {
          final parts = place.formatted.split(',');
          placeName = parts.first.trim();
          subtitle = place.formatted;
        } else {
          placeName = 'Pinned Location';
          subtitle = '${point.latitude.toStringAsFixed(4)}, ${point.longitude.toStringAsFixed(4)}';
        }

        locType = place.toTripLocation().type;
      } else {
        placeName = 'Pinned Location';
        subtitle = '${point.latitude.toStringAsFixed(4)}, ${point.longitude.toStringAsFixed(4)}';
      }

      final resolvedLoc = TripLocation(
        id: tempId,
        title: placeName,
        latitude: point.latitude,
        longitude: point.longitude,
        type: locType,
        description: subtitle,
        address: subtitle,
        isPublicPlace: true,
        placeDetails: place,
      );

      setState(() {
        _customPinnedLocation = resolvedLoc;
        if (_selectedLocation?.id == tempId) {
          _selectedLocation = resolvedLoc;
        }
      });
    } catch (_) {}
  }

  void _showLocationPermissionDialog() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogCtx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.16),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  height: 72,
                  width: 72,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0072FF).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.location_on_rounded,
                      size: 40,
                      color: Color(0xFF0072FF),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Share Live Location',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                const Text(
                  'Share your real-time GPS location with your trip group during the trip. You can turn this off at any time.',
                  style: TextStyle(
                    fontSize: 13.5,
                    height: 1.5,
                    color: Color(0xFF64748B),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Container(
                  width: double.infinity,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF00C6FF), Color(0xFF0072FF)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0072FF).withOpacity(0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: () async {
                      Navigator.pop(dialogCtx);
                      final prefs = await SharedPreferences.getInstance();
                      final prefKey = 'location_sharing_granted_${_tripId ?? 'default'}';
                      await prefs.setBool(prefKey, true);

                      setState(() {
                        _hasGrantedPermission = true;
                        _isLocationSharingOn = true;
                      });

                      if (_hasAcquiredGps && _tripId != null && _isDuringTrip) {
                        _locationService.updateMyLocation(
                          _tripId!,
                          latitude: _myLocation.latitude,
                          longitude: _myLocation.longitude,
                          isSharing: true,
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: const Text(
                      'Turn On Live Sharing',
                      style: TextStyle(color: Colors.white, fontSize: 14.5, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () {
                    Navigator.pop(dialogCtx);
                    setState(() {
                      _isLocationSharingOn = false;
                    });
                  },
                  child: const Text('Not Now', style: TextStyle(color: Color(0xFF94A3B8))),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showTurnOffLocationDialog() {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Stop Sharing Location?'),
        content: const Text('Your fellow trip members will no longer be able to see your live position on the map.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogCtx);
              setState(() {
                _isLocationSharingOn = false;
              });

              final prefs = await SharedPreferences.getInstance();
              final prefKey = 'location_sharing_granted_${_tripId ?? 'default'}';
              await prefs.setBool(prefKey, false);

              if (_tripId != null) {
                _locationService.toggleLocationSharing(_tripId!, isSharing: false);
              }

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Live location sharing disabled'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Stop Sharing', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredMembersList = _filteredMembers;
    final filteredLocationsList = _filteredLocations;

    return Scaffold(
      body: Stack(
        children: [
          // 1. OpenStreetMap Tile Layer with flutter_map
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _myLocation,
              initialZoom: _hasAcquiredGps ? MapConfig.initialZoomWithGps : MapConfig.initialZoomWithoutGps,
              minZoom: MapConfig.minZoom,
              maxZoom: MapConfig.maxZoom,
              onTap: (tapPosition, point) => _handlePinMapLocation(point),
              onLongPress: (tapPosition, point) => _handlePinMapLocation(point),
            ),
            children: [
              TileLayer(
                urlTemplate: MapConfig.tileUrlTemplate,
                userAgentPackageName: MapConfig.userAgentPackageName,
              ),

              // Attribution Layer (OSM & Geoapify)
              RichAttributionWidget(
                attributions: const [
                  TextSourceAttribution(
                    MapConfig.osmAttribution,
                  ),
                  TextSourceAttribution(
                    MapConfig.geoapifyAttribution,
                  ),
                ],
              ),

              // Nearby POIs Markers Layer (Displayed only after tapping "Find Nearby")
              MarkerLayer(
                markers: _nearbyPoiPlaces.map((poi) {
                  final isSelected = _selectedLocation?.id == poi.placeId;
                  return Marker(
                    point: LatLng(poi.latitude, poi.longitude),
                    width: 44,
                    height: 44,
                    child: GestureDetector(
                      onTap: () {
                        _selectGeoapifyPlace(poi);
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: isSelected ? const Color(0xFF0F172A) : poi.categoryColor,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 6,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Icon(
                          poi.categoryIcon,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),

              // Trip Itinerary Markers Layer (Travel, Hotels, Sightseeing, Restaurants)
              MarkerLayer(
                markers: filteredLocationsList.map((loc) {
                  final isSelected = _selectedLocation?.id == loc.id;
                  final color = _getLocationColor(loc.type);
                  return Marker(
                    point: LatLng(loc.latitude, loc.longitude),
                    width: isSelected ? 52 : 44,
                    height: isSelected ? 52 : 44,
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedLocation = loc;
                          _selectedMember = null;
                          _customPinnedLocation = null;
                        });
                        _centerOn(LatLng(loc.latitude, loc.longitude));
                      },
                      child: Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: isSelected ? AppColors.primary : Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected ? Colors.white : color,
                            width: 2.2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: color.withOpacity(isSelected ? 0.45 : 0.25),
                              blurRadius: isSelected ? 10 : 6,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Icon(
                          _getLocationIcon(loc.type),
                          color: isSelected ? Colors.white : color,
                          size: isSelected ? 22 : 18,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),

              // Trip Member Location Markers
              MarkerLayer(
                markers: filteredMembersList
                    .where((member) => member.id != 'me' && member.id != _currentUserId && member.isSharing)
                    .map((member) {
                  return Marker(
                    point: LatLng(member.latitude, member.longitude),
                    width: 70,
                    height: 75,
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedMember = member;
                          _selectedLocation = null;
                          _customPinnedLocation = null;
                        });
                        _centerOn(LatLng(member.latitude, member.longitude));
                      },
                      child: MemberMapMarker(
                        member: member,
                        isCurrentUser: false,
                      ),
                    ),
                  );
                }).toList(),
              ),

              // Current User's Real Device GPS Location Marker
              // Always visible whenever phone location permission is given and GPS location acquired,
              // regardless of:
              // - whether trip has started, ended, or is active
              // - whether sharing location with other members is ON or OFF
              // - which category filter is currently active
              if (_hasAcquiredGps)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _myLocation,
                      width: 60,
                      height: 72,
                      child: GestureDetector(
                        onTap: () {
                          final meMember = MemberLocation(
                            id: _currentUserId ?? 'me',
                            name: _currentUserName != null && _currentUserName!.isNotEmpty
                                ? _currentUserName!
                                : 'You',
                            profileImage: _currentUserPhoto ?? '',
                            latitude: _myLocation.latitude,
                            longitude: _myLocation.longitude,
                            familyName: _isLocationSharingOn
                                ? 'Live Sharing Active with Group'
                                : 'Live Sharing OFF (Only you can see this)',
                            isOnline: true,
                            lastUpdated: DateTime.now(),
                          );
                          setState(() {
                            _selectedMember = meMember;
                            _selectedLocation = null;
                            _customPinnedLocation = null;
                          });
                          _centerOn(_myLocation);
                        },
                        child: _UserLocationMarker(
                          profilePhoto: _currentUserPhoto,
                          isSharing: _isLocationSharingOn,
                        ),
                      ),
                    ),
                  ],
                ),

              // Custom Dropped Pin Marker Layer (when user pins anywhere on map)
              if (_customPinnedLocation != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: LatLng(_customPinnedLocation!.latitude, _customPinnedLocation!.longitude),
                      width: 48,
                      height: 52,
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedLocation = _customPinnedLocation;
                            _selectedMember = null;
                          });
                        },
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(7),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEF4444),
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2.5),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFFEF4444).withValues(alpha: 0.4),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.location_on_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),

          // 2. Top Row: Back button, Search bar, and Location share ON/OFF button ALL IN ONE ROW
          Positioned(
              top: 48,
              left: 16,
              right: 16,
              child: Row(
                children: [
                  // Back button
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Icon(Icons.arrow_back_ios_new, color: Color(0xFF0F172A), size: 18),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Search Bar Input
                  Expanded(
                    child: Container(
                      height: 44,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: TextField(
                        controller: _searchController,
                        onChanged: _onSearchChanged,
                        onTap: () {
                          if (_searchQuery.trim().isNotEmpty) {
                            setState(() => _isSearchFocused = true);
                          }
                        },
                        style: const TextStyle(fontSize: 13.5, color: Color(0xFF0F172A)),
                        decoration: InputDecoration(
                          hintText: 'Search places, hotels...',
                          hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                          prefixIcon: const Icon(Icons.search, color: Color(0xFF0072FF), size: 20),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.close, size: 18, color: Color(0xFF64748B)),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() {
                                      _searchQuery = '';
                                      _isSearchFocused = false;
                                      _geoapifyResults = [];
                                    });
                                  },
                                )
                              : null,
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(22),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Location Share ON/OFF Button (Single button, no text, only visible during trip dates)
                  if (_isDuringTrip) ...[
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () {
                        if (_isLocationSharingOn) {
                          _showTurnOffLocationDialog();
                        } else {
                          _showLocationPermissionDialog();
                        }
                      },
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: _isLocationSharingOn ? const Color(0xFF22C55E) : Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: _isLocationSharingOn
                                  ? const Color(0xFF22C55E).withOpacity(0.35)
                                  : Colors.black.withOpacity(0.08),
                              blurRadius: 10,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Icon(
                            _isLocationSharingOn ? Icons.share_location : Icons.location_off_outlined,
                            color: _isLocationSharingOn ? Colors.white : const Color(0xFF64748B),
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

          // 4. Horizontal Category Filter Chips Bar (Members, Travel, Hotels, Sightseeing, Restaurants)
          Positioned(
              top: 102,
              left: 16,
              right: 16,
              child: SizedBox(
                height: 38,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _categoryFilters.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final filterName = _categoryFilters[index];
                    final isSelected = _activeFilter == filterName;
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _activeFilter = filterName;
                          _selectedMember = null;
                          _selectedLocation = null;
                          _nearbyPoiPlaces = []; // Clear nearby POIs so itinerary items show first
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected ? const Color(0xFF0F172A) : Colors.white,
                          borderRadius: BorderRadius.circular(19),
                          border: Border.all(
                            color: isSelected ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0),
                            width: 1.2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.06),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _getFilterIcon(filterName),
                              size: 15,
                              color: isSelected ? Colors.white : const Color(0xFF475569),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              filterName,
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                                color: isSelected ? Colors.white : const Color(0xFF1E293B),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),

          // 5. "Find Nearby [Category]" Action Button (Only during trip for Hotels, Sightseeing, Restaurants when GPS allowed)
          if (_shouldDisplayFindNearbyButton)
            Positioned(
              top: 148,
              left: 16,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: _isLoadingNearbyPois ? null : () => _exploreNearbyCategory(_activeFilter),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_isLoadingNearbyPois)
                            const SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0072FF)),
                            )
                          else
                            const Icon(Icons.explore_outlined, size: 14, color: Color(0xFF0072FF)),
                          const SizedBox(width: 6),
                          Text(
                            'Find Nearby $_activeFilter',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0072FF)),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_nearbyPoiPlaces.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _nearbyPoiPlaces = [];
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFFECACA), width: 1),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.clear, size: 12, color: Color(0xFFDC2626)),
                            const SizedBox(width: 4),
                            Text(
                              'Clear (${_nearbyPoiPlaces.length})',
                              style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFFDC2626)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

          // 6. Search Results Dropdown Overlay (Geoapify Places + Members + Activities)
          if (_isSearchFocused && _searchQuery.trim().isNotEmpty)
            Positioned(
              top: 100,
              left: 16,
              right: 16,
              child: Container(
                constraints: const BoxConstraints(maxHeight: 360),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.16),
                      blurRadius: 24,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: ListView(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shrinkWrap: true,
                    children: [
                      if (_isSearchingGeoapify)
                        const Padding(
                          padding: EdgeInsets.all(12),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0072FF))),
                              SizedBox(width: 10),
                              Text('Searching places...', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                            ],
                          ),
                        ),

                      if (_searchErrorMessage != null)
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: _isRateLimited ? const Color(0xFFFFFBEB) : const Color(0xFFFEF2F2),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: _isRateLimited ? const Color(0xFFFDE68A) : const Color(0xFFFECACA),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                _isRateLimited ? Icons.speed : Icons.info_outline,
                                size: 16,
                                color: _isRateLimited ? const Color(0xFFD97706) : const Color(0xFFDC2626),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _searchErrorMessage!,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: _isRateLimited ? const Color(0xFF92400E) : const Color(0xFF991B1B),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                      // 1. Geoapify Public Places
                      if (_geoapifyResults.isNotEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          child: Text(
                            'PUBLIC PLACES (${_geoapifyResults.length})',
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF64748B), letterSpacing: 0.5),
                          ),
                        ),
                        ..._geoapifyResults.map((place) => ListTile(
                              dense: true,
                              leading: Container(
                                padding: const EdgeInsets.all(7),
                                decoration: BoxDecoration(
                                  color: place.categoryColor.withOpacity(0.12),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(place.categoryIcon, size: 16, color: place.categoryColor),
                              ),
                              title: Text(
                                place.name,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(
                                place.formatted,
                                style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: Text(
                                _calculateDistanceText(LatLng(place.latitude, place.longitude)),
                                style: const TextStyle(fontSize: 10, color: Color(0xFF0072FF), fontWeight: FontWeight.w600),
                              ),
                              onTap: () => _selectGeoapifyPlace(place),
                            )),
                        const Divider(height: 1, color: Color(0xFFF1F5F9)),
                      ],

                      // 2. Matching Trip Members (Only during trip dates)
                      if (_allMatchingMembers.isNotEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          child: Text(
                            'TRIP MEMBERS (${_allMatchingMembers.length})',
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF64748B), letterSpacing: 0.5),
                          ),
                        ),
                        ..._allMatchingMembers.map((m) => ListTile(
                              dense: true,
                              leading: CircleAvatar(
                                radius: 15,
                                backgroundImage: m.profileImage.isNotEmpty ? NetworkImage(m.profileImage) : null,
                                child: m.profileImage.isEmpty ? const Icon(Icons.person, size: 16) : null,
                              ),
                              title: Text(m.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              subtitle: Text(m.familyName, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                              onTap: () {
                                setState(() {
                                  _activeFilter = 'Members';
                                  _selectedMember = m;
                                  _selectedLocation = null;
                                  _isSearchFocused = false;
                                  _searchController.text = m.name;
                                });
                                FocusScope.of(context).unfocus();
                                _centerOn(LatLng(m.latitude, m.longitude));
                              },
                            )),
                        const Divider(height: 1, color: Color(0xFFF1F5F9)),
                      ],

                      // 3. Matching Itinerary Activities
                      if (_allMatchingActivities.isNotEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          child: Text(
                            'ITINERARY EVENTS (${_allMatchingActivities.length})',
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF64748B), letterSpacing: 0.5),
                          ),
                        ),
                        ..._allMatchingActivities.map((loc) => ListTile(
                              dense: true,
                              leading: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: _getLocationColor(loc.type).withOpacity(0.12),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(_getLocationIcon(loc.type), size: 16, color: _getLocationColor(loc.type)),
                              ),
                              title: Text(loc.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              subtitle: Text(loc.description, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)), maxLines: 1),
                              onTap: () {
                                setState(() {
                                  _selectedLocation = loc;
                                  _selectedMember = null;
                                  _isSearchFocused = false;
                                  _searchController.text = loc.title;
                                });
                                FocusScope.of(context).unfocus();
                                _centerOn(LatLng(loc.latitude, loc.longitude));
                              },
                            )),
                      ],

                      if (_geoapifyResults.isEmpty &&
                          _allMatchingMembers.isEmpty &&
                          _allMatchingActivities.isEmpty &&
                          !_isSearchingGeoapify)
                        const Padding(
                          padding: EdgeInsets.all(20),
                          child: Center(
                            child: Text(
                              'No places or members found matching your search.',
                              style: TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),

          // 7. Right Floating Controls: Fit Destinations, GPS, Zoom Controls
          Positioned(
            right: 16,
            bottom: (_selectedMember != null || _selectedLocation != null) ? 290 : 90,
            child: Column(
              children: [
                GestureDetector(
                  onTap: _fitAllDestinations,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.12),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.crop_free_rounded, color: Color(0xFF0F172A), size: 20),
                  ),
                ),

                GestureDetector(
                  onTap: () async {
                    if (!_hasAcquiredGps) {
                      await _startDeviceLocationTracking();
                    }
                    _centerOn(_myLocation);
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.12),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.my_location_rounded, color: Color(0xFF0072FF), size: 20),
                  ),
                ),

                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.12),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
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
                          padding: const EdgeInsets.all(11),
                          decoration: const BoxDecoration(
                            border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
                          ),
                          child: const Icon(Icons.add, color: Color(0xFF0F172A), size: 18),
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
                          padding: const EdgeInsets.all(11),
                          child: const Icon(Icons.remove, color: Color(0xFF0F172A), size: 18),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 8. Bottom Information Card for Selected Marker
          if (_selectedMember != null || _selectedLocation != null)
            Positioned(
              left: 16,
              right: 16,
              bottom: 24,
              child: LocationInfoCard(
                member: _selectedMember,
                tripLocation: _selectedLocation,
                distanceText: _selectedMember != null
                    ? _calculateDistanceText(LatLng(_selectedMember!.latitude, _selectedMember!.longitude))
                    : (_selectedLocation != null
                        ? _calculateDistanceText(LatLng(_selectedLocation!.latitude, _selectedLocation!.longitude))
                        : null),
                onClose: () {
                  setState(() {
                    _selectedMember = null;
                    _selectedLocation = null;
                    _customPinnedLocation = null;
                  });
                },
                onFocusMember: _selectedMember != null
                    ? () => _centerOn(LatLng(_selectedMember!.latitude, _selectedMember!.longitude))
                    : null,
                onNavigate: () {
                  if (_selectedMember != null) {
                    _openExternalNavigation(
                      LatLng(_selectedMember!.latitude, _selectedMember!.longitude),
                      _selectedMember!.name,
                    );
                  } else if (_selectedLocation != null) {
                    _openExternalNavigation(
                      LatLng(_selectedLocation!.latitude, _selectedLocation!.longitude),
                      _selectedLocation!.title,
                    );
                  }
                },
                onAddToItinerary: (_isTripLeader && _selectedLocation?.isPublicPlace == true)
                    ? () => _addPlaceToItinerary(_selectedLocation!)
                    : null,
                onEditEvent: (_isTripLeader && _selectedLocation != null && !_selectedLocation!.isPublicPlace && _selectedLocation!.rawActivity != null)
                    ? () => _editItineraryEvent(_selectedLocation!)
                    : null,
              ),
            ),
        ],
      ),
    );
  }

  IconData _getFilterIcon(String filterKey) {
    switch (filterKey) {
      case 'Members':
        return Icons.people_alt_rounded;
      case 'Travel':
        return Icons.flight_takeoff_rounded;
      case 'Hotels':
        return Icons.hotel_rounded;
      case 'Sightseeing':
        return Icons.photo_camera_rounded;
      case 'Restaurants':
        return Icons.restaurant_rounded;
      default:
        return Icons.place_rounded;
    }
  }

  IconData _getLocationIcon(LocationType type) {
    switch (type) {
      case LocationType.hotel:
        return Icons.hotel_rounded;
      case LocationType.airport:
        return Icons.flight_takeoff_rounded;
      case LocationType.restaurant:
        return Icons.restaurant_rounded;
      case LocationType.sightseeing:
        return Icons.photo_camera_rounded;
      case LocationType.activity:
        return Icons.local_activity_rounded;
      case LocationType.general:
        return Icons.place_rounded;
    }
  }

  Color _getLocationColor(LocationType type) {
    switch (type) {
      case LocationType.hotel:
        return const Color(0xFF20C060);
      case LocationType.airport:
        return const Color(0xFFEA580C);
      case LocationType.restaurant:
        return const Color(0xFFF59E0B);
      case LocationType.sightseeing:
        return const Color(0xFF0EA5E9);
      case LocationType.activity:
        return const Color(0xFF9333EA);
      case LocationType.general:
        return const Color(0xFF3B82F6);
    }
  }
}

/// Custom GPS Marker representing the current user's location on the map.
/// Always rendered when device GPS permission is given / position acquired.
class _UserLocationMarker extends StatelessWidget {
  final String? profilePhoto;
  final bool isSharing;

  const _UserLocationMarker({
    this.profilePhoto,
    required this.isSharing,
  });

  @override
  Widget build(BuildContext context) {
    final hasPhoto = profilePhoto != null && profilePhoto!.trim().isNotEmpty;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            // Outer accuracy radar pulse halo
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF0072FF).withValues(alpha: 0.16),
              ),
            ),
            // Secondary glow ring
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF0072FF).withValues(alpha: 0.28),
              ),
            ),
            // User Avatar or GPS Disc
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                border: Border.all(color: const Color(0xFF0072FF), width: 2.2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Center(
                child: hasPhoto
                    ? ClipOval(
                        child: CachedNetworkImage(
                          imageUrl: ImageUtils.getOptimizedImageUrl(profilePhoto!),
                          width: 24,
                          height: 24,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => _buildGpsCore(),
                        ),
                      )
                    : _buildGpsCore(),
              ),
            ),
            // Sharing status dot (green when sharing with group, blue when only local)
            Positioned(
              bottom: 4,
              right: 4,
              child: Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  color: isSharing ? const Color(0xFF22C55E) : const Color(0xFF0072FF),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 1),
        // "You" label badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(6),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: const Text(
            'You',
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0072FF),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGpsCore() {
    return Container(
      width: 14,
      height: 14,
      decoration: const BoxDecoration(
        color: Color(0xFF0072FF),
        shape: BoxShape.circle,
      ),
      child: const Center(
        child: Icon(
          Icons.navigation,
          color: Colors.white,
          size: 8,
        ),
      ),
    );
  }
}

