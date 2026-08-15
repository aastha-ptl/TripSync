import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class AddTripScreen extends StatefulWidget {
  const AddTripScreen({super.key});

  @override
  State<AddTripScreen> createState() => _AddTripScreenState();
}

class _AddTripScreenState extends State<AddTripScreen> {
  final _formKey = GlobalKey<FormState>();
  
  // Form controllers and states
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  
  DateTime? _startDate;
  DateTime? _endDate;
  String? _selectedTripType = 'Friends';
  bool _isUploadingPhoto = false;
  String? _selectedImagePath; // Simulated uploaded image path/name

  final List<String> _tripTypes = ['Friends', 'Family', 'Solo', 'Business', 'Couple'];

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  // Formatting date manually to avoid needing intl package
  String _formatDate(DateTime date) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${date.day.toString().padLeft(2, '0')} ${months[date.month - 1]} ${date.year}';
  }

  Future<void> _selectStartDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _startDate) {
      setState(() {
        _startDate = picked;
        // If end date is before start date, reset end date
        if (_endDate != null && _endDate!.isBefore(_startDate!)) {
          _endDate = null;
        }
      });
    }
  }

  Future<void> _selectEndDate(BuildContext context) async {
    if (_startDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a start date first'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? _startDate!.add(const Duration(days: 1)),
      firstDate: _startDate!,
      lastDate: _startDate!.add(const Duration(days: 365 * 2)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _endDate) {
      setState(() {
        _endDate = picked;
      });
    }
  }

  void _simulateUploadPhoto() {
    setState(() {
      _isUploadingPhoto = true;
    });
    // Simulate web/file API delay
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        setState(() {
          _isUploadingPhoto = false;
          _selectedImagePath = 'trip_cover_mockup.png';
        });
      }
    });
  }

  void _submitForm() {
    if (_formKey.currentState!.validate()) {
      if (_startDate == null || _endDate == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select both Start and End dates'),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }
      
      // Simulate success and navigation
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: Color(0xFFE6F7ED),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle,
                  color: AppColors.secondary,
                  size: 48,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Trip Created!',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Your new trip has been planned successfully.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context); // Pop dialog
                  Navigator.pop(context); // Pop AddTripScreen back to Dashboard
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Go to Home'),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Column(
          children: [
            _buildCustomHeader(context),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      // Trip Name Card
                      _buildFormCard(
                        icon: Icons.business_center,
                        iconBgColor: const Color(0xFFE8F8EE),
                        iconColor: AppColors.secondary,
                        label: 'Trip Name',
                        isRequired: true,
                        child: TextFormField(
                          controller: _nameController,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Enter trip name',
                            hintStyle: TextStyle(
                              fontSize: 14,
                              color: AppColors.textLight,
                              fontWeight: FontWeight.w500,
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFFEEF2F6), width: 1.5),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFFEEF2F6), width: 1.5),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                            ),
                            errorBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: AppColors.error, width: 1.5),
                            ),
                            focusedErrorBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: AppColors.error, width: 2),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Trip name is required';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Trip Description Card
                      _buildFormCard(
                        icon: Icons.description_outlined,
                        iconBgColor: const Color(0xFFF3E8FF),
                        iconColor: Colors.purple,
                        label: 'Trip Description',
                        isRequired: false,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            TextFormField(
                              controller: _descriptionController,
                              maxLines: 4,
                              maxLength: 500,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                              buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                              onChanged: (text) {
                                setState(() {});
                              },
                              decoration: InputDecoration(
                                hintText: 'Describe your trip, places, plans, and more...',
                                hintStyle: TextStyle(
                                  fontSize: 14,
                                  color: AppColors.textLight,
                                  fontWeight: FontWeight.w500,
                                ),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: Color(0xFFEEF2F6), width: 1.5),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: Color(0xFFEEF2F6), width: 1.5),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${_descriptionController.text.length}/500',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textLight,
                              ),
                            )
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Start Date Card
                      _buildFormCard(
                        icon: Icons.calendar_month,
                        iconBgColor: const Color(0xFFE8F0FE),
                        iconColor: AppColors.primary,
                        label: 'Start Date',
                        isRequired: true,
                        child: InkWell(
                          onTap: () => _selectStartDate(context),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFEEF2F6), width: 1.5),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  _startDate != null ? _formatDate(_startDate!) : 'Select start date',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: _startDate != null ? AppColors.textPrimary : AppColors.textLight,
                                  ),
                                ),
                                Icon(Icons.calendar_today_outlined, color: AppColors.textLight, size: 20),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // End Date Card
                      _buildFormCard(
                        icon: Icons.calendar_month,
                        iconBgColor: const Color(0xFFE8F0FE),
                        iconColor: AppColors.primary,
                        label: 'End Date',
                        isRequired: true,
                        child: InkWell(
                          onTap: () => _selectEndDate(context),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFEEF2F6), width: 1.5),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  _endDate != null ? _formatDate(_endDate!) : 'Select end date',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: _endDate != null ? AppColors.textPrimary : AppColors.textLight,
                                  ),
                                ),
                                Icon(Icons.calendar_today_outlined, color: AppColors.textLight, size: 20),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Cover Image Card
                      _buildFormCard(
                        icon: Icons.image_outlined,
                        iconBgColor: const Color(0xFFFEF3C7),
                        iconColor: Colors.amber[700]!,
                        label: 'Cover Image',
                        isRequired: false,
                        child: Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: const Color(0xFFD1D5DB),
                              style: BorderStyle.solid,
                              width: 1,
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              color: const Color(0xFFF9FAFB),
                              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  if (_selectedImagePath != null) ...[
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: AppColors.secondary.withOpacity(0.1),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.check,
                                        color: AppColors.secondary,
                                        size: 28,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    const Text(
                                      'Photo uploaded successfully!',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          _selectedImagePath = null;
                                        });
                                      },
                                      child: const Text(
                                        'Remove photo',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: AppColors.error,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ] else ...[
                                    const Icon(
                                      Icons.cloud_upload_outlined,
                                      color: AppColors.primary,
                                      size: 32,
                                    ),
                                    const SizedBox(height: 8),
                                    const Text(
                                      'Upload a photo for your trip',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    const Text(
                                      'JPG, PNG up to 5MB',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textLight,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    _isUploadingPhoto
                                        ? const SizedBox(
                                            height: 36,
                                            width: 36,
                                            child: CircularProgressIndicator(strokeWidth: 3),
                                          )
                                        : ElevatedButton(
                                            onPressed: _simulateUploadPhoto,
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: const Color(0xFFEFF6FF),
                                              foregroundColor: AppColors.primary,
                                              elevation: 0,
                                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(10),
                                                side: const BorderSide(color: Color(0xFFDBEAFE)),
                                              ),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: const [
                                                Icon(Icons.add, size: 16),
                                                SizedBox(width: 4),
                                                Text(
                                                  'Upload Photo',
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Trip Type Card
                      _buildFormCard(
                        icon: Icons.people_outline,
                        iconBgColor: const Color(0xFFECFDF5),
                        iconColor: const Color(0xFF059669),
                        label: 'Trip Type',
                        isRequired: false,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFEEF2F6), width: 1.5),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _selectedTripType,
                              isExpanded: true,
                              icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.textLight),
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                              onChanged: (String? newValue) {
                                setState(() {
                                  _selectedTripType = newValue;
                                });
                              },
                              items: _tripTypes.map<DropdownMenuItem<String>>((String value) {
                                return DropdownMenuItem<String>(
                                  value: value,
                                  child: Text(value),
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Create Trip Button
                      Container(
                        width: double.infinity,
                        height: 56,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          gradient: const LinearGradient(
                            colors: [
                              Color(0xFF1E5AE6),
                              Color(0xFF8B5CF6),
                            ],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF1E5AE6).withOpacity(0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: _submitForm,
                            borderRadius: BorderRadius.circular(16),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                Icon(Icons.send_rounded, color: Colors.white, size: 20),
                                SizedBox(width: 8),
                                Text(
                                  'Create Trip',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            Color(0xFF1E5AE6),
            Color(0xFF8B5CF6),
          ],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Color(0x331E5AE6),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Back Button
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              height: 40,
              width: 40,
              decoration: BoxDecoration(
                color: const Color(0x33FFFFFF),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0x4DFFFFFF)),
              ),
              child: const Icon(
                Icons.chevron_left,
                color: Colors.white,
                size: 24,
              ),
            ),
          ),
          const SizedBox(width: 16),
          // Titles
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Create New Trip',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Fill in the details to plan your trip',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
          // Illustration representation
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                height: 48,
                width: 48,
                decoration: BoxDecoration(
                  color: const Color(0x33FFFFFF),
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              const Icon(
                Icons.luggage,
                color: Colors.white,
                size: 26,
              ),
              Positioned(
                right: 4,
                top: 4,
                child: Icon(
                  Icons.send,
                  color: Colors.white70,
                  size: 14,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFormCard({
    required IconData icon,
    required Color iconBgColor,
    required Color iconColor,
    required String label,
    required bool isRequired,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconBgColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 12),
              RichText(
                text: TextSpan(
                  text: label,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                  children: [
                    if (isRequired)
                      const TextSpan(
                        text: ' *',
                        style: TextStyle(
                          color: AppColors.error,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}
