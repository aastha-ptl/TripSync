import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/widgets/custom_app_bar.dart';
import '../services/trip_service.dart';
import '../../profile/services/user_service.dart';
import 'trip_details_screen.dart';
import 'solo_traveler_dashboard_screen.dart';
import 'family_leader_dashboard_screen.dart';
import 'family_member_dashboard_screen.dart';
import 'member_dashboard_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:tripsync/core/utils/image_utils.dart';
import 'add_trip_screen.dart';
import '../../participants/screens/all_join_requests_screen.dart';
import '../../../core/utils/date_formatter.dart';

class TripsScreen extends StatefulWidget {
  final VoidCallback onProfileTap;

  const TripsScreen({super.key, required this.onProfileTap});

  @override
  State<TripsScreen> createState() => _TripsScreenState();
}

class _TripsScreenState extends State<TripsScreen> {
  String _searchQuery = '';
  String _selectedFilter = 'All';
  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> _allTrips = [];
  bool _isLoading = true;
  final TripService _tripService = TripService();
  final UserService _userService = UserService();
  String? _profilePhotoUrl;
  String? _profileName;

  @override
  void initState() {
    super.initState();
    _fetchTrips();
    _fetchProfile();
  }

  Future<void> _fetchProfile() async {
    final response = await _userService.getProfile();
    if (mounted && response['success'] == true) {
      setState(() {
        _profilePhotoUrl = response['data']['profilePhoto'];
        if (response['data']['firstName'] != null) {
          _profileName = '${response['data']['firstName']} ${response['data']['lastName'] ?? ''}'.trim();
        } else {
          _profileName = response['data']['name'];
        }
      });
    }
  }

  Future<void> _fetchTrips() async {
    setState(() {
      _isLoading = true;
    });

    final response = await _tripService.getTrips();
    if (mounted) {
      if (response['success'] == true) {
        final List<dynamic> data = response['data'];
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        
        setState(() {
          _allTrips = data.map((trip) {
            final startDate = TripInfoHelper.parseTripDate(trip['startDate'].toString());
            final endDate = TripInfoHelper.parseTripDate(trip['endDate'].toString());
            
            String status = 'Ongoing';
            Color statusColor = const Color(0xFFE8F0FE);
            Color textColor = const Color(0xFF1E5AE6);
            
            if (today.isBefore(startDate)) {
              status = 'Upcoming';
            } else if (today.isAfter(endDate)) {
              status = 'Completed';
              statusColor = const Color(0xFFF1F5F9);
              textColor = const Color(0xFF475569);
            }

            final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
            final dateStr = '${months[startDate.month - 1]} ${startDate.day} - ${months[endDate.month - 1]} ${endDate.day}, ${endDate.year}';
            
            String roleStr = trip['participantRole'] ?? 'Member';
            if (roleStr == 'tripLeader') roleStr = 'Trip Leader';
            if (roleStr == 'soloTraveler') roleStr = 'Solo Traveler';

            String imageUrl = trip['coverImage'] ?? 'https://images.unsplash.com/photo-1502602898657-3e91760cbb34?w=400&auto=format&fit=crop&q=60';
            if (imageUrl.startsWith('http://localhost')) {
               // handle localhost issues if needed, but assuming valid URL
            }

            return {
              'id': trip['_id'],
              '_id': trip['_id'],
              'startDate': trip['startDate'],
              'endDate': trip['endDate'],
              'title': trip['name'] ?? 'Untitled Trip',
              'name': trip['name'] ?? 'Untitled Trip',
              'description': trip['description'] ?? '',
              'location': 'Trip Location', // Not in schema, placeholder
              'dates': dateStr,
              'status': status,
              'statusColor': statusColor,
              'textColor': textColor,
              'imageUrl': imageUrl,
              'role': roleStr,
              'originalRole': trip['participantRole'] ?? 'Member',
              'membersCount': trip['membersCount'] ?? 1,
              'inviteToken': trip['invitationCode']?.toString() ?? trip['inviteToken']?.toString() ?? 'No Code Available',
            };
          }).toList();
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(response['message'] ?? 'Failed to load trips')),
        );
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _filteredTrips {
    return _allTrips.where((trip) {
      final matchesSearch = trip['title'].toString().toLowerCase().contains(_searchQuery.toLowerCase()) ||
          trip['location'].toString().toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesFilter = _selectedFilter == 'All' || trip['status'].toString().toLowerCase() == _selectedFilter.toLowerCase();
      return matchesSearch && matchesFilter;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          CustomAppBar(
            title: 'My Trips',
            profilePhotoUrl: _profilePhotoUrl,
            profileName: _profileName,
            onProfileTap: widget.onProfileTap,
            notificationIcon: Icons.group_add_outlined,
            onNotificationTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AllJoinRequestsScreen(),
                ),
              );
            },
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 20),
                          _buildSearchBar(),
                          const SizedBox(height: 16),
                          _buildFilterChips(),
                          const SizedBox(height: 24),
                          _buildAllTripsSection(),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }



  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
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
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: Color(0xFF0F172A),
        ),
        decoration: InputDecoration(
          hintText: 'Search trips by name...',
          hintStyle: const TextStyle(
            fontSize: 14,
            color: Color(0xFF94A3B8),
            fontWeight: FontWeight.w500,
          ),
          prefixIcon: const Icon(Icons.search, color: Color(0xFF64748B), size: 22),
          suffixIcon: _searchQuery.isNotEmpty
              ? GestureDetector(
                  onTap: () {
                    _searchController.clear();
                    setState(() {
                      _searchQuery = '';
                    });
                  },
                  child: const Icon(Icons.clear, color: Color(0xFF64748B), size: 20),
                )
              : null,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFFEEF2F6), width: 1.5),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFFEEF2F6), width: 1.5),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFF1E5AE6), width: 1.5),
          ),
          filled: true,
          fillColor: Colors.white,
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    final filters = ['All', 'Upcoming', 'Ongoing', 'Completed'];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: filters.map((filter) {
          final isSelected = _selectedFilter == filter;
          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedFilter = filter;
              });
            },
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF1E5AE6) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? const Color(0xFF1E5AE6) : const Color(0xFFE2E8F0),
                  width: 1,
                ),
              ),
              child: Text(
                filter,
                style: TextStyle(
                  color: isSelected ? Colors.white : const Color(0xFF475569),
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildAllTripsSection() {
    final filtered = _filteredTrips;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _selectedFilter == 'All' ? 'All Trips' : '$_selectedFilter Trips',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  Text(
                    'Found: ${filtered.length}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF475569),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        filtered.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40.0),
                  child: Column(
                    children: const [
                      Icon(Icons.search_off, size: 48, color: Color(0xFF94A3B8)),
                      SizedBox(height: 12),
                      Text(
                        'No trips found',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            : ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  final trip = filtered[index];
                  return GestureDetector(
                    onTap: () => _navigateToTripDashboard(trip),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.02),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: CachedNetworkImage(imageUrl: ImageUtils.getOptimizedImageUrl(trip['imageUrl']),
                              width: 80,
                              height: 80,
                              fit: BoxFit.cover,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  trip['title'],
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF0F172A),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 6),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 4,
                                  children: [
                                    if (trip['role'] != null)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFE8F0FE),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          trip['role'],
                                          style: const TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF1E5AE6),
                                          ),
                                        ),
                                      ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: trip['statusColor'],
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        trip['status'],
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                          color: trip['textColor'],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.location_on_outlined,
                                      size: 14,
                                      color: Color(0xFF64748B),
                                    ),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        trip['location'],
                                        style: const TextStyle(
                                          fontSize: 13,
                                          color: Color(0xFF64748B),
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 1,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.calendar_today_outlined,
                                      size: 13,
                                      color: Color(0xFF94A3B8),
                                    ),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        trip['dates'],
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFF64748B),
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 1,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Row(
                            children: [
                              if (trip['role'] == 'Trip Leader') ...[
                                IconButton(
                                  icon: const Icon(Icons.edit_outlined, size: 20, color: Color(0xFF64748B)),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  onPressed: () async {
                                    final result = await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => AddTripScreen(tripData: trip),
                                      ),
                                    );
                                    if (result == true) {
                                      _fetchTrips();
                                    }
                                  },
                                ),
                                const SizedBox(width: 8),
                              ],
                              PopupMenuButton<String>(
                                icon: const Icon(
                                  Icons.more_vert,
                                  color: Color(0xFF94A3B8),
                                  size: 20,
                                ),
                                padding: EdgeInsets.zero,
                                onSelected: (value) async {
                                  if (value == 'share') {
                                    final inviteToken = trip['inviteToken'] ?? '';
                                    final pcIp = AppConstants.pcIp;
                                    final inviteLink = 'http://$pcIp:5000/join/$inviteToken';
                                    showDialog(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                        content: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const SizedBox(height: 16),
                                            const Text(
                                              'Share Trip',
                                              style: TextStyle(
                                                fontSize: 20,
                                                fontWeight: FontWeight.bold,
                                                color: AppColors.textPrimary,
                                              ),
                                            ),
                                            const SizedBox(height: 16),
                                            Container(
                                              padding: const EdgeInsets.all(12),
                                              decoration: BoxDecoration(
                                                color: Colors.grey[100],
                                                borderRadius: BorderRadius.circular(8),
                                                border: Border.all(color: Colors.grey[300]!),
                                              ),
                                              child: Column(
                                                children: [
                                                  const Text(
                                                    'Invite Token',
                                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Row(
                                                    children: [
                                                      Expanded(
                                                        child: SelectableText(
                                                          inviteToken,
                                                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primary),
                                                          textAlign: TextAlign.center,
                                                        ),
                                                      ),
                                                      IconButton(
                                                        icon: const Icon(Icons.copy, size: 18, color: AppColors.primary),
                                                        onPressed: () {
                                                          Clipboard.setData(ClipboardData(text: inviteToken));
                                                          ScaffoldMessenger.of(context).showSnackBar(
                                                            const SnackBar(content: Text('Invite token copied!')),
                                                          );
                                                        },
                                                      ),
                                                    ],
                                                  ),
                                                  const Divider(height: 16),
                                                  const Text(
                                                    'Invite Link',
                                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Row(
                                                    children: [
                                                      Expanded(
                                                        child: SelectableText(
                                                          inviteLink,
                                                          style: const TextStyle(fontSize: 12, color: AppColors.primary),
                                                          textAlign: TextAlign.center,
                                                        ),
                                                      ),
                                                      IconButton(
                                                        icon: const Icon(Icons.copy, size: 18, color: AppColors.primary),
                                                        onPressed: () {
                                                          Clipboard.setData(ClipboardData(text: inviteLink));
                                                          ScaffoldMessenger.of(context).showSnackBar(
                                                            const SnackBar(content: Text('Invite link copied!')),
                                                          );
                                                        },
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(height: 16),
                                            ElevatedButton(
                                              onPressed: () => Navigator.pop(context),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: AppColors.primary,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
                                                minimumSize: const Size(double.infinity, 45),
                                              ),
                                              child: const Text('Close', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  } else if (value == 'delete') {
                                    showDialog(
                                      context: context,
                                      builder: (BuildContext dialogContext) {
                                        return AlertDialog(
                                          title: const Text('Delete Trip'),
                                          content: const Text('Are you sure you want to delete this trip? This action cannot be undone.'),
                                          actions: [
                                            TextButton(
                                              child: const Text('Cancel'),
                                              onPressed: () => Navigator.pop(dialogContext),
                                            ),
                                            TextButton(
                                              child: const Text('Delete', style: TextStyle(color: Colors.red)),
                                              onPressed: () async {
                                                Navigator.pop(dialogContext);
                                                setState(() => _isLoading = true);
                                                final res = await _tripService.deleteTrip(trip['id']);
                                                if (res['success'] == true) {
                                                  _fetchTrips();
                                                } else {
                                                  setState(() => _isLoading = false);
                                                  if (mounted) {
                                                    ScaffoldMessenger.of(context).showSnackBar(
                                                      SnackBar(content: Text(res['message'] ?? 'Failed to delete trip')),
                                                    );
                                                  }
                                                }
                                              },
                                            ),
                                          ],
                                        );
                                      }
                                    );
                                  }
                                },
                                itemBuilder: (BuildContext context) {
                                  return [
                                    const PopupMenuItem<String>(
                                      value: 'share',
                                      child: Row(
                                        children: [
                                          Icon(Icons.share_outlined, size: 20, color: Color(0xFF64748B)),
                                          SizedBox(width: 8),
                                          Text('Share Trip'),
                                        ],
                                      ),
                                    ),
                                    if (trip['role'] == 'Trip Leader')
                                      const PopupMenuItem<String>(
                                        value: 'delete',
                                        child: Row(
                                          children: [
                                            Icon(Icons.delete_outline, size: 20, color: Colors.red),
                                            SizedBox(width: 8),
                                            Text('Delete Trip', style: TextStyle(color: Colors.red)),
                                          ],
                                        ),
                                      ),
                                  ];
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ],
    );
  }

  void _navigateToTripDashboard(Map<String, dynamic> trip) {
    if (trip['id'] == null) return;
    
    final role = trip['originalRole']?.toString().toLowerCase() ?? 'member';
    
    if (role == 'admin' || role == 'creator' || role == 'tripleader') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => TripDetailsScreen(
            tripData: trip,
            profilePhotoUrl: _profilePhotoUrl,
            profileName: _profileName,
          ),
        ),
      );
    } else if (role == 'solotraveler' || role == 'solo_traveler') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => SoloTravelerDashboardScreen(
            tripData: trip,
            profilePhotoUrl: _profilePhotoUrl,
            profileName: _profileName,
          ),
        ),
      );
    } else if (role == 'familyleader' || role == 'family_leader') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => FamilyLeaderDashboardScreen(
            tripData: trip,
            profilePhotoUrl: _profilePhotoUrl,
            profileName: _profileName,
          ),
        ),
      );
    } else if (role == 'familymember' || role == 'family_member') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => FamilyMemberDashboardScreen(
            tripData: trip,
            profilePhotoUrl: _profilePhotoUrl,
            profileName: _profileName,
          ),
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => MemberDashboardScreen(
            tripData: trip,
            profilePhotoUrl: _profilePhotoUrl,
            profileName: _profileName,
          ),
        ),
      );
    }
  }
}

