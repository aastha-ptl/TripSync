import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class AddEventScreen extends StatefulWidget {
  const AddEventScreen({super.key});

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

  String _selectedCategory = 'sightseeing';
  String _selectedDay = 'Day 2 (May 21)';

  final List<String> _daysList = [
    'Day 1 (May 20)',
    'Day 2 (May 21)',
    'Day 3 (May 22)',
    'Day 4 (May 23)',
    'Day 5 (May 24)',
    'Day 6 (May 25)',
    'Day 7 (May 26)',
  ];

  final List<Map<String, dynamic>> _categories = [
    {'id': 'sightseeing', 'label': 'Sightseeing', 'icon': Icons.image_search_outlined, 'color': Color(0xFF0EA5E9)},
    {'id': 'food', 'label': 'Food', 'icon': Icons.restaurant_outlined, 'color': Color(0xFF20C060)},
    {'id': 'lodging', 'label': 'Lodging', 'icon': Icons.hotel_outlined, 'color': Color(0xFF9333EA)},
    {'id': 'transport', 'label': 'Transport', 'icon': Icons.flight_takeoff_outlined, 'color': Color(0xFFEA580C)},
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _locationController.dispose();
    _timeController.dispose();
    _costController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _saveEvent() {
    if (_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: const [
              Icon(Icons.check_circle_outline, color: Colors.white),
              SizedBox(width: 10),
              Text('Event successfully added to itinerary!'),
            ],
          ),
          backgroundColor: AppColors.secondary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
      Navigator.pop(context);
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
              _buildDayDropdown(),
              const SizedBox(height: 16),
              _buildInputField(
                controller: _timeController,
                label: 'Time',
                hint: 'e.g. 10:30 AM, 04:00 PM',
                icon: Icons.access_time_outlined,
                validator: (val) => val == null || val.isEmpty ? 'Time is required' : null,
              ),
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
      title: const Text(
        'Add Itinerary Event',
        style: TextStyle(
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

  Widget _buildDayDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
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
      child: DropdownButtonHideUnderline(
        child: DropdownButtonFormField<String>(
          value: _selectedDay,
          decoration: const InputDecoration(
            border: InputBorder.none,
            prefixIcon: Icon(Icons.calendar_today_outlined, color: AppColors.textSecondary, size: 18),
            labelText: 'Trip Day',
            labelStyle: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
          items: _daysList.map((String value) {
            return DropdownMenuItem<String>(
              value: value,
              child: Text(value),
            );
          }).toList(),
          onChanged: (newValue) {
            if (newValue != null) {
              setState(() {
                _selectedDay = newValue;
              });
            }
          },
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
        onPressed: _saveEvent,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: const Text(
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
