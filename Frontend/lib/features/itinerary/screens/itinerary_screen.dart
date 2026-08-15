import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/routes/app_routes.dart';

class ItineraryScreen extends StatefulWidget {
  const ItineraryScreen({super.key});

  @override
  State<ItineraryScreen> createState() => _ItineraryScreenState();
}

class _ItineraryScreenState extends State<ItineraryScreen> {
  int _selectedDayIndex = 1; // Default to Day 2 (where we have active/upcoming items)

  final List<Map<String, dynamic>> _days = [
    {'day': 'Day 1', 'date': 'May 20', 'label': 'Arrival & Check-in'},
    {'day': 'Day 2', 'date': 'May 21', 'label': 'Eiffel & Louvre'},
    {'day': 'Day 3', 'date': 'May 22', 'label': 'Seine Cruise'},
    {'day': 'Day 4', 'date': 'May 23', 'label': 'Versailles Palace'},
    {'day': 'Day 5', 'date': 'May 24', 'label': 'Champs-Élysées'},
    {'day': 'Day 6', 'date': 'May 25', 'label': 'Musée d\'Orsay'},
    {'day': 'Day 7', 'date': 'May 26', 'label': 'Departure'},
  ];

  final Map<int, List<Map<String, dynamic>>> _activities = {
    0: [
      {
        'time': '10:30 AM',
        'title': 'Arrival CDG Airport',
        'location': 'Charles de Gaulle Airport, Terminal 2E',
        'type': 'transport',
        'status': 'completed',
        'cost': 'Included',
        'notes': 'Group flight AF-023. Rahul to coordinate bags.',
      },
      {
        'time': '02:00 PM',
        'title': 'Check-in Le Bristol Hotel',
        'location': '112 Rue du Faubourg Saint-Honoré',
        'type': 'lodging',
        'status': 'completed',
        'cost': '€240/night',
        'notes': 'Booking ref: #BRISTOL-PARIS-2025. Standard rooms.',
      },
      {
        'time': '07:00 PM',
        'title': 'Dinner at Le Meurice',
        'location': '228 Rue de Rivoli, 75001 Paris',
        'type': 'food',
        'status': 'completed',
        'cost': '₹4,850',
        'notes': 'Michelin star fine dining. Dress code: Formal.',
      },
    ],
    1: [
      {
        'time': '09:00 AM',
        'title': 'Breakfast at Café de Flore',
        'location': '172 Boulevard Saint-Germain',
        'type': 'food',
        'status': 'completed',
        'cost': '€18',
        'notes': 'Famous historical cafe. Try the hot chocolate!',
      },
      {
        'time': '10:30 AM',
        'title': 'Eiffel Tower Tour',
        'location': 'Champ de Mars, Paris',
        'type': 'sightseeing',
        'status': 'active',
        'cost': '€29',
        'notes': 'Access to summit via elevator. Meet at North Pillar.',
      },
      {
        'time': '03:00 PM',
        'title': 'Louvre Museum Visit',
        'location': 'Rue de Rivoli, 75001 Paris',
        'type': 'sightseeing',
        'status': 'upcoming',
        'cost': '€22',
        'notes': 'Pre-booked ticket time-slot. Guides provided.',
      },
    ],
    2: [
      {
        'time': '11:00 AM',
        'title': 'Arc de Triomphe Tour',
        'location': 'Place Charles de Gaulle',
        'type': 'sightseeing',
        'status': 'upcoming',
        'cost': '€13',
        'notes': 'Climb up for top-down views of Champs-Élysées.',
      },
      {
        'time': '06:30 PM',
        'title': 'Seine River Evening Cruise',
        'location': 'Bateaux-Mouches, Port de la Conférence',
        'type': 'sightseeing',
        'status': 'upcoming',
        'cost': '€15',
        'notes': '1-hour sightseeing boat cruise with glass dome.',
      },
    ],
    3: [
      {
        'time': '10:00 AM',
        'title': 'Day trip to Palace of Versailles',
        'location': 'Place d\'Armes, 78000 Versailles',
        'type': 'sightseeing',
        'status': 'upcoming',
        'cost': '€27',
        'notes': 'Take RER C train from Paris city center.',
      },
    ],
    4: [
      {
        'time': '11:30 AM',
        'title': 'Shopping & Walk at Champs-Élysées',
        'location': 'Avenue des Champs-Élysées',
        'type': 'sightseeing',
        'status': 'upcoming',
        'cost': 'Free',
        'notes': 'Leisure walk, cafes and luxury shop browsing.',
      },
      {
        'time': '08:00 PM',
        'title': 'French Cuisine Tasting Dinner',
        'location': 'L\'Ambroisie, Place des Vosges',
        'type': 'food',
        'status': 'upcoming',
        'cost': '€90',
        'notes': 'Traditional French appetizers, wine, and dessert.',
      },
    ],
    5: [
      {
        'time': '10:00 AM',
        'title': 'Visit Musée d\'Orsay',
        'location': '1 Rue de la Légion d\'Honneur',
        'type': 'sightseeing',
        'status': 'upcoming',
        'cost': '€16',
        'notes': 'Impressionist art galleries in old railway station.',
      },
    ],
    6: [
      {
        'time': '12:00 PM',
        'title': 'Departure CDG Airport',
        'location': 'Charles de Gaulle Airport, Terminal 2E',
        'type': 'transport',
        'status': 'upcoming',
        'cost': 'Included',
        'notes': 'Flight AF-024 back home. Be at airport 3h early.',
      },
    ],
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          _buildDaySelector(),
          Expanded(
            child: _buildActivityTimeline(),
          ),
        ],
      ),
      floatingActionButton: _buildFAB(),
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
        children: const [
          Text(
            'Paris Getaway Itinerary',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 2),
          Text(
            'May 20 – May 27, 2025 • 7 Days',
            style: TextStyle(
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
        Navigator.pushNamed(context, AppRoutes.addEvent);
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
