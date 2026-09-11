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
  int _pendingRequestsCount = 0;
  String? _currentUserRole;
  String? _fetchedTripType;
  String? _fetchedBusinessTripType;

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
                                            'Leader',
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
                                            color: const Color(0xFFF0FDF4),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: const Text(
                                            'Family Leader',
                                            style: TextStyle(
                                              fontSize: 8,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF16A34A),
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
                              
                              final groupText = member['group'] != null && member['group'].toString().isNotEmpty && member['group'] != 'null'
                                  ? (hasFamilyMembers ? member['group'] : (isLeader ? 'Individual' : 'Solo Traveler'))
                                  : (hasFamilyMembers ? 'Family Group' : (isLeader ? 'Individual' : 'Solo Traveler'));
                              final contactText = member['phone'] ?? member['mobile'] ?? member['email'] ?? 'No contact info';

                              Widget subtitleWidget = Text(
                                '$groupText • $contactText',
                                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                              );

                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: isFamilyLeader ? const Color(0xFFF4FBF7) : Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: isFamilyLeader ? const Color(0xFFBBF7D0) : const Color(0xFFE2E8F0),
                                    width: isFamilyLeader ? 1.5 : 1.0,
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    if (isFamilyLeader) ...[
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(6),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFDCFCE7),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: const Icon(Icons.family_restroom, color: Color(0xFF16A34A), size: 16),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              groupText != 'Family' && groupText != 'Individual' ? groupText : 'Family Group',
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A)),
                                            ),
                                          ),
                                          Text(
                                            '${familyMembers.length + 1} Members',
                                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Color(0xFF16A34A)),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      const Divider(height: 1, color: Color(0xFFBBF7D0)),
                                      const SizedBox(height: 12),
                                    ],
                                    Row(
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
                                        IconButton(
                                          icon: const Icon(Icons.call_outlined, color: AppColors.primary, size: 20),
                                          onPressed: () async {
                                            final phone = member['phone'];
                                            if (phone != null && phone.toString().isNotEmpty) {
                                              final Uri launchUri = Uri(
                                                scheme: 'tel',
                                                path: phone.toString(),
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
                                            } else {
                                              if (context.mounted) {
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  SnackBar(content: Text('No phone number available for ${member['name']}')),
                                                );
                                              }
                                            }
                                          },
                                        ),
                                      ],
                                    ),
                                    if (hasFamilyMembers) ...[
                                      const SizedBox(height: 12),
                                      Column(
                                        children: familyMembers.map((fm) {
                                          final fmName = (fm['name'] ?? '').toString();
                                          final fmEmail = (fm['email'] ?? '').toString();
                                          final fmPhone = (fm['phone'] ?? fm['mobile'] ?? '').toString();
                                          final fmRel = (fm['relationship'] ?? 'Family').toString();

                                          final q = _searchQuery.trim().toLowerCase();
                                          final isMatched = q.isNotEmpty && (
                                            fmName.toLowerCase().contains(q) ||
                                            fmEmail.toLowerCase().contains(q) ||
                                            fmPhone.toLowerCase().contains(q) ||
                                            fmRel.toLowerCase().contains(q)
                                          );

                                          return Container(
                                            margin: const EdgeInsets.only(bottom: 6),
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                            decoration: BoxDecoration(
                                              color: isMatched ? const Color(0xFFF0FDF4) : Colors.white,
                                              borderRadius: BorderRadius.circular(12),
                                              border: Border.all(
                                                color: isMatched ? const Color(0xFF16A34A) : const Color(0xFFBBF7D0),
                                                width: isMatched ? 1.5 : 1.0,
                                              ),
                                            ),
                                            child: Row(
                                              children: [
                                                CircleAvatar(
                                                  radius: 14,
                                                  backgroundColor: Colors.white,
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
                                                            color: isMatched ? const Color(0xFF16A34A) : AppColors.primary,
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
                                                                color: isMatched ? const Color(0xFF15803D) : const Color(0xFF334155),
                                                              ),
                                                              overflow: TextOverflow.ellipsis,
                                                            ),
                                                          ),
                                                          Container(
                                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                            decoration: BoxDecoration(
                                                              color: isMatched ? const Color(0xFFDCFCE7) : const Color(0xFFEFF6FF),
                                                              borderRadius: BorderRadius.circular(6),
                                                            ),
                                                            child: Text(
                                                              isMatched ? 'Matched' : 'Member',
                                                              style: TextStyle(
                                                                fontSize: 10,
                                                                color: isMatched ? const Color(0xFF16A34A) : AppColors.primary,
                                                                fontWeight: FontWeight.bold,
                                                              ),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                      const SizedBox(height: 2),
                                                      Text(
                                                        '$fmRel • ${fmPhone.isNotEmpty ? fmPhone : (fmEmail.isNotEmpty ? fmEmail : 'No contact info')}',
                                                        style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                IconButton(
                                                  icon: const Icon(Icons.call_outlined, color: AppColors.primary, size: 18),
                                                  onPressed: () async {
                                                    final phone = fm['phone'] ?? fm['mobile'] ?? fm['email'];
                                                    if (phone != null && phone.toString().isNotEmpty && RegExp(r'^[0-9+\-\s]+$').hasMatch(phone.toString())) {
                                                      final Uri launchUri = Uri(
                                                        scheme: 'tel',
                                                        path: phone.toString(),
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
                                                    } else {
                                                      if (context.mounted) {
                                                        ScaffoldMessenger.of(context).showSnackBar(
                                                          SnackBar(content: Text('No valid phone number available for ${fm['name']}')),
                                                        );
                                                      }
                                                    }
                                                  },
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
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
