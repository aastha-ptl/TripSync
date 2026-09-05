import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/trip_expense_service.dart';

class TripExpensePersonBalanceScreen extends StatefulWidget {
  final String tripId;
  final String targetId;
  final bool isGuest;
  final String? actingAsGuestId;

  const TripExpensePersonBalanceScreen({
    super.key,
    required this.tripId,
    required this.targetId,
    this.isGuest = false,
    this.actingAsGuestId,
  });

  @override
  State<TripExpensePersonBalanceScreen> createState() => _TripExpensePersonBalanceScreenState();
}

class _TripExpensePersonBalanceScreenState extends State<TripExpensePersonBalanceScreen> {
  final TripExpenseService _expenseService = TripExpenseService();

  bool _isLoading = true;
  bool _isSettling = false;
  String _selectedFilter = 'unpaid'; // 'unpaid' or 'paid'

  Map<String, dynamic>? _targetInfo;

  List<Map<String, dynamic>> _unpaidExpenses = [];
  List<Map<String, dynamic>> _paidExpenses = [];

  // Multi-selection for paying when user owes
  final Set<String> _selectedParticipantIds = {};

  @override
  void initState() {
    super.initState();
    _fetchBalanceDetail();
  }

  Future<void> _fetchBalanceDetail() async {
    final res = await _expenseService.getBalanceDetail(
      widget.tripId,
      widget.targetId,
      isGuest: widget.isGuest,
      actingAsGuestId: widget.actingAsGuestId,
    );

    if (res['success'] == true && mounted) {
      final data = res['data'];
      final unpaid = (data['unpaidExpenses'] as List).cast<Map<String, dynamic>>();
      final paid = (data['paidExpenses'] as List).cast<Map<String, dynamic>>();

      setState(() {
        _targetInfo = data['target'];
        _unpaidExpenses = unpaid;
        _paidExpenses = paid;

        // Select all unpaid items by default
        _selectedParticipantIds.clear();
        for (var item in _unpaidExpenses) {
          _selectedParticipantIds.add(item['participantId'].toString());
        }
        _isLoading = false;
      });
    } else {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  double _calculateSelectedNetTotal() {
    double youOweSum = 0.0;
    double theyOweSum = 0.0;
    for (var item in _unpaidExpenses) {
      final pId = item['participantId'].toString();
      if (_selectedParticipantIds.contains(pId)) {
        final share = (item['shareAmount'] as num?)?.toDouble() ?? 0.0;
        if (item['youOwe'] == true) {
          youOweSum += share;
        } else {
          theyOweSum += share;
        }
      }
    }
    return youOweSum - theyOweSum;
  }

  Future<void> _settleSelected() async {
    if (_selectedParticipantIds.isEmpty) return;

    setState(() => _isSettling = true);
    final res = await _expenseService.settlePersonExpenses(
      widget.tripId,
      _selectedParticipantIds.toList(),
    );
    if (!mounted) return;
    setState(() => _isSettling = false);

    if (res['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Expenses marked as settled!'),
          backgroundColor: Color(0xFF16A34A),
        ),
      );
      _fetchBalanceDetail();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['message'] ?? 'Failed to settle expenses'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFFF8FAFC),
        body: Center(child: CircularProgressIndicator(color: Color(0xFF1E5AE6))),
      );
    }

    final targetName = _targetInfo?['name'] ?? 'Member';
    final avatarUrl = _targetInfo?['avatar'];
    final selectedNetTotal = _calculateSelectedNetTotal();

    final String displayTitle;
    final double displayAmount;
    final Color displayColor;

    if (_selectedFilter == 'unpaid') {
      if (_selectedParticipantIds.isEmpty) {
        displayTitle = 'No expenses selected';
        displayAmount = 0.0;
        displayColor = const Color(0xFF64748B);
      } else if (selectedNetTotal > 0.009) {
        displayTitle = 'You owe $targetName';
        displayAmount = selectedNetTotal;
        displayColor = const Color(0xFFEF4444); // Red: Owed by you
      } else if (selectedNetTotal < -0.009) {
        displayTitle = '$targetName owes you';
        displayAmount = selectedNetTotal.abs();
        displayColor = const Color(0xFF16A34A); // Green: Owed to you
      } else {
        displayTitle = 'Settled with $targetName';
        displayAmount = 0.0;
        displayColor = const Color(0xFF0F172A);
      }
    } else {
      displayTitle = _paidExpenses.isNotEmpty
          ? 'Paid history with $targetName'
          : 'Settled with $targetName';
      displayAmount = 0.0;
      displayColor = const Color(0xFF0F172A);
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF0F172A)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          targetName,
          style: const TextStyle(color: Color(0xFF0F172A), fontSize: 17, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert, color: Color(0xFF0F172A)),
            onPressed: () {},
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: Column(
                    children: [
                      const SizedBox(height: 20),

                      // Avatar
                      CircleAvatar(
                        radius: 38,
                        backgroundColor: const Color(0xFFEFF6FF),
                        backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                        child: avatarUrl == null
                            ? Text(
                                targetName.isNotEmpty ? targetName[0].toUpperCase() : 'M',
                                style: const TextStyle(
                                  color: Color(0xFF1E5AE6),
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(height: 14),

                      // Title: dynamically reflects selection (e.g. "You owe Aarohi Patel" or "Aarohi Patel owes you")
                      Text(
                        displayTitle,
                        style: const TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Hero Amount: dynamically reflects selection of radio buttons
                      Text(
                        '₹${displayAmount.toStringAsFixed(2)}',
                        style: TextStyle(
                          color: displayColor,
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Filter Pills: [ Unpaid ] | [ Paid ]
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildFilterPill('unpaid', 'Unpaid'),
                          const SizedBox(width: 12),
                          _buildFilterPill('paid', 'Paid'),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // List Items
                      if (_selectedFilter == 'unpaid')
                        _buildUnpaidList()
                      else
                        _buildPaidList(),

                      const SizedBox(height: 30),
                    ],
                  ),
                ),
              ),
            ),

            // Bottom Settle up button for selected items
            if (_selectedFilter == 'unpaid' && _selectedParticipantIds.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(20.0),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 10,
                      offset: const Offset(0, -3),
                    ),
                  ],
                ),
                child: SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isSettling ? null : _settleSelected,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E5AE6),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                      elevation: 0,
                    ),
                    child: _isSettling
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Text(
                            'Settle up ₹${selectedNetTotal.abs().toStringAsFixed(2)}',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterPill(String filterKey, String label) {
    final isSelected = _selectedFilter == filterKey;
    return GestureDetector(
      onTap: () => setState(() => _selectedFilter = filterKey),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFEFF6FF) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFF1E5AE6) : const Color(0xFFE2E8F0),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? const Color(0xFF1E5AE6) : const Color(0xFF64748B),
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildUnpaidList() {
    if (_unpaidExpenses.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 40.0),
        alignment: Alignment.center,
        child: const Text(
          'No unpaid expenses',
          style: TextStyle(color: Color(0xFF64748B), fontSize: 14),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _unpaidExpenses.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final item = _unpaidExpenses[index];
        final pId = item['participantId'].toString();
        final isSelected = _selectedParticipantIds.contains(pId);
        final youOwe = item['youOwe'] == true;
        final share = (item['shareAmount'] as num?)?.toDouble() ?? 0.0;
        final dateStr = item['date'] != null
            ? DateFormat('d MMM • h:mm a').format(DateTime.parse(item['date']).toLocal())
            : '';

        return Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {
              setState(() {
                if (isSelected) {
                  _selectedParticipantIds.remove(pId);
                } else {
                  _selectedParticipantIds.add(pId);
                }
              });
            },
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected ? const Color(0xFFBFDBFE) : const Color(0xFFE2E8F0),
                  width: isSelected ? 1.5 : 1.0,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSelected ? const Color(0xFF1E5AE6) : Colors.transparent,
                      border: Border.all(
                        color: isSelected ? const Color(0xFF1E5AE6) : const Color(0xFFCBD5E1),
                        width: 2,
                      ),
                    ),
                    child: isSelected
                        ? const Icon(Icons.check, size: 16, color: Colors.white)
                        : null,
                  ),
                  const SizedBox(width: 14),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item['title'] ?? 'Expense',
                          style: const TextStyle(
                            color: Color(0xFF0F172A),
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$dateStr • Requested by ${item['requestedBy']}',
                          style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
                        ),
                      ],
                    ),
                  ),

                  Text(
                    '₹${share.toStringAsFixed(2)}',
                    style: TextStyle(
                      color: youOwe
                          ? const Color(0xFFEF4444) // Red: Owed by you
                          : const Color(0xFF16A34A), // Green: Owed to you
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPaidList() {
    if (_paidExpenses.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 40.0),
        alignment: Alignment.center,
        child: const Text(
          'No paid history yet',
          style: TextStyle(color: Color(0xFF64748B), fontSize: 14),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _paidExpenses.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final item = _paidExpenses[index];
        final share = (item['shareAmount'] as num?)?.toDouble() ?? 0.0;
        final dateStr = item['date'] != null
            ? DateFormat('d MMM').format(DateTime.parse(item['date']).toLocal())
            : '';
        final isRequestedByYou = item['requestedBy'] == 'you';

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: const Color(0xFFEFF6FF),
                backgroundImage: _targetInfo?['avatar'] != null
                    ? NetworkImage(_targetInfo!['avatar'])
                    : null,
                child: _targetInfo?['avatar'] == null
                    ? Text(
                        (_targetInfo?['name'] as String?)?.isNotEmpty == true
                            ? _targetInfo!['name'][0].toUpperCase()
                            : 'M',
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
                      item['title'] ?? 'Expense',
                      style: const TextStyle(
                        color: Color(0xFF0F172A),
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$dateStr • Requested by ${item['requestedBy']}',
                      style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
                    ),
                  ],
                ),
              ),
              Text(
                '₹${share.toStringAsFixed(2)}',
                style: TextStyle(
                  color: isRequestedByYou ? const Color(0xFF16A34A) : const Color(0xFF0F172A),
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
