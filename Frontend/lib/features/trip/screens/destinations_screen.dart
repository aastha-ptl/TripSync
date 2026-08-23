import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/routes/app_routes.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:tripsync/core/utils/image_utils.dart';

import '../../../core/utils/date_formatter.dart';

class DestinationsScreen extends StatefulWidget {
  final Map<String, dynamic>? tripData;
  const DestinationsScreen({super.key, this.tripData});

  @override
  State<DestinationsScreen> createState() => _DestinationsScreenState();
}

class _DestinationsScreenState extends State<DestinationsScreen> {
  final List<Map<String, dynamic>> _destinations = [
    {
      'city': 'Paris',
      'dates': 'May 20 – May 23, 2026',
      'image': 'https://images.unsplash.com/photo-1502602898657-3e91760cbb34?w=400&auto=format&fit=crop&q=80',
      'highlights': ['Eiffel Tower', 'Louvre Museum', 'Seine Cruise'],
      'weather': 'Sunny • 24°C',
      'lat': '48.8566',
      'lng': '2.3522',
    },
    {
      'city': 'Lyon',
      'dates': 'May 23 – May 25, 2026',
      'image': 'https://images.unsplash.com/photo-1509840841025-9088ba78a826?w=400&auto=format&fit=crop&q=80',
      'highlights': ['Vieux Lyon', 'Basilica of Fourvière', 'Paul Bocuse Market'],
      'weather': 'Partly Cloudy • 22°C',
      'lat': '45.7640',
      'lng': '4.8357',
    },
    {
      'city': 'Nice',
      'dates': 'May 25 – May 27, 2026',
      'image': 'https://images.unsplash.com/photo-1533105079780-92b9be482077?w=400&auto=format&fit=crop&q=80',
      'highlights': ['Promenade des Anglais', 'Castle Hill', 'Old Town'],
      'weather': 'Clear • 26°C',
      'lat': '43.7102',
      'lng': '7.2620',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final newDest = await Navigator.pushNamed(context, AppRoutes.addDestination);
          if (newDest != null && newDest is Map<String, dynamic>) {
            setState(() {
              _destinations.add(newDest);
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('${newDest['city']} added successfully!'),
                backgroundColor: AppColors.secondary,
              ),
            );
          }
        },
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add_location_alt_outlined, color: Colors.white),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Unified Header
            Container(
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
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context),
                      behavior: HitTestBehavior.opaque,
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: CachedNetworkImage(imageUrl: ImageUtils.getOptimizedImageUrl('https://images.unsplash.com/photo-1502602898657-3e91760cbb34?w=150&auto=format&fit=crop&q=80'),
                              height: 48,
                              width: 48,
                              fit: BoxFit.cover,
                              errorWidget: (context, url, error) => Container(
                                height: 48,
                                width: 48,
                                color: Colors.grey[200],
                                child: const Icon(Icons.image, color: Colors.grey),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Destinations',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.calendar_today_outlined,
                                      size: 11,
                                      color: Color(0xFF64748B),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      TripInfoHelper.formatTripHeader(
                                        widget.tripData,
                                        defaultText: 'May 20 – May 27, 2025 • 3 Cities',
                                        showCities: true,
                                      ),
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
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: CircleAvatar(
                      radius: 20,
                      backgroundImage: CachedNetworkImageProvider(ImageUtils.getOptimizedImageUrl('https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=150&auto=format&fit=crop&q=80',)),
                    ),
                  ),
                ],
              ),
            ),
            // Destinations list
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _destinations.length,
                itemBuilder: (context, index) {
                  final dest = _destinations[index];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.02),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Card Cover Image
                        Stack(
                          children: [
                            ClipRRect(
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                              child: CachedNetworkImage(imageUrl: ImageUtils.getOptimizedImageUrl(dest['image']),
                                height: 160,
                                width: double.infinity,
                                fit: BoxFit.cover,
                                errorWidget: (context, url, error) => Container(
                                  height: 160,
                                  width: double.infinity,
                                  color: Colors.grey[200],
                                  child: const Icon(Icons.image, color: Colors.grey, size: 40),
                                ),
                              ),
                            ),
                            Positioned(
                              top: 12,
                              right: 12,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.6),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  dest['weather'],
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        // Details
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    dest['city'],
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFEFF6FF),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.calendar_month, size: 12, color: AppColors.primary),
                                        const SizedBox(width: 4),
                                        Text(
                                          dest['dates'],
                                          style: const TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.primary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'Key Highlights',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: (dest['highlights'] as List<String>).map((hl) {
                                  return Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      hl,
                                      style: const TextStyle(
                                        fontSize: 10,
                                        color: AppColors.textPrimary,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),

                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
