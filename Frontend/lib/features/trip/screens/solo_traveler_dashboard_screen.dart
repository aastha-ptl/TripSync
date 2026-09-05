import 'package:flutter/material.dart';
import '../../../core/routes/app_routes.dart';
import '../../documents/screens/documents_screen.dart';
import '../../participants/screens/participants_screen.dart';
import '../../expenses/screens/trip_expense_screen.dart';
import '../../profile/screens/profile_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:tripsync/core/utils/image_utils.dart';
import 'package:intl/intl.dart';
import '../../itinerary/services/itinerary_service.dart';
import '../../../core/utils/date_formatter.dart';

class SoloTravelerDashboardScreen extends StatefulWidget {
  final Map<String, dynamic>? tripData;
  final String? profilePhotoUrl;
  final String? profileName;

  const SoloTravelerDashboardScreen({
    super.key,
    this.tripData,
    this.profilePhotoUrl,
    this.profileName,
  });

  @override
  State<SoloTravelerDashboardScreen> createState() => _SoloTravelerDashboardScreenState();
}

class _SoloTravelerDashboardScreenState extends State<SoloTravelerDashboardScreen> {
  int _selectedNavIndex = 0;
  bool _isLoading = true;
  List<Map<String, dynamic>> _upcomingActivities = [];

  @override
  void initState() {
    super.initState();
    _fetchUpcomingActivities();
  }

  Future<void> _fetchUpcomingActivities() async {
    final tripId = widget.tripData?['_id'];
    if (tripId == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      final itineraryService = ItineraryService();
      final response = await itineraryService.getItinerary(tripId);
      
      if (response['success'] == true && mounted) {
        final List<dynamic> daysData = response['data'] ?? [];
        List<Map<String, dynamic>> allActivities = [];
        
        final now = DateTime.now();
        
        for (var dayData in daysData) {
          final List<dynamic> activitiesData = dayData['activities'] ?? [];
          for (var act in activitiesData) {
            if (act['startTime'] != null) {
               final startTime = DateTime.parse(act['startTime']).toLocal();
               if (startTime.isAfter(now) || 
                   (startTime.year == now.year && startTime.month == now.month && startTime.day == now.day)) {
                  allActivities.add({
                    ...act,
                    'parsedStartTime': startTime,
                  });
               }
            }
          }
        }
        
        allActivities.sort((a, b) => (a['parsedStartTime'] as DateTime).compareTo(b['parsedStartTime'] as DateTime));
        
        setState(() {
          _upcomingActivities = allActivities.take(3).toList();
          _isLoading = false;
        });
      } else {
         if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_selectedNavIndex == 1) {
      return Scaffold(
        body: TripExpenseScreen(
          tripData: widget.tripData,
          profilePhotoUrl: widget.profilePhotoUrl,
          profileName: widget.profileName,
          onBack: () {
            setState(() {
              _selectedNavIndex = 0;
            });
          },
        ),
        bottomNavigationBar: _buildBottomNavigationBar(),
      );
    }

    if (_selectedNavIndex == 2) {
      return Scaffold(
        body: DocumentsScreen(
          tripData: widget.tripData,
          profilePhotoUrl: widget.profilePhotoUrl,
          profileName: widget.profileName,
          isSoloTraveler: true,
          onBack: () {
            setState(() {
              _selectedNavIndex = 0;
            });
          },
        ),
        bottomNavigationBar: _buildBottomNavigationBar(),
        floatingActionButton: Padding(
          padding: const EdgeInsets.only(bottom: 16.0),
          child: _buildFloatingChatButton(),
        ),
      );
    }

    if (_selectedNavIndex == 3) {
      return Scaffold(
        body: ParticipantsScreen(
          tripData: widget.tripData,
          profilePhotoUrl: widget.profilePhotoUrl,
          profileName: widget.profileName,
          isSoloTraveler: true,
          onBack: () {
            setState(() {
              _selectedNavIndex = 0;
            });
          },
        ),
        bottomNavigationBar: _buildBottomNavigationBar(),
        floatingActionButton: Padding(
          padding: const EdgeInsets.only(bottom: 16.0),
          child: _buildFloatingChatButton(),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                _buildTopHeader(),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 20),
                          _buildQuickActionGrid(),
                          const SizedBox(height: 24),
                          _buildUpcomingScheduleSection(),
                          const SizedBox(height: 24),
                          _buildTripOverviewSection(),
                          const SizedBox(height: 100), // Extra space for FAB & bottom nav
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            // Floating Chat Button
            Positioned(
              right: 16,
              bottom: 16,
              child: _buildFloatingChatButton(),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  Widget _buildTopHeader() {
    return Container(
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
        // Left side containing Trip Image, Name and Info (Tap to go back)
        Expanded(
          child: GestureDetector(
            onTap: () => Navigator.pop(context),
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
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            widget.tripData?['title'] ?? 'Paris Getaway',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          // Solo Traveler Badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE8F0FE),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                Icon(
                                  Icons.emoji_events,
                                  size: 10,
                                  color: Color(0xFF1E5AE6),
                                ),
                                SizedBox(width: 3),
                                Text(
                                  'Solo Traveler',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1E5AE6),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.calendar_today_outlined,
                                size: 12,
                                color: Color(0xFF64748B),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _getTripDateRange(),
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF64748B),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          const Text(
                            '•',
                            style: TextStyle(
                              fontSize: 11,
                              color: Color(0xFF94A3B8),
                            ),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.people_outline,
                                size: 13,
                                color: Color(0xFF64748B),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${widget.tripData?['membersCount'] ?? 1} Members',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF64748B),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
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
        // Right side profile picture
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
  );
}

String _getInitials(String? name) {
  if (name == null || name.trim().isEmpty) return '';
  final parts = name.trim().split(RegExp(r'\s+'));
  if (parts.length > 1) {
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }
  return parts[0][0].toUpperCase();
}

String _getTripDateRange() {
  if (widget.tripData == null) return 'Unknown dates';
  
  try {
    final start = TripInfoHelper.parseTripDate(widget.tripData!['startDate'].toString());
    final end = TripInfoHelper.parseTripDate(widget.tripData!['endDate'].toString());
    final startStr = DateFormat('MMM d').format(start);
    final endStr = DateFormat('MMM d, yyyy').format(end);
    return '$startStr – $endStr';
  } catch (e) {
    return 'Unknown dates';
  }
}

String _getTripDuration() {
  if (widget.tripData == null) return '0 Days';
  
  try {
    final start = TripInfoHelper.parseTripDate(widget.tripData!['startDate'].toString());
    final end = TripInfoHelper.parseTripDate(widget.tripData!['endDate'].toString());
    final duration = end.difference(start).inDays + 1;
    return '$duration Days';
  } catch (e) {
    return '0 Days';
  }
}



  Widget _buildQuickActionGrid() {
    return Row(
      children: [
        Expanded(
          child: _buildQuickActionCard(
            color: const Color(0xFFE8F0FE),
            iconColor: const Color(0xFF1E5AE6),
            icon: Icons.calendar_month_outlined,
            title: 'Itinerary',
            subtitle: 'View your trip plan',
            textColor: const Color(0xFF1E5AE6),
            onTap: () {
              Navigator.pushNamed(context, AppRoutes.itinerary, arguments: {'tripData': widget.tripData, 'isSoloTraveler': true});
            },
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildQuickActionCard(
            color: const Color(0xFFF3E8FF),
            iconColor: const Color(0xFF9333EA),
            icon: Icons.chat_bubble_outline,
            title: 'Tasks',
            subtitle: 'Manage tasks',
            textColor: const Color(0xFF9333EA),
            onTap: () {
              Navigator.pushNamed(context, AppRoutes.tasks, arguments: {'tripData': widget.tripData});
            },
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildQuickActionCard(
            color: const Color(0xFFFFF2E6),
            iconColor: const Color(0xFFEA580C),
            icon: Icons.pie_chart_outline,
            title: 'Trip Overview',
            subtitle: 'Trip summary',
            textColor: const Color(0xFFEA580C),
            onTap: () {
              Navigator.pushNamed(context, AppRoutes.tripOverview, arguments: {'tripData': widget.tripData});
            },
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActionCard({
    required Color color,
    required Color iconColor,
    required IconData icon,
    required String title,
    required String subtitle,
    required Color textColor,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 120,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Icon Box
            Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: iconColor,
                size: 16,
              ),
            ),
            // Texts
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 9,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
            // View all arrow button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    'View all',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.chevron_right,
                    size: 10,
                    color: textColor,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUpcomingScheduleSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Upcoming Schedule',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
            ),
            GestureDetector(
              onTap: () {},
              child: Row(
                children: const [
                  Text(
                    'View All',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E5AE6),
                    ),
                  ),
                  SizedBox(width: 4),
                  Icon(
                    Icons.arrow_forward,
                    size: 14,
                    color: Color(0xFF1E5AE6),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (_isLoading)
          const Center(child: CircularProgressIndicator())
        else if (_upcomingActivities.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'No upcoming activities scheduled.',
              style: TextStyle(
                color: Color(0xFF64748B),
                fontSize: 14,
              ),
            ),
          )
        else
          ..._upcomingActivities.asMap().entries.map((entry) {
            final index = entry.key;
            final act = entry.value;
            final isLast = index == _upcomingActivities.length - 1;
            
            final startTime = act['parsedStartTime'] as DateTime;
            final month = DateFormat('MMM').format(startTime).toUpperCase();
            final day = DateFormat('dd').format(startTime);
            final time = DateFormat('h:mm a').format(startTime);
            
            Color dotColor = const Color(0xFF1E5AE6);
            if (act['type'] == 'transport') dotColor = const Color(0xFFEA580C);
            else if (act['type'] == 'food') dotColor = const Color(0xFFF59E0B);
            else if (act['type'] == 'lodging') dotColor = const Color(0xFF9333EA);

            return _buildTimelineItem(
              dotColor: dotColor,
              month: month,
              day: day,
              title: act['title'] ?? 'Activity',
              location: act['location']?['name'] ?? '',
              time: time,
              timeColor: dotColor,
              isLast: isLast,
            );
          }),
      ],
    );
  }

  Widget _buildTimelineItem({
    required Color dotColor,
    required String month,
    required String day,
    required String title,
    required String location,
    required String time,
    required Color timeColor,
    required bool isLast,
  }) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Timeline indicator
          Column(
            children: [
              const SizedBox(height: 12),
              Container(
                height: 8,
                width: 8,
                decoration: BoxDecoration(
                  color: dotColor,
                  shape: BoxShape.circle,
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 1.5,
                    color: const Color(0xFFE2E8F0),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          // Month/Day Box
          Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            width: 50,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  month,
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E5AE6),
                  ),
                ),
                Text(
                  day,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Info Column
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  location,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          // Time
          Center(
            child: Text(
              time,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: timeColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTripOverviewSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Trip Overview',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
            ),
            GestureDetector(
              onTap: () {},
              child: Row(
                children: const [
                  Text(
                    'View All',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E5AE6),
                    ),
                  ),
                  SizedBox(width: 4),
                  Icon(
                    Icons.arrow_forward,
                    size: 14,
                    color: Color(0xFF1E5AE6),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedNavIndex = 3;
                  });
                },
                child: _buildOverviewCard(
                  icon: Icons.people_alt_outlined,
                  iconColor: const Color(0xFF20C060),
                  value: '${widget.tripData?['membersCount'] ?? 1}',
                  label: 'Members',
                  actionLabel: 'View all',
                  actionColor: const Color(0xFF20C060),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: GestureDetector(
                onTap: () {
                  Navigator.pushNamed(context, AppRoutes.itinerary, arguments: {'tripData': widget.tripData, 'isSoloTraveler': true});
                },
                child: _buildOverviewCard(
                  icon: Icons.calendar_today_outlined,
                  iconColor: const Color(0xFF1E5AE6),
                  value: _getTripDuration(),
                  label: 'Duration',
                  actionLabel: 'View details',
                  actionColor: const Color(0xFF1E5AE6),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: GestureDetector(
                onTap: () {
                  Navigator.pushNamed(context, AppRoutes.destinations, arguments: {'tripData': widget.tripData});
                },
                child: _buildOverviewCard(
                  icon: Icons.location_on_outlined,
                  iconColor: const Color(0xFF9333EA),
                  value: '${widget.tripData?['destinations']?.length ?? 1}',
                  label: 'Destinations',
                  actionLabel: 'View all',
                  actionColor: const Color(0xFF9333EA),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildOverviewCard({
    required IconData icon,
    required Color iconColor,
    required String value,
    required String label,
    required String actionLabel,
    required Color actionColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.01),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon
          Icon(
            icon,
            color: iconColor,
            size: 20,
          ),
          const SizedBox(height: 10),
          // Value
          Text(
            value,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 2),
          // Label
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 10),
          // Action link
          Text(
            actionLabel,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: actionColor,
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildFloatingChatButton() {
    return GestureDetector(
      onTap: () {
        Navigator.pushNamed(context, AppRoutes.chat);
      },
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
          height: 52,
          width: 52,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF00C6FF), Color(0xFF0072FF)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0072FF).withOpacity(0.3),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Icon(
            Icons.chat,
            color: Colors.white,
            size: 22,
          ),
        ),
        // Badge
        Positioned(
          top: -2,
          right: -2,
          child: Container(
            padding: const EdgeInsets.all(5),
            decoration: const BoxDecoration(
              color: Colors.red,
              shape: BoxShape.circle,
            ),
            child: const Text(
              '3',
              style: TextStyle(
                color: Colors.white,
                fontSize: 9,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    ),);
  }

  Widget _buildBottomNavigationBar() {
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
          _buildNavItem(0, Icons.calendar_month, 'Activities'),
          _buildNavItem(1, Icons.account_balance_wallet_outlined, 'Expenses'),
          // Middle Floating Map button
          GestureDetector(
            onTap: () {
              Navigator.pushNamed(context, AppRoutes.map);
            },
            child: Container(
              height: 48,
              width: 48,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF00C6FF), Color(0xFF0072FF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0072FF).withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: const Icon(
                Icons.location_on,
                color: Colors.white,
                size: 24,
              ),
            ),
          ),
          _buildNavItem(2, Icons.folder_open_outlined, 'Documents'),
          _buildNavItem(3, Icons.people_outline, 'Users'),
        ],
      ),
    ),
  );
}

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isSelected = _selectedNavIndex == index;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedNavIndex = index;
        });
      },
      child: Container(
        color: Colors.transparent,
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? const Color(0xFF1E5AE6) : const Color(0xFF94A3B8),
              size: 20,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? const Color(0xFF1E5AE6) : const Color(0xFF94A3B8),
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
