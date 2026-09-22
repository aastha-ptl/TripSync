import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../profile/services/user_service.dart';
import '../../trip/services/trip_service.dart';
import '../services/trip_expense_service.dart';
import '../../../core/widgets/custom_app_bar.dart';
import '../../profile/screens/profile_screen.dart';
import 'trip_expense_screen.dart';

class ExpenseScreen extends StatefulWidget {
  final VoidCallback? onProfileTap;

  const ExpenseScreen({super.key, this.onProfileTap});

  @override
  State<ExpenseScreen> createState() => _ExpenseScreenState();
}

class _ExpenseScreenState extends State<ExpenseScreen> {
  String _selectedTrip = 'All Trips';
  String? _selectedTripId;
  String _selectedCategory = 'All Categories';
  String _selectedMonth = 'This Month';
  DateTime? _selectedStartDate;
  DateTime? _selectedEndDate;

  bool _showAllTrips = false;
  bool _showAllNeedToPay = false;
  bool _showAllNeedsToPayYou = false;

  bool _isLoading = true;

  // Trips dropdown options (Trip Name -> Trip ID)
  final Map<String, String> _tripNameToIdMap = {};
  List<String> _tripFilterOptions = ['All Trips'];

  // Display data from the User Expense API
  List<Map<String, dynamic>> _tripDetailsData = [];
  List<Map<String, dynamic>> _needToPayData = [];
  List<Map<String, dynamic>> _needsToPayYouData = [];

  double _totalExpensesAllTrips = 0.0;
  double _mySpendingAllTrips = 0.0;
  double _totalNeedToPay = 0.0;
  double _totalNeedToReceive = 0.0;

  List<Map<String, dynamic>> _categoryExpenses = [];

  // Trend chart state
  List<FlSpot> _trendSpots = [];
  List<String> _trendMonthLabels = [];
  double _trendMaxY = 10000;
  double _monthlyAverage = 0;
  double _trendPercentChange = 0;
  bool _trendIsUp = true;
  List<double> _sparklineData = [0, 0, 0, 0, 0, 0];

  final UserService _userService = UserService();
  final TripService _tripService = TripService();
  final TripExpenseService _expenseService = TripExpenseService();

  String? _profilePhotoUrl;
  String? _profileName;

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    await _fetchProfile();
    await _fetchUserTrips();
    await _fetchUserExpenseOverview();
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchProfile() async {
    try {
      final response = await _userService.getProfile();
      if (mounted && response['success'] == true && response['data'] != null) {
        final uData = response['data'];
        setState(() {
          _profilePhotoUrl = uData['profilePhoto'];
          if (uData['firstName'] != null) {
            _profileName = '${uData['firstName']} ${uData['lastName'] ?? ''}'.trim();
          } else {
            _profileName = uData['name'];
          }
        });
      }
    } catch (e) {
      debugPrint('[ExpenseScreen] Error fetching profile: $e');
    }
  }

  Future<void> _fetchUserTrips() async {
    try {
      final tripsRes = await _tripService.getTrips();
      if (tripsRes['success'] == true && tripsRes['data'] != null) {
        final List tripsList = tripsRes['data'];
        _tripNameToIdMap.clear();
        final List<String> options = ['All Trips'];

        for (var trip in tripsList) {
          final id = (trip['_id'] ?? trip['id'] ?? '').toString();
          String name = 'Trip';
          if (trip['name'] != null && trip['name'].toString().trim().isNotEmpty) {
            name = trip['name'].toString().trim();
          } else if (trip['title'] != null && trip['title'].toString().trim().isNotEmpty) {
            name = trip['title'].toString().trim();
          } else if (trip['destination'] != null) {
            if (trip['destination'] is Map && trip['destination']['name'] != null) {
              name = trip['destination']['name'].toString().trim();
            } else if (trip['destination'] is String && trip['destination'].toString().trim().isNotEmpty) {
              name = trip['destination'].toString().trim();
            }
          }
          if (id.isNotEmpty) {
            _tripNameToIdMap[name] = id;
            if (!options.contains(name)) {
              options.add(name);
            }
          }
        }

        if (mounted) {
          setState(() {
            _tripFilterOptions = options;
          });
        }
      }
    } catch (e) {
      debugPrint('[ExpenseScreen] Error fetching trips list: $e');
    }
  }

  Future<void> _fetchUserExpenseOverview() async {
    try {
      final currencyFormatter = NumberFormat('#,##0', 'en_US');
      final res = await _expenseService.getUserExpenseOverview(
        tripId: _selectedTripId,
        category: _selectedCategory != 'All Categories' ? _selectedCategory : null,
        timePeriod: _selectedMonth,
        startDate: _selectedStartDate != null ? DateFormat('yyyy-MM-dd').format(_selectedStartDate!) : null,
        endDate: _selectedEndDate != null ? DateFormat('yyyy-MM-dd').format(_selectedEndDate!) : null,
      );

      debugPrint('[ExpenseScreen] User overview response: $res');

      if (res['success'] == true && res['data'] != null) {
        final data = res['data'];

        // 1. Summary Cards
        final summary = data['summary'] ?? {};
        final totalExp = ((summary['totalExpenses'] ?? 0) as num).toDouble();
        final mySpend = ((summary['mySpending'] ?? 0) as num).toDouble();
        final needPay = ((summary['needToPay'] ?? 0) as num).toDouble();
        final needRec = ((summary['needToReceive'] ?? 0) as num).toDouble();

        // 2. Categories Breakdown
        final rawCats = data['categories'] as List? ?? [];
        final List<Map<String, dynamic>> cats = rawCats.map((c) {
          return {
            'category': c['category']?.toString() ?? 'Others',
            'spent': ((c['spent'] ?? 0) as num).toDouble(),
            'pct': ((c['percentage'] ?? 0) as num).round(),
            'color': _parseHexColor(c['color']),
            'icon': _parseIcon(c['icon']),
          };
        }).toList();

        // 3. Trend Graph & Sparkline
        final trend = data['trend'] ?? {};
        final monthlyTrend = trend['monthlyTrend'] as List? ?? [];
        final List<String> labels = [];
        final List<FlSpot> spots = [];
        double maxVal = 0;

        for (int i = 0; i < monthlyTrend.length; i++) {
          final item = monthlyTrend[i];
          labels.add(item['month']?.toString() ?? '');
          final double amt = ((item['amount'] ?? 0) as num).toDouble();
          if (amt > maxVal) maxVal = amt;
          spots.add(FlSpot(i.toDouble(), amt));
        }

        final rawSpark = trend['sparklineData'] as List? ?? [];
        List<double> sparkData = rawSpark.map((v) => (v as num).toDouble()).toList();
        if (sparkData.length < 2) sparkData = [0, 0, 0, 0, 0, 0];

        final double avg = ((trend['monthlyAverage'] ?? 0) as num).toDouble();
        final double pChange = ((trend['percentChange'] ?? 0) as num).toDouble();
        final bool isUp = trend['isUp'] == true;
        double chartMaxY = maxVal > 0 ? (((maxVal * 1.25) / 1000).ceil() * 1000.0) : 10000;
        if (chartMaxY < 1000) chartMaxY = 1000;

        // 4. Trip Wise Details Table
        final rawTrips = data['tripWiseDetails'] as List? ?? [];
        final List<Map<String, dynamic>> trips = rawTrips.map((t) {
          final userExp = ((t['userExpense'] ?? 0) as num).toDouble();
          final tripTotal = ((t['tripTotalExpense'] ?? 0) as num).toDouble();
          final mySpent = ((t['mySpending'] ?? 0) as num).toDouble();
          final pay = ((t['needToPay'] ?? 0) as num).toDouble();
          final rec = ((t['needToReceive'] ?? 0) as num).toDouble();

          return {
            'id': t['tripId']?.toString(),
            'name': t['tripName']?.toString() ?? 'Trip',
            'date': t['dateFormatted']?.toString() ?? '',
            'total': '₹${currencyFormatter.format(userExp.toInt())}',
            'totalSub': 'Trip Total: ₹${currencyFormatter.format(tripTotal.toInt())}',
            'mine': '₹${currencyFormatter.format(mySpent.toInt())}',
            'pay': '₹${currencyFormatter.format(pay.toInt())}',
            'receive': '₹${currencyFormatter.format(rec.toInt())}',
            'status': t['status']?.toString() ?? 'Active',
            'isActive': t['isActive'] == true,
            'rawTrip': t['rawTrip'],
          };
        }).toList();

        // 5. Payment Splits
        final splits = data['paymentSplits'] ?? {};
        final rawWhoPay = splits['whoYouNeedToPay'] as List? ?? [];
        final rawWhoRec = splits['whoNeedsToPayYou'] as List? ?? [];

        final List<Map<String, dynamic>> payList = rawWhoPay.map((p) => {
          'name': p['name']?.toString() ?? 'Member',
          'amount': '₹${currencyFormatter.format(((p['amount'] ?? 0) as num).toInt())}',
          'color': const Color(0xFFEF4444),
        }).toList();

        final List<Map<String, dynamic>> recList = rawWhoRec.map((p) => {
          'name': p['name']?.toString() ?? 'Member',
          'amount': '₹${currencyFormatter.format(((p['amount'] ?? 0) as num).toInt())}',
          'color': const Color(0xFF20C060),
        }).toList();

        if (mounted) {
          setState(() {
            _totalExpensesAllTrips = totalExp;
            _mySpendingAllTrips = mySpend;
            _totalNeedToPay = needPay;
            _totalNeedToReceive = needRec;
            _categoryExpenses = cats;
            _trendMonthLabels = labels;
            _trendSpots = spots;
            _sparklineData = sparkData;
            _monthlyAverage = avg;
            _trendPercentChange = pChange;
            _trendIsUp = isUp;
            _trendMaxY = chartMaxY;
            _tripDetailsData = trips;
            _needToPayData = payList;
            _needsToPayYouData = recList;
          });
        }
      }
    } catch (e, stack) {
      debugPrint('[ExpenseScreen] Error fetching user expense overview: $e\n$stack');
    }
  }

  Color _parseHexColor(dynamic hexStr) {
    if (hexStr is String && hexStr.startsWith('#')) {
      final hex = hexStr.replaceFirst('#', '');
      if (hex.length == 6) {
        return Color(int.parse('FF$hex', radix: 16));
      }
    }
    return const Color(0xFF1E5AE6);
  }

  IconData _parseIcon(dynamic iconStr) {
    switch (iconStr) {
      case 'hotel':
        return Icons.hotel_outlined;
      case 'flight_takeoff':
        return Icons.flight_takeoff_outlined;
      case 'restaurant':
        return Icons.restaurant_menu_outlined;
      case 'local_activity':
        return Icons.local_activity_outlined;
      case 'confirmation_number':
        return Icons.confirmation_number_outlined;
      case 'shopping_bag':
        return Icons.shopping_bag_outlined;
      case 'medical_services':
        return Icons.medical_services_outlined;
      default:
        return Icons.category_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Column(
          children: [
            CustomAppBar(
              title: 'Expense',
              profilePhotoUrl: _profilePhotoUrl,
              profileName: _profileName,
              onProfileTap: () {
                if (widget.onProfileTap != null) {
                  widget.onProfileTap!();
                } else {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ProfileScreen(),
                    ),
                  );
                }
              },
            ),
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1E5AE6)),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadAllData,
                      color: const Color(0xFF1E5AE6),
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 20),
                              _buildFilters(),
                              const SizedBox(height: 20),
                              _buildSummaryCards(),
                              const SizedBox(height: 28),
                              _buildExpenseOverviewSection(),
                              const SizedBox(height: 28),
                              _buildTripWiseDetailsSection(),
                              const SizedBox(height: 28),
                              _buildPaymentSplitsSection(),
                              const SizedBox(height: 32),
                            ],
                          ),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Filters ---
  Widget _buildFilters() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          _buildFilterDropdown(
            icon: Icons.card_membership_outlined,
            label: _selectedTrip,
            onTap: () {
              _showFilterOptions('Trips', _tripFilterOptions, (val) {
                setState(() {
                  _selectedTrip = val;
                  _selectedTripId = val == 'All Trips' ? null : _tripNameToIdMap[val];
                });
                _fetchUserExpenseOverview();
              });
            },
          ),
          const SizedBox(width: 10),
          _buildFilterDropdown(
            icon: Icons.grid_view_outlined,
            label: _selectedCategory,
            onTap: () {
              final categories = [
                'All Categories',
                'Accommodation',
                'Transportation',
                'Food & Dining',
                'Activities',
                'Tickets',
                'Shopping',
                'Medical',
                'Others',
              ];
              _showFilterOptions('Categories', categories, (val) {
                setState(() {
                  _selectedCategory = val;
                });
                _fetchUserExpenseOverview();
              });
            },
          ),
          const SizedBox(width: 10),
          _buildCalendarButton(),
        ],
      ),
    );
  }

  Widget _buildCalendarButton() {
    return GestureDetector(
      onTap: _showTimeFilterPicker,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFF1F5F9)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x04000000),
              blurRadius: 6,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: const Icon(Icons.calendar_month_outlined, size: 18, color: AppColors.textSecondary),
      ),
    );
  }

  void _showTimeFilterPicker() {
    _showFilterOptions('Time Period', ['This Month', 'Last Month', 'All Time', 'Custom Date Range'], (val) async {
      if (val == 'Custom Date Range') {
        final picked = await showDateRangePicker(
          context: context,
          firstDate: DateTime(2020),
          lastDate: DateTime(2035),
          initialDateRange: _selectedStartDate != null && _selectedEndDate != null
              ? DateTimeRange(start: _selectedStartDate!, end: _selectedEndDate!)
              : null,
          builder: (context, child) {
            return Theme(
              data: Theme.of(context).copyWith(
                colorScheme: const ColorScheme.light(
                  primary: Color(0xFF1E5AE6),
                  onPrimary: Colors.white,
                  onSurface: AppColors.textPrimary,
                ),
              ),
              child: child!,
            );
          },
        );
        if (picked != null) {
          setState(() {
            _selectedStartDate = picked.start;
            _selectedEndDate = picked.end;
            _selectedMonth = '${DateFormat('MMM d').format(picked.start)} - ${DateFormat('MMM d').format(picked.end)}';
          });
          _fetchUserExpenseOverview();
        }
      } else {
        setState(() {
          _selectedStartDate = null;
          _selectedEndDate = null;
          _selectedMonth = val;
        });
        _fetchUserExpenseOverview();
      }
    });
  }

  Widget _buildFilterDropdown({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFF1F5F9)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x04000000),
              blurRadius: 6,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: AppColors.textSecondary),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.keyboard_arrow_down, size: 16, color: AppColors.textLight),
          ],
        ),
      ),
    );
  }

  void _showFilterOptions(String title, List<String> options, Function(String) onSelect) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
                  child: Text(
                    'Select $title',
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                ),
                const Divider(color: Color(0xFFF1F5F9)),
                ...options.map((opt) {
                  final isSelected = opt == _selectedTrip || opt == _selectedCategory || opt == _selectedMonth;
                  return ListTile(
                    title: Text(
                      opt,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected ? const Color(0xFF1E5AE6) : AppColors.textPrimary,
                      ),
                    ),
                    trailing: isSelected ? const Icon(Icons.check, color: Color(0xFF1E5AE6), size: 20) : null,
                    onTap: () {
                      Navigator.pop(context);
                      onSelect(opt);
                    },
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  // --- Summary Cards ---
  Widget _buildSummaryCards() {
    final currencyFormatter = NumberFormat('#,##0', 'en_US');

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildSummaryCard(
                title: 'Total Expenses',
                value: '₹${currencyFormatter.format(_totalExpensesAllTrips.toInt())}',
                caption: _selectedTrip == 'All Trips' ? 'Your total share' : 'Your trip expense',
                icon: Icons.account_balance_wallet,
                accentColor: const Color(0xFF1E5AE6),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: _buildSummaryCard(
                title: 'My Spending',
                value: '₹${currencyFormatter.format(_mySpendingAllTrips.toInt())}',
                caption: 'You have paid',
                icon: Icons.credit_card_outlined,
                accentColor: const Color(0xFF20C060),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _buildSummaryCard(
                title: 'Need to Pay',
                value: '₹${currencyFormatter.format(_totalNeedToPay.toInt())}',
                caption: 'You need to pay',
                icon: Icons.arrow_upward,
                accentColor: const Color(0xFFEF4444),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: _buildSummaryCard(
                title: 'Need to Receive',
                value: '₹${currencyFormatter.format(_totalNeedToReceive.toInt())}',
                caption: 'You will receive',
                icon: Icons.arrow_downward,
                accentColor: const Color(0xFF20C060),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSummaryCard({
    required String title,
    required String value,
    required String caption,
    required IconData icon,
    required Color accentColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accentColor.withValues(alpha: 0.15), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: accentColor, size: 24),
          ),
          const SizedBox(height: 6),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 10,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: accentColor,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            caption,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 8.5,
              color: AppColors.textLight,
            ),
          ),
        ],
      ),
    );
  }

  // --- Expense Overview ---
  Widget _buildExpenseOverviewSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Expense Overview',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            GestureDetector(
              onTap: _showTimeFilterPicker,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    Text(
                      _selectedMonth,
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.keyboard_arrow_down, size: 14, color: AppColors.textSecondary),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        // Category Split
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFF1F5F9)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x04000000),
                blurRadius: 12,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Expense by Category',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Donut Chart
                  SizedBox(
                    height: 140,
                    width: 140,
                    child: Stack(
                      children: [
                        PieChart(
                          PieChartData(
                            sectionsSpace: 3,
                            centerSpaceRadius: 32,
                            startDegreeOffset: -90,
                            sections: _categoryExpenses.isNotEmpty
                                ? _categoryExpenses.map((c) {
                                    final double val = (c['spent'] as double);
                                    final int pct = c['pct'] as int;
                                    return PieChartSectionData(
                                      color: c['color'] as Color,
                                      value: val > 0 ? val : 1,
                                      radius: 30,
                                      showTitle: pct >= 5,
                                      title: '$pct%',
                                      titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                                    );
                                  }).toList()
                                : [
                                    PieChartSectionData(color: const Color(0xFFCBD5E1), value: 100, radius: 30, showTitle: false),
                                  ],
                          ),
                        ),
                        Center(
                          child: Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              border: Border.all(color: const Color(0xFFF1F5F9), width: 1.5),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x06000000),
                                  blurRadius: 4,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 4.0),
                                    child: Text(
                                      _totalExpensesAllTrips >= 100000
                                          ? '₹${(_totalExpensesAllTrips / 100000).toStringAsFixed(1)}L'
                                          : '₹${NumberFormat('#,##0', 'en_US').format(_totalExpensesAllTrips.toInt())}',
                                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                                    ),
                                  ),
                                ),
                                const Text(
                                  'Total',
                                  style: TextStyle(fontSize: 8, color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Legend
                  Expanded(
                    child: Column(
                      children: _categoryExpenses.isNotEmpty
                          ? _categoryExpenses.map((c) {
                              final currencyFormatter = NumberFormat('#,##0', 'en_US');
                              return _buildLegendItem(
                                c['color'] as Color,
                                c['category'].toString(),
                                '₹${currencyFormatter.format((c['spent'] as double).toInt())}',
                                '${c['pct']}%',
                              );
                            }).toList()
                          : [
                              _buildLegendItem(const Color(0xFFCBD5E1), 'No Expenses', '₹0', '0%'),
                            ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Trend Chart
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFF1F5F9)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x04000000),
                blurRadius: 12,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Expense Trend',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _trendIsUp ? const Color(0xFFE8FDF0) : const Color(0xFFFEE2E2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _trendIsUp ? Icons.arrow_upward : Icons.arrow_downward,
                          size: 10,
                          color: _trendIsUp ? const Color(0xFF20C060) : const Color(0xFFEF4444),
                        ),
                        const SizedBox(width: 2),
                        Text(
                          '${_trendPercentChange.toStringAsFixed(1)}%',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: _trendIsUp ? const Color(0xFF20C060) : const Color(0xFFEF4444),
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          'vs last month',
                          style: TextStyle(fontSize: 8, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 180,
                child: LineChart(
                  LineChartData(
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      horizontalInterval: (_trendMaxY / 4).clamp(100.0, double.infinity),
                      getDrawingHorizontalLine: (value) => FlLine(
                        color: const Color(0xFFF1F5F9),
                        strokeWidth: 1,
                      ),
                    ),
                    titlesData: FlTitlesData(
                      show: true,
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          interval: (_trendMaxY / 4).clamp(100.0, double.infinity),
                          getTitlesWidget: (value, meta) {
                            if (value == 0) return const Text('0', style: TextStyle(color: AppColors.textLight, fontSize: 10));
                            if (value >= 1000) {
                              return Text('${(value / 1000).toInt()}K', style: const TextStyle(color: AppColors.textLight, fontSize: 10));
                            }
                            return Text('${value.toInt()}', style: const TextStyle(color: AppColors.textLight, fontSize: 10));
                          },
                          reservedSize: 32,
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, meta) {
                            final idx = value.toInt();
                            if (idx >= 0 && idx < _trendMonthLabels.length) {
                              return Text(
                                _trendMonthLabels[idx],
                                style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                              );
                            }
                            return const Text('');
                          },
                          reservedSize: 20,
                        ),
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    minX: 0,
                    maxX: 5,
                    minY: 0,
                    maxY: _trendMaxY,
                    lineBarsData: [
                      LineChartBarData(
                        spots: _trendSpots.isNotEmpty
                            ? _trendSpots
                            : const [
                                FlSpot(0, 0),
                                FlSpot(1, 0),
                                FlSpot(2, 0),
                                FlSpot(3, 0),
                                FlSpot(4, 0),
                                FlSpot(5, 0),
                              ],
                        isCurved: true,
                        color: const Color(0xFF20C060),
                        barWidth: 3,
                        isStrokeCapRound: true,
                        dotData: FlDotData(
                          show: true,
                          getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                            radius: 4,
                            color: Colors.white,
                            strokeWidth: 3,
                            strokeColor: const Color(0xFF20C060),
                          ),
                        ),
                        belowBarData: BarAreaData(
                          show: true,
                          gradient: LinearGradient(
                            colors: [
                              const Color(0xFF20C060).withValues(alpha: 0.24),
                              const Color(0xFF20C060).withValues(alpha: 0.0),
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Sparkline stats
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: const Icon(Icons.trending_up, color: Color(0xFF20C060), size: 16),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Average Expense / Month',
                          style: TextStyle(fontSize: 10, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '₹${NumberFormat('#,##0', 'en_US').format(_monthlyAverage.toInt())}',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                        ),
                      ],
                    ),
                    const Spacer(),
                    SizedBox(
                      width: 80,
                      height: 24,
                      child: CustomPaint(
                        painter: SparklinePainter(
                          data: _sparklineData,
                          color: const Color(0xFF20C060),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLegendItem(Color color, String name, String amount, String percent) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Row(
        children: [
          Container(
            height: 7,
            width: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              name,
              style: const TextStyle(fontSize: 10, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Flexible(
            child: Text(
              amount,
              style: const TextStyle(fontSize: 10, color: AppColors.textPrimary, fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 24,
            child: Text(
              percent,
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 9, color: AppColors.textLight),
            ),
          ),
        ],
      ),
    );
  }

  // --- Trip Wise Details ---
  Widget _buildTripWiseDetailsSection() {
    final displayTrips = _showAllTrips ? _tripDetailsData : _tripDetailsData.take(3).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Trip Wise Details',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
            if (_tripDetailsData.length > 3)
              TextButton(
                onPressed: () {
                  setState(() {
                    _showAllTrips = !_showAllTrips;
                  });
                },
                child: Text(
                  _showAllTrips ? 'Show Less' : 'View All',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1E5AE6)),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        if (_tripDetailsData.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFF1F5F9)),
            ),
            child: Column(
              children: const [
                Icon(Icons.flight_takeoff, size: 36, color: AppColors.textLight),
                SizedBox(height: 8),
                Text('No trips found', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                SizedBox(height: 4),
                Text('Create or join a trip to track expenses', style: TextStyle(fontSize: 11, color: AppColors.textLight)),
              ],
            ),
          )
        else
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFF1F5F9)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x04000000),
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                showCheckboxColumn: false,
                columnSpacing: 20,
                horizontalMargin: 16,
                headingRowHeight: 40,
                dataRowMinHeight: 52,
                dataRowMaxHeight: 56,
                columns: const [
                  DataColumn(label: Text('Trip', style: TextStyle(fontSize: 10, color: AppColors.textLight, fontWeight: FontWeight.w600))),
                  DataColumn(label: Text('Total Expense', style: TextStyle(fontSize: 10, color: AppColors.textLight, fontWeight: FontWeight.w600))),
                  DataColumn(label: Text('My Spending', style: TextStyle(fontSize: 10, color: AppColors.textLight, fontWeight: FontWeight.w600))),
                  DataColumn(label: Text('Need to Pay', style: TextStyle(fontSize: 10, color: AppColors.textLight, fontWeight: FontWeight.w600))),
                  DataColumn(label: Text('Need to Receive', style: TextStyle(fontSize: 10, color: AppColors.textLight, fontWeight: FontWeight.w600))),
                  DataColumn(label: Text('Status', style: TextStyle(fontSize: 10, color: AppColors.textLight, fontWeight: FontWeight.w600))),
                  DataColumn(label: Text('', style: TextStyle(fontSize: 10, color: AppColors.textLight, fontWeight: FontWeight.w600))),
                ],
                rows: displayTrips.map((trip) {
                  return _buildTripRow(
                    name: trip['name'],
                    date: trip['date'],
                    total: trip['total'],
                    totalSub: trip['totalSub'],
                    mine: trip['mine'],
                    pay: trip['pay'],
                    receive: trip['receive'],
                    status: trip['status'],
                    isActive: trip['isActive'],
                    onTap: () {
                      if (trip['rawTrip'] != null) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => TripExpenseScreen(
                              tripData: trip['rawTrip'],
                              profilePhotoUrl: _profilePhotoUrl,
                              profileName: _profileName,
                            ),
                          ),
                        ).then((_) => _loadAllData());
                      }
                    },
                  );
                }).toList(),
              ),
            ),
          ),
      ],
    );
  }

  DataRow _buildTripRow({
    required String name,
    required String date,
    required String total,
    required String totalSub,
    required String mine,
    required String pay,
    required String receive,
    required String status,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return DataRow(
      onSelectChanged: (_) => onTap(),
      cells: [
        DataCell(
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              Text(date, style: const TextStyle(fontSize: 9, color: AppColors.textLight)),
            ],
          ),
        ),
        DataCell(
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(total, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              Text(totalSub, style: const TextStyle(fontSize: 9, color: AppColors.textLight)),
            ],
          ),
        ),
        DataCell(Text(mine, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF20C060)))),
        DataCell(Text(pay, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFFEF4444)))),
        DataCell(Text(receive, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFFF59E0B)))),
        DataCell(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isActive ? const Color(0xFFE8FDF0) : const Color(0xFFE8F0FE),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              status,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: isActive ? const Color(0xFF20C060) : const Color(0xFF1E5AE6),
              ),
            ),
          ),
        ),
        const DataCell(Icon(Icons.chevron_right, size: 16, color: AppColors.textLight)),
      ],
    );
  }

  // --- Payment Splits ---
  Widget _buildPaymentSplitsSection() {
    final displayNeedToPay = _showAllNeedToPay ? _needToPayData : _needToPayData.take(3).toList();
    final displayNeedsToPayYou = _showAllNeedsToPayYou ? _needsToPayYouData : _needsToPayYouData.take(3).toList();
    final currencyFormatter = NumberFormat('#,##0', 'en_US');

    return Column(
      children: [
        // Who You Need to Pay
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Who You Need to Pay', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                if (_needToPayData.length > 3)
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _showAllNeedToPay = !_showAllNeedToPay;
                      });
                    },
                    child: Text(
                      _showAllNeedToPay ? 'Show Less' : 'View All',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF1E5AE6)),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFF1F5F9)),
              ),
              child: Column(
                children: [
                  if (displayNeedToPay.isNotEmpty)
                    ...displayNeedToPay.map((item) => _buildSplitItem(item['name'], item['amount'], item['color']))
                  else
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8.0),
                      child: Text('No pending payments', style: TextStyle(fontSize: 11, color: AppColors.textLight)),
                    ),
                  const Divider(color: Color(0xFFF1F5F9), height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total to Pay', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
                      Text('₹${currencyFormatter.format(_totalNeedToPay.toInt())}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFFEF4444))),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        // Who Needs to Pay You
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Who Needs to Pay You', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                if (_needsToPayYouData.length > 3)
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _showAllNeedsToPayYou = !_showAllNeedsToPayYou;
                      });
                    },
                    child: Text(
                      _showAllNeedsToPayYou ? 'Show Less' : 'View All',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF1E5AE6)),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFF1F5F9)),
              ),
              child: Column(
                children: [
                  if (displayNeedsToPayYou.isNotEmpty)
                    ...displayNeedsToPayYou.map((item) => _buildSplitItem(item['name'], item['amount'], item['color']))
                  else
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8.0),
                      child: Text('No pending receivables', style: TextStyle(fontSize: 11, color: AppColors.textLight)),
                    ),
                  const Divider(color: Color(0xFFF1F5F9), height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total to Receive', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
                      Text('₹${currencyFormatter.format(_totalNeedToReceive.toInt())}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF20C060))),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSplitItem(String name, String amount, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(name, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
          Text(amount, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }
}

// --- Sparkline Painter ---
class SparklinePainter extends CustomPainter {
  final List<double> data;
  final Color color;

  SparklinePainter({required this.data, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty || data.length < 2) return;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    final path = Path();
    final double stepX = size.width / (data.length - 1);
    final double max = data.reduce((a, b) => a > b ? a : b);
    final double min = data.reduce((a, b) => a < b ? a : b);
    final double range = (max - min) == 0 ? 1 : (max - min);

    for (int i = 0; i < data.length; i++) {
      final x = i * stepX;
      final y = size.height - ((data[i] - min) / range * size.height * 0.7 + size.height * 0.15);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant SparklinePainter oldDelegate) {
    return oldDelegate.data != data || oldDelegate.color != color;
  }
}
