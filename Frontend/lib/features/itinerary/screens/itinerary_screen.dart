import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/routes/app_routes.dart';
import '../services/itinerary_service.dart';

class ItineraryScreen extends StatefulWidget {
  final Map<String, dynamic>? tripData;
  final bool isSoloTraveler;

  const ItineraryScreen({
    super.key, 
    this.tripData,
    this.isSoloTraveler = false,
  });

  @override
  State<ItineraryScreen> createState() => _ItineraryScreenState();
}

class _ItineraryScreenState extends State<ItineraryScreen> {
  final ItineraryService _itineraryService = ItineraryService();
  bool _isLoading = true;
  int _selectedDayIndex = 0;
  List<Map<String, dynamic>> _days = [];
  Map<int, List<Map<String, dynamic>>> _activities = {};

  @override
  void initState() {
    super.initState();
    _fetchItinerary();
  }

  Future<void> _fetchItinerary() async {
    final tripId = widget.tripData?['_id'];
    if (tripId == null) {
      setState(() => _isLoading = false);
      return;
    }

    // Pre-calculate the days based on trip start and end date
    List<Map<String, dynamic>> loadedDays = [];
    Map<int, List<Map<String, dynamic>>> loadedActivities = {};
    
    if (widget.tripData?['startDate'] != null && widget.tripData?['endDate'] != null) {
      final startDateStr = widget.tripData!['startDate'].toString();
      final endDateStr = widget.tripData!['endDate'].toString();
      
      DateTime startDate = DateTime.parse(startDateStr).toLocal();
      DateTime endDate = DateTime.parse(endDateStr).toLocal();
      
      startDate = DateTime(startDate.year, startDate.month, startDate.day);
      endDate = DateTime(endDate.year, endDate.month, endDate.day);
      
      final durationInDays = endDate.difference(startDate).inDays + 1;
      
      for (int i = 0; i < durationInDays; i++) {
        final currentDay = startDate.add(Duration(days: i));
        loadedDays.add({
          'day': 'Day ${i + 1}',
          'date': DateFormat('MMM d').format(currentDay),
          'rawDate': currentDay,
          'label': '',
        });
        loadedActivities[i] = [];
      }
    }

    final response = await _itineraryService.getItinerary(tripId);
    if (response['success'] == true) {
      final List<dynamic> daysData = response['data'] ?? [];
      
      for (var dayData in daysData) {
        final DateTime date = DateTime.parse(dayData['date']).toLocal();
        final normalizedDate = DateTime(date.year, date.month, date.day);
        
        int dayIndex = loadedDays.indexWhere((d) => 
          (d['rawDate'] as DateTime).isAtSameMomentAs(normalizedDate)
        );
        
        if (dayIndex != -1) {
          if (dayData['title'] != null && dayData['title'].isNotEmpty && dayData['title'] != 'Day ${dayData['dayNumber']}') {
            loadedDays[dayIndex]['label'] = dayData['title'];
          }
          
          final List<dynamic> activitiesData = dayData['activities'] ?? [];
          List<Map<String, dynamic>> dayActivities = [];
          for (var act in activitiesData) {
            String timeStr = '';
            if (act['startTime'] != null) {
              final startTime = DateTime.parse(act['startTime']).toLocal();
              timeStr = DateFormat('hh:mm a').format(startTime);
            }
            
            dayActivities.add({
              '_id': act['_id'],
              'rawDate': normalizedDate,
              'time': timeStr,
              'title': act['title'] ?? '',
              'location': act['location']?['name'] ?? '',
              'type': act['type'] ?? 'other',
              'status': act['status'] ?? 'planned',
              'cost': (act['estimatedCost'] != null && act['estimatedCost'] > 0) ? '₹${act['estimatedCost']}' : 'Free',
              'notes': act['description'] ?? '',
            });
          }
          loadedActivities[dayIndex] = dayActivities;
        }
      }
    }

    int initialSelectedIndex = 0;
    if (loadedDays.isNotEmpty) {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      
      final startDate = loadedDays.first['rawDate'] as DateTime;
      final endDate = loadedDays.last['rawDate'] as DateTime;
      
      if (today.isAfter(endDate)) {
        initialSelectedIndex = 0;
      } else if (today.isBefore(startDate)) {
        initialSelectedIndex = 0;
      } else {
        initialSelectedIndex = loadedDays.indexWhere((d) => 
          (d['rawDate'] as DateTime).isAtSameMomentAs(today)
        );
        if (initialSelectedIndex == -1) initialSelectedIndex = 0;
      }
    }

    setState(() {
      _days = loadedDays;
      _activities = loadedActivities;
      _selectedDayIndex = initialSelectedIndex;
      _isLoading = false;
    });
  }

  void _editActivity(Map<String, dynamic> activity) {
    Navigator.pushNamed(
      context,
      AppRoutes.addEvent,
      arguments: {
        'tripData': widget.tripData,
        'existingActivity': activity,
      },
    ).then((_) {
      setState(() => _isLoading = true);
      _fetchItinerary();
    });
  }

  void _deleteActivity(Map<String, dynamic> activity) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Activity'),
        content: const Text('Are you sure you want to delete this activity?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              setState(() => _isLoading = true);
              final tripId = widget.tripData?['_id'];
              final activityId = activity['_id'];
              if (tripId != null && activityId != null) {
                final response = await _itineraryService.deleteActivity(tripId, activityId);
                if (response['success'] == true) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Activity deleted successfully'), backgroundColor: Colors.green),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(response['message'] ?? 'Failed to delete activity'), backgroundColor: Colors.red),
                  );
                }
              }
              _fetchItinerary();
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _buildAppBar(),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (_days.isNotEmpty) _buildDaySelector(),
                Expanded(
                  child: _buildActivityTimeline(),
                ),
              ],
            ),
      floatingActionButton: widget.isSoloTraveler ? null : _buildFAB(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 4,
      shadowColor: Colors.black.withOpacity(0.12),
      scrolledUnderElevation: 0,
      flexibleSpace: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF00C6FF), Color(0xFF0072FF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
      ),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
        onPressed: () => Navigator.pop(context),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.tripData?['name'] ?? 'Trip Itinerary',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            _days.isNotEmpty ? '${_days.first['date']} - ${_days.last['date']} • ${_days.length} Days' : 'Loading...',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.map_outlined, color: Colors.white, size: 22),
          onPressed: () {},
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildDaySelector() {
    return Container(
      height: 85,
      padding: const EdgeInsets.symmetric(vertical: 12),
      color: AppColors.surface,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        physics: const BouncingScrollPhysics(),
        itemCount: _days.length,
        itemBuilder: (context, index) {
          final day = _days[index];
          final isSelected = _selectedDayIndex == index;
          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedDayIndex = index;
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 70,
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                gradient: isSelected
                    ? const LinearGradient(
                        colors: [AppColors.primary, Color(0xFF3B82F6)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                color: isSelected ? null : AppColors.background,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected ? Colors.transparent : const Color(0xFFE2E8F0),
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.25),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        )
                      ]
                    : null,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    day['day']!,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.white70 : AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    day['date']!.split(' ')[1],
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: isSelected ? Colors.white : AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildActivityTimeline() {
    final activities = _activities[_selectedDayIndex] ?? [];

    if (activities.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.calendar_today_outlined, size: 48, color: AppColors.textLight),
            SizedBox(height: 12),
            Text(
              'No activities planned for this day.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      physics: const BouncingScrollPhysics(),
      itemCount: activities.length,
      itemBuilder: (context, index) {
        final activity = activities[index];
        final isLast = index == activities.length - 1;
        return _buildTimelineItem(activity, isLast);
      },
    );
  }

  Widget _buildTimelineItem(Map<String, dynamic> activity, bool isLast) {
    IconData typeIcon = Icons.tour_outlined;
    Color typeColor = AppColors.primary;

    switch (activity['type']) {
      case 'transport':
        typeIcon = Icons.flight_takeoff_outlined;
        typeColor = const Color(0xFFEA580C);
        break;
      case 'lodging':
        typeIcon = Icons.hotel_outlined;
        typeColor = const Color(0xFF9333EA);
        break;
      case 'food':
        typeIcon = Icons.restaurant_outlined;
        typeColor = AppColors.secondary;
        break;
      case 'sightseeing':
        typeIcon = Icons.image_search_outlined;
        typeColor = const Color(0xFF0EA5E9);
        break;
    }

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Time Indicator Column
          SizedBox(
            width: 75,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 12),
                Text(
                  activity['time'],
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                // Cost badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    activity['cost'],
                    style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Connector Dots & Line
          Column(
            children: [
              const SizedBox(height: 12),
              Container(
                height: 28,
                width: 28,
                decoration: BoxDecoration(
                  color: typeColor.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(typeIcon, size: 15, color: typeColor),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: const Color(0xFFE2E8F0),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 14),
          // Details Card
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(bottom: 20),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.02),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          activity['title'],
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildStatusBadge(activity['status']),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                if (activity['status'] == 'completed') {
                                  activity['status'] = 'upcoming';
                                } else {
                                  activity['status'] = 'completed';
                                }
                              });
                            },
                            child: Icon(
                              activity['status'] == 'completed'
                                  ? Icons.check_circle
                                  : Icons.radio_button_unchecked,
                              size: 18,
                              color: activity['status'] == 'completed'
                                  ? const Color(0xFF20C060)
                                  : const Color(0xFF94A3B8),
                            ),
                          ),
                          if (!widget.isSoloTraveler) ...[
                            const SizedBox(width: 4),
                            PopupMenuButton<String>(
                              padding: EdgeInsets.zero,
                              icon: const Icon(Icons.more_vert, size: 18, color: AppColors.textSecondary),
                              onSelected: (value) {
                                if (value == 'edit') {
                                  _editActivity(activity);
                                } else if (value == 'delete') {
                                  _deleteActivity(activity);
                                }
                              },
                              itemBuilder: (context) => [
                                const PopupMenuItem(
                                  value: 'edit',
                                  child: Row(
                                    children: [
                                      Icon(Icons.edit_outlined, size: 18, color: AppColors.textPrimary),
                                      SizedBox(width: 8),
                                      Text('Edit', style: TextStyle(fontSize: 14)),
                                    ],
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: 'delete',
                                  child: Row(
                                    children: [
                                      Icon(Icons.delete_outline, size: 18, color: Colors.red),
                                      SizedBox(width: 8),
                                      Text('Delete', style: TextStyle(fontSize: 14, color: Colors.red)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined, size: 12, color: AppColors.textLight),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          activity['location'],
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      activity['notes'],
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bg = const Color(0xFFF1F5F9);
    Color txt = AppColors.textSecondary;
    String label = 'Upcoming';
    IconData? icon;

    if (status == 'completed') {
      bg = const Color(0xFFDCFCE7);
      txt = const Color(0xFF15803D);
      label = 'Done';
      icon = Icons.check_circle;
    } else if (status == 'active') {
      bg = const Color(0xFFDBEAFE);
      txt = const Color(0xFF1D4ED8);
      label = 'Now';
      icon = Icons.play_arrow;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 10, color: txt),
            const SizedBox(width: 3),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.bold,
              color: txt,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFAB() {
    return FloatingActionButton.extended(
      onPressed: () {
        Navigator.pushNamed(context, AppRoutes.addEvent, arguments: {'tripData': widget.tripData}).then((_) {
          // Refresh itinerary when returning from add event screen
          setState(() {
            _isLoading = true;
          });
          _fetchItinerary();
        });
      },
      backgroundColor: AppColors.primary,
      icon: const Icon(Icons.add, color: Colors.white),
      label: const Text(
        'Add Event',
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      ),
      elevation: 4,
    );
  }
}
