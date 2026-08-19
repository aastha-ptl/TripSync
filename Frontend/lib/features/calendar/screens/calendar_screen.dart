import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_colors.dart';
import '../../trip/services/trip_service.dart';
import '../../profile/services/user_service.dart';
import '../../../core/widgets/custom_app_bar.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:tripsync/core/utils/image_utils.dart';
class CalendarScreen extends StatefulWidget {
  final VoidCallback onProfileTap;

  const CalendarScreen({super.key, required this.onProfileTap});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _focusedMonth = DateTime.now();
  final List<Map<String, dynamic>> _calendarDays = [];
  
  List<Map<String, dynamic>> _userTrips = [];
  bool _isLoading = true;
  final TripService _tripService = TripService();
  final UserService _userService = UserService();
  String? _profilePhotoUrl;

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
        
        setState(() {
          _userTrips = data.map((trip) {
            final rawStartDate = DateTime.parse(trip['startDate']);
            final rawEndDate = DateTime.parse(trip['endDate']);
            final startDate = DateTime(rawStartDate.year, rawStartDate.month, rawStartDate.day);
            final endDate = DateTime(rawEndDate.year, rawEndDate.month, rawEndDate.day);
            
            final now = DateTime.now();
            final today = DateTime(now.year, now.month, now.day);
            
            String status = 'ongoing';
            if (today.isBefore(startDate)) {
              status = 'upcoming';
            } else if (today.isAfter(endDate)) {
              status = 'completed';
            }

            return {
              'name': trip['name'] ?? 'Untitled Trip',
              'location': 'Trip Location', // Not in schema, placeholder
              'startDate': startDate,
              'endDate': endDate,
              'status': status,
              'coverImage': trip['coverImage'] ?? 'https://images.unsplash.com/photo-1502602898657-3e91760cbb34?w=400&auto=format&fit=crop&q=60',
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

  String _getDayStatus(DateTime date) {
    final compareDate = DateTime(date.year, date.month, date.day);
    
    // Check if the date falls in any trip
    for (var trip in _userTrips) {
      final startDate = trip['startDate'] as DateTime;
      final endDate = trip['endDate'] as DateTime;
      
      final tripStart = DateTime(startDate.year, startDate.month, startDate.day);
      final tripEnd = DateTime(endDate.year, endDate.month, endDate.day);

      if (!compareDate.isBefore(tripStart) && !compareDate.isAfter(tripEnd)) {
        return trip['status'];
      }
    }
    
    return 'none';
  }

  void _generateCalendarDays() {
    _calendarDays.clear();
    final year = _focusedMonth.year;
    final month = _focusedMonth.month;

    // First day of the current focused month
    final firstDayOfMonth = DateTime(year, month, 1);
    
    // Day of the week for the first day (1 = Monday, 7 = Sunday)
    // We want Monday (1) to map to 0 padding days, Tuesday (2) to 1 padding day, etc.
    final paddingDaysCount = firstDayOfMonth.weekday - 1;

    // Days in previous month
    final daysInPrevMonth = DateTime(year, month, 0).day;
    final prevMonthYear = month == 1 ? year - 1 : year;
    final prevMonthVal = month == 1 ? 12 : month - 1;

    // Add padding days from the previous month
    for (int i = paddingDaysCount - 1; i >= 0; i--) {
      final dayVal = daysInPrevMonth - i;
      final dayDate = DateTime(prevMonthYear, prevMonthVal, dayVal);
      _calendarDays.add({
        'day': dayVal,
        'isCurrent': false,
        'status': _getDayStatus(dayDate),
      });
    }

    // Days in current month
    final daysInCurrentMonth = DateTime(year, month + 1, 0).day;
    for (int i = 1; i <= daysInCurrentMonth; i++) {
      final dayDate = DateTime(year, month, i);
      _calendarDays.add({
        'day': i,
        'isCurrent': true,
        'status': _getDayStatus(dayDate),
      });
    }

    // Pad with next month's days to make grid neat (multiples of 7)
    final totalAddedSoFar = _calendarDays.length;
    final totalSlotsNeeded = (totalAddedSoFar / 7).ceil() * 7;
    final nextMonthPadding = totalSlotsNeeded - totalAddedSoFar;
    final nextMonthYear = month == 12 ? year + 1 : year;
    final nextMonthVal = month == 12 ? 1 : month + 1;

    for (int i = 1; i <= nextMonthPadding; i++) {
      final dayDate = DateTime(nextMonthYear, nextMonthVal, i);
      _calendarDays.add({
        'day': i,
        'isCurrent': false,
        'status': _getDayStatus(dayDate),
      });
    }
  }

  void _changeMonth(int offset) {
    setState(() {
      _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + offset, 1);
    });
  }

  void _resetToToday() {
    setState(() {
      _focusedMonth = DateTime.now();
    });
  }

  @override
  Widget build(BuildContext context) {
    _generateCalendarDays();
    return SafeArea(
      child: Column(
        children: [
          CustomAppBar(
            title: 'Calendar',
            profilePhotoUrl: _profilePhotoUrl,
            onProfileTap: widget.onProfileTap,
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
                          _buildCalendarControls(),
                          const SizedBox(height: 20),
                          _buildCalendarGrid(),
                          const SizedBox(height: 20),
                          _buildCalendarLegend(),
                          const SizedBox(height: 24),
                          _buildOngoingTripCard(),
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



  String _getCurrentMonthYear() {
    final months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return '${months[_focusedMonth.month - 1]} ${_focusedMonth.year}';
  }

  Widget _buildCalendarControls() {
    return Row(
      children: [
        GestureDetector(
          onTap: () => _changeMonth(-1),
          child: Container(
            height: 40,
            width: 40,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: const Icon(Icons.chevron_left, color: Color(0xFF0F172A)),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.calendar_today_outlined, size: 16, color: Color(0xFF0F172A)),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    _getCurrentMonthYear(),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.keyboard_arrow_down, size: 16, color: Color(0xFF475569)),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: () => _changeMonth(1),
          child: Container(
            height: 40,
            width: 40,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: const Icon(Icons.chevron_right, color: Color(0xFF0F172A)),
          ),
        ),
        const SizedBox(width: 12),
        GestureDetector(
          onTap: _resetToToday,
          child: Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: const [
                Icon(Icons.gps_fixed, size: 16, color: Color(0xFF0D9488)),
                SizedBox(width: 6),
                Text(
                  'Today',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0D9488),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCalendarGrid() {
    final List<String> weekDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: weekDays.map((day) => Expanded(
              child: Center(
                child: Text(
                  day,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF64748B),
                  ),
                ),
              ),
            )).toList(),
          ),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 12,
              crossAxisSpacing: 10,
              childAspectRatio: 1.0,
            ),
            itemCount: _calendarDays.length,
            itemBuilder: (context, index) {
              final dayData = _calendarDays[index];
              final int dayVal = dayData['day'];
              final bool isCurrent = dayData['isCurrent'];
              String status = dayData['status'];

              final now = DateTime.now();
              final isToday = isCurrent &&
                  dayVal == now.day &&
                  _focusedMonth.month == now.month &&
                  _focusedMonth.year == now.year;

              if (isToday) {
                status = 'today';
              }

              Color? textColor = isCurrent ? const Color(0xFF0F172A) : const Color(0xFF94A3B8);
              Color? bgCircleColor;
              Color? dotColor;

              if (status == 'upcoming') {
                bgCircleColor = const Color(0xFFDCFCE7);
                textColor = const Color(0xFF15803D);
                dotColor = const Color(0xFF15803D);
              } else if (status == 'ongoing') {
                bgCircleColor = const Color(0xFF1E5AE6);
                textColor = Colors.white;
                dotColor = const Color(0xFF1E5AE6);
              } else if (status == 'completed') {
                bgCircleColor = const Color(0xFFE2E8F0);
                textColor = const Color(0xFF475569);
                dotColor = const Color(0xFF64748B);
              } else if (status == 'today') {
                bgCircleColor = const Color(0xFF0D9488);
                textColor = Colors.white;
                dotColor = const Color(0xFF0D9488);
              }

              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Expanded(
                    child: Container(
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: bgCircleColor,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        dayVal.toString(),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: (status != 'none' || !isCurrent) ? FontWeight.bold : FontWeight.w500,
                          color: textColor,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    height: 4,
                    width: 4,
                    decoration: BoxDecoration(
                      color: dotColor ?? Colors.transparent,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarLegend() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _buildLegendItem('Ongoing', const Color(0xFF1E5AE6)),
        _buildLegendItem('Upcoming', const Color(0xFF15803D)),
        _buildLegendItem('Completed', const Color(0xFF64748B)),
        _buildLegendItem('Today', const Color(0xFF0D9488)),
      ],
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          height: 8,
          width: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Color(0xFF475569),
          ),
        ),
      ],
    );
  }

  String _formatTripDates(DateTime start, DateTime end) {
    final months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return '${months[start.month - 1]} ${start.day} – ${months[end.month - 1]} ${end.day}, ${start.year}';
  }

  int _calculateCurrentDayOfTrip(DateTime start, DateTime end) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tripStart = DateTime(start.year, start.month, start.day);
    if (today.isBefore(tripStart)) return 0;
    return today.difference(tripStart).inDays + 1;
  }

  Widget _buildOngoingTripCard() {
    // Find an ongoing trip
    Map<String, dynamic>? displayTrip;
    
    for (var trip in _userTrips) {
      if (trip['status'] == 'ongoing') {
        displayTrip = trip;
        break;
      }
    }
    
    // If no ongoing trip, find an upcoming trip
    if (displayTrip == null) {
      for (var trip in _userTrips) {
        if (trip['status'] == 'upcoming') {
          displayTrip = trip;
          break;
        }
      }
    }

    if (displayTrip == null) {
      return const SizedBox.shrink(); // Hide the card if there are no ongoing or upcoming trips
    }

    final startDate = displayTrip['startDate'] as DateTime;
    final endDate = displayTrip['endDate'] as DateTime;
    final totalDays = endDate.difference(startDate).inDays + 1;
    final currentDay = _calculateCurrentDayOfTrip(startDate, endDate);
    final progress = totalDays > 0 ? (currentDay / totalDays).clamp(0.0, 1.0) : 0.0;

    final isOngoing = displayTrip['status'] == 'ongoing';
    final cardTitle = isOngoing ? 'Ongoing Trip' : 'Upcoming Trip';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: Color(0xFF1E5AE6),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.flight_takeoff,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      cardTitle,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ],
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
          ),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: CachedNetworkImage(imageUrl: ImageUtils.getOptimizedImageUrl(displayTrip['coverImage']),
                    width: 90,
                    height: 90,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              displayTrip['name'],
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0F172A),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const Icon(
                            Icons.more_vert,
                            color: Color(0xFF94A3B8),
                            size: 20,
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: const [
                          Icon(
                            Icons.location_on_outlined,
                            size: 14,
                            color: Color(0xFF64748B),
                          ),
                          SizedBox(width: 4),
                          Text(
                            'Trip Location', // Update this if location is added to backend
                            style: TextStyle(
                              fontSize: 13,
                              color: Color(0xFF64748B),
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
                          Text(
                            _formatTripDates(startDate, endDate),
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                      if (isOngoing) ...[
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEFF6FF),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'Day $currentDay of $totalDays',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1E5AE6),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              '${(progress * 100).toInt()}% Completed',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF475569),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: progress,
                            backgroundColor: const Color(0xFFF1F5F9),
                            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF1E5AE6)),
                            minHeight: 6,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
