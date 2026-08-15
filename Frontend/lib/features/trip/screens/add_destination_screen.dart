import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class AddDestinationScreen extends StatefulWidget {
  const AddDestinationScreen({super.key});

  @override
  State<AddDestinationScreen> createState() => _AddDestinationScreenState();
}

class _AddDestinationScreenState extends State<AddDestinationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _cityController = TextEditingController();
  final _datesController = TextEditingController();
  final _highlightController = TextEditingController();

  List<String> _highlights = [];
  String _selectedCoverUrl = 'https://images.unsplash.com/photo-1464822759023-fed622ff2c3b?w=400&auto=format&fit=crop&q=80';

  final List<String> _presetImages = [
    'https://images.unsplash.com/photo-1502602898657-3e91760cbb34?w=400&auto=format&fit=crop&q=80', // Paris
    'https://images.unsplash.com/photo-1509840841025-9088ba78a826?w=400&auto=format&fit=crop&q=80', // Lyon
    'https://images.unsplash.com/photo-1533105079780-92b9be482077?w=400&auto=format&fit=crop&q=80', // Nice
    'https://images.unsplash.com/photo-1534447677768-be436bb09401?w=400&auto=format&fit=crop&q=80', // General Travel
  ];

  void _addHighlight() {
    final text = _highlightController.text.trim();
    if (text.isNotEmpty && !_highlights.contains(text)) {
      setState(() {
        _highlights.add(text);
        _highlightController.clear();
      });
    }
  }

  void _removeHighlight(String text) {
    setState(() {
      _highlights.remove(text);
    });
  }

  void _saveDestination() {
    if (_formKey.currentState!.validate()) {
      Navigator.pop(context, {
        'city': _cityController.text.trim(),
        'dates': _datesController.text.trim().isNotEmpty ? _datesController.text.trim() : 'TBD',
        'image': _selectedCoverUrl,
        'highlights': _highlights.isNotEmpty ? _highlights : ['Sightseeing'],
        'weather': 'Sunny • 24°C',
        'lat': '48.8566',
        'lng': '2.3522',
      });
    }
  }

  void _pickFromSimulatedGallery() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        final List<String> galleryImages = [
          'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?w=400&auto=format&fit=crop&q=80',
          'https://images.unsplash.com/photo-1454496522488-7a8e488e8606?w=400&auto=format&fit=crop&q=80',
          'https://images.unsplash.com/photo-1469854523086-cc02fe5d8800?w=400&auto=format&fit=crop&q=80',
          'https://images.unsplash.com/photo-1533105079780-92b9be482077?w=400&auto=format&fit=crop&q=80',
          'https://images.unsplash.com/photo-1476514525535-07fb3b4ae5f1?w=400&auto=format&fit=crop&q=80',
          'https://images.unsplash.com/photo-1506744038136-46273834b3fb?w=400&auto=format&fit=crop&q=80',
        ];

        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Select from Mobile Gallery',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 1.2,
                ),
                itemCount: galleryImages.length,
                itemBuilder: (context, index) {
                  final img = galleryImages[index];
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedCoverUrl = img;
                      });
                      Navigator.pop(context);
                    },
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        img,
                        fit: BoxFit.cover,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF00C6FF), Color(0xFF0072FF)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ),
        title: const Text(
          'Add Destination',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 17,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Cover Selection header
              const Text(
                'Select Cover Photo',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 12),
              // Large Cover Preview
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Image.network(
                  _selectedCoverUrl,
                  height: 160,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    height: 160,
                    width: double.infinity,
                    color: Colors.grey[200],
                    child: const Icon(Icons.image, color: Colors.grey, size: 40),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Preset list selection with simulated mobile gallery button
              SizedBox(
                height: 64,
                child: Row(
                  children: [
                    // Simulated mobile gallery picker trigger
                    GestureDetector(
                      onTap: _pickFromSimulatedGallery,
                      child: Container(
                        width: 80,
                        height: 60,
                        margin: const EdgeInsets.only(right: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_photo_alternate_outlined, color: AppColors.primary, size: 20),
                            SizedBox(height: 4),
                            Text(
                              'Gallery',
                              style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: AppColors.primary),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _presetImages.length,
                        itemBuilder: (context, index) {
                          final imgUrl = _presetImages[index];
                          final isSelected = _selectedCoverUrl == imgUrl;
                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedCoverUrl = imgUrl;
                              });
                            },
                            child: Container(
                              margin: const EdgeInsets.only(right: 12),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected ? AppColors.primary : Colors.transparent,
                                  width: 2,
                                ),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Image.network(
                                  imgUrl,
                                  width: 80,
                                  height: 60,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // City Input
              const Text(
                'Destination Details',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _cityController,
                validator: (value) => value == null || value.trim().isEmpty ? 'Please enter a city' : null,
                decoration: InputDecoration(
                  labelText: 'City Name',
                  hintText: 'e.g. Marseille',
                  prefixIcon: const Icon(Icons.location_city, color: AppColors.primary),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Dates Input
              TextFormField(
                controller: _datesController,
                decoration: InputDecoration(
                  labelText: 'Travel Dates',
                  hintText: 'e.g. May 27 – May 29, 2026',
                  prefixIcon: const Icon(Icons.calendar_month, color: AppColors.primary),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Highlights Input
              const Text(
                'Landmark Highlights',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _highlightController,
                      decoration: InputDecoration(
                        hintText: 'Add highlight (e.g. Old Port)',
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                      ),
                      onFieldSubmitted: (_) => _addHighlight(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    height: 52,
                    width: 52,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.add, color: Colors.white),
                      onPressed: _addHighlight,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Highlights Chips display
              if (_highlights.isNotEmpty)
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _highlights.map((hl) {
                    return InputChip(
                      label: Text(hl, style: const TextStyle(fontSize: 12)),
                      onDeleted: () => _removeHighlight(hl),
                      deleteIconColor: AppColors.textSecondary,
                      backgroundColor: const Color(0xFFE2E8F0),
                    );
                  }).toList(),
                ),
              const SizedBox(height: 40),

              // Save Button
              Container(
                width: double.infinity,
                height: 54,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: AppColors.primary,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: _saveDestination,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text(
                    'Add Destination to Trip',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
