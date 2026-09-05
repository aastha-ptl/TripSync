import 'package:flutter/material.dart';
import '../services/trip_expense_service.dart';

class TripExpenseDetailScreen extends StatefulWidget {
  final String tripId;
  final String expenseId;
  final String? actingAsGuestId;

  const TripExpenseDetailScreen({
    super.key,
    required this.tripId,
    required this.expenseId,
    this.actingAsGuestId,
  });

  @override
  State<TripExpenseDetailScreen> createState() => _TripExpenseDetailScreenState();
}

class _TripExpenseDetailScreenState extends State<TripExpenseDetailScreen> {
  final TripExpenseService _expenseService = TripExpenseService();
  bool _isLoading = true;
  bool _isSettling = false;
  Map<String, dynamic>? _expenseData;
  List<Map<String, dynamic>> _participants = [];
  bool _isCreator = false;
  double _totalPaid = 0;
  double _amountLeft = 0;
  int _paidCount = 0;

  @override
  void initState() {
    super.initState();
    _fetchDetail();
  }

  Future<void> _fetchDetail() async {
    final res = await _expenseService.getExpenseDetail(
      widget.tripId,
      widget.expenseId,
      actingAsGuestId: widget.actingAsGuestId,
    );
    if (res['success'] == true && mounted) {
      final data = res['data'];
      setState(() {
        _expenseData = data['expense'];
        _participants = (data['participants'] as List).cast<Map<String, dynamic>>();
        _isCreator = data['isCreator'] == true;
        _totalPaid = (data['totalPaid'] as num?)?.toDouble() ?? 0.0;
        _amountLeft = (data['amountLeft'] as num?)?.toDouble() ?? 0.0;
        _paidCount = data['paidCount'] ?? 0;
        _isLoading = false;
      });
    } else {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _settleSelf(String participantId) async {
    setState(() => _isSettling = true);
    final res = await _expenseService.settleParticipant(
      widget.tripId,
      widget.expenseId,
      participantId: participantId,
    );
    if (!mounted) return;
    setState(() => _isSettling = false);

    if (res['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Payment marked as settled!'),
          backgroundColor: Color(0xFF16A34A),
        ),
      );
      _fetchDetail();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['message'] ?? 'Failed to settle'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Future<void> _closeRequest() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('Close Request?', style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold)),
        content: const Text(
          'Are you sure you want to close this expense split request? It will be removed from your active splits.',
          style: TextStyle(color: Color(0xFF64748B)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            child: const Text('Close Request', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final res = await _expenseService.deleteExpense(widget.tripId, widget.expenseId);
      if (!mounted) return;
      if (res['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Request closed successfully')),
        );
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res['message'] ?? 'Failed to close request')),
        );
      }
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

    if (_expenseData == null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(backgroundColor: Colors.white),
        body: const Center(
          child: Text('Expense not found', style: TextStyle(color: Color(0xFF0F172A))),
        ),
      );
    }

    final totalAmount = (_expenseData!['amount'] as num?)?.toDouble() ?? 0.0;
    final totalParticipants = _participants.length;
    final progress = totalAmount > 0 ? (_totalPaid / totalAmount).clamp(0.0, 1.0) : 0.0;

    final myUnpaidPart = _participants.firstWhere(
      (p) => p['isCurrentUser'] == true && p['settlementStatus'] == 'pending' && !p['isCreator'],
      orElse: () => {},
    );
    final canUserPay = myUnpaidPart.isNotEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF0F172A)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Split Details',
          style: TextStyle(color: Color(0xFF0F172A), fontSize: 18, fontWeight: FontWeight.bold),
        ),
        actions: [
          if (_isCreator)
            PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Color(0xFF0F172A)),
            color: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            onSelected: (val) {
              if (val == 'close') {
                _closeRequest();
              } 
            },
            itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'close',
                  child: Text('Close request', style: TextStyle(color: Color(0xFFEF4444))),
                ),
            ],
           ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    children: [
                      // Main overview card
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
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
                          children: [
                            // Creator Avatar
                            CircleAvatar(
                              radius: 32,
                              backgroundColor: const Color(0xFFEFF6FF),
                              backgroundImage: _expenseData!['createdBy']?['profilePhoto'] != null
                                  ? NetworkImage(_expenseData!['createdBy']['profilePhoto'])
                                  : null,
                              child: _expenseData!['createdBy']?['profilePhoto'] == null
                                  ? const Icon(Icons.person, size: 32, color: Color(0xFF1E5AE6))
                                  : null,
                            ),
                            const SizedBox(height: 12),

                            // Title
                            Text(
                              _expenseData!['title'] ?? 'Expense',
                              style: const TextStyle(
                                color: Color(0xFF0F172A),
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 6),

                            // Total Amount
                            Text(
                              'Total: ₹${totalAmount.toStringAsFixed(totalAmount.truncateToDouble() == totalAmount ? 0 : 2)}',
                              style: const TextStyle(
                                color: Color(0xFF1E5AE6),
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 20),

                            // Progress Bar
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: LinearProgressIndicator(
                                value: progress,
                                minHeight: 8,
                                backgroundColor: const Color(0xFFE2E8F0),
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  progress >= 1.0 ? const Color(0xFF16A34A) : const Color(0xFF1E5AE6),
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),

                            // Paid vs Left amounts
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '₹${_totalPaid.toStringAsFixed(2)} paid',
                                  style: const TextStyle(color: Color(0xFF16A34A), fontSize: 13, fontWeight: FontWeight.w600),
                                ),
                                Text(
                                  '₹${_amountLeft.toStringAsFixed(2)} left',
                                  style: const TextStyle(color: Color(0xFF64748B), fontSize: 13, fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Paid count & Send reminder row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '$_paidCount of $totalParticipants paid',
                            style: const TextStyle(
                              color: Color(0xFF0F172A),
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (_isCreator && _amountLeft > 0)
                            TextButton.icon(
                              onPressed: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Reminder sent to unpaid participants!'),
                                    backgroundColor: Color(0xFF1E5AE6),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.notifications_active_outlined, size: 16, color: Color(0xFF1E5AE6)),
                              label: const Text(
                                'Send reminder',
                                style: TextStyle(
                                  color: Color(0xFF1E5AE6),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Participant breakdown list
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _participants.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final p = _participants[index];
                          final isSettled = p['settlementStatus'] == 'settled';
                          final isCreator = p['isCreator'] == true;
                          final share = (p['shareAmount'] as num?)?.toDouble() ?? 0.0;

                          return Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Row(
                              children: [
                                // Avatar with status badge
                                Stack(
                                  children: [
                                    CircleAvatar(
                                      radius: 20,
                                      backgroundColor: const Color(0xFFEFF6FF),
                                      backgroundImage: p['avatar'] != null ? NetworkImage(p['avatar']) : null,
                                      child: p['avatar'] == null
                                          ? Text(
                                              (p['name'] as String).isNotEmpty
                                                  ? p['name'][0].toUpperCase()
                                                  : 'M',
                                              style: const TextStyle(color: Color(0xFF1E5AE6), fontWeight: FontWeight.bold),
                                            )
                                          : null,
                                    ),
                                    if (isSettled)
                                      Positioned(
                                        bottom: 0,
                                        right: 0,
                                        child: Container(
                                          padding: const EdgeInsets.all(2),
                                          decoration: const BoxDecoration(
                                            color: Color(0xFF16A34A),
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(Icons.check, size: 10, color: Colors.white),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(width: 14),

                                // Name & status subtitle
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        p['isCurrentUser'] == true ? 'You' : p['name'],
                                        style: const TextStyle(
                                          color: Color(0xFF0F172A),
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        isCreator
                                            ? 'Sent this request'
                                            : isSettled
                                            ? 'Paid'
                                            : 'Unpaid',
                                        style: TextStyle(
                                          color: isSettled
                                              ? const Color(0xFF16A34A)
                                              : const Color(0xFF64748B),
                                          fontSize: 12,
                                          fontWeight: isSettled ? FontWeight.w600 : FontWeight.normal,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                // Share amount
                                Text(
                                  '₹${share.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    color: isSettled ? const Color(0xFF16A34A) : const Color(0xFF0F172A),
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),

            // Pay action button if user owes money
            if (canUserPay)
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
                    onPressed: _isSettling ? null : () => _settleSelf(myUnpaidPart['id']),
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
                            'Settle up ₹${((myUnpaidPart['shareAmount'] as num?)?.toDouble() ?? 0).toStringAsFixed(2)}',
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
}
