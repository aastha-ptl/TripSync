import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/theme/app_colors.dart';
import '../../profile/services/user_service.dart';
import '../../../core/widgets/custom_app_bar.dart';

class ExpenseScreen extends StatefulWidget {
  const ExpenseScreen({super.key});

  @override
  State<ExpenseScreen> createState() => _ExpenseScreenState();
}

class _ExpenseScreenState extends State<ExpenseScreen> {
  String _selectedTrip = 'All Trips';
  String _selectedCategory = 'All Categories';
  String _selectedMonth = 'This Month';

  bool _showAllTrips = false;
  bool _showAllNeedToPay = false;
  bool _showAllNeedsToPayYou = false;

  final List<Map<String, dynamic>> _tripDetailsData = [
    {
      'name': 'Paris Getaway',
      'date': 'May 20 - May 27, 2025',
      'total': '₹45,230',
      'totalSub': '35% of total',
      'mine': '₹18,400',
      'pay': '₹5,230',
      'receive': '₹2,150',
      'status': 'Active',
      'isActive': true,
    },
    {
      'name': 'Bali Adventure',
      'date': 'Jun 10 - Jun 18, 2025',
      'total': '₹38,450',
      'totalSub': '30% of total',
      'mine': '₹20,600',
      'pay': '₹3,850',
      'receive': '₹1,200',
      'status': 'Active',
      'isActive': true,
    },
    {
      'name': 'New York Trip',
      'date': 'Apr 05 - Apr 12, 2025',
      'total': '₹28,760',
      'totalSub': '22% of total',
      'mine': '₹12,300',
      'pay': '₹2,760',
      'receive': '₹1,450',
      'status': 'Completed',
      'isActive': false,
    },
    {
      'name': 'Switzerland Trip',
      'date': 'Mar 15 - Mar 22, 2025',
      'total': '₹15,340',
      'totalSub': '12% of total',
      'mine': '₹11,130',
      'pay': '₹910',
      'receive': '₹3,430',
      'status': 'Completed',
      'isActive': false,
    },
    {
      'name': 'Greece Escape',
      'date': 'Jul 12 - Jul 20, 2025',
      'total': '₹18,250',
      'totalSub': '14% of total',
      'mine': '₹10,500',
      'pay': '₹2,100',
      'receive': '₹3,200',
      'status': 'Completed',
      'isActive': false,
    },
    {
      'name': 'Dubai Trip',
      'date': 'Aug 18 - Aug 25, 2025',
      'total': '₹31,400',
      'totalSub': '24% of total',
      'mine': '₹15,800',
      'pay': '₹4,120',
      'receive': '₹1,850',
      'status': 'Completed',
      'isActive': false,
    },
  ];

  final List<Map<String, dynamic>> _needToPayData = [
    {'name': 'Aman Verma', 'amount': '₹6,200', 'color': Color(0xFFEF4444)},
    {'name': 'Pooja Shah', 'amount': '₹5,150', 'color': Color(0xFFEF4444)},
    {'name': 'Karan Joshi', 'amount': '₹4,200', 'color': Color(0xFFEF4444)},
    {'name': 'Rohan Das', 'amount': '₹2,100', 'color': Color(0xFFEF4444)},
    {'name': 'Sonia Sen', 'amount': '₹1,100', 'color': Color(0xFFEF4444)},
  ];

  final List<Map<String, dynamic>> _needsToPayYouData = [
    {'name': 'Rahul Sharma', 'amount': '₹4,250', 'color': Color(0xFF20C060)},
    {'name': 'Sneha Patel', 'amount': '₹3,180', 'color': Color(0xFF20C060)},
    {'name': 'Vivek Singh', 'amount': '₹2,300', 'color': Color(0xFF20C060)},
    {'name': 'Anjali Mehta', 'amount': '₹2,500', 'color': Color(0xFF20C060)},
    {'name': 'Kunal Sen', 'amount': '₹1,800', 'color': Color(0xFF20C060)},
    {'name': 'Riya Gupta', 'amount': '₹1,200', 'color': Color(0xFF20C060)},
  ];

  final UserService _userService = UserService();
  String? _profilePhotoUrl;

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  Future<void> _fetchProfile() async {
    final response = await _userService.getProfile();
    if (mounted && response['success'] == true) {
      setState(() {
        _profilePhotoUrl = response['data']['profilePhoto'];
      });
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
            ),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
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
              _showFilterOptions('Trips', ['All Trips', 'Paris Getaway', 'Bali Adventure'], (val) {
                setState(() => _selectedTrip = val);
              });
            },
          ),
          const SizedBox(width: 10),
          _buildFilterDropdown(
            icon: Icons.grid_view_outlined,
            label: _selectedCategory,
            onTap: () {
              _showFilterOptions('Categories', ['All Categories', 'Food', 'Transport'], (val) {
                setState(() => _selectedCategory = val);
              });
            },
          ),
          const SizedBox(width: 10),
          _buildFilterDropdown(
            icon: Icons.calendar_month_outlined,
            label: _selectedMonth,
            onTap: () {
              _showFilterOptions('Time', ['This Month', 'Last Month', 'Custom Range'], (val) {
                setState(() => _selectedMonth = val);
              });
            },
          ),
        ],
      ),
    );
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
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Select $title',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              ...options.map((opt) => ListTile(
                    title: Text(opt),
                    onTap: () {
                      onSelect(opt);
                      Navigator.pop(context);
                    },
                  )),
            ],
          ),
        );
      },
    );
  }

  // --- Summary Cards ---
  Widget _buildSummaryCards() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildSummaryCard(
                title: 'Total Expenses',
                value: '₹1,28,450',
                caption: 'All trips combined',
                icon: Icons.account_balance_wallet,
                accentColor: const Color(0xFF1E5AE6),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: _buildSummaryCard(
                title: 'My Spending',
                value: '₹62,430',
                caption: 'You have spent',
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
                value: '₹18,750',
                caption: 'You need to pay',
                icon: Icons.arrow_downward,
                accentColor: const Color(0xFFEF4444),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: _buildSummaryCard(
                title: 'Need to Receive',
                value: '₹12,230',
                caption: 'You will receive',
                icon: Icons.arrow_upward,
                accentColor: const Color(0xFFF59E0B),
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
        border: Border.all(color: accentColor.withOpacity(0.15), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: accentColor.withOpacity(0.06),
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
              color: accentColor.withOpacity(0.1),
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
          Text(
            value,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: accentColor,
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
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: const [
                  Text(
                    'This Month',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                  ),
                  SizedBox(width: 4),
                  Icon(Icons.keyboard_arrow_down, size: 14, color: AppColors.textSecondary),
                ],
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
                            sections: [
                              PieChartSectionData(color: const Color(0xFF1E5AE6), value: 32, radius: 30, showTitle: true, title: '32%', titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)),
                              PieChartSectionData(color: const Color(0xFF20C060), value: 20, radius: 30, showTitle: true, title: '20%', titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)),
                              PieChartSectionData(color: const Color(0xFFF59E0B), value: 15, radius: 30, showTitle: true, title: '15%', titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)),
                              PieChartSectionData(color: const Color(0xFFEF4444), value: 13, radius: 30, showTitle: true, title: '13%', titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)),
                              PieChartSectionData(color: const Color(0xFF8B5CF6), value: 10, radius: 30, showTitle: true, title: '10%', titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)),
                              PieChartSectionData(color: const Color(0xFF06B6D4), value: 6, radius: 30, showTitle: false),
                              PieChartSectionData(color: const Color(0xFFCBD5E1), value: 4, radius: 30, showTitle: false),
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
                              children: const [
                                Text(
                                  '₹1.28L',
                                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                                ),
                                Text(
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
                      children: [
                        _buildLegendItem(const Color(0xFF1E5AE6), 'Food & Dining', '₹41,020', '32%'),
                        _buildLegendItem(const Color(0xFF20C060), 'Accommodation', '₹25,680', '20%'),
                        _buildLegendItem(const Color(0xFFF59E0B), 'Transportation', '₹19,230', '15%'),
                        _buildLegendItem(const Color(0xFFEF4444), 'Activities', '₹16,670', '13%'),
                        _buildLegendItem(const Color(0xFF8B5CF6), 'Shopping', '₹12,820', '10%'),
                        _buildLegendItem(const Color(0xFF06B6D4), 'Tickets', '₹7,700', '6%'),
                        _buildLegendItem(const Color(0xFFCBD5E1), 'Others', '₹5,030', '4%'),
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
                      color: const Color(0xFFE8FDF0),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: const [
                        Icon(Icons.arrow_upward, size: 10, color: Color(0xFF20C060)),
                        SizedBox(width: 2),
                        Text(
                          '18.6%',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF20C060)),
                        ),
                        SizedBox(width: 4),
                        Text(
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
                      horizontalInterval: 10000,
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
                          interval: 10000,
                          getTitlesWidget: (value, meta) {
                            if (value == 0) return const Text('0', style: TextStyle(color: AppColors.textLight, fontSize: 10));
                            return Text('${(value / 1000).toInt()}K', style: const TextStyle(color: AppColors.textLight, fontSize: 10));
                          },
                          reservedSize: 28,
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, meta) {
                            switch (value.toInt()) {
                              case 0: return const Text('May', style: TextStyle(color: AppColors.textSecondary, fontSize: 11));
                              case 1: return const Text('Jun', style: TextStyle(color: AppColors.textSecondary, fontSize: 11));
                              case 2: return const Text('Jul', style: TextStyle(color: AppColors.textSecondary, fontSize: 11));
                              case 3: return const Text('Aug', style: TextStyle(color: AppColors.textSecondary, fontSize: 11));
                              case 4: return const Text('Sep', style: TextStyle(color: AppColors.textSecondary, fontSize: 11));
                              case 5: return const Text('Oct', style: TextStyle(color: AppColors.textSecondary, fontSize: 11));
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
                    maxY: 40000,
                    lineBarsData: [
                      LineChartBarData(
                        spots: const [
                          FlSpot(0, 18000),
                          FlSpot(1, 24000),
                          FlSpot(2, 20000),
                          FlSpot(3, 32000),
                          FlSpot(4, 22000),
                          FlSpot(5, 12000),
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
                              const Color(0xFF20C060).withOpacity(0.24),
                              const Color(0xFF20C060).withOpacity(0.0),
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
                      children: const [
                        Text(
                          'Average Expense / Month',
                          style: TextStyle(fontSize: 10, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                        ),
                        SizedBox(height: 2),
                        Text(
                          '₹21,333',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                        ),
                      ],
                    ),
                    const Spacer(),
                    SizedBox(
                      width: 80,
                      height: 24,
                      child: CustomPaint(
                        painter: SparklinePainter(
                          data: [18, 24, 20, 32, 22, 12],
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
  }) {
    return DataRow(
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

  Widget _buildPaymentSplitsSection() {
    final displayNeedToPay = _showAllNeedToPay ? _needToPayData : _needToPayData.take(3).toList();
    final displayNeedsToPayYou = _showAllNeedsToPayYou ? _needsToPayYouData : _needsToPayYouData.take(3).toList();

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
                  ...displayNeedToPay.map((item) => _buildSplitItem(item['name'], item['amount'], item['color'])),
                  const Divider(color: Color(0xFFF1F5F9), height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: const [
                      Text('Total to Pay', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
                      Text('₹18,750', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFFEF4444))),
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
                  ...displayNeedsToPayYou.map((item) => _buildSplitItem(item['name'], item['amount'], item['color'])),
                  const Divider(color: Color(0xFFF1F5F9), height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: const [
                      Text('Total to Receive', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
                      Text('₹12,230', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF20C060))),
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
    if (data.isEmpty) return;
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
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
