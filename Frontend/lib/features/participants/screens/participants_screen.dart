import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

import '../../profile/screens/profile_screen.dart';
import '../../profile/services/user_service.dart';
import '../../trip/services/trip_service.dart';
import '../screens/join_requests_screen.dart';
import '../screens/manage_family_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:tripsync/core/utils/image_utils.dart';
import '../../../core/utils/date_formatter.dart';
import 'package:url_launcher/url_launcher.dart';

class ParticipantsScreen extends StatefulWidget {
  final VoidCallback? onBack;
  final Map<String, dynamic>? tripData;
  final String? profilePhotoUrl;
  final String? profileName;
  final bool isSoloTraveler;
  final String? userRole;

  const ParticipantsScreen({
    super.key, 
    this.onBack,
    this.tripData,
    this.profilePhotoUrl,
    this.profileName,
    this.isSoloTraveler = false,
    this.userRole,
  });

  @override
  State<ParticipantsScreen> createState() => _ParticipantsScreenState();
}

class _ParticipantsScreenState extends State<ParticipantsScreen> {
  final TripService _tripService = TripService();
  final UserService _userService = UserService();
  String _searchQuery = '';
  bool _isLoading = true;
  List<Map<String, dynamic>> _participants = [];
  List<Map<String, dynamic>> _removedTravelers = [];
  String? _currentUserId;
  int _pendingRequestsCount = 0;
  String? _currentUserRole;
  String? _fetchedTripType;
  String? _fetchedBusinessTripType;
  final Set<String> _expandedFamilyIds = {};

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchParticipants();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool get _isFamilyTrip {
    final tripType = _fetchedTripType ?? widget.tripData?['tripType'];
    final businessTripType = _fetchedBusinessTripType ?? widget.tripData?['businessTripType'];
    return tripType == 'Family' ||
        (tripType == 'Business' && businessTripType == 'Employees + Family');
  }

  bool get _isTripLeader {
    if (widget.tripData?['isRemovedFromTrip'] == true) return false;
    final role = (_currentUserRole ??
            widget.userRole ??
            widget.tripData?['originalRole'] ??
            widget.tripData?['participantRole'])
        ?.toString()
        .toLowerCase();
    return role == 'tripleader' ||
        role == 'trip_leader' ||
        role == 'creator' ||
        role == 'leader';
  }

  bool get _canManageFamily {
    if (widget.tripData?['isRemovedFromTrip'] == true) return false;
    if (!_isFamilyTrip) return false;
    final role = (_currentUserRole ??
            widget.userRole ??
            widget.tripData?['originalRole'] ??
            widget.tripData?['participantRole'])
        ?.toString()
        .toLowerCase();
    if (role == 'familymember' || role == 'family_member' || role == 'member') {
      return false;
    }
    // Trip leader, family leader, or solo traveler / individual in family trip
    return true;
  }

  Future<void> _fetchParticipants() async {
    final tripId = widget.tripData?['id'] ?? widget.tripData?['_id'];
    if (tripId == null) {
      setState(() => _isLoading = false);
      return;
    }

    final responses = await Future.wait([
      _tripService.getTripParticipants(tripId.toString()),
      _tripService.getJoinRequests(tripId.toString()),
      _userService.getProfile(),
    ]);

    final response = responses[0];
    final reqResponse = responses[1];
    final profileRes = responses[2];

    int count = 0;
    if (reqResponse['success'] == true && reqResponse['data'] is List) {
      count = (reqResponse['data'] as List).length;
    }

    String? currentUserId;
    if (profileRes['success'] == true && profileRes['data'] != null) {
      currentUserId = profileRes['data']['_id']?.toString();
    }

    if (response['success'] == true) {
      final List<dynamic> rawData = response['data'] ?? [];
      final List<Map<String, dynamic>> participantsList = rawData.map((e) => Map<String, dynamic>.from(e)).toList();

      final List<dynamic> removedRaw = response['removedTravelers'] ?? [];
      final List<Map<String, dynamic>> removedList = removedRaw.map((e) => Map<String, dynamic>.from(e)).toList();

      String? detectedRole;
      if (currentUserId != null) {
        for (var p in participantsList) {
          final pUserId = p['userId']?.toString() ?? p['user']?['_id']?.toString() ?? p['user']?.toString();
          if (pUserId == currentUserId.toString()) {
            detectedRole = p['role']?.toString();
            break;
          }
        }
      }

      final fetchedType = response['tripType']?.toString();
      final fetchedBType = response['businessTripType']?.toString();

      setState(() {
        _participants = participantsList;
        _removedTravelers = removedList;
        _currentUserId = currentUserId;
        _pendingRequestsCount = count;
        _currentUserRole = detectedRole;
        if (fetchedType != null) _fetchedTripType = fetchedType;
        if (fetchedBType != null) _fetchedBusinessTripType = fetchedBType;
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(response['message'] ?? 'Failed to load members')),
        );
      }
    }
  }

  String _getInitials(String? name) {
    if (name == null || name.isEmpty) return 'U';
    return name.split(' ').take(2).map((e) => e[0].toUpperCase()).join();
  }

  bool _hasValidPhone(dynamic phone) {
    if (phone == null) return false;
    final str = phone.toString().trim();
    if (str.isEmpty) return false;
    final lower = str.toLowerCase();
    if (lower == 'null' || lower == 'n/a' || lower == 'none' || lower == 'no contact info') return false;
    return RegExp(r'\d').hasMatch(str);
  }

  List<Map<String, dynamic>> get _filteredParticipants {
    final query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) return _participants;

    return _participants.where((p) {
      final name = (p['name'] ?? '').toString().toLowerCase();
      final group = (p['group'] ?? '').toString().toLowerCase();
      final type = (p['type'] ?? '').toString().toLowerCase();
      final phone = (p['phone'] ?? '').toString().toLowerCase();
      final email = (p['email'] ?? '').toString().toLowerCase();

      final matchesLeader = name.contains(query) ||
          group.contains(query) ||
          type.contains(query) ||
          phone.contains(query) ||
          email.contains(query);

      if (matchesLeader) return true;

      // Check all nested family members
      final familyMembers = p['familyMembers'] as List<dynamic>? ?? [];
      final matchesFamilyMember = familyMembers.any((fm) {
        final fmName = (fm['name'] ?? '').toString().toLowerCase();
        final fmEmail = (fm['email'] ?? '').toString().toLowerCase();
        final fmPhone = (fm['phone'] ?? fm['mobile'] ?? '').toString().toLowerCase();
        final fmRel = (fm['relationship'] ?? '').toString().toLowerCase();

        return fmName.contains(query) ||
            fmEmail.contains(query) ||
            fmPhone.contains(query) ||
            fmRel.contains(query);
      });

      return matchesFamilyMember;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    int totalMembers = 0;
    int uniqueFamilies = 0;
    int totalSolo = 0;

    for (var p in _participants) {
      final role = p['role']?.toString().toLowerCase() ?? '';
      final type = p['type']?.toString().toLowerCase() ?? '';
      final group = p['group']?.toString().toLowerCase() ?? '';
      final fm = p['familyMembers'] as List<dynamic>? ?? [];

      final hasFamily = fm.isNotEmpty;
      final isFamily = hasFamily &&
          (type == 'family' ||
              group.contains('family') ||
              role == 'familyleader' ||
              role == 'family_leader' ||
              role == 'tripleader' ||
              role == 'trip_leader');

      if (isFamily) {
        uniqueFamilies++;
        totalMembers += 1 + fm.length; // Leader + family members
      } else {
        // Individual / Solo traveler (includes soloTraveler, or tripLeader/familyLeader traveling without family)
        totalSolo++;
        totalMembers++;
      }
    }

    final filtered = _filteredParticipants;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),

      body: SafeArea(
        child: Column(
          children: [
            // Custom Header (Unified with documents navbar style)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: widget.onBack ?? () => Navigator.pop(context),
                      behavior: HitTestBehavior.opaque,
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: widget.tripData != null && widget.tripData!['imageUrl'] != null
                                ? CachedNetworkImage(imageUrl: ImageUtils.getOptimizedImageUrl(widget.tripData!['imageUrl']),
                                    height: 48,
                                    width: 48,
                                    fit: BoxFit.cover,
                                    errorWidget: (context, url, error) => Container(
                                      height: 48,
                                      width: 48,
                                      color: Colors.grey[200],
                                      child: const Icon(Icons.image, color: Colors.grey),
                                    ),
                                  )
                                : CachedNetworkImage(imageUrl: ImageUtils.getOptimizedImageUrl('https://images.unsplash.com/photo-1502602898657-3e91760cbb34?w=150&auto=format&fit=crop&q=80'),
                                    height: 48,
                                    width: 48,
                                    fit: BoxFit.cover,
                                  ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Trip Members',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.calendar_today_outlined,
                                      size: 11,
                                      color: Color(0xFF64748B),
                                    ),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        TripInfoHelper.formatTripHeader(
                                          widget.tripData,
                                          defaultText: 'May 20 – May 27, 2025 • 8 Members',
                                          showMembers: true,
                                          customMembersCount: totalMembers,
                                        ),
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: Color(0xFF64748B),
                                          fontWeight: FontWeight.w500,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // 1. Join Request Approval Button (Only for Trip Leader)
                  if (_isTripLeader)
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.how_to_reg_outlined, color: AppColors.primary),
                          tooltip: 'Review Join Requests',
                          onPressed: () async {
                            final acceptedUser = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => JoinRequestsScreen(tripData: widget.tripData),
                              ),
                            );
                            if (acceptedUser != null && acceptedUser is Map<String, dynamic>) {
                              _fetchParticipants();
                            } else {
                              _fetchParticipants();
                            }
                          },
                        ),
                        if (_pendingRequestsCount > 0)
                          Positioned(
                            right: 4,
                            top: 4,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Color(0xFFEF4444), // red
                                shape: BoxShape.circle,
                              ),
                              constraints: const BoxConstraints(
                                minWidth: 16,
                                minHeight: 16,
                              ),
                              child: Center(
                                child: Text(
                                  _pendingRequestsCount > 99 ? '99+' : _pendingRequestsCount.toString(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),

                  // 2. Add / Update Family Members Button
                  if (_canManageFamily)
                    IconButton(
                      icon: const Icon(Icons.person_add_alt_1_outlined, color: AppColors.primary),
                      tooltip: 'Family Details',
                      onPressed: () async {
                        final updated = await Navigator.push<bool>(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ManageFamilyScreen(
                              tripData: {
                                ...?widget.tripData,
                                'tripType': _fetchedTripType ?? widget.tripData?['tripType'],
                                'businessTripType': _fetchedBusinessTripType ?? widget.tripData?['businessTripType'],
                              },
                            ),
                          ),
                        );
                        if (updated == true) {
                          _fetchParticipants();
                        }
                      },
                    ),
                  // 3. Leave Trip Button
                  if (widget.tripData?['isRemovedFromTrip'] != true)
                    IconButton(
                      icon: const Icon(Icons.exit_to_app_rounded, color: Color(0xFFEF4444)),
                      tooltip: 'Leave Trip',
                      onPressed: _handleLeaveTrip,
                    ),
                  // Profile Picture
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const Scaffold(
                            backgroundColor: Color(0xFFF8FAFC),
                            body: ProfileScreen(),
                          ),
                        ),
                      );
                    },
                    child: CircleAvatar(
                      radius: 16,
                      backgroundColor: const Color(0xFFE2E8F0),
                      backgroundImage: widget.profilePhotoUrl != null && widget.profilePhotoUrl!.isNotEmpty
                          ? CachedNetworkImageProvider(ImageUtils.getOptimizedImageUrl(widget.profilePhotoUrl))
                          : null,
                      child: widget.profilePhotoUrl == null || widget.profilePhotoUrl!.isEmpty
                          ? Text(
                              _getInitials(widget.profileName),
                              style: const TextStyle(
                                color: Color(0xFF475569),
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            )
                          : null,
                    ),
                  ),
                ],
              ),
            ),

            if (_isLoading)
              const Expanded(child: Center(child: CircularProgressIndicator()))
            else
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Analytics Divs Row
                    Row(
                      children: [
                        // Total Members
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.01),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEFF6FF),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(Icons.groups_outlined, color: Color(0xFF1E5AE6), size: 18),
                                ),
                                const SizedBox(height: 10),
                                const Text(
                                  'Members',
                                  style: TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w500),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '$totalMembers Travelers',
                                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Total Families
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.01),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFECFDF5),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(Icons.family_restroom_outlined, color: Color(0xFF10B981), size: 18),
                                ),
                                const SizedBox(height: 10),
                                const Text(
                                  'Families',
                                  style: TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w500),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '$uniqueFamilies Groups',
                                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Total Solo
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.01),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFF7ED),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(Icons.person_outline, color: Color(0xFFF97316), size: 18),
                                ),
                                const SizedBox(height: 10),
                                const Text(
                                  'Solo Travelers',
                                  style: TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w500),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '$totalSolo Travelers',
                                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Search box
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.02),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: TextField(
                        controller: _searchController,
                        onChanged: (val) {
                          setState(() {
                            _searchQuery = val;
                          });
                        },
                        decoration: InputDecoration(
                          hintText: 'Search members or families...',
                          hintStyle: const TextStyle(color: AppColors.textLight, fontSize: 14),
                          prefixIcon: const Icon(Icons.search, color: AppColors.primary, size: 20),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 18, color: AppColors.textLight),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() {
                                      _searchQuery = '';
                                    });
                                  },
                                )
                              : null,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Title
                    const Text(
                      'All Travelers List',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Members List
                    filtered.isEmpty
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 40),
                              child: Text('No members match your search'),
                            ),
                          )
                        : Column(
                            children: filtered.map((member) {
                              final isLeader = member['role'] == 'tripLeader' || member['role'] == 'Trip Leader';
                              final familyMembers = member['familyMembers'] as List<dynamic>? ?? [];
                              final hasFamilyMembers = familyMembers.isNotEmpty;
                              final isFamilyLeader = (member['role'] == 'familyLeader' || member['role'] == 'Family Leader') && hasFamilyMembers;
                              final memberId = (member['id'] ?? member['_id'] ?? member['userId'] ?? member['name'] ?? '').toString();
                              final memberUserId = (member['userId'] ?? member['id'] ?? member['_id'] ?? '').toString();
                              final isMyFamilyLeader = _currentUserId != null &&
                                  _currentUserId!.isNotEmpty &&
                                  (memberUserId == _currentUserId || memberId == _currentUserId);

                              final q = _searchQuery.trim().toLowerCase();
                              final hasMatchingChild = q.isNotEmpty && familyMembers.any((fm) {
                                final fmName = (fm['name'] ?? '').toString().toLowerCase();
                                final fmEmail = (fm['email'] ?? '').toString().toLowerCase();
                                final fmPhone = (fm['phone'] ?? fm['mobile'] ?? '').toString().toLowerCase();
                                final fmRel = (fm['relationship'] ?? '').toString().toLowerCase();
                                return fmName.contains(q) || fmEmail.contains(q) || fmPhone.contains(q) || fmRel.contains(q);
                              });
                              final isExpanded = _expandedFamilyIds.contains(memberId) || hasMatchingChild;

                              Widget titleWidget = Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.only(top: 2),
                                      child: Text(
                                        '${member['name']}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.textPrimary,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      if (isLeader)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFEFF6FF),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: const Text(
                                            'Trip Leader',
                                            style: TextStyle(
                                              fontSize: 8,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF1E5AE6),
                                            ),
                                          ),
                                        ),
                                      if (isFamilyLeader && !isLeader)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF1F5F9),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: const Text(
                                            'Family Leader',
                                            style: TextStyle(
                                              fontSize: 8,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF475569),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              );

                              Widget leadingWidget = CircleAvatar(
                                radius: 22,
                                backgroundImage: CachedNetworkImageProvider(
                                  ImageUtils.getOptimizedImageUrl(member['avatar'] ?? 'https://ui-avatars.com/api/?name=${Uri.encodeComponent(member['name'] ?? 'User')}')
                                ),
                              );
                              
                              final groupText = member['group'] != null &&
                                      member['group'].toString().isNotEmpty &&
                                      member['group'] != 'null' &&
                                      member['group'] != 'Individual'
                                  ? (hasFamilyMembers ? member['group'] : 'Solo Traveler')
                                  : (hasFamilyMembers ? 'Family Group' : 'Solo Traveler');
                              final memberAge = (member['age'] != null && member['age'].toString() != '0' && member['age'].toString().isNotEmpty && member['age'].toString().toLowerCase() != 'null')
                                  ? member['age'].toString()
                                  : 'N/A';

                              Widget subtitleWidget = Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    hasFamilyMembers
                                        ? '$groupText (${familyMembers.length + 1} Members)'
                                        : groupText,
                                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Age: $memberAge',
                                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                  ),
                                ],
                              );

                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: const Color(0xFFE2E8F0),
                                    width: 1.0,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.02),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  children: [
                                    GestureDetector(
                                      behavior: HitTestBehavior.opaque,
                                      onTap: hasFamilyMembers
                                          ? () {
                                              setState(() {
                                                if (_expandedFamilyIds.contains(memberId)) {
                                                  _expandedFamilyIds.remove(memberId);
                                                } else {
                                                  _expandedFamilyIds.add(memberId);
                                                }
                                              });
                                            }
                                          : null,
                                      child: Row(
                                        children: [
                                          leadingWidget,
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                titleWidget,
                                                const SizedBox(height: 2),
                                                subtitleWidget,
                                              ],
                                            ),
                                          ),
                                          if (_hasValidPhone(member['phone']))
                                            IconButton(
                                              icon: const Icon(Icons.call_outlined, color: AppColors.primary, size: 20),
                                              tooltip: 'Call',
                                              onPressed: () async {
                                                final phone = member['phone'];
                                                if (phone != null && phone.toString().isNotEmpty) {
                                                  final Uri launchUri = Uri(
                                                    scheme: 'tel',
                                                    path: phone.toString().trim(),
                                                  );
                                                  if (await canLaunchUrl(launchUri)) {
                                                    await launchUrl(launchUri);
                                                  } else {
                                                    if (context.mounted) {
                                                      ScaffoldMessenger.of(context).showSnackBar(
                                                        SnackBar(content: Text('Could not launch dialer for ${member['name']}')),
                                                      );
                                                    }
                                                  }
                                                }
                                              },
                                            ),
                                          if (hasFamilyMembers)
                                            IconButton(
                                              icon: AnimatedRotation(
                                                turns: isExpanded ? 0.5 : 0.0,
                                                duration: const Duration(milliseconds: 200),
                                                child: const Icon(
                                                  Icons.keyboard_arrow_down_rounded,
                                                  color: Color(0xFF64748B),
                                                  size: 24,
                                                ),
                                              ),
                                              tooltip: isExpanded ? 'Hide family members' : 'Show family members',
                                              onPressed: () {
                                                setState(() {
                                                  if (_expandedFamilyIds.contains(memberId)) {
                                                    _expandedFamilyIds.remove(memberId);
                                                  } else {
                                                    _expandedFamilyIds.add(memberId);
                                                  }
                                                });
                                              },
                                            ),
                                        ],
                                      ),
                                    ),
                                    if (hasFamilyMembers && isExpanded) ...[
                                      const SizedBox(height: 10),
                                      const Divider(height: 1, color: Color(0xFFE2E8F0)),
                                      const SizedBox(height: 10),
                                      Column(
                                        children: familyMembers.map((fm) {
                                          final fmName = (fm['name'] ?? '').toString();
                                          final fmEmail = (fm['email'] ?? '').toString();
                                          final fmPhone = (fm['phone'] ?? fm['mobile'] ?? '').toString();
                                          final fmRel = (fm['relationship'] ?? 'Family').toString();
                                          final fmAge = (fm['age'] != null && fm['age'].toString() != '0' && fm['age'].toString().isNotEmpty && fm['age'].toString().toLowerCase() != 'null')
                                              ? fm['age'].toString()
                                              : 'N/A';

                                          final isMatched = q.isNotEmpty && (
                                            fmName.toLowerCase().contains(q) ||
                                            fmEmail.toLowerCase().contains(q) ||
                                            fmPhone.toLowerCase().contains(q) ||
                                            fmRel.toLowerCase().contains(q) ||
                                            fmAge.toLowerCase().contains(q)
                                          );

                                          return Container(
                                            margin: const EdgeInsets.only(bottom: 6),
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                            decoration: BoxDecoration(
                                              color: isMatched ? const Color(0xFFEFF6FF) : const Color(0xFFF8FAFC),
                                              borderRadius: BorderRadius.circular(12),
                                              border: Border.all(
                                                color: isMatched ? const Color(0xFF3B82F6) : const Color(0xFFE2E8F0),
                                                width: 1.0,
                                              ),
                                            ),
                                            child: Row(
                                              children: [
                                                CircleAvatar(
                                                  radius: 14,
                                                  backgroundColor: const Color(0xFFE2E8F0),
                                                  backgroundImage: (fm['avatar'] != null && fm['avatar'].toString().isNotEmpty)
                                                      ? CachedNetworkImageProvider(ImageUtils.getOptimizedImageUrl(fm['avatar']))
                                                      : null,
                                                  child: (fm['avatar'] == null || fm['avatar'].toString().isEmpty)
                                                      ? Text(
                                                          fmName.isNotEmpty 
                                                              ? fmName[0].toUpperCase() 
                                                              : 'U',
                                                          style: TextStyle(
                                                            fontSize: 12,
                                                            color: isMatched ? const Color(0xFF1D4ED8) : const Color(0xFF475569),
                                                            fontWeight: FontWeight.bold,
                                                          ),
                                                        )
                                                      : null,
                                                ),
                                                const SizedBox(width: 10),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Row(
                                                        children: [
                                                          Expanded(
                                                            child: Text(
                                                              fmName.isNotEmpty ? fmName : 'Unknown',
                                                              style: TextStyle(
                                                                fontSize: 13,
                                                                fontWeight: isMatched ? FontWeight.bold : FontWeight.w600,
                                                                color: isMatched ? const Color(0xFF1D4ED8) : const Color(0xFF334155),
                                                              ),
                                                              overflow: TextOverflow.ellipsis,
                                                            ),
                                                          ),
                                                          Container(
                                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                            decoration: BoxDecoration(
                                                              color: isMatched ? const Color(0xFFDBEAFE) : const Color(0xFFF1F5F9),
                                                              borderRadius: BorderRadius.circular(6),
                                                            ),
                                                            child: Text(
                                                              isMatched ? 'Matched' : 'Member',
                                                              style: TextStyle(
                                                                fontSize: 10,
                                                                color: isMatched ? const Color(0xFF1D4ED8) : const Color(0xFF64748B),
                                                                fontWeight: FontWeight.bold,
                                                              ),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                      const SizedBox(height: 2),
                                                      Text(
                                                        'Age: $fmAge',
                                                        style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                                      ),
                                                      const SizedBox(height: 1),
                                                      Text(
                                                        'Relation: $fmRel',
                                                        style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                if (_hasValidPhone(fmPhone))
                                                  IconButton(
                                                    icon: const Icon(Icons.call_outlined, color: AppColors.primary, size: 18),
                                                    tooltip: 'Call',
                                                    onPressed: () async {
                                                      final phone = fm['phone'] ?? fm['mobile'] ?? fm['email'];
                                                      if (phone != null && phone.toString().isNotEmpty) {
                                                        final Uri launchUri = Uri(
                                                          scheme: 'tel',
                                                          path: phone.toString().trim(),
                                                        );
                                                        if (await canLaunchUrl(launchUri)) {
                                                          await launchUrl(launchUri);
                                                        } else {
                                                          if (context.mounted) {
                                                            ScaffoldMessenger.of(context).showSnackBar(
                                                              SnackBar(content: Text('Could not launch dialer for ${fm['name']}')),
                                                            );
                                                          }
                                                        }
                                                      }
                                                    },
                                                  ),
                                                if (isMyFamilyLeader)
                                                  IconButton(
                                                    icon: const Icon(Icons.person_remove_outlined, color: Color(0xFFEF4444), size: 18),
                                                    tooltip: 'Remove from trip',
                                                    onPressed: () => _confirmRemoveFamilyMember(fm),
                                                  ),
                                              ],
                                            ),
                                          );
                                        }).toList(),
                                      ),
                                    ],
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                    // Removed Travelers List
                    if (_removedTravelers.isNotEmpty) ...[
                      const SizedBox(height: 28),
                      Row(
                        children: [
                          const Text(
                            'Removed Travelers List',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEE2E2),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${_removedTravelers.length}',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFDC2626),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Column(
                        children: _removedTravelers.map((rm) {
                          return _buildRemovedTravelerTile(rm);
                        }).toList(),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRemovedTravelerTile(Map<String, dynamic> rm) {
    final name = (rm['name'] ?? 'Removed Traveler').toString();
    final type = (rm['type'] ?? 'Solo').toString();
    final avatar = rm['avatar']?.toString();
    final familyLeaderName = rm['familyLeaderName']?.toString();
    final status = (rm['status'] ?? 'removed').toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: const Color(0xFFE2E8F0),
            backgroundImage: (avatar != null && avatar.isNotEmpty)
                ? CachedNetworkImageProvider(ImageUtils.getOptimizedImageUrl(avatar))
                : null,
            child: (avatar == null || avatar.isEmpty)
                ? Text(
                    name.isNotEmpty ? name[0].toUpperCase() : 'U',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF64748B),
                      fontWeight: FontWeight.bold,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        name,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF475569),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEE2E2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        status == 'left' ? 'Left' : 'Removed',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFDC2626),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                if (familyLeaderName != null && familyLeaderName.isNotEmpty)
                  Text(
                    'Family Member • Family Leader: $familyLeaderName',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF64748B),
                      fontWeight: FontWeight.w500,
                    ),
                  )
                else
                  Text(
                    type == 'Family Member' ? 'Family Member' : 'Solo Traveler',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF64748B),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmRemoveFamilyMember(Map<String, dynamic> fm) async {
    final fmName = (fm['name'] ?? 'this family member').toString();
    final memberId = (fm['id'] ?? fm['_id'] ?? fm['userId'])?.toString();
    if (memberId == null || memberId.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Remove Family Member?'),
        content: Text('Are you sure you want to remove $fmName from your family in this trip?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final tripId = (widget.tripData?['id'] ?? widget.tripData?['_id'])?.toString();
      if (tripId == null) return;

      setState(() => _isLoading = true);
      final res = await _tripService.removeFamilyMember(tripId, memberId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res['message'] ?? 'Family member removed.')),
        );
      }
      _fetchParticipants();
    }
  }

  Future<void> _handleLeaveTrip() async {
    final tripId = (widget.tripData?['id'] ?? widget.tripData?['_id'])?.toString();
    if (tripId == null) return;

    final isFriendsOrEmployeeOnly = !_isFamilyTrip;
    final isTripLeader = _isTripLeader;

    // Current user's participant entry
    final myParticipant = _participants.firstWhere(
      (p) => p['userId']?.toString() == _currentUserId,
      orElse: () => {},
    );
    final myRole = (myParticipant['role'] ?? _currentUserRole ?? '').toString().toLowerCase();
    final isFamilyMember = myRole == 'familymember' || myRole == 'family_member';
    final isFamilyLeader = myRole == 'familyleader' || myRole == 'family_leader';
    final isSolo = myRole == 'solotraveler' || myRole == 'solo_traveler' || myRole == 'solo';

    // Rule 1: Family Member in Family / Employee+Family trip cannot leave on their own
    if (_isFamilyTrip && isFamilyMember) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Cannot Leave Trip Directly'),
          content: const Text(
            'Family members cannot leave the trip directly. Only your Family Leader can remove you from the trip from their account.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
      return;
    }

    // Rule 2: Friends or Employees Only
    if (isFriendsOrEmployeeOnly) {
      if (!isTripLeader) {
        // Regular member leaves without permission
        final confirm = await _showConfirmDialog(
          title: 'Leave Trip',
          content: 'Are you sure you want to leave this trip?',
          confirmText: 'Leave Trip',
        );
        if (confirm == true) {
          _executeLeaveTrip(tripId);
        }
      } else {
        // Trip Leader leaves: assign position to other trip member
        final otherMembers = _participants.where((p) => p['userId']?.toString() != _currentUserId).toList();
        if (otherMembers.isEmpty) {
          final confirm = await _showConfirmDialog(
            title: 'Leave Trip',
            content: 'You are the only member in this trip. Leaving will cancel the trip. Are you sure you want to leave?',
            confirmText: 'Cancel Trip & Leave',
          );
          if (confirm == true) {
            _executeLeaveTrip(tripId);
          }
        } else {
          _showSelectLeaderAndLeaveDialog(
            title: 'Assign New Trip Leader',
            subtitle: 'You must assign another trip member as Trip Leader before leaving.',
            candidates: otherMembers,
            onConfirmed: (selectedUserId) {
              _executeLeaveTrip(tripId, newTripLeaderId: selectedUserId);
            },
          );
        }
      }
      return;
    }

    // Rule 3: Family or Employee with Family Trip
    if (_isFamilyTrip) {
      // 3A: Solo traveler
      if (isSolo && !isTripLeader) {
        final confirm = await _showConfirmDialog(
          title: 'Leave Trip',
          content: 'Are you sure you want to leave this trip as a solo traveler?',
          confirmText: 'Leave Trip',
        );
        if (confirm == true) {
          _executeLeaveTrip(tripId);
        }
        return;
      }

      // 3B: Family Leader (and not Trip Leader)
      if (isFamilyLeader && !isTripLeader) {
        final myFamilyMembers = (myParticipant['familyMembers'] as List<dynamic>?) ?? [];
        if (myFamilyMembers.isEmpty) {
          final confirm = await _showConfirmDialog(
            title: 'Leave Trip',
            content: 'Are you sure you want to leave this trip?',
            confirmText: 'Leave Trip',
          );
          if (confirm == true) {
            _executeLeaveTrip(tripId);
          }
          return;
        }

        // Ask "Leave with Full Family" or "Only Me Leave"
        _showFamilyLeaderLeaveChoices(
          familyMembers: myFamilyMembers,
          onLeaveFullFamily: () {
            _executeLeaveTrip(tripId, leaveType: 'full_family');
          },
          onOnlyMeLeave: (selectedFmId, selectedFmEmail) {
            _executeLeaveTrip(
              tripId,
              leaveType: 'only_me',
              newFamilyLeaderId: selectedFmId,
              newFamilyLeaderEmail: selectedFmEmail,
            );
          },
        );
        return;
      }

      // 3C: Trip Leader in Family Trip
      if (isTripLeader) {
        final myFamilyMembers = (myParticipant['familyMembers'] as List<dynamic>?) ?? [];
        final isWithFamily = myFamilyMembers.isNotEmpty;

        if (!isWithFamily) {
          // Trip Leader is Solo Traveler: assign to any other Solo Traveler or Family Leader
          final eligibleLeaders = _participants.where((p) {
            if (p['userId']?.toString() == _currentUserId) return false;
            final r = (p['role'] ?? '').toString().toLowerCase();
            return r == 'solotraveler' || r == 'solo_traveler' || r == 'familyleader' || r == 'family_leader';
          }).toList();

          if (eligibleLeaders.isEmpty) {
            final confirm = await _showConfirmDialog(
              title: 'Leave Trip',
              content: 'You are the only leader in this trip. Leaving will cancel the trip. Confirm?',
              confirmText: 'Cancel Trip & Leave',
            );
            if (confirm == true) {
              _executeLeaveTrip(tripId);
            }
          } else {
            _showSelectLeaderAndLeaveDialog(
              title: 'Assign New Trip Leader',
              subtitle: 'Assign the Trip Leader position to another Solo Traveler or Family Leader.',
              candidates: eligibleLeaders,
              onConfirmed: (selectedLeaderId) {
                _executeLeaveTrip(tripId, newTripLeaderId: selectedLeaderId);
              },
            );
          }
        } else {
          // Trip Leader WITH Family:
          _showTripLeaderWithFamilyLeaveFlow(
            myFamilyMembers: myFamilyMembers,
            tripId: tripId,
          );
        }
      }
    }
  }

  void _showFamilyLeaderLeaveChoices({
    required List<dynamic> familyMembers,
    required VoidCallback onLeaveFullFamily,
    required void Function(String? fmId, String? fmEmail) onOnlyMeLeave,
  }) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Leave Trip Options',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 8),
            const Text(
              'As a Family Leader, please choose how you want to leave:',
              style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 20),
            ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              leading: const Icon(Icons.group_remove_outlined, color: Color(0xFFEF4444)),
              title: const Text('Leave with Full Family', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              subtitle: const Text('You and all members of your family will leave the trip.', style: TextStyle(fontSize: 12)),
              onTap: () {
                Navigator.pop(ctx);
                onLeaveFullFamily();
              },
            ),
            const SizedBox(height: 12),
            ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              leading: const Icon(Icons.person_outline, color: Color(0xFF1E5AE6)),
              title: const Text('Only Me Leave', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              subtitle: const Text('Assign Family Leader position to another member of your family.', style: TextStyle(fontSize: 12)),
              onTap: () {
                Navigator.pop(ctx);
                _showAssignFamilyLeaderSheet(
                  familyMembers: familyMembers,
                  onConfirmed: onOnlyMeLeave,
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showAssignFamilyLeaderSheet({
    required List<dynamic> familyMembers,
    required void Function(String? fmId, String? fmEmail) onConfirmed,
  }) {
    String? selectedMemberId;
    String? selectedMemberEmail;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) => StatefulBuilder(
        builder: (sheetCtx, setSheetState) {
          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 24,
              bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Assign New Family Leader',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Select a family member who has an account in the app. If a member does not have an account, add their registered email first.',
                  style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 16),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 280),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: familyMembers.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final fm = familyMembers[i];
                      final fmId = (fm['id'] ?? fm['_id'] ?? fm['userId'])?.toString();
                      final fmName = (fm['name'] ?? 'Family Member').toString();
                      final fmEmail = (fm['email'] ?? '').toString();
                      final hasAccount = (fm['userId'] != null && fm['userId'].toString().isNotEmpty) || fmEmail.isNotEmpty;
                      final isSelected = selectedMemberId == fmId;

                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected ? const Color(0xFFEFF6FF) : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected ? const Color(0xFF1E5AE6) : const Color(0xFFE2E8F0),
                            width: isSelected ? 1.5 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Radio<String>(
                              value: fmId ?? '',
                              groupValue: selectedMemberId,
                              onChanged: hasAccount
                                  ? (val) {
                                      setSheetState(() {
                                        selectedMemberId = val;
                                        selectedMemberEmail = fmEmail;
                                      });
                                    }
                                  : null,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(fmName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                                  if (fmEmail.isNotEmpty)
                                    Text(fmEmail, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)))
                                  else
                                    const Text('No app account linked', style: TextStyle(fontSize: 11, color: Color(0xFFEF4444))),
                                ],
                              ),
                            ),
                            if (!hasAccount)
                              TextButton(
                                onPressed: () async {
                                  final linkRes = await _promptLinkEmailDialog(fmName);
                                  if (linkRes != null && linkRes['email'] != null) {
                                    final newEmail = linkRes['email'] as String;
                                    final uData = linkRes['user'] as Map<String, dynamic>?;
                                    setSheetState(() {
                                      fm['email'] = newEmail;
                                      if (uData != null && uData['id'] != null) {
                                        fm['userId'] = uData['id'].toString();
                                      }
                                      selectedMemberId = fmId;
                                      selectedMemberEmail = newEmail;
                                    });
                                  }
                                },
                                child: const Text('Add Email', style: TextStyle(fontSize: 11)),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: selectedMemberId == null
                        ? null
                        : () {
                            Navigator.pop(sheetCtx);
                            onConfirmed(selectedMemberId, selectedMemberEmail);
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E5AE6),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Transfer Leadership & Leave', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<Map<String, dynamic>?> _promptLinkEmailDialog(String memberName) async {
    final controller = TextEditingController();
    String? errorMsg;
    bool isVerifying = false;

    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Link Account for $memberName'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Enter the registered email of this family member. They must have an account in the app.',
                style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: controller,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  hintText: 'Registered email address',
                  errorText: errorMsg,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isVerifying
                  ? null
                  : () async {
                      final email = controller.text.trim();
                      if (email.isEmpty) {
                        setDialogState(() => errorMsg = 'Email is required');
                        return;
                      }
                      setDialogState(() {
                        isVerifying = true;
                        errorMsg = null;
                      });

                      final tripId = (widget.tripData?['id'] ?? widget.tripData?['_id'])?.toString();
                      if (tripId == null) return;

                      final res = await _tripService.checkFamilyMemberEmail(tripId, email);
                      if (!dialogCtx.mounted) return;
                      if (res['success'] == true && res['isRegistered'] == true) {
                        Navigator.pop(dialogCtx, {
                          'email': email,
                          'user': res['user'],
                        });
                      } else {
                        setDialogState(() {
                          isVerifying = false;
                          errorMsg = res['message'] ?? 'Email not registered in app.';
                        });
                      }
                    },
              child: isVerifying
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Verify & Link'),
            ),
          ],
        ),
      ),
    );
  }

  void _showTripLeaderWithFamilyLeaveFlow({
    required List<dynamic> myFamilyMembers,
    required String tripId,
  }) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Trip Leader Leave Options',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 8),
            const Text(
              'You are the Trip Leader with a family group. Please select how you want to leave:',
              style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 20),
            ListTile(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: Color(0xFFE2E8F0))),
              leading: const Icon(Icons.group_remove_outlined, color: Color(0xFFEF4444)),
              title: const Text('Leave with Full Family', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              subtitle: const Text('Your family leaves, and Trip Leadership transfers to another group.', style: TextStyle(fontSize: 12)),
              onTap: () {
                Navigator.pop(ctx);
                final outsideLeaders = _participants.where((p) {
                  if (p['userId']?.toString() == _currentUserId) return false;
                  final r = (p['role'] ?? '').toString().toLowerCase();
                  return r == 'solotraveler' || r == 'solo_traveler' || r == 'familyleader' || r == 'family_leader';
                }).toList();

                if (outsideLeaders.isEmpty) {
                  _executeLeaveTrip(tripId, leaveType: 'full_family');
                } else {
                  _showSelectLeaderAndLeaveDialog(
                    title: 'Assign New Trip Leader',
                    subtitle: 'Select another Family Leader or Solo Traveler outside your family.',
                    candidates: outsideLeaders,
                    onConfirmed: (selectedLeaderId) {
                      _executeLeaveTrip(tripId, leaveType: 'full_family', newTripLeaderId: selectedLeaderId);
                    },
                  );
                }
              },
            ),
            const SizedBox(height: 12),
            ListTile(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: Color(0xFFE2E8F0))),
              leading: const Icon(Icons.person_outline, color: Color(0xFF1E5AE6)),
              title: const Text('Only Me Leave', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              subtitle: const Text('Assign Family Leader to your family member, then assign Trip Leader.', style: TextStyle(fontSize: 12)),
              onTap: () {
                Navigator.pop(ctx);
                // Step 1: Assign Family Leader
                _showAssignFamilyLeaderSheet(
                  familyMembers: myFamilyMembers,
                  onConfirmed: (selectedFmId, selectedFmEmail) {
                    // Step 2: Assign Trip Leader
                    final allEligibleLeaders = _participants.where((p) {
                      if (p['userId']?.toString() == _currentUserId) return false;
                      final r = (p['role'] ?? '').toString().toLowerCase();
                      return r == 'solotraveler' || r == 'solo_traveler' || r == 'familyleader' || r == 'family_leader';
                    }).toList();

                    // Include newly chosen family leader if not in list
                    final chosenFm = myFamilyMembers.firstWhere(
                      (m) => (m['id'] ?? m['_id'] ?? m['userId'])?.toString() == selectedFmId ||
                             (m['userId']?.toString() == selectedFmId),
                      orElse: () => {'name': 'New Family Leader'},
                    );
                    final fmName = chosenFm['name'] ?? 'New Family Leader';
                    final actualUserId = chosenFm['userId']?.toString() ?? selectedFmId;

                    final candidatesList = List<Map<String, dynamic>>.from(allEligibleLeaders);
                    if (actualUserId != null && !candidatesList.any((c) => c['userId']?.toString() == actualUserId)) {
                      candidatesList.insert(0, {
                        'userId': actualUserId,
                        'name': '$fmName (Your New Family Leader)',
                        'role': 'familyLeader',
                        'type': 'Family Group',
                      });
                    }

                    _showSelectLeaderAndLeaveDialog(
                      title: 'Assign New Trip Leader',
                      subtitle: 'Assign Trip Leader to your new Family Leader, another Family Leader, or a Solo Traveler.',
                      candidates: candidatesList,
                      onConfirmed: (selectedTripLeaderId) {
                        _executeLeaveTrip(
                          tripId,
                          leaveType: 'only_me',
                          newFamilyLeaderId: selectedFmId,
                          newFamilyLeaderEmail: selectedFmEmail,
                          newTripLeaderId: selectedTripLeaderId,
                        );
                      },
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showSelectLeaderAndLeaveDialog({
    required String title,
    required String subtitle,
    required List<Map<String, dynamic>> candidates,
    required void Function(String selectedLeaderId) onConfirmed,
  }) {
    String? selectedId;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetCtx) => StatefulBuilder(
        builder: (sheetCtx, setSheetState) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
              const SizedBox(height: 6),
              Text(subtitle, style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B))),
              const SizedBox(height: 16),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 280),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: candidates.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final cand = candidates[i];
                    final candUserId = (cand['userId'] ?? cand['id'] ?? cand['_id'])?.toString();
                    final candName = cand['name'] ?? 'Trip Member';
                    final candType = cand['type'] ?? cand['group'] ?? 'Member';
                    final isSelected = selectedId == candUserId;

                    return Container(
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFFEFF6FF) : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected ? const Color(0xFF1E5AE6) : const Color(0xFFE2E8F0),
                          width: isSelected ? 1.5 : 1,
                        ),
                      ),
                      child: RadioListTile<String>(
                        value: candUserId ?? '',
                        groupValue: selectedId,
                        title: Text(candName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                        subtitle: Text(candType, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                        onChanged: (val) {
                          setSheetState(() => selectedId = val);
                        },
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: selectedId == null
                      ? null
                      : () {
                          Navigator.pop(sheetCtx);
                          onConfirmed(selectedId!);
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEF4444),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Assign Leadership & Leave Trip', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<bool?> _showConfirmDialog({
    required String title,
    required String content,
    required String confirmText,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text(confirmText),
          ),
        ],
      ),
    );
  }

  Future<void> _executeLeaveTrip(
    String tripId, {
    String? leaveType,
    String? newTripLeaderId,
    String? newFamilyLeaderId,
    String? newFamilyLeaderEmail,
  }) async {
    setState(() => _isLoading = true);
    final res = await _tripService.leaveTrip(
      tripId,
      leaveType: leaveType,
      newTripLeaderId: newTripLeaderId,
      newFamilyLeaderId: newFamilyLeaderId,
      newFamilyLeaderEmail: newFamilyLeaderEmail,
    );

    if (!mounted) return;

    if (res['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['message'] ?? 'You have left the trip.'),
          backgroundColor: const Color(0xFF16A34A),
        ),
      );
      Navigator.of(context).popUntil((route) => route.isFirst);
    } else {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['message'] ?? 'Failed to leave trip.'),
          backgroundColor: const Color(0xFFEF4444),
        ),
      );
    }
  }
}
