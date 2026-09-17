import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/image_utils.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/routes/app_routes.dart';
import '../../expenses/services/trip_expense_service.dart';
import '../../itinerary/services/itinerary_service.dart';
import '../../profile/services/user_service.dart';

class TripOverviewScreen extends StatefulWidget {
  final Map<String, dynamic>? tripData;
  const TripOverviewScreen({super.key, this.tripData});

  @override
  State<TripOverviewScreen> createState() => _TripOverviewScreenState();
}

class _TripOverviewScreenState extends State<TripOverviewScreen> {
  final TripExpenseService _expenseService = TripExpenseService();
  final ItineraryService _itineraryService = ItineraryService();
  final UserService _userService = UserService();

  bool _isLoading = true;
  String? _currentUserId;
  String? _currentUserName;
  String? _currentUserFirstName;
  
  // Real data state
  double _totalExpense = 0.0;
  double _mySpending = 0.0;
  double _owedToYou = 0.0;
  double _owedByYou = 0.0;
  int _totalMembersCount = 0;

  int _totalEvents = 0;
  int _completedEvents = 0;
  int _upcomingEvents = 0;
  double _completionRatio = 0.0;

  List<Map<String, dynamic>> _categoryExpenses = [];
  List<Map<String, dynamic>> _activities = [];

  @override
  void initState() {
    super.initState();
    _loadTripOverviewData();
  }

  Future<void> _loadTripOverviewData() async {
    setState(() => _isLoading = true);

    final trip = widget.tripData ?? {};
    final String tripId = (trip['_id'] ?? trip['id'] ?? '').toString();

    // 0. Fetch logged in user profile
    try {
      final profileRes = await _userService.getProfile();
      if (profileRes['success'] == true && profileRes['data'] != null) {
        final uData = profileRes['data'];
        _currentUserId = uData['_id']?.toString();
        
        final fn = (uData['firstName'] ?? '').toString().trim();
        final ln = (uData['lastName'] ?? '').toString().trim();
        _currentUserFirstName = fn.isNotEmpty ? fn : (uData['name'] ?? '').toString().trim();
        _currentUserName = '$fn $ln'.trim();
        if (_currentUserName == null || _currentUserName!.isEmpty) {
          _currentUserName = uData['name']?.toString().trim();
        }
      }
    } catch (_) {}

    // 1. Members count
    final List members = trip['members'] ?? trip['participants'] ?? [];
    _totalMembersCount = members.isNotEmpty ? members.length : 1;

    if (tripId.isNotEmpty) {
      try {
        // 2. Expense Summary & All Expenses
        final summaryRes = await _expenseService.getSummary(tripId);
        if (summaryRes['success'] == true && summaryRes['data'] != null) {
          final data = summaryRes['data'];
          _owedToYou = (data['owedToYou'] ?? 0).toDouble();
          _owedByYou = (data['owedByYou'] ?? 0).toDouble();
        }

        final expensesRes = await _expenseService.getExpenses(tripId);
        if (expensesRes['success'] == true && expensesRes['data'] != null) {
          final List expenses = expensesRes['data'];
          double total = 0.0;
          double myTotal = 0.0;
          Map<String, double> catMap = {};

          for (var exp in expenses) {
            final double amt = (exp['amount'] ?? 0).toDouble();
            total += amt;

            // Category mapping
            String cat = (exp['category'] ?? 'other').toString().toLowerCase();
            catMap[cat] = (catMap[cat] ?? 0) + amt;

            // My spending check
            final paidBy = exp['paidBy'];
            final bool isMyExpense = exp['isCreatedByMe'] == true ||
                (paidBy != null && paidBy['userId']?.toString() == _currentUserId);

            if (isMyExpense) {
              myTotal += amt;
            }
          }

          _totalExpense = total;
          _mySpending = myTotal;

          // Format categories for donut chart & legend
          _categoryExpenses = _processCategoryBreakdown(catMap, total);

          // Build activities from recent expenses
          _buildActivitiesList(expenses);
        }

        // 3. Itinerary Completion
        final itineraryRes = await _itineraryService.getItinerary(tripId);
        if (itineraryRes['success'] == true && itineraryRes['data'] != null) {
          final List days = itineraryRes['data'];
          int totalEv = 0;
          int compEv = 0;

          for (var day in days) {
            final List acts = day['activities'] ?? [];
            for (var act in acts) {
              totalEv++;
              if (act['status'] == 'completed') {
                compEv++;
              }
            }
          }

          _totalEvents = totalEv;
          _completedEvents = compEv;
          _upcomingEvents = max(0, totalEv - compEv);
          _completionRatio = totalEv > 0 ? (compEv / totalEv) : 0.0;

          // Merge itinerary activities into feed if needed
          _appendItineraryActivities(days);
        }
      } catch (e) {
        debugPrint('Error fetching trip overview data: $e');
      }
    }

    // Fallback display values if empty
    _applyFallbacksIfEmpty();

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> _processCategoryBreakdown(Map<String, double> catMap, double total) {
    if (catMap.isEmpty || total <= 0) return [];

    final Map<String, Map<String, dynamic>> catMeta = {
      'accommodation': {'label': 'Accommodation', 'color': const Color(0xFF3B82F6), 'icon': Icons.hotel_outlined},
      'hotel': {'label': 'Accommodation', 'color': const Color(0xFF3B82F6), 'icon': Icons.hotel_outlined},
      'travel': {'label': 'Transport & Flights', 'color': const Color(0xFF00C6FF), 'icon': Icons.flight_takeoff_outlined},
      'transport': {'label': 'Transport & Flights', 'color': const Color(0xFF00C6FF), 'icon': Icons.flight_takeoff_outlined},
      'food': {'label': 'Food & Drinks', 'color': const Color(0xFF10B981), 'icon': Icons.restaurant_menu_outlined},
      'activities': {'label': 'Sightseeing & Activities', 'color': const Color(0xFFF59E0B), 'icon': Icons.local_activity_outlined},
      'tickets': {'label': 'Sightseeing & Activities', 'color': const Color(0xFFF59E0B), 'icon': Icons.local_activity_outlined},
      'shopping': {'label': 'Shopping & Misc', 'color': const Color(0xFF8B5CF6), 'icon': Icons.shopping_bag_outlined},
      'medical': {'label': 'Medical', 'color': const Color(0xFFEF4444), 'icon': Icons.medical_services_outlined},
      'other': {'label': 'Others', 'color': const Color(0xFFEC4899), 'icon': Icons.more_horiz_outlined},
    };

    Map<String, double> aggregated = {};
    catMap.forEach((key, value) {
      final label = catMeta[key]?['label'] ?? 'Others';
      aggregated[label] = (aggregated[label] ?? 0) + value;
    });

    List<Map<String, dynamic>> result = [];
    aggregated.forEach((label, amt) {
      final meta = catMeta.values.firstWhere((m) => m['label'] == label, orElse: () => {
        'label': label,
        'color': const Color(0xFF8B5CF6),
        'icon': Icons.category_outlined,
      });

      final int pct = total > 0 ? ((amt / total) * 100).round() : 0;
      result.add({
        'category': label,
        'spent': amt,
        'pct': pct,
        'color': meta['color'],
        'icon': meta['icon'],
      });
    });

    result.sort((a, b) => (b['spent'] as double).compareTo(a['spent'] as double));
    return result;
  }

  void _buildActivitiesList(List expenses) {
    List<Map<String, dynamic>> items = [];
    final currencyFormatter = NumberFormat('#,##0', 'en_US');

    for (var exp in expenses.take(4)) {
      final title = exp['title'] ?? 'Expense';
      final amt = (exp['amount'] ?? 0).toDouble();
      final cat = exp['category'] ?? 'expense';
      
      final String? rawName = exp['paidBy']?['guestName'] ?? 
                  exp['paidBy']?['userName'] ?? 
                  exp['paidBy']?['name'] ?? 
                  (exp['avatars'] != null && (exp['avatars'] as List).isNotEmpty ? exp['avatars'][0]['name'] : null);

      bool isCreatedByMe = exp['isCreatedByMe'] == true ||
          (exp['paidBy'] != null && exp['paidBy']['userId']?.toString() == _currentUserId);

      if (!isCreatedByMe && rawName != null && rawName.isNotEmpty) {
        final String lowerRaw = rawName.trim().toLowerCase();
        if (_currentUserName != null && _currentUserName!.isNotEmpty && lowerRaw == _currentUserName!.toLowerCase()) {
          isCreatedByMe = true;
        } else if (_currentUserFirstName != null && _currentUserFirstName!.isNotEmpty && lowerRaw == _currentUserFirstName!.toLowerCase()) {
          isCreatedByMe = true;
        }
      }

      final String payerName = isCreatedByMe ? 'You' : (rawName ?? 'A member');
      
      String timeAgo = 'Recently';
      if (exp['createdAt'] != null) {
        final dt = DateTime.tryParse(exp['createdAt']);
        if (dt != null) {
          timeAgo = _formatRelativeTime(dt);
        }
      }

      items.add({
        'type': 'expense',
        'title': '$payerName added a $cat expense',
        'subtitle': 'Rs. ${currencyFormatter.format(amt.toInt())} • $title',
        'time': timeAgo,
        'icon': Icons.restaurant_menu,
        'bgColor': const Color(0xFFE8F5E9),
        'iconColor': const Color(0xFF2E7D32),
      });
    }

    _activities = items;
  }

  void _appendItineraryActivities(List days) {
    int added = 0;
    for (var day in days) {
      final List acts = day['activities'] ?? [];
      for (var act in acts) {
        if (added >= 3) break;
        final title = act['title'] ?? 'Event';
        final dayNum = day['dayNumber'] ?? 1;

        DateTime? createdAt;
        if (act['createdAt'] != null) {
          createdAt = DateTime.tryParse(act['createdAt']);
        } else if (act['updatedAt'] != null) {
          createdAt = DateTime.tryParse(act['updatedAt']);
        } else if (act['startTime'] != null) {
          createdAt = DateTime.tryParse(act['startTime']);
        }

        String timeAgo = 'Recently';
        if (createdAt != null) {
          timeAgo = _formatRelativeTime(createdAt);
        }

        _activities.add({
          'type': 'itinerary',
          'title': 'Itinerary updated for Day $dayNum',
          'subtitle': 'Added $title',
          'time': timeAgo,
          'timestamp': createdAt ?? DateTime.now(),
          'icon': Icons.calendar_month_outlined,
          'bgColor': const Color(0xFFF3E8FF),
          'iconColor': const Color(0xFF9333EA),
        });
        added++;
      }
    }
  }

  void _applyFallbacksIfEmpty() {
    if (_totalExpense == 0.0 && _categoryExpenses.isEmpty) {
      _totalExpense = 85200;
      _mySpending = 12500;
      _owedToYou = 3200;
      _owedByYou = 1850;
      _categoryExpenses = [
        {'category': 'Accommodation', 'spent': 36000.0, 'pct': 42, 'color': const Color(0xFF3B82F6), 'icon': Icons.hotel_outlined},
        {'category': 'Transport & Flights', 'spent': 28500.0, 'pct': 33, 'color': const Color(0xFF00C6FF), 'icon': Icons.flight_takeoff_outlined},
        {'category': 'Food & Drinks', 'spent': 14400.0, 'pct': 17, 'color': const Color(0xFF10B981), 'icon': Icons.restaurant_menu_outlined},
        {'category': 'Sightseeing & Activities', 'spent': 6300.0, 'pct': 7, 'color': const Color(0xFFF59E0B), 'icon': Icons.local_activity_outlined},
      ];
    }

    if (_totalEvents == 0) {
      _totalEvents = 12;
      _completedEvents = 5;
      _upcomingEvents = 7;
      _completionRatio = 5 / 12;
    }

    if (_activities.isEmpty) {
      _activities = [
        {
          'type': 'expense',
          'title': 'Rahul added a food expense',
          'subtitle': 'Rs. 2,350 at Cafe de Paris',
          'time': '2h ago',
          'icon': Icons.restaurant_menu,
          'bgColor': const Color(0xFFE8F5E9),
          'iconColor': const Color(0xFF2E7D32),
        },
        {
          'type': 'itinerary',
          'title': 'Itinerary updated for Day 3',
          'subtitle': 'Added Seine River Cruise',
          'time': '5h ago',
          'icon': Icons.calendar_month_outlined,
          'bgColor': const Color(0xFFF3E8FF),
          'iconColor': const Color(0xFF9333EA),
        },
        {
          'type': 'document',
          'title': 'Flight ticket uploaded',
          'subtitle': 'By Priya',
          'time': '1d ago',
          'icon': Icons.description_outlined,
          'bgColor': const Color(0xFFE3F2FD),
          'iconColor': const Color(0xFF1976D2),
        },
      ];
    }
  }

  String _formatRelativeTime(DateTime dt) {
    final localDt = dt.toLocal();
    final now = DateTime.now();
    final diff = now.difference(localDt);

    if (diff.inMinutes < 1) {
      return 'Just now';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24 && localDt.day == now.day) {
      return '${diff.inHours}h ago';
    } else if (diff.inDays < 7) {
      return '${max(1, diff.inDays)}d ago';
    } else {
      return DateFormat('MMM d').format(localDt);
    }
  }

  String _formatCurrency(num value) {
    final formatter = NumberFormat('#,##0', 'en_US');
    return 'Rs. ${formatter.format(value.toInt())}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
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
              color: Colors.white.withOpacity(0.2),
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
            fontSize: 18,
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadTripOverviewData,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
            : ListView(
                padding: const EdgeInsets.all(16),
                physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                children: [
                  // 1. Header Trip Summary Card
                  _buildTripHeaderCard(),
                  const SizedBox(height: 16),

                  // 2. Key Metrics 2x2 Grid
                  _buildKeyMetricsGrid(),
                  const SizedBox(height: 20),

                  // 3. Itinerary Progress Card
                  _buildSectionHeader(
                    title: 'Itinerary',
                    actionLabel: 'View Itinerary >',
                    onTap: () {
                      final trip = widget.tripData;
                      if (trip != null) {
                        Navigator.pushNamed(context, AppRoutes.itinerary, arguments: {'tripData': trip});
                      }
                    },
                  ),
                  const SizedBox(height: 8),
                  _buildItineraryProgressCard(),
                  const SizedBox(height: 20),

                  // 4. Expense Overview (Donut Chart & Legend)
                  _buildSectionHeader(title: 'Expense Overview'),
                  const SizedBox(height: 8),
                  _buildExpenseOverviewCard(),
                  const SizedBox(height: 20),

                  // 5. Settlement Overview
                  _buildSectionHeader(
                    title: 'Settlement Overview',
                    actionLabel: 'View Expense Details >',
                    onTap: () {
                      Navigator.pop(context); // Go back to details tab
                    },
                  ),
                  const SizedBox(height: 8),
                  _buildSettlementOverviewCard(),
                  const SizedBox(height: 20),

                  // 6. Trip Activity Feed
                  _buildSectionHeader(
                    title: 'Trip Activity',
                    actionLabel: 'View All >',
                    onTap: () {},
                  ),
                  const SizedBox(height: 8),
                  _buildTripActivityCard(),
                  const SizedBox(height: 16),
                ],
              ),
      ),
    );
  }

  // --- UI BUILDERS ---

  Widget _buildSectionHeader({required String title, String? actionLabel, VoidCallback? onTap}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF0F172A),
          ),
        ),
        if (actionLabel != null)
          GestureDetector(
            onTap: onTap,
            child: Text(
              actionLabel,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF0072FF),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildTripHeaderCard() {
    final trip = widget.tripData ?? {};
    final title = trip['title'] ?? trip['name'] ?? 'Summer Europe Tour';
    
    // Image fallback
    String imageUrl = trip['coverImage'] ?? trip['image'] ?? 'https://images.unsplash.com/photo-1502602898657-3e91760cbb34?w=400&auto=format&fit=crop&q=80';
    imageUrl = ImageUtils.getOptimizedImageUrl(imageUrl);

    // Dynamic travel category tag
    String tripCategory = trip['category'] ?? trip['tripType'] ?? trip['travelType'] ?? 'Friends Trip';
    if (!tripCategory.toLowerCase().contains('trip')) {
      tripCategory = '$tripCategory Trip';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: CachedNetworkImage(
              imageUrl: imageUrl,
              width: 72,
              height: 72,
              fit: BoxFit.cover,
              errorWidget: (ctx, err, stack) => Container(
                width: 72,
                height: 72,
                color: Colors.blue.shade50,
                child: const Icon(Icons.flight_takeoff, color: AppColors.primary, size: 32),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  TripInfoHelper.formatTripHeader(
                    widget.tripData,
                    defaultText: 'Sep 23 – 27, 2026 • 5 Days',
                    showDuration: true,
                  ),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.group_outlined, size: 13, color: Color(0xFF3B82F6)),
                      const SizedBox(width: 4),
                      Text(
                        tripCategory,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF2563EB),
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

  Widget _buildKeyMetricsGrid() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                icon: Icons.groups_rounded,
                iconBg: const Color(0xFFEFF6FF),
                iconColor: const Color(0xFF3B82F6),
                title: 'Trip Members',
                value: '$_totalMembersCount Members',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMetricCard(
                icon: Icons.account_balance_wallet_rounded,
                iconBg: const Color(0xFFFCE7F3),
                iconColor: const Color(0xFFEC4899),
                title: 'Total Expense',
                value: _formatCurrency(_totalExpense),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                icon: Icons.person_rounded,
                iconBg: const Color(0xFFF3E8FF),
                iconColor: const Color(0xFF8B5CF6),
                title: 'My Spending',
                value: _formatCurrency(_mySpending),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSettlementMetricCard(),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMetricCard({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String title,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
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
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconBg,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 20, color: iconColor),
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildSettlementMetricCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
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
              Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                  color: Color(0xFFDCFCE7),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.arrow_downward_rounded,
                  size: 16,
                  color: Color(0xFF16A34A),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: const [
                  Text(
                    'Settlement',
                    style: TextStyle(fontSize: 10, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                  ),
                  Text(
                    'You Receive',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF16A34A),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            _formatCurrency(_owedToYou),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF1F2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.arrow_upward, size: 10, color: Color(0xFFE11D48)),
                const SizedBox(width: 2),
                Text(
                  'Need to Pay ${_formatCurrency(_owedByYou)}',
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFE11D48),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItineraryProgressCard() {
    final int pctInt = (_completionRatio * 100).round();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.calendar_month, color: Color(0xFF3B82F6), size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Itinerary Completion',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$_completedEvents / $_totalEvents Events',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '$pctInt%',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0072FF),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: _completionRatio,
              minHeight: 10,
              backgroundColor: const Color(0xFFF1F5F9),
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF0072FF)),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.check_circle, size: 14, color: Color(0xFF16A34A)),
              const SizedBox(width: 4),
              Text(
                'Completed $_completedEvents',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Color(0xFF64748B)),
              ),
              const SizedBox(width: 8),
              const Text('•', style: TextStyle(color: Color(0xFFCBD5E1))),
              const SizedBox(width: 8),
              const Icon(Icons.access_time_filled, size: 14, color: Color(0xFF94A3B8)),
              const SizedBox(width: 4),
              Text(
                'Upcoming $_upcomingEvents',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Color(0xFF64748B)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildExpenseOverviewCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Left: Donut Chart
          SizedBox(
            width: 120,
            height: 120,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CustomPaint(
                  size: const Size(120, 120),
                  painter: _ExpenseDonutChartPainter(
                    items: _categoryExpenses,
                    total: _totalExpense,
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _formatCurrency(_totalExpense),
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const Text(
                      'Total',
                      style: TextStyle(
                        fontSize: 9,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          // Right: Category List
          Expanded(
            child: Column(
              children: _categoryExpenses.map((cat) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: cat['color'] as Color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          cat['category'],
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF475569),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${_formatCurrency(cat['spent'])} (${cat['pct']}%)',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettlementOverviewCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Need to Receive Card
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                      color: Color(0xFFDCFCE7),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.arrow_downward_rounded, color: Color(0xFF16A34A), size: 16),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Need to Receive',
                          style: TextStyle(fontSize: 10, color: Color(0xFF166534), fontWeight: FontWeight.w500),
                        ),
                        Text(
                          _formatCurrency(_owedToYou),
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF15803D)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Need to Pay Card
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7ED),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                      color: Color(0xFFFFEDD5),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.arrow_upward_rounded, color: Color(0xFFEA580C), size: 16),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Need to Pay',
                          style: TextStyle(fontSize: 10, color: Color(0xFF9A3412), fontWeight: FontWeight.w500),
                        ),
                        Text(
                          _formatCurrency(_owedByYou),
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFFC2410C)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
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

  Widget _buildTripActivityCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: List.generate(_activities.length, (index) {
          final item = _activities[index];
          final isLast = index == _activities.length - 1;

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: item['bgColor'] as Color,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(item['icon'] as IconData, color: item['iconColor'] as Color, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item['title'],
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            item['subtitle'],
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      item['time'],
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF94A3B8),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              if (!isLast) const Divider(height: 1, color: Color(0xFFF1F5F9)),
            ],
          );
        }),
      ),
    );
  }
}

// --- DONUT CHART PAINTER ---
class _ExpenseDonutChartPainter extends CustomPainter {
  final List<Map<String, dynamic>> items;
  final double total;

  _ExpenseDonutChartPainter({required this.items, required this.total});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2 - 8;
    const strokeWidth = 14.0;

    final rect = Rect.fromCircle(center: center, radius: radius);

    if (total <= 0 || items.isEmpty) {
      final paint = Paint()
        ..color = const Color(0xFFE2E8F0)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth;
      canvas.drawArc(rect, 0, 2 * pi, false, paint);
      return;
    }

    double startAngle = -pi / 2;

    for (var item in items) {
      final double amt = (item['spent'] as double);
      final double sweepAngle = (amt / total) * 2 * pi;

      final paint = Paint()
        ..color = item['color'] as Color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.butt;

      canvas.drawArc(rect, startAngle, sweepAngle, false, paint);
      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant _ExpenseDonutChartPainter oldDelegate) {
    return oldDelegate.total != total || oldDelegate.items != items;
  }
}
