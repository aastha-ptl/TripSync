import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class CalendarScreen extends StatefulWidget {
  final VoidCallback onProfileTap;

  const CalendarScreen({super.key, required this.onProfileTap});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _focusedMonth = DateTime.now();
  final List<Map<String, dynamic>> _calendarDays = [];

  DateTime _ongoingStart = DateTime.now().subtract(const Duration(days: 2));
  DateTime _ongoingEnd = DateTime.now().add(const Duration(days: 2));
  DateTime _upcomingStart = DateTime.now().add(const Duration(days: 5));
  DateTime _upcomingEnd = DateTime.now().add(const Duration(days: 9));
  DateTime _completedStart = DateTime.now().subtract(const Duration(days: 10));
  DateTime _completedEnd = DateTime.now().subtract(const Duration(days: 6));

  @override
  void initState() {
    super.initState();
    _generateCalendarDays();
  }

  String _getDayStatus(DateTime date) {
    final compareDate = DateTime(date.year, date.month, date.day);
    final ongoingStart = DateTime(_ongoingStart.year, _ongoingStart.month, _ongoingStart.day);
    final ongoingEnd = DateTime(_ongoingEnd.year, _ongoingEnd.month, _ongoingEnd.day);
    final upcomingStart = DateTime(_upcomingStart.year, _upcomingStart.month, _upcomingStart.day);
    final upcomingEnd = DateTime(_upcomingEnd.year, _upcomingEnd.month, _upcomingEnd.day);
    final completedStart = DateTime(_completedStart.year, _completedStart.month, _completedStart.day);
    final completedEnd = DateTime(_completedEnd.year, _completedEnd.month, _completedEnd.day);

    if (!compareDate.isBefore(ongoingStart) && !compareDate.isAfter(ongoingEnd)) {
      return 'ongoing';
    } else if (!compareDate.isBefore(upcomingStart) && !compareDate.isAfter(upcomingEnd)) {
      return 'upcoming';
    } else if (!compareDate.isBefore(completedStart) && !compareDate.isAfter(completedEnd)) {
      return 'completed';
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
          _buildHeader(title: 'Calendar'),
          Expanded(
            child: SingleChildScrollView(
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

  Widget _buildHeader({String? title}) {
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
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
        Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.asset(
                'assets/images/logo.png',
                height: 56,
                width: 56,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  height: 56,
                  width: 56,
                  color: Colors.grey[200],
                  child: const Icon(Icons.map, color: AppColors.primary),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              title ?? 'Calendar',
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        Row(
          children: [
            Stack(
              children: [
                IconButton(
                  icon: const Icon(
                    Icons.notifications_outlined,
                    color: AppColors.textPrimary,
                    size: 28,
                  ),
                  onPressed: () {},
                ),
                Positioned(
                  right: 12,
                  top: 12,
                  child: Container(
                    height: 8,
                    width: 8,
                    decoration: const BoxDecoration(
                      color: Color(0xFF1E5AE6),
                      shape: BoxShape.circle,
                    ),
                  ),
                )
              ],
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: widget.onProfileTap,
              child: const CircleAvatar(
                radius: 20,
                backgroundImage: NetworkImage(
                  'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=150&auto=format&fit=crop&q=80',
                ),
              ),
            ),
          ],
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
                Text(
                  _getCurrentMonthYear(),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
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
    final totalDays = _ongoingEnd.difference(_ongoingStart).inDays + 1;
    final currentDay = _calculateCurrentDayOfTrip(_ongoingStart, _ongoingEnd);
    final progress = totalDays > 0 ? (currentDay / totalDays).clamp(0.0, 1.0) : 0.0;

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
                    const Text(
                      'Ongoing Trip',
                      style: TextStyle(
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
                  child: Image.network(
                     'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?w=300&auto=format&fit=crop&q=60',
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
                        children: const [
                          Expanded(
                            child: Text(
                              'Goa Beach Trip',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                          ),
                          Icon(
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
                            'Goa, India',
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
                            _formatTripDates(_ongoingStart, _ongoingEnd),
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
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
