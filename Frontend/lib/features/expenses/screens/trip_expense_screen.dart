import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:tripsync/core/utils/image_utils.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/utils/date_formatter.dart';
import '../../profile/screens/profile_screen.dart';
import '../services/trip_expense_service.dart';
import 'trip_expense_create_screen.dart';
import 'trip_expense_detail_screen.dart';
import 'trip_expense_person_balance_screen.dart';

class TripExpenseScreen extends StatefulWidget {
  final Map<String, dynamic>? tripData;
  final String? profilePhotoUrl;
  final String? profileName;
  final VoidCallback? onBack;

  const TripExpenseScreen({
    super.key,
    this.tripData,
    this.profilePhotoUrl,
    this.profileName,
    this.onBack,
  });

  @override
  State<TripExpenseScreen> createState() => _TripExpenseScreenState();
}

class _TripExpenseScreenState extends State<TripExpenseScreen> {
  final TripExpenseService _expenseService = TripExpenseService();

  int _selectedTabIndex = 0; // 0 = Splits, 1 = Expenses
  bool _isLoading = true;

  // Family Leader Dropdown
  bool _isFamilyLeader = false;
  List<Map<String, dynamic>> _myFamilyMembers = [];
  String? _actingAsGuestId; // null = myself, or guestId
  String _actingAsName = 'Myself';

  // Summary
  double _owedByYou = 0.0;
  double _owedToYou = 0.0;

  // Splits tab data
  List<Map<String, dynamic>> _myExpenses = [];
  final ScrollController _splitsScrollController = ScrollController();

  // Expenses tab data (Balances)
  List<Map<String, dynamic>> _owedByYouList = [];
  List<Map<String, dynamic>> _owedToYouList = [];
  List<Map<String, dynamic>> _settledList = [];

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    _splitsScrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom({bool animate = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_splitsScrollController.hasClients) {
        final target = _splitsScrollController.position.maxScrollExtent;
        if (animate) {
          _splitsScrollController.animateTo(
            target,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        } else {
          _splitsScrollController.jumpTo(target);
        }
      }
    });
  }

  Future<void> _loadInitialData() async {
    final tripId = widget.tripData?['_id'];
    if (tripId == null) {
      setState(() => _isLoading = false);
      return;
    }

    // Load members and check family leader status
    final membersRes = await _expenseService.getMembers(tripId);
    if (membersRes['success'] == true && mounted) {
      final data = membersRes['data'];
      _isFamilyLeader = data['isFamilyLeader'] == true;
      final rawFamily = data['myNonAppFamilyMembers'] as List? ?? [];
      _myFamilyMembers = rawFamily.cast<Map<String, dynamic>>();
    }

    await _fetchAllData();
  }

  Future<void> _fetchAllData() async {
    final tripId = widget.tripData?['_id'];
    if (tripId == null) return;

    final summaryFuture = _expenseService.getSummary(tripId, actingAsGuestId: _actingAsGuestId);
    final expensesFuture = _expenseService.getExpenses(tripId, actingAsGuestId: _actingAsGuestId);
    final balancesFuture = _expenseService.getBalances(tripId, actingAsGuestId: _actingAsGuestId);

    final results = await Future.wait([summaryFuture, expensesFuture, balancesFuture]);

    if (mounted) {
      final summaryRes = results[0];
      final expensesRes = results[1];
      final balancesRes = results[2];

      setState(() {
        if (balancesRes['success'] == true) {
          final bData = balancesRes['data'];
          _owedByYouList = (bData['owedByYou'] as List).cast<Map<String, dynamic>>();
          _owedToYouList = (bData['owedToYou'] as List).cast<Map<String, dynamic>>();
          _settledList = (bData['settled'] as List).cast<Map<String, dynamic>>();

          // Calculate netted settle-up values (+ / -)
          _owedByYou = _owedByYouList.fold<double>(
            0.0,
            (sum, p) => sum + ((p['amount'] as num?)?.toDouble() ?? 0.0),
          );
          _owedToYou = _owedToYouList.fold<double>(
            0.0,
            (sum, p) => sum + ((p['amount'] as num?)?.toDouble() ?? 0.0),
          );
        } else if (summaryRes['success'] == true) {
          final sData = summaryRes['data'];
          _owedByYou = (sData['owedByYou'] as num?)?.toDouble() ?? 0.0;
          _owedToYou = (sData['owedToYou'] as num?)?.toDouble() ?? 0.0;
        }

        if (expensesRes['success'] == true) {
          _myExpenses = (expensesRes['data'] as List).cast<Map<String, dynamic>>();
        }

        _isLoading = false;
      });

      _scrollToBottom();
    }
  }

  void _openCreateExpense() async {
    final res = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => TripExpenseCreateScreen(tripData: widget.tripData),
      ),
    );
    if (res == true) {
      await _fetchAllData();
      _scrollToBottom(animate: true);
    }
  }

  void _openDetail(String expenseId) async {
    final tripId = widget.tripData?['_id'];
    if (tripId == null) return;

    final res = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => TripExpenseDetailScreen(
          tripId: tripId,
          expenseId: expenseId,
          actingAsGuestId: _actingAsGuestId,
        ),
      ),
    );
    if (res == true) {
      _fetchAllData();
    }
  }

  void _openPersonBalance(Map<String, dynamic> person) async {
    final tripId = widget.tripData?['_id'];
    if (tripId == null) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TripExpensePersonBalanceScreen(
          tripId: tripId,
          targetId: person['id'],
          isGuest: person['isGuest'] == true,
          actingAsGuestId: _actingAsGuestId,
        ),
      ),
    );
    _fetchAllData();
  }

  Future<void> _quickPayExpense(Map<String, dynamic> expense) async {
    final tripId = widget.tripData?['_id'];
    if (tripId == null) return;

    final myPartId = expense['myParticipantId'];
    if (myPartId == null) return;

    final res = await _expenseService.settleParticipant(
      tripId,
      expense['_id'],
      participantId: myPartId,
    );

    if (!mounted) return;
    if (res['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Payment marked as settled!'),
          backgroundColor: Color(0xFF16A34A),
        ),
      );
      _fetchAllData();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['message'] ?? 'Failed to settle'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Future<void> _downloadExpensePdf() async {
    final tripId = widget.tripData?['_id'];
    if (tripId == null) return;

    final tripTitle = widget.tripData?['title'] ?? 'Trip';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Downloading expense report for $tripTitle...'),
        backgroundColor: const Color(0xFF1E5AE6),
        duration: const Duration(seconds: 2),
      ),
    );

    try {
      final downloadUrl = await _expenseService.getPdfReportUrl(
        tripId,
        actingAsGuestId: _actingAsGuestId,
      );
      final uri = Uri.parse(downloadUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(uri);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to open download link: $e'),
          backgroundColor: Colors.redAccent,
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
            _buildTopHeader(),
            _buildTopTabBar(),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF1E5AE6)))
                  : (_selectedTabIndex == 0 ? _buildSplitsTab() : _buildExpensesTab()),
            ),
          ],
        ),
      ),
    );
  }

  // Top Header (identical to Documents, Users, and Activity tabs)
  Widget _buildTopHeader() {
    return Container(
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
              onTap: widget.onBack ?? () => Navigator.pop(context),
              behavior: HitTestBehavior.opaque,
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: widget.tripData != null && widget.tripData!['imageUrl'] != null
                        ? CachedNetworkImage(
                            imageUrl: ImageUtils.getOptimizedImageUrl(widget.tripData!['imageUrl']),
                            height: 48,
                            width: 48,
                            fit: BoxFit.cover,
                            errorWidget: (context, url, error) => Container(
                              height: 48,
                              width: 48,
                              color: Colors.grey[200],
                              child: const Icon(Icons.image, color: Colors.grey),
                            ),
                          )
                        : CachedNetworkImage(
                            imageUrl: ImageUtils.getOptimizedImageUrl(
                              'https://images.unsplash.com/photo-1502602898657-3e91760cbb34?w=150&auto=format&fit=crop&q=80',
                            ),
                            height: 48,
                            width: 48,
                            fit: BoxFit.cover,
                          ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text(
                              'Expenses',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            if (_actingAsGuestId != null) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEFF6FF),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0xFFBFDBFE)),
                                ),
                                child: Text(
                                  _actingAsName,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: Color(0xFF1E5AE6),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ],
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
                            Expanded(
                              child: Text(
                                TripInfoHelper.formatTripHeader(
                                  widget.tripData,
                                  defaultText: 'May 20 – May 27, 2025 • 8 Members',
                                  showMembers: true,
                                ),
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF64748B),
                                  fontWeight: FontWeight.w500,
                                ),
                                overflow: TextOverflow.ellipsis,
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

          // Family Leader Switcher Dropdown (if leader)
          if (_isFamilyLeader && _myFamilyMembers.isNotEmpty) ...[
            PopupMenuButton<String>(
              icon: Container(
                padding: const EdgeInsets.all(7),
                decoration: const BoxDecoration(
                  color: Color(0xFFEFF6FF),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.switch_account, color: Color(0xFF1E5AE6), size: 18),
              ),
              color: Colors.white,
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              onSelected: (val) {
                setState(() {
                  if (val == 'myself') {
                    _actingAsGuestId = null;
                    _actingAsName = 'Myself';
                  } else {
                    _actingAsGuestId = val;
                    final member = _myFamilyMembers.firstWhere((m) => m['id'] == val);
                    _actingAsName = member['name'];
                  }
                  _isLoading = true;
                });
                _fetchAllData();
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'myself',
                  child: Text('Myself', style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.w500)),
                ),
                ..._myFamilyMembers.map((m) => PopupMenuItem(
                      value: m['id'].toString(),
                      child: Text('${m['name']} (Family)', style: const TextStyle(color: Color(0xFF0F172A))),
                    )),
              ],
            ),
            const SizedBox(width: 8),
          ],

          // Download Expense PDF Report
          GestureDetector(
            onTap: _downloadExpensePdf,
            child: Container(
              padding: const EdgeInsets.all(7),
              decoration: const BoxDecoration(
                color: Color(0xFFEFF6FF),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.picture_as_pdf_outlined, color: Color(0xFF1E5AE6), size: 18),
            ),
          ),
          const SizedBox(width: 8),

          // Profile Picture (matches Documents, Users, and Activity tabs)
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const Scaffold(
                    backgroundColor: Color(0xFFF8FAFC),
                    body: ProfileScreen(),
                  ),
                ),
              );
            },
            child: CircleAvatar(
              radius: 16,
              backgroundColor: const Color(0xFFE2E8F0),
              backgroundImage: widget.profilePhotoUrl != null && widget.profilePhotoUrl!.isNotEmpty
                  ? CachedNetworkImageProvider(ImageUtils.getOptimizedImageUrl(widget.profilePhotoUrl))
                  : null,
              child: widget.profilePhotoUrl == null || widget.profilePhotoUrl!.isEmpty
                  ? Text(
                      _getInitials(widget.profileName),
                      style: const TextStyle(
                        color: Color(0xFF475569),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    )
                  : null,
            ),
          ),
        ],
      ),
    );
  }

  String _getInitials(String? name) {
    if (name == null || name.trim().isEmpty) return '';
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length > 1) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return parts[0][0].toUpperCase();
  }

  // Segmented Sub-Tab Bar (Splits vs Expenses)
  Widget _buildTopTabBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1)),
      ),
      child: Row(
        children: [
          _buildTopTabItem(0, 'Splits'),
          _buildTopTabItem(1, 'Expenses'),
        ],
      ),
    );
  }

  Widget _buildTopTabItem(int index, String title) {
    final isSelected = _selectedTabIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTabIndex = index),
        child: Container(
          color: Colors.transparent,
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Column(
            children: [
              Text(
                title,
                style: TextStyle(
                  color: isSelected ? const Color(0xFF1E5AE6) : const Color(0xFF64748B),
                  fontSize: 15,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                height: 3,
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFF1E5AE6) : Colors.transparent,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // TAB 1: Splits (Chronological feed, newest at bottom, NO message bar)
  Widget _buildSplitsTab() {
    return Stack(
      children: [
        if (_myExpenses.isEmpty)
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: const BoxDecoration(
                    color: Color(0xFFEFF6FF),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.receipt_long_outlined, size: 48, color: Color(0xFF1E5AE6)),
                ),
                const SizedBox(height: 16),
                const Text(
                  'No splits created yet',
                  style: TextStyle(color: Color(0xFF0F172A), fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Split bills easily with trip members',
                  style: TextStyle(color: Color(0xFF64748B), fontSize: 14),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: _openCreateExpense,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E5AE6),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    elevation: 0,
                  ),
                  icon: const Icon(Icons.add),
                  label: const Text('Split an expense'),
                ),
              ],
            ),
          )
        else
          RefreshIndicator(
            onRefresh: _fetchAllData,
            color: const Color(0xFF1E5AE6),
            child: ListView.separated(
              controller: _splitsScrollController,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
              itemCount: _myExpenses.length,
              separatorBuilder: (context, index) {
                final current = _myExpenses[index];
                if (current['createdAt'] != null) {
                  final timeStr = DateFormat('h:mm a').format(DateTime.parse(current['createdAt']).toLocal());
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Row(
                      children: [
                        const Expanded(child: Divider(color: Color(0xFFE2E8F0))),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12.0),
                          child: Text(
                            timeStr,
                            style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11, fontWeight: FontWeight.w500),
                          ),
                        ),
                        const Expanded(child: Divider(color: Color(0xFFE2E8F0))),
                      ],
                    ),
                  );
                }
                return const SizedBox(height: 16);
              },
              itemBuilder: (context, index) {
                final expense = _myExpenses[index];
                return _buildExpenseCard(expense);
              },
            ),
          ),

        // Bottom Sticky "Split expense" Button
        Positioned(
          left: 20,
          right: 20,
          bottom: 16,
          child: SizedBox(
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _openCreateExpense,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E5AE6),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                elevation: 4,
              ),
              icon: const Icon(Icons.add, size: 20),
              label: const Text(
                'Split expense',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // Google Pay style interactive card styled with TripSync theme
  Widget _buildExpenseCard(Map<String, dynamic> exp) {
    final isCreatedByMe = exp['isCreatedByMe'] == true;
    final title = exp['title'] ?? 'Expense';
    final amount = (exp['amount'] as num?)?.toDouble() ?? 0.0;
    final totalParticipants = exp['totalParticipants'] ?? 0;
    final paidCount = exp['paidCount'] ?? 0;
    final amountLeft = (exp['amountLeft'] as num?)?.toDouble() ?? 0.0;
    final canPay = exp['canPay'] == true;
    final userShare = (exp['userShare'] as num?)?.toDouble() ?? 0.0;
    final dateStr = exp['createdAt'] != null
        ? DateFormat('h:mm a').format(DateTime.parse(exp['createdAt']).toLocal())
        : '';
    final isFullyPaid = paidCount == totalParticipants && totalParticipants > 0;
    final progress = amount > 0 ? ((amount - amountLeft) / amount).clamp(0.0, 1.0) : 0.0;

    final avatars = (exp['avatars'] as List? ?? []).cast<Map<String, dynamic>>();

    return Align(
      alignment: isCreatedByMe ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onTap: () => _openDetail(exp['_id']),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.82,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Context Header: "Requested for 'Rent'" or "Split request"
              Text(
                isCreatedByMe ? "Requested for '$title'" : "Split request: $title",
                style: const TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),

              // Large Amount
              Text(
                '₹${amount.toStringAsFixed(amount.truncateToDouble() == amount ? 0 : 2)}',
                style: const TextStyle(
                  color: Color(0xFF0F172A),
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),

              // Overlapping Avatars Row
              SizedBox(
                height: 32,
                child: Stack(
                  children: [
                    for (int i = 0; i < avatars.length && i < 5; i++)
                      Positioned(
                        left: i * 22.0,
                        child: CircleAvatar(
                          radius: 15,
                          backgroundColor: const Color(0xFFE2E8F0),
                          backgroundImage: avatars[i]['avatar'] != null
                              ? NetworkImage(avatars[i]['avatar'])
                              : null,
                          child: avatars[i]['avatar'] == null
                              ? Text(
                                  (avatars[i]['name'] as String).isNotEmpty
                                      ? avatars[i]['name'][0].toUpperCase()
                                      : 'M',
                                  style: const TextStyle(fontSize: 11, color: Color(0xFF0F172A), fontWeight: FontWeight.bold),
                                )
                              : null,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Progress Bar
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 6,
                  backgroundColor: const Color(0xFFE2E8F0),
                  valueColor: AlwaysStoppedAnimation(
                    isFullyPaid ? const Color(0xFF16A34A) : const Color(0xFF1E5AE6),
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // Amount left
              if (!isFullyPaid)
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    '₹${amountLeft.toStringAsFixed(2)} left',
                    style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
                  ),
                ),
              const SizedBox(height: 10),

              // Status Row: "5 of 6 paid • 1:19 pm"
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        isFullyPaid ? Icons.check_circle : Icons.access_time,
                        size: 14,
                        color: isFullyPaid ? const Color(0xFF16A34A) : const Color(0xFF64748B),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        isFullyPaid
                            ? 'All paid • $dateStr'
                            : '$paidCount of $totalParticipants paid • $dateStr',
                        style: TextStyle(
                          color: isFullyPaid ? const Color(0xFF16A34A) : const Color(0xFF64748B),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const Icon(Icons.chevron_right, size: 18, color: Color(0xFF94A3B8)),
                ],
              ),

              // Settle up button inside card if current user owes
              if (canPay) ...[
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 40,
                  child: ElevatedButton(
                    onPressed: () => _quickPayExpense(exp),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFEFF6FF),
                      foregroundColor: const Color(0xFF1E5AE6),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                    child: Text(
                      'Settle up ₹${userShare.toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // TAB 2: Expenses (Balances Overview)
  Widget _buildExpensesTab() {
    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: _fetchAllData,
          color: const Color(0xFF1E5AE6),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Summary Card
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      // Left: Owed by you (RED)
                      Expanded(
                        child: Column(
                          children: [
                            Text(
                              '₹${_owedByYou.toStringAsFixed(2)}',
                              style: const TextStyle(
                                color: Color(0xFFEF4444), // RED as requested
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Owed by you',
                              style: TextStyle(color: Color(0xFF64748B), fontSize: 13, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ),
                      Container(height: 40, width: 1, color: const Color(0xFFE2E8F0)),
                      // Right: Owed to you (GREEN)
                      Expanded(
                        child: Column(
                          children: [
                            Text(
                              '₹${_owedToYou.toStringAsFixed(2)}',
                              style: const TextStyle(
                                color: Color(0xFF16A34A), // GREEN as requested
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Owed to you',
                              style: TextStyle(color: Color(0xFF64748B), fontSize: 13, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Download PDF Report Action Card
                InkWell(
                  onTap: _downloadExpensePdf,
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFBFDBFE)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                            color: Color(0xFF1E5AE6),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.picture_as_pdf_outlined, color: Colors.white, size: 18),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Download Expense Report (PDF)',
                                style: const TextStyle(
                                  color: Color(0xFF1E5AE6),
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Complete report with own expenses & shared payments for ${widget.tripData?['title'] ?? 'this trip'}',
                                style: const TextStyle(
                                  color: Color(0xFF64748B),
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.download_rounded, color: Color(0xFF1E5AE6), size: 22),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Section 1: Owed by you
                if (_owedByYouList.isNotEmpty) ...[
                  const Text(
                    'Owed by you',
                    style: TextStyle(
                      color: Color(0xFF0F172A),
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _owedByYouList.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final person = _owedByYouList[index];
                      return _buildPersonTile(person, isOwedByYou: true);
                    },
                  ),
                  const SizedBox(height: 24),
                ],

                // Section 2: People owe you
                if (_owedToYouList.isNotEmpty) ...[
                  Text(
                    '${_owedToYouList.length} ${_owedToYouList.length == 1 ? 'person owes' : 'people owe'} you',
                    style: const TextStyle(
                      color: Color(0xFF0F172A),
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _owedToYouList.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final person = _owedToYouList[index];
                      return _buildPersonTile(person, isOwedByYou: false);
                    },
                  ),
                  const SizedBox(height: 24),
                ],

                // Section 3: Settled
                if (_settledList.isNotEmpty) ...[
                  const Text(
                    'Settled',
                    style: TextStyle(
                      color: Color(0xFF0F172A),
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _settledList.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final person = _settledList[index];
                      return _buildPersonTile(person, isSettled: true);
                    },
                  ),
                ],

                if (_owedByYouList.isEmpty && _owedToYouList.isEmpty && _settledList.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40.0),
                      child: Column(
                        children: const [
                          Icon(Icons.check_circle_outline, size: 48, color: Color(0xFF16A34A)),
                          SizedBox(height: 12),
                          Text(
                            'All balances are settled!',
                            style: TextStyle(color: Color(0xFF0F172A), fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'No pending payments between members',
                            style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),

        // Bottom Sticky Action Buttons
        Positioned(
          left: 20,
          right: 20,
          bottom: 16,
          child: Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: OutlinedButton(
                    onPressed: _openCreateExpense,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF1E5AE6),
                      side: const BorderSide(color: Color(0xFF1E5AE6)),
                      backgroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                    ),
                    child: const Text('Split expense', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () {
                      if (_owedByYouList.isNotEmpty) {
                        _openPersonBalance(_owedByYouList.first);
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('All balances are currently settled!')),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E5AE6),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                      elevation: 0,
                    ),
                    child: const Text('Settle up', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPersonTile(
    Map<String, dynamic> person, {
    bool isOwedByYou = false,
    bool isSettled = false,
  }) {
    final name = person['name'] ?? 'Member';
    final avatar = person['avatar'];
    final amount = (person['amount'] as num?)?.toDouble() ?? 0.0;
    final unpaidCount = person['unpaidCount'] ?? 0;
    final expensesCount = person['expensesCount'] ?? 0;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: InkWell(
        onTap: () => _openPersonBalance(person),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: const Color(0xFFEFF6FF),
                backgroundImage: avatar != null ? NetworkImage(avatar) : null,
                child: avatar == null
                    ? Text(
                        name.isNotEmpty ? name[0].toUpperCase() : 'M',
                        style: const TextStyle(color: Color(0xFF1E5AE6), fontWeight: FontWeight.bold),
                      )
                    : null,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        color: Color(0xFF0F172A),
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isSettled
                          ? '$expensesCount expenses'
                          : '$unpaidCount unpaid ${unpaidCount == 1 ? 'expense' : 'expenses'}',
                      style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
                    ),
                  ],
                ),
              ),
              Text(
                '₹${amount.toStringAsFixed(2)}',
                style: TextStyle(
                  color: isSettled
                      ? const Color(0xFF64748B)
                      : isOwedByYou
                      ? const Color(0xFFEF4444) // RED for Owed by you
                      : const Color(0xFF16A34A), // GREEN for Owed to you
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 6),
              const Icon(Icons.chevron_right, size: 18, color: Color(0xFF94A3B8)),
            ],
          ),
        ),
      ),
    );
  }
}
