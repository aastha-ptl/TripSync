import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:tripsync/core/utils/image_utils.dart';

class TripOverviewScreen extends StatelessWidget {
  const TripOverviewScreen({super.key});

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
          'Trip Overview',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 17,
          ),
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        physics: const BouncingScrollPhysics(),
        children: [
          // Trip Title Card
          _buildTripSummaryCard(),
          const SizedBox(height: 20),

          // Statistics Grid
          const Text(
            'Key Stats',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 10),
          _buildStatsGrid(),
          const SizedBox(height: 24),

          // Completion Progress Bar Card
          const Text(
            'Itinerary Completion',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 10),
          _buildProgressCard(),
          const SizedBox(height: 24),

          // Budget Breakdown
          const Text(
            'Budget Breakdown (Rs. 1,50,000 Total)',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 10),
          _buildBudgetBreakdown(),
          const SizedBox(height: 24),

          // Stops Timeline
          const Text(
            'Destinations & Stops',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 10),
          _buildTimelineStops(),
        ],
      ),
    );
  }

  Widget _buildTripSummaryCard() {
    return Container(
      padding: const EdgeInsets.all(20),
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
      child: Row(
        children: [
          Container(
            height: 60,
            width: 60,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              image: DecorationImage(
                image: CachedNetworkImageProvider(ImageUtils.getOptimizedImageUrl('https://images.unsplash.com/photo-1502602898657-3e91760cbb34?w=400&auto=format&fit=crop&q=80')),
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Summer Europe Tour',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Paris • Lyon • Nice',
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFF64748B),
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'May 20 - May 27, 2026 (7 Days)',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.5,
      children: [
        _buildStatCard(
          icon: Icons.people_outline,
          title: 'Total Members',
          value: '8',
          color: const Color(0xFF3B82F6),
        ),
        _buildStatCard(
          icon: Icons.map_outlined,
          title: 'Destinations',
          value: '3 Stops',
          color: const Color(0xFF10B981),
        ),
        _buildStatCard(
          icon: Icons.account_balance_wallet_outlined,
          title: 'Amount Spent',
          value: 'Rs. 85,200',
          color: const Color(0xFFF59E0B),
        ),
        _buildStatCard(
          icon: Icons.folder_outlined,
          title: 'Total Files',
          value: '14 Docs',
          color: const Color(0xFFEC4899),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
              ),
              Icon(icon, color: color, size: 16),
            ],
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text(
                'Overall Completion',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              ),
              Text(
                '41% (5/12 Events)',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.primary),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: const LinearProgressIndicator(
              value: 5 / 12,
              minHeight: 10,
              backgroundColor: Color(0xFFEFF6FF),
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBudgetBreakdown() {
    final List<Map<String, dynamic>> items = [
      {
        'category': 'Accommodation',
        'spent': 36000,
        'color': const Color(0xFF3B82F6),
        'icon': Icons.hotel_outlined,
      },
      {
        'category': 'Transport & Flights',
        'spent': 28500,
        'color': const Color(0xFFF59E0B),
        'icon': Icons.flight_takeoff_outlined,
      },
      {
        'category': 'Food & Drinks',
        'spent': 14400,
        'color': const Color(0xFF10B981),
        'icon': Icons.restaurant_menu_outlined,
      },
      {
        'category': 'Sightseeing & Activities',
        'spent': 6300,
        'color': const Color(0xFF8B5CF6),
        'icon': Icons.local_activity_outlined,
      },
    ];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: items.map((item) {
          final double pct = item['spent'] / 150000;
          return Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(item['icon'], size: 16, color: item['color']),
                        const SizedBox(width: 8),
                        Text(
                          item['category'],
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF0F172A)),
                        ),
                      ],
                    ),
                    Text(
                      'Rs. ${item['spent']} (${(pct * 100).toInt()}%)',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: pct,
                    minHeight: 6,
                    backgroundColor: const Color(0xFFF1F5F9),
                    valueColor: AlwaysStoppedAnimation<Color>(item['color']),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTimelineStops() {
    final List<Map<String, String>> stops = [
      {
        'name': 'Paris (Stop 1)',
        'duration': '3 Days',
        'desc': 'Eiffel Tower, Louvre Museum, Seine Cruise',
        'status': 'Completed',
      },
      {
        'name': 'Lyon (Stop 2)',
        'duration': '2 Days',
        'desc': 'Old Town, Basilica of Fourvière, Local Cuisines',
        'status': 'Ongoing',
      },
      {
        'name': 'Nice (Stop 3)',
        'duration': '2 Days',
        'desc': 'French Riviera beaches, Promenade, Castle Hill',
        'status': 'Upcoming',
      },
    ];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: List.generate(stops.length, (idx) {
          final stop = stops[idx];
          final isCompleted = stop['status'] == 'Completed';
          final isOngoing = stop['status'] == 'Ongoing';
          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Timeline line & circle indicators
                Column(
                  children: [
                    Container(
                      height: 16,
                      width: 16,
                      decoration: BoxDecoration(
                        color: isCompleted
                            ? const Color(0xFF10B981)
                            : (isOngoing ? AppColors.primary : const Color(0xFF94A3B8)),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                    if (idx < stops.length - 1)
                      Expanded(
                        child: Container(
                          width: 2,
                          color: const Color(0xFFE2E8F0),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 14),
                // Contents
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              stop['name']!,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: isCompleted
                                    ? const Color(0xFFEFFDF5)
                                    : (isOngoing ? const Color(0xFFEFF6FF) : const Color(0xFFF1F5F9)),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                stop['status']!,
                                style: TextStyle(
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                  color: isCompleted
                                      ? const Color(0xFF10B981)
                                      : (isOngoing ? AppColors.primary : const Color(0xFF64748B)),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${stop['duration']} • ${stop['desc']}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}
