import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../expenses/screens/expense_screen.dart';
import '../../calendar/screens/calendar_screen.dart';
import '../../profile/screens/profile_screen.dart';
import '../../trip/screens/trips_screen.dart';
import '../../trip/screens/trip_details_screen.dart';
import '../../trip/screens/solo_traveler_dashboard_screen.dart';
import '../../trip/screens/family_leader_dashboard_screen.dart';
import '../../trip/screens/family_member_dashboard_screen.dart';
import '../../trip/screens/member_dashboard_screen.dart';
import '../../../core/routes/app_routes.dart';
import '../../auth/services/auth_service.dart';
import '../../trip/services/trip_service.dart';
import '../../profile/services/user_service.dart';
import '../../../core/widgets/custom_app_bar.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:tripsync/core/utils/image_utils.dart';
import '../../../core/utils/date_formatter.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _currentIndex = 0;
  Key _tripsScreenKey = UniqueKey();
  int _carouselIndex = 0;
  final PageController _pageController = PageController();

  List<Map<String, dynamic>> _upcomingTrips = [];
  List<Map<String, dynamic>> _allTrips = [];
  int _upcomingCount = 0;
  int _ongoingCount = 0;
  int _completedCount = 0;
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
          _profileName = '${response['data']['firstName']} ${response['data']['lastName']}';
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
        final months = ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'];
        final fullMonths = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
        
        List<Map<String, dynamic>> all = [];
        List<Map<String, dynamic>> upcoming = [];
        int upcomingCount = 0;
        int ongoingCount = 0;
        int completedCount = 0;

        for (var trip in data) {
          final startDate = TripInfoHelper.parseTripDate(trip['startDate'].toString());
          final endDate = TripInfoHelper.parseTripDate(trip['endDate'].toString());
          
          String status = 'Ongoing';
          Color statusColor = const Color(0xFF1E5AE6); // Default for ongoing
          Color textColor = Colors.white;
          
          if (today.isBefore(startDate)) {
            status = 'Upcoming';
            statusColor = const Color(0xFF20C060);
            upcomingCount++;
          } else if (today.isAfter(endDate)) {
            status = 'Completed';
            statusColor = Colors.orange;
            completedCount++;
          } else {
            ongoingCount++;
          }

          String imageUrl = trip['coverImage'] ?? 'https://images.unsplash.com/photo-1502602898657-3e91760cbb34?w=400&auto=format&fit=crop&q=60';
          String location = 'Trip Location';
          
          all.add({
            'id': trip['_id'],
            '_id': trip['_id'],
            'startDate': trip['startDate'],
            'endDate': trip['endDate'],
            'title': trip['name'] ?? 'Untitled Trip',
            'name': trip['name'] ?? 'Untitled Trip',
            'description': trip['description'] ?? '',
            'location': location,
            'dates': '${fullMonths[startDate.month - 1]} ${startDate.day} - ${fullMonths[endDate.month - 1]} ${endDate.day}, ${endDate.year}',
            'status': status,
            'statusColor': statusColor.withOpacity(0.1),
            'textColor': statusColor,
            'imageUrl': imageUrl,
            'role': trip['participantRole'] ?? 'Member',
            'originalRole': trip['participantRole'] ?? 'Member',
            'membersCount': trip['membersCount'] ?? 1,
          });

          if (status == 'Upcoming' || status == 'Ongoing') {
            upcoming.add({
              'id': trip['_id'],
              '_id': trip['_id'],
              'startDate': trip['startDate'],
              'endDate': trip['endDate'],
              'title': trip['name'] ?? 'Untitled',
              'name': trip['name'] ?? 'Untitled',
              'description': trip['description'] ?? '',
              'location': location,
              'month': months[startDate.month - 1],
              'day': startDate.day.toString().padLeft(2, '0'),
              'status': status,
              'statusColor': statusColor,
              'imageUrl': imageUrl,
              'daysLeft': '',
              'role': trip['participantRole'] ?? 'Member',
              'originalRole': trip['participantRole'] ?? 'Member',
              'members': const [],
              'extraMembers': '',
              'membersCount': trip['membersCount'] ?? 1,
            });
          }
        }

        setState(() {
          _allTrips = all;
          _upcomingTrips = upcoming;
          _upcomingCount = upcomingCount;
          _ongoingCount = ongoingCount;
          _completedCount = completedCount;
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
  Widget build(BuildContext context) {
    Widget body;
    switch (_currentIndex) {
      case 0:
        body = _buildHomeBody();
        break;
      case 1:
        body = TripsScreen(
          key: _tripsScreenKey,
          onProfileTap: () {
            setState(() {
              _currentIndex = 4;
            });
          },
        );
        break;
      case 2:
        body = CalendarScreen(
          onProfileTap: () {
            setState(() {
              _currentIndex = 4;
            });
          },
        );
        break;
      case 3:
        body = const ExpenseScreen();
        break;
      case 4:
        body = const ProfileScreen();
        break;
      default:
        body = _buildHomeBody();
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: body,
      bottomNavigationBar: _buildBottomNavBar(),
    );
  }

  Widget _buildHomeBody() {
    return SafeArea(
      child: Column(
        children: [
          CustomAppBar(
            profilePhotoUrl: _profilePhotoUrl,
            profileName: _profileName,
            onProfileTap: () {
              setState(() {
                _currentIndex = 4;
              });
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
                          _buildQuickNav(),
                          const SizedBox(height: 24),
                          _buildJoinTripBanner(),
                          const SizedBox(height: 24),
                          if (_upcomingTrips.isNotEmpty) _buildUpcomingSection(),
                          if (_upcomingTrips.isNotEmpty) const SizedBox(height: 24),
                          if (_allTrips.isNotEmpty) _buildAllTripsSection(),
                          if (_allTrips.isNotEmpty) const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }






  Widget _buildQuickNav() {
    return Row(
      children: [
        Expanded(
          child: _TripStatCard(
            title: 'Upcoming',
            count: _upcomingCount.toString(),
            themeColor: const Color(0xFF20C060),
            backgroundColor: const Color(0xFFF2FBF6),
            borderColor: const Color(0xFFE2F7EB),
            icon: Icons.calendar_today_outlined,
            sparklinePoints: const [10, 12, 11, 15, 13, 19, 17, 22, 19, 21],
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _TripStatCard(
            title: 'Ongoing',
            count: _ongoingCount.toString(),
            themeColor: const Color(0xFF1E5AE6),
            backgroundColor: const Color(0xFFF3F7FE),
            borderColor: const Color(0xFFE5EFFF),
            icon: Icons.flight_takeoff_outlined,
            sparklinePoints: const [10, 11, 13, 12, 15, 14, 17, 16, 20, 19],
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _TripStatCard(
            title: 'Completed',
            count: _completedCount.toString(),
            themeColor: const Color(0xFF8B5CF6),
            backgroundColor: const Color(0xFFF8F5FF),
            borderColor: const Color(0xFFF0EBFF),
            icon: Icons.check_circle_outline,
            sparklinePoints: const [10, 12, 11, 14, 13, 17, 15, 19, 18, 20],
          ),
        ),
      ],
    );
  }

  Widget _buildJoinTripBanner() {
    return GestureDetector(
      onTap: () async {
        await Navigator.pushNamed(context, AppRoutes.joinTrip);
        _fetchTrips();
        setState(() {
          _tripsScreenKey = UniqueKey();
        });
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: const Color(0xFFEFF6FF),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFDBEAFE)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.group_add_rounded,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'Have an Invite Token?',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Tap here to join a trip',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios,
              color: AppColors.primary,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUpcomingSection() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Upcoming Trip',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            GestureDetector(
              onTap: () {},
              child: Row(
                children: const [
                  Text(
                    'View All',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E5AE6),
                    ),
                  ),
                  SizedBox(width: 4),
                  Icon(
                    Icons.chevron_right,
                    size: 16,
                    color: Color(0xFF1E5AE6),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 240,
          child: PageView.builder(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() {
                _carouselIndex = index;
              });
            },
            itemCount: _upcomingTrips.length,
            itemBuilder: (context, index) {
              final trip = _upcomingTrips[index];
              return GestureDetector(
                onTap: () => _navigateToTripDashboard(trip),
                child: Container(
                  margin: const EdgeInsets.only(right: 12),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Stack(
                    children: [
                      // Image
                      CachedNetworkImage(imageUrl: ImageUtils.getOptimizedImageUrl(trip['imageUrl']),
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
                        placeholder: (context, url) => Container(
                          color: Colors.grey[200],
                          child: const Center(
                              child: CircularProgressIndicator(),
                          ),
                        ),
                      ),
                      // Gradient Overlay
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withOpacity(0.1),
                              Colors.black.withOpacity(0.75),
                            ],
                          ),
                        ),
                      ),
                      // Date Badge
                      Positioned(
                        top: 16,
                        left: 16,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            children: [
                              Text(
                                trip['month'],
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                trip['day'],
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      // Status Badge
                      Positioned(
                        top: 16,
                        right: 16,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: trip['statusColor'],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            trip['status'],
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      // Bottom Details
                      Positioned(
                        bottom: 16,
                        left: 16,
                        right: 16,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              trip['title'],
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(
                                  Icons.location_on,
                                  color: Colors.white70,
                                  size: 16,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  trip['location'],
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Colors.white70,
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
              ));
            },
          ),
        ),
        const SizedBox(height: 12),
        // Dots Indicator
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            _upcomingTrips.length,
            (index) => Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: _carouselIndex == index ? 16 : 8,
              height: 8,
              decoration: BoxDecoration(
                color: _carouselIndex == index ? const Color(0xFF1E5AE6) : const Color(0xFFD1D5DB),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAvatarStack(List<dynamic> imageUrls, String extra) {
    List<Widget> children = [];
    
    for (int i = 0; i < imageUrls.length; i++) {
      children.add(
        Positioned(
          left: i * 18.0,
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 1.5),
            ),
            child: CircleAvatar(
              radius: 12,
              backgroundImage: CachedNetworkImageProvider(ImageUtils.getOptimizedImageUrl(imageUrls[i])),
            ),
          ),
        ),
      );
    }
    
    if (extra.isNotEmpty) {
      children.add(
        Positioned(
          left: imageUrls.length * 18.0,
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 1.5),
            ),
            child: CircleAvatar(
              radius: 12,
              backgroundColor: const Color(0xFF475569),
              child: Text(
                extra,
                style: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      );
    }
    
    return SizedBox(
      width: (imageUrls.length + (extra.isNotEmpty ? 1 : 0)) * 18.0 + 6.0,
      height: 26,
      child: Stack(
        alignment: Alignment.centerLeft,
        clipBehavior: Clip.none,
        children: children,
      ),
    );
  }

  
  Widget _buildAllTripsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'All Trips',
              style: TextStyle(
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
                children: const [
                  Text(
                    'Sort by: Upcoming',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF475569),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(width: 4),
                  Icon(
                    Icons.keyboard_arrow_down,
                    size: 16,
                    color: Color(0xFF475569),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _allTrips.length,
          itemBuilder: (context, index) {
            final trip = _allTrips[index];
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
                        ),
                        const SizedBox(height: 6),
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
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: trip['statusColor'],
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          trip['status'],
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: trip['textColor'],
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(
                        Icons.chevron_right,
                        color: Color(0xFF94A3B8),
                        size: 18,
                      ),
                    ],
                  ),
                ],
              ),
            ));
          },
        ),
      ],
    );
  }

  void _navigateToTripDashboard(Map<String, dynamic> trip) {
    if (trip['id'] == null) return;
    
    final role = trip['role']?.toString().toLowerCase() ?? 'member';
    
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


  Widget _buildBottomNavBar() {
    return Container(
      height: 76,
      margin: const EdgeInsets.only(left: 16, right: 16, bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildNavBarItem(0, Icons.home_outlined, Icons.home, 'Home'),
            _buildNavBarItem(1, Icons.business_center_outlined, Icons.business_center, 'Trips'),
            _buildNavBarMiddleItem(),
            _buildNavBarItem(3, Icons.account_balance_wallet_outlined, Icons.account_balance_wallet, 'Expense'),
            _buildNavBarItem(2, Icons.calendar_month_outlined, Icons.calendar_month, 'Calendar'),
          ],
        ),
      ),
    );
  }

  Widget _buildNavBarItem(int index, IconData outlineIcon, IconData filledIcon, String label) {
    final isSelected = _currentIndex == index;
    final color = isSelected ? const Color(0xFF1E5AE6) : AppColors.textLight;
    final icon = isSelected ? filledIcon : outlineIcon;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _currentIndex = index;
          });
        },
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: color,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavBarMiddleItem() {
    return GestureDetector(
      onTap: () async {
        await Navigator.pushNamed(context, AppRoutes.addTrip);
        _fetchTrips();
        setState(() {
          _tripsScreenKey = UniqueKey();
        });
      },
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF00C6FF),
              Color(0xFF0072FF),
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0072FF).withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Icon(
          Icons.add,
          color: Colors.white,
          size: 28,
        ),
      ),
    );
  }

  void _showAddOptionsSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Create New',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildQuickActionItem(
                    icon: Icons.flight_takeoff,
                    label: 'Add Trip',
                    color: const Color(0xFF1E5AE6),
                    onTap: () {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Add Trip functionality coming soon!')),
                      );
                    },
                  ),
                  _buildQuickActionItem(
                    icon: Icons.account_balance_wallet,
                    label: 'Add Expense',
                    color: const Color(0xFF20C060),
                    onTap: () {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Add Expense functionality coming soon!')),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  Widget _buildQuickActionItem({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: color,
              size: 28,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF0F172A),
            ),
          ),
        ],
      ),
    );
  }
}

class _TripStatCard extends StatelessWidget {
  final String title;
  final String count;
  final Color themeColor;
  final Color backgroundColor;
  final Color borderColor;
  final IconData icon;
  final List<double> sparklinePoints;

  const _TripStatCard({
    required this.title,
    required this.count,
    required this.themeColor,
    required this.backgroundColor,
    required this.borderColor,
    required this.icon,
    required this.sparklinePoints,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: themeColor.withOpacity(0.02), 
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Icon badge and Title
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: themeColor.withOpacity(0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: themeColor,
                  size: 16,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: themeColor,
                    height: 1.1,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                count,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                  height: 1,
                ),
              ),
              const SizedBox(width: 4),
              const Text(
                'Trips',
                style: TextStyle(
                  fontSize: 10,
                  color: Color(0xFF64748B),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Sparkline
          SizedBox(
            height: 25,
            width: double.infinity,
            child: CustomPaint(
              painter: _DashboardSparklinePainter(
                points: sparklinePoints,
                color: themeColor,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Container(
            height: 1,
            color: borderColor.withOpacity(0.4),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text(
                  'Tap to View',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                height: 20,
                width: 20,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x0A000000),
                      blurRadius: 2,
                      offset: Offset(0, 1),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.chevron_right,
                  size: 12,
                  color: Color(0xFF0F172A),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DashboardSparklinePainter extends CustomPainter {
  final List<double> points;
  final Color color;

  _DashboardSparklinePainter({required this.points, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    final fillPaint = Paint()
      ..style = PaintingStyle.fill;

    final path = Path();
    final double stepX = size.width / (points.length - 1);

    double minVal = points.reduce((a, b) => a < b ? a : b);
    double maxVal = points.reduce((a, b) => a > b ? a : b);
    double valRange = maxVal - minVal;
    if (valRange == 0) valRange = 1;

    double getY(double val) {
      double pct = (val - minVal) / valRange;
      return size.height - (pct * (size.height - 8) + 4);
    }

    path.moveTo(0, getY(points[0]));
    for (int i = 1; i < points.length; i++) {
      double x1 = (i - 1) * stepX;
      double y1 = getY(points[i - 1]);
      double x2 = i * stepX;
      double y2 = getY(points[i]);

      double cx = x1 + stepX / 2;
      path.cubicTo(cx, y1, cx, y2, x2, y2);
    }

    final fillPath = Path.from(path);
    fillPath.lineTo(size.width, size.height);
    fillPath.lineTo(0, size.height);
    fillPath.close();

    fillPaint.shader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        color.withOpacity(0.12),
        color.withOpacity(0.0),
      ],
    ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _DashboardSparklinePainter oldDelegate) {
    return oldDelegate.points != points || oldDelegate.color != color;
  }
}

