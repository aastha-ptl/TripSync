import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

import '../services/itinerary_service.dart';

class AddEventScreen extends StatefulWidget {
  final Map<String, dynamic>? tripData;
  final Map<String, dynamic>? existingActivity;

  const AddEventScreen({super.key, this.tripData, this.existingActivity});

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

  final List<Map<String, dynamic>> _categories = [
    {'id': 'sightseeing', 'label': 'Sightseeing', 'icon': Icons.image_search_outlined, 'color': Color(0xFF0EA5E9)},
    {'id': 'food', 'label': 'Food', 'icon': Icons.restaurant_outlined, 'color': Color(0xFF20C060)},
    {'id': 'lodging', 'label': 'Lodging', 'icon': Icons.hotel_outlined, 'color': Color(0xFF9333EA)},
    {'id': 'transport', 'label': 'Transport', 'icon': Icons.flight_takeoff_outlined, 'color': Color(0xFFEA580C)},
  ];

  @override
  void initState() {
    super.initState();
    if (widget.existingActivity != null) {
      final activity = widget.existingActivity!;
      _titleController.text = activity['title'] ?? '';
      _locationController.text = activity['location'] ?? '';
      _timeController.text = activity['time'] ?? '';
      _costController.text = (activity['cost'] ?? '').toString().replaceAll('₹', '');
      _notesController.text = activity['notes'] ?? '';
      
      if (activity['rawDate'] != null) {
        _selectedDate = activity['rawDate'] as DateTime;
        _dateController.text = "${_selectedDate!.month}/${_selectedDate!.day}/${_selectedDate!.year}";
      }
      
      _selectedCategory = activity['type'] ?? 'sightseeing';
    }
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response['message'] ?? 'Failed to ${isEdit ? 'update' : 'add'} event'),
            backgroundColor: Colors.red,
          ),
        );
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
              _buildDateField(),
              const SizedBox(height: 16),
              _buildTimeField(),
              const SizedBox(height: 24),

              _buildSectionTitle('Budget & Notes'),
              const SizedBox(height: 12),
              _buildInputField(
                controller: _costController,
                label: 'Estimated Cost',
                hint: 'e.g. €25, Free, ₹1,200',
                icon: Icons.euro_symbol_outlined,
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
          // Reset time to start of day for comparison
          final DateTime today = DateTime(now.year, now.month, now.day);
          final DateTime? picked = await showDatePicker(
            context: context,
            initialDate: _selectedDate ?? today,
            firstDate: today,
            lastDate: DateTime(now.year + 5),
          );
          if (picked != null) {
            setState(() {
              _selectedDate = picked;
              _dateController.text = "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
              if (_selectedTime != null && _isTimeInvalid(picked, _selectedTime!)) {
                _selectedTime = null;
                _timeController.clear();
              }
            });
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
            setState(() {
              _selectedTime = picked;
              _timeController.text = picked.format(context);
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
