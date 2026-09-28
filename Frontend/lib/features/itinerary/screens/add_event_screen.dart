import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_formatter.dart';
import '../services/itinerary_service.dart';

class AddEventScreen extends StatefulWidget {
  final Map<String, dynamic>? tripData;
  final Map<String, dynamic>? existingActivity;
  final List<Map<String, dynamic>>? existingActivities;
  final DateTime? initialDate;

  const AddEventScreen({
    super.key,
    this.tripData,
    this.existingActivity,
    this.existingActivities,
    this.initialDate,
  });

  @override
  State<AddEventScreen> createState() => _AddEventScreenState();
}

class _AddEventScreenState extends State<AddEventScreen> {
  final _formKey = GlobalKey<FormState>();
  
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _timeController = TextEditingController();
  final TextEditingController _costController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  final TextEditingController _dateController = TextEditingController();
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  String _selectedCategory = 'sightseeing';

  DateTime? _tripStartDate;
  DateTime? _tripEndDate;
  List<Map<String, dynamic>> _tripDays = [];
  int? _selectedDayNumber;
  List<Map<String, dynamic>> _activitiesList = [];

  final List<Map<String, dynamic>> _categories = [
    {'id': 'sightseeing', 'label': 'Sightseeing', 'icon': Icons.image_search_outlined, 'color': Color(0xFF0EA5E9)},
    {'id': 'food', 'label': 'Food', 'icon': Icons.restaurant_outlined, 'color': Color(0xFF20C060)},
    {'id': 'lodging', 'label': 'Lodging', 'icon': Icons.hotel_outlined, 'color': Color(0xFF9333EA)},
    {'id': 'transport', 'label': 'Transport', 'icon': Icons.flight_takeoff_outlined, 'color': Color(0xFFEA580C)},
  ];

  @override
  void initState() {
    super.initState();
    _initTripDatesAndFields();
    if (widget.tripData?['_id'] != null) {
      _fetchExistingActivities(widget.tripData!['_id'].toString());
    }
  }

  void _initTripDatesAndFields() {
    if (widget.existingActivities != null) {
      _activitiesList = List<Map<String, dynamic>>.from(widget.existingActivities!);
    }

    if (widget.tripData != null &&
        widget.tripData!['startDate'] != null &&
        widget.tripData!['endDate'] != null) {
      try {
        final start = TripInfoHelper.parseTripDate(widget.tripData!['startDate'].toString());
        final end = TripInfoHelper.parseTripDate(widget.tripData!['endDate'].toString());

        _tripStartDate = DateTime(start.year, start.month, start.day);
        _tripEndDate = DateTime(end.year, end.month, end.day);

        if (_tripEndDate!.isBefore(_tripStartDate!)) {
          _tripEndDate = _tripStartDate;
        }

        final durationInDays = _tripEndDate!.difference(_tripStartDate!).inDays + 1;
        _tripDays = List.generate(durationInDays, (index) {
          final dayDate = _tripStartDate!.add(Duration(days: index));
          final dateLabel = DateFormat('MMM d').format(dayDate);
          return {
            'dayNumber': index + 1,
            'label': 'Day ${index + 1} ($dateLabel)',
            'date': dayDate,
          };
        });
      } catch (e) {
        debugPrint('Error parsing trip dates: $e');
      }
    }

    if (widget.existingActivity != null) {
      final activity = widget.existingActivity!;
      _titleController.text = activity['title'] ?? '';
      _locationController.text = activity['location'] ?? '';
      _timeController.text = activity['time'] ?? '';
      if (_timeController.text.isNotEmpty) {
        _selectedTime = _parseTimeOfDay(_timeController.text);
      }
      final rawCost = activity['estimatedCost'] ?? activity['cost'];
      if (rawCost != null) {
        String costStr = rawCost.toString().replaceAll('₹', '').replaceAll('/person', '').trim();
        if (costStr.toLowerCase() == 'free') {
          costStr = '';
        }
        _costController.text = costStr;
      } else {
        _costController.text = '';
      }
      _notesController.text = activity['notes'] ?? '';
      
      if (activity['rawDate'] != null) {
        final raw = activity['rawDate'] as DateTime;
        _selectedDate = DateTime(raw.year, raw.month, raw.day);
        _dateController.text = "${_selectedDate!.year}-${_selectedDate!.month.toString().padLeft(2, '0')}-${_selectedDate!.day.toString().padLeft(2, '0')}";
        _syncDayFromDate(_selectedDate!);
      }
      
      _selectedCategory = activity['type'] ?? 'sightseeing';
    } else {
      if (widget.initialDate != null) {
        _selectedDate = DateTime(widget.initialDate!.year, widget.initialDate!.month, widget.initialDate!.day);
        _dateController.text = "${_selectedDate!.year}-${_selectedDate!.month.toString().padLeft(2, '0')}-${_selectedDate!.day.toString().padLeft(2, '0')}";
        _syncDayFromDate(_selectedDate!);
      } else if (_tripStartDate != null) {
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        if (!today.isBefore(_tripStartDate!) && !today.isAfter(_tripEndDate!)) {
          _selectedDate = today;
        } else {
          _selectedDate = _tripStartDate;
        }
        _dateController.text = "${_selectedDate!.year}-${_selectedDate!.month.toString().padLeft(2, '0')}-${_selectedDate!.day.toString().padLeft(2, '0')}";
        _syncDayFromDate(_selectedDate!);
      }
    }
  }

  Future<void> _fetchExistingActivities(String tripId) async {
    try {
      final response = await _itineraryService.getItinerary(tripId);
      if (response['success'] == true && response['data'] != null) {
        final List<dynamic> daysData = response['data'];
        final List<Map<String, dynamic>> allActs = [];
        for (var dayData in daysData) {
          final DateTime? dayDate = dayData['date'] != null ? DateTime.tryParse(dayData['date'])?.toLocal() : null;
          final List<dynamic> acts = dayData['activities'] ?? [];
          for (var act in acts) {
            String timeStr = '';
            DateTime? parsedStartTime;
            if (act['startTime'] != null) {
              parsedStartTime = DateTime.tryParse(act['startTime'])?.toLocal();
              if (parsedStartTime != null) {
                timeStr = DateFormat('hh:mm a').format(parsedStartTime);
              }
            }
            allActs.add({
              '_id': act['_id']?.toString(),
              'title': act['title'] ?? '',
              'rawDate': dayDate != null
                  ? DateTime(dayDate.year, dayDate.month, dayDate.day)
                  : (parsedStartTime != null
                      ? DateTime(parsedStartTime.year, parsedStartTime.month, parsedStartTime.day)
                      : null),
              'time': timeStr,
              'startTime': parsedStartTime,
              'location': act['location']?['name'] ?? '',
            });
          }
        }
        if (mounted) {
          setState(() {
            _activitiesList = allActs;
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching itinerary for conflict check: $e');
    }
  }

  TimeOfDay? _parseTimeOfDay(String timeStr) {
    final trimmed = timeStr.trim();
    if (trimmed.isEmpty) return null;
    try {
      final format = DateFormat.jm();
      final dt = format.parse(trimmed);
      return TimeOfDay(hour: dt.hour, minute: dt.minute);
    } catch (_) {
      try {
        final parts = trimmed.split(':');
        if (parts.length >= 2) {
          int hour = int.parse(parts[0].trim());
          final minPart = parts[1].trim().split(' ');
          int minute = int.parse(minPart[0].trim());
          if (minPart.length > 1) {
            final period = minPart[1].toUpperCase();
            if (period == 'PM' && hour < 12) hour += 12;
            if (period == 'AM' && hour == 12) hour = 0;
          }
          return TimeOfDay(hour: hour, minute: minute);
        }
      } catch (_) {}
    }
    return null;
  }

  Map<String, dynamic>? _findConflictingActivity(DateTime date, TimeOfDay time) {
    final targetDate = DateTime(date.year, date.month, date.day);
    final targetHour = time.hour;
    final targetMinute = time.minute;
    final currentActivityId = (widget.existingActivity?['_id'] ?? widget.existingActivity?['id'])?.toString();

    for (final act in _activitiesList) {
      final actId = (act['_id'] ?? act['id'])?.toString();
      if (currentActivityId != null && actId != null && actId == currentActivityId) {
        continue;
      }

      DateTime? actDate;
      if (act['rawDate'] is DateTime) {
        actDate = act['rawDate'] as DateTime;
      } else if (act['date'] != null) {
        actDate = DateTime.tryParse(act['date'].toString())?.toLocal();
      } else if (act['startTime'] != null) {
        if (act['startTime'] is DateTime) {
          actDate = act['startTime'] as DateTime;
        } else {
          actDate = DateTime.tryParse(act['startTime'].toString())?.toLocal();
        }
      }

      if (actDate == null) continue;
      final normActDate = DateTime(actDate.year, actDate.month, actDate.day);
      if (!normActDate.isAtSameMomentAs(targetDate)) {
        continue;
      }

      TimeOfDay? actTime;
      if (act['startTime'] is DateTime) {
        final st = act['startTime'] as DateTime;
        actTime = TimeOfDay(hour: st.hour, minute: st.minute);
      } else if (act['time'] != null && act['time'].toString().isNotEmpty) {
        actTime = _parseTimeOfDay(act['time'].toString());
      } else if (act['startTime'] != null) {
        final st = DateTime.tryParse(act['startTime'].toString())?.toLocal();
        if (st != null) {
          actTime = TimeOfDay(hour: st.hour, minute: st.minute);
        }
      }

      if (actTime == null) continue;

      if (actTime.hour == targetHour && actTime.minute == targetMinute) {
        return act;
      }
    }
    return null;
  }

  void _showTimeConflictDialog(Map<String, dynamic> conflict, String timeStr) {
    final conflictingTitle = (conflict['title'] != null && conflict['title'].toString().trim().isNotEmpty)
        ? conflict['title'].toString()
        : 'Another Event';
    final location = conflict['location']?.toString();
    final dateStr = _selectedDate != null ? DateFormat('EEEE, MMM d').format(_selectedDate!) : 'this day';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                color: Color(0xFFFEE2E2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.access_time_filled_rounded,
                color: AppColors.error,
                size: 34,
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Time Slot Conflict',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'An event is already scheduled at $timeStr on $dateStr.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.event_outlined, color: AppColors.primary, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          conflictingTitle,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: AppColors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            const Icon(Icons.access_time, size: 12, color: AppColors.textLight),
                            const SizedBox(width: 4),
                            Text(
                              timeStr,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.error,
                              ),
                            ),
                            if (location != null && location.isNotEmpty) ...[
                              const SizedBox(width: 8),
                              const Text('•', style: TextStyle(color: AppColors.textLight, fontSize: 12)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  location,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Please choose a different time to avoid overlapping events.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textLight,
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Change Time',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _syncDayFromDate(DateTime date) {
    if (_tripStartDate == null) return;
    final normalizedDate = DateTime(date.year, date.month, date.day);
    final diff = normalizedDate.difference(_tripStartDate!).inDays;
    if (diff >= 0 && _tripEndDate != null && !normalizedDate.isAfter(_tripEndDate!)) {
      _selectedDayNumber = diff + 1;
    } else {
      _selectedDayNumber = null;
    }
  }

  void _onDaySelected(int? dayNumber) {
    if (dayNumber == null || _tripStartDate == null) return;
    final newDate = _tripStartDate!.add(Duration(days: dayNumber - 1));
    setState(() {
      _selectedDayNumber = dayNumber;
      _selectedDate = newDate;
      _dateController.text = "${newDate.year}-${newDate.month.toString().padLeft(2, '0')}-${newDate.day.toString().padLeft(2, '0')}";
      if (_selectedTime != null) {
        if (_isTimeInvalid(newDate, _selectedTime!)) {
          _selectedTime = null;
          _timeController.clear();
        } else {
          final conflict = _findConflictingActivity(newDate, _selectedTime!);
          if (conflict != null) {
            final timeStr = _timeController.text;
            _selectedTime = null;
            _timeController.clear();
            _showTimeConflictDialog(conflict, timeStr);
          }
        }
      }
    });
  }

  void _onDatePicked(DateTime picked) {
    setState(() {
      _selectedDate = picked;
      _dateController.text = "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
      _syncDayFromDate(picked);
      if (_selectedTime != null) {
        if (_isTimeInvalid(picked, _selectedTime!)) {
          _selectedTime = null;
          _timeController.clear();
        } else {
          final conflict = _findConflictingActivity(picked, _selectedTime!);
          if (conflict != null) {
            final timeStr = _timeController.text;
            _selectedTime = null;
            _timeController.clear();
            _showTimeConflictDialog(conflict, timeStr);
          }
        }
      }
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _locationController.dispose();
    _timeController.dispose();
    _dateController.dispose();
    _costController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  bool _isSaving = false;
  final ItineraryService _itineraryService = ItineraryService();

  Future<void> _saveEvent() async {
    if (_formKey.currentState!.validate()) {
      final tripId = widget.tripData?['_id'];
      if (tripId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error: No trip data available')),
        );
        return;
      }

      // Check conflict before sending
      if (_selectedDate != null && _selectedTime != null) {
        final conflict = _findConflictingActivity(_selectedDate!, _selectedTime!);
        if (conflict != null) {
          _showTimeConflictDialog(conflict, _timeController.text);
          return;
        }
      }

      setState(() {
        _isSaving = true;
      });

      // Parse date to a format the backend can use
      String formattedDate = '';
      if (_selectedDate != null) {
        formattedDate = "${_selectedDate!.year}-${_selectedDate!.month.toString().padLeft(2, '0')}-${_selectedDate!.day.toString().padLeft(2, '0')}";
      }

      // Time comes from the controller text directly (e.g., "10:30 AM")
      final timeText = _timeController.text;

      final eventData = {
        'title': _titleController.text.trim(),
        'location': _locationController.text.trim(),
        'date': formattedDate,
        'time': timeText,
        'type': _selectedCategory,
        'cost': _costController.text.trim(),
        'notes': _notesController.text.trim(),
      };

      final isEdit = widget.existingActivity != null;
      Map<String, dynamic> response;
      if (isEdit) {
        final activityId = widget.existingActivity!['_id'];
        response = await _itineraryService.updateActivity(tripId, activityId, eventData);
      } else {
        response = await _itineraryService.addActivity(tripId, eventData);
      }

      setState(() {
        _isSaving = false;
      });

      if (response['success'] == true) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_outline, color: Colors.white),
                const SizedBox(width: 10),
                Text(isEdit ? 'Event successfully updated!' : 'Event successfully added to itinerary!'),
              ],
            ),
            backgroundColor: AppColors.secondary,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
        Navigator.pop(context, true);
      } else {
        if (!mounted) return;
        if (response['conflict'] == true ||
            (response['message'] != null &&
                response['message'].toString().toLowerCase().contains('already scheduled'))) {
          _showTimeConflictDialog(
            response['conflictingActivity'] ?? {'title': 'Existing Event'},
            timeText,
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response['message'] ?? 'Failed to ${isEdit ? 'update' : 'add'} event'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _buildAppBar(),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionTitle('Event Category'),
              const SizedBox(height: 12),
              _buildCategorySelector(),
              const SizedBox(height: 24),
              
              _buildSectionTitle('Event Info'),
              const SizedBox(height: 12),
              _buildInputField(
                controller: _titleController,
                label: 'Event Title',
                hint: 'e.g. Visit Eiffel Tower, Lunch at Cafe',
                icon: Icons.title_outlined,
                validator: (val) => val == null || val.isEmpty ? 'Title is required' : null,
              ),
              const SizedBox(height: 16),
              _buildInputField(
                controller: _locationController,
                label: 'Location',
                hint: 'e.g. Champ de Mars, Paris',
                icon: Icons.location_on_outlined,
                validator: (val) => val == null || val.isEmpty ? 'Location is required' : null,
              ),
              const SizedBox(height: 24),

              _buildSectionTitle('Date & Timing'),
              const SizedBox(height: 12),
              _buildDayField(),
              _buildDateField(),
              const SizedBox(height: 16),
              _buildTimeField(),
              const SizedBox(height: 24),

              _buildSectionTitle('Budget & Notes'),
              const SizedBox(height: 12),
              _buildInputField(
                controller: _costController,
                label: 'Estimated Cost (per person)',
                hint: 'e.g. 3000, Free',
                icon: Icons.currency_rupee,
              ),
              const SizedBox(height: 16),
              _buildInputField(
                controller: _notesController,
                label: 'Notes / Booking details',
                hint: 'Confirmation codes, baggage info, links...',
                icon: Icons.description_outlined,
                maxLines: 3,
              ),
              const SizedBox(height: 40),
              
              _buildSaveButton(),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
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
      title: Text(
        widget.existingActivity != null ? 'Edit Itinerary Event' : 'Add Itinerary Event',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.bold,
        color: AppColors.textPrimary,
      ),
    );
  }

  Widget _buildCategorySelector() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 2.2,
      ),
      itemCount: _categories.length,
      itemBuilder: (context, index) {
        final cat = _categories[index];
        final isSelected = _selectedCategory == cat['id'];
        final Color catColor = cat['color'];
        return GestureDetector(
          onTap: () {
            setState(() {
              _selectedCategory = cat['id'];
            });
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: isSelected ? catColor.withOpacity(0.12) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected ? catColor : const Color(0xFFE2E8F0),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.01),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(cat['icon'], color: isSelected ? catColor : AppColors.textSecondary, size: 20),
                const SizedBox(width: 8),
                Text(
                  cat['label'],
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? catColor : AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.01),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        validator: validator,
        style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
          hintText: hint,
          hintStyle: const TextStyle(color: AppColors.textLight, fontSize: 13),
          prefixIcon: Icon(icon, color: AppColors.textSecondary, size: 18),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }

  bool _isTimeInvalid(DateTime date, TimeOfDay time) {
    final now = DateTime.now();
    if (date.year == now.year && date.month == now.month && date.day == now.day) {
      if (time.hour < now.hour || (time.hour == now.hour && time.minute < now.minute)) {
        return true;
      }
    }
    return false;
  }

  Widget _buildDayField() {
    if (_tripDays.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.01),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: DropdownButtonFormField<int>(
        isExpanded: true,
        value: _selectedDayNumber,
        decoration: const InputDecoration(
          labelText: 'Trip Day',
          labelStyle: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          hintText: 'Select Day',
          hintStyle: TextStyle(color: AppColors.textLight, fontSize: 13),
          prefixIcon: Icon(Icons.event_note_outlined, color: AppColors.textSecondary, size: 18),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.textSecondary),
        dropdownColor: Colors.white,
        borderRadius: BorderRadius.circular(16),
        items: _tripDays.map((day) {
          return DropdownMenuItem<int>(
            value: day['dayNumber'] as int,
            child: Text(
              day['label'] as String,
              style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
              overflow: TextOverflow.ellipsis,
            ),
          );
        }).toList(),
        onChanged: (val) {
          if (val != null) {
            _onDaySelected(val);
          }
        },
      ),
    );
  }

  Widget _buildDateField() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.01),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextFormField(
        controller: _dateController,
        readOnly: true,
        validator: (val) => val == null || val.isEmpty ? 'Date is required' : null,
        onTap: () async {
          final DateTime now = DateTime.now();
          final DateTime today = DateTime(now.year, now.month, now.day);
          
          DateTime first = _tripStartDate ?? today;
          DateTime last = _tripEndDate ?? DateTime(now.year + 5);

          if (last.isBefore(first)) {
            last = first;
          }

          DateTime initial = _selectedDate ?? today;
          if (initial.isBefore(first)) {
            initial = first;
          } else if (initial.isAfter(last)) {
            initial = last;
          }

          final DateTime? picked = await showDatePicker(
            context: context,
            initialDate: initial,
            firstDate: first,
            lastDate: last,
            selectableDayPredicate: (DateTime day) {
              if (_tripStartDate != null && _tripEndDate != null) {
                final d = DateTime(day.year, day.month, day.day);
                return !d.isBefore(_tripStartDate!) && !d.isAfter(_tripEndDate!);
              }
              return true;
            },
          );
          if (picked != null) {
            _onDatePicked(picked);
          }
        },
        style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
        decoration: const InputDecoration(
          labelText: 'Trip Date',
          labelStyle: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          hintText: 'Select Date',
          hintStyle: TextStyle(color: AppColors.textLight, fontSize: 13),
          prefixIcon: Icon(Icons.calendar_today_outlined, color: AppColors.textSecondary, size: 18),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }

  Widget _buildTimeField() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.01),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextFormField(
        controller: _timeController,
        readOnly: true,
        validator: (val) {
          if (val == null || val.isEmpty) return 'Time is required';
          return null;
        },
        onTap: () async {
          if (_selectedDate == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Please select a date first')),
            );
            return;
          }
          final TimeOfDay? picked = await showTimePicker(
            context: context,
            initialTime: _selectedTime ?? TimeOfDay.now(),
          );
          if (picked != null) {
            if (_isTimeInvalid(_selectedDate!, picked)) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Cannot select a past time for today')),
                );
              }
              return;
            }

            final now = DateTime.now();
            final dt = DateTime(now.year, now.month, now.day, picked.hour, picked.minute);
            final formattedTime = DateFormat('hh:mm a').format(dt);

            final conflict = _findConflictingActivity(_selectedDate!, picked);
            if (conflict != null) {
              if (mounted) {
                _showTimeConflictDialog(conflict, formattedTime);
              }
              return;
            }

            setState(() {
              _selectedTime = picked;
              _timeController.text = formattedTime;
            });
          }
        },
        style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
        decoration: const InputDecoration(
          labelText: 'Time',
          labelStyle: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          hintText: 'Select Time',
          hintStyle: TextStyle(color: AppColors.textLight, fontSize: 13),
          prefixIcon: Icon(Icons.access_time_outlined, color: AppColors.textSecondary, size: 18),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }

  Widget _buildSaveButton() {
    return Container(
      width: double.infinity,
      height: 52,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          colors: [Color(0xFF00C6FF), Color(0xFF0072FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0072FF).withOpacity(0.25),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: _isSaving ? null : _saveEvent,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: _isSaving 
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
              )
            : const Text(
                'Save Event',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }
}
