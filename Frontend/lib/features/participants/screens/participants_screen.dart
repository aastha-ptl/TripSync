import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/routes/app_routes.dart';

import '../../profile/screens/profile_screen.dart';
import '../../trip/services/trip_service.dart';
import '../screens/join_requests_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:tripsync/core/utils/image_utils.dart';
import '../../../core/utils/date_formatter.dart';

class ParticipantsScreen extends StatefulWidget {
  final VoidCallback? onBack;
  final Map<String, dynamic>? tripData;
  final String? profilePhotoUrl;
  final String? profileName;
  final bool isSoloTraveler;

  const ParticipantsScreen({
    super.key, 
    this.onBack,
    this.tripData,
    this.profilePhotoUrl,
    this.profileName,
    this.isSoloTraveler = false,
  });

  @override
  State<ParticipantsScreen> createState() => _ParticipantsScreenState();
}

class _ParticipantsScreenState extends State<ParticipantsScreen> {
  final TripService _tripService = TripService();
  String _searchQuery = '';
  bool _isLoading = true;
  List<Map<String, dynamic>> _participants = [];
  int _pendingRequestsCount = 0;

  @override
  void initState() {
    super.initState();
    _fetchParticipants();
  }

  Future<void> _fetchParticipants() async {
    if (widget.tripData == null || widget.tripData!['id'] == null) {
      setState(() => _isLoading = false);
      return;
    }

    final responses = await Future.wait([
      _tripService.getTripParticipants(widget.tripData!['id']),
      _tripService.getJoinRequests(widget.tripData!['id']),
    ]);

    final response = responses[0];
    final reqResponse = responses[1];

    int count = 0;
    if (reqResponse['success'] == true) {
      count = (reqResponse['data'] as List).length;
    }

    if (response['success'] == true) {
      setState(() {
        _participants = List<Map<String, dynamic>>.from(response['data']);
        _pendingRequestsCount = count;
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
    if (_searchQuery.isEmpty) return _participants;
    return _participants.where((p) {
      return p['name'].toString().toLowerCase().contains(_searchQuery.toLowerCase()) ||
          p['group'].toString().toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    // Calculations for analytics
    final totalMembers = _participants.length;
    // Families count: unique group names that are not 'Solo Traveler'
    final uniqueFamilies = _participants
        .where((p) => p['type'] == 'Family')
        .map((p) => p['group'])
        .toSet()
        .length;
    final totalSolo = _participants.where((p) => p['type'] == 'Solo').length;

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
                  const SizedBox(width: 12),
                  if (!widget.isSoloTraveler)
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.person_add_alt_1_outlined, color: AppColors.primary),
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
                              // Fetch again anyway in case they accepted/rejected but it didn't return the exact user object
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
                        onChanged: (val) {
                          setState(() {
                            _searchQuery = val;
                          });
                        },
                        decoration: const InputDecoration(
                          hintText: 'Search members or families...',
                          hintStyle: TextStyle(color: AppColors.textLight, fontSize: 14),
                          prefixIcon: Icon(Icons.search, color: AppColors.primary, size: 20),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(vertical: 14, horizontal: 16),
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
                              final isFamilyLeader = member['role'] == 'familyLeader';
                              final familyMembers = member['familyMembers'] as List<dynamic>? ?? [];
                              final hasFamilyMembers = isFamilyLeader && familyMembers.isNotEmpty;

                              Widget titleWidget = Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      '${member['name']}${hasFamilyMembers ? ' (+${familyMembers.length})' : ''}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.textPrimary,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (isLeader) ...[
                                    const SizedBox(width: 8),
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
                                  ],
                                  if (isFamilyLeader && !isLeader) ...[
                                    const SizedBox(width: 8),
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
                                ],
                              );

                              Widget leadingWidget = CircleAvatar(
                                radius: 22,
                                backgroundImage: CachedNetworkImageProvider(
                                  ImageUtils.getOptimizedImageUrl(member['avatar'] ?? 'https://ui-avatars.com/api/?name=${Uri.encodeComponent(member['name'] ?? 'User')}')
                                ),
                              );
                              
                              Widget subtitleWidget = Text(
                                '${member['group']} • ${member['phone'] ?? 'N/A'}',
                                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                              );

                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                ),
                                child: hasFamilyMembers ? Theme(
                                  data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                                  child: ExpansionTile(
                                    tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                                    leading: leadingWidget,
                                    title: titleWidget,
                                    subtitle: subtitleWidget,
                                    children: [
                                      Divider(height: 1, color: Colors.grey[200]),
                                      ...familyMembers.map((fm) => ListTile(
                                        contentPadding: const EdgeInsets.only(left: 70, right: 16, top: 4, bottom: 4),
                                        title: Text(fm['name'] ?? 'Family Member', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                                        subtitle: Text('${fm['relationship'] ?? 'Relative'} • ${fm['age'] ?? '?'} yrs\n${fm['email'] ?? 'No email'}', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                                      )).toList(),
                                      const SizedBox(height: 8),
                                    ],
                                  ),
                                ) : ListTile(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                  leading: leadingWidget,
                                  title: titleWidget,
                                  subtitle: subtitleWidget,
                                  trailing: IconButton(
                                    icon: const Icon(Icons.call_outlined, color: AppColors.primary, size: 20),
                                    onPressed: () {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('Calling ${member['name']}...')),
                                      );
                                    },
                                  ),
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

String _getInitials(String? name) {
  if (name == null || name.trim().isEmpty) return '';
  final parts = name.trim().split(RegExp(r'\s+'));
  if (parts.length > 1) {
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }
  return parts[0][0].toUpperCase();
}
