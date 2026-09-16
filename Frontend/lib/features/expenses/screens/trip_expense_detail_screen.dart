import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/constants/api_endpoints.dart';
import '../services/trip_expense_service.dart';
import 'trip_expense_create_screen.dart';

class TripExpenseDetailScreen extends StatefulWidget {
  final String tripId;
  final String expenseId;
  final String? actingAsGuestId;
  final Map<String, dynamic>? tripData;

  const TripExpenseDetailScreen({
    super.key,
    required this.tripId,
    required this.expenseId,
    this.actingAsGuestId,
    this.tripData,
  });

  @override
  State<TripExpenseDetailScreen> createState() => _TripExpenseDetailScreenState();
}

class _TripExpenseDetailScreenState extends State<TripExpenseDetailScreen> {
  final TripExpenseService _expenseService = TripExpenseService();
  bool _isLoading = true;
  bool _isSettling = false;
  bool _isModified = false;

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
      _isModified = true;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Payment marked as settled!'),
          backgroundColor: AppColors.secondary,
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

  Future<void> _deleteExpense() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('Delete Expense?', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
        content: const Text(
          'Are you sure you want to delete this expense? This action cannot be undone and will delete associated receipt proof.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final res = await _expenseService.deleteExpense(widget.tripId, widget.expenseId);
      if (!mounted) return;
      if (res['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Expense deleted successfully')),
        );
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res['message'] ?? 'Failed to delete expense')),
        );
      }
    }
  }

  void _editExpense() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TripExpenseCreateScreen(
          tripData: widget.tripData ?? {'_id': widget.tripId},
          existingExpense: _expenseData,
        ),
      ),
    ).then((updated) {
      if (updated == true) {
        _isModified = true;
        _fetchDetail();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    if (_expenseData == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(backgroundColor: Colors.white),
        body: const Center(
          child: Text('Expense not found', style: TextStyle(color: AppColors.textPrimary)),
        ),
      );
    }

    final totalAmount = (_expenseData!['amount'] as num?)?.toDouble() ?? 0.0;
    final estimatedCost = (_expenseData!['estimatedAmount'] as num?)?.toDouble();
    final expenseType = _expenseData!['expenseType'] ?? 'other';
    final dayNum = _expenseData!['dayNumber'] ?? 1;
    final categoryRaw = (_expenseData!['category'] ?? 'other').toString().toLowerCase();
    final category = categoryRaw == 'accommodation' ? 'STAY' : categoryRaw.toUpperCase();
    final receiptUrl = _expenseData!['receiptUrl'];
    final totalParticipants = _participants.length;
    final progress = totalAmount > 0 ? (_totalPaid / totalAmount).clamp(0.0, 1.0) : 0.0;

    final myUnpaidPart = _participants.firstWhere(
      (p) => p['isCurrentUser'] == true && p['settlementStatus'] == 'pending' && !p['isCreator'],
      orElse: () => {},
    );
    final canUserPay = myUnpaidPart.isNotEmpty;

    // Difference calculations
    String? diffText;
    Color diffColor = Colors.grey;
    if (expenseType == 'itinerary') {
      if (estimatedCost != null && estimatedCost > 0) {
        final diff = totalAmount - estimatedCost;
        if (diff > 0) {
          diffText = '₹${diff.toStringAsFixed(0)} more than estimated';
          diffColor = const Color(0xFFEA580C);
        } else if (diff < 0) {
          diffText = '₹${(-diff).toStringAsFixed(0)} less than estimated';
          diffColor = const Color(0xFF20C060);
        } else {
          diffText = 'Same as estimated';
          diffColor = const Color(0xFF0EA5E9);
        }
      } else {
        diffText = 'Estimated cost not available';
      }
    } else {
      diffText = 'Estimated: Not applicable';
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        Navigator.pop(context, _isModified);
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 4,
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
            onPressed: () => Navigator.pop(context, _isModified),
          ),
        title: const Text(
          'Expense Breakdown',
          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
        ),
        actions: [
          if (_isCreator) ...[
            IconButton(
              icon: const Icon(Icons.edit_outlined, color: Colors.white, size: 20),
              onPressed: _editExpense,
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.white, size: 20),
              onPressed: _deleteExpense,
            ),
          ],
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
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
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  'Day $dayNum',
                                  style: const TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  category,
                                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),

                          // Creator Avatar
                          CircleAvatar(
                            radius: 30,
                            backgroundColor: const Color(0xFFEFF6FF),
                            backgroundImage: _expenseData!['createdBy']?['profilePhoto'] != null
                                ? NetworkImage(_expenseData!['createdBy']['profilePhoto'])
                                : null,
                            child: _expenseData!['createdBy']?['profilePhoto'] == null
                                ? const Icon(Icons.person, size: 30, color: AppColors.primary)
                                : null,
                          ),
                          const SizedBox(height: 12),

                          // Title
                          Text(
                            _expenseData!['title'] ?? 'Expense',
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),

                          // Total Amount
                          Text(
                            'Actual: ₹${totalAmount.toStringAsFixed(2)}',
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),

                          // Difference Badge
                          if (diffText != null)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: diffColor.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                diffText,
                                style: TextStyle(color: diffColor, fontSize: 11, fontWeight: FontWeight.bold),
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
                                progress >= 1.0 ? const Color(0xFF16A34A) : AppColors.primary,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),

                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '₹${_totalPaid.toStringAsFixed(2)} paid',
                                style: const TextStyle(color: Color(0xFF16A34A), fontSize: 13, fontWeight: FontWeight.w600),
                              ),
                              Text(
                                '₹${_amountLeft.toStringAsFixed(2)} left',
                                style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Bill / Receipt Proof Card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.receipt_long_outlined, size: 18, color: AppColors.primary),
                              SizedBox(width: 8),
                              Text(
                                'Bill / Receipt Proof',
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          if (receiptUrl != null && receiptUrl.toString().isNotEmpty) ...[
                            if (receiptUrl.toString().toLowerCase().endsWith('.pdf')) ...[
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFEF2F2),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFFFCA5A5)),
                                ),
                                child: Column(
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(Icons.picture_as_pdf, size: 40, color: Color(0xFFDC2626)),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                receiptUrl.toString().split('/').last,
                                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              const SizedBox(height: 2),
                                              const Text('PDF Receipt Document', style: TextStyle(fontSize: 11, color: Color(0xFFDC2626))),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton.icon(
                                        onPressed: () async {
                                          final fullUrl = ApiEndpoints.buildImageUrl(receiptUrl.toString());
                                          final uri = Uri.parse(fullUrl);
                                          if (await canLaunchUrl(uri)) {
                                            await launchUrl(uri, mode: LaunchMode.externalApplication);
                                          }
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFFDC2626),
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                        ),
                                        icon: const Icon(Icons.open_in_new, size: 16),
                                        label: const Text('View / Open PDF Proof', style: TextStyle(fontWeight: FontWeight.bold)),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ] else ...[
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.network(
                                  ApiEndpoints.buildImageUrl(receiptUrl),
                                  height: 180,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                    height: 100,
                                    color: Colors.grey.shade100,
                                    child: const Center(child: Text('Failed to load bill image')),
                                  ),
                                ),
                              ),
                            ],
                          ] else ...[
                            const Text(
                              'No bill attached',
                              style: TextStyle(fontSize: 13, color: AppColors.textLight, fontStyle: FontStyle.italic),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Paid count
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '$_paidCount of $totalParticipants paid',
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
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
                              Stack(
                                children: [
                                  CircleAvatar(
                                    radius: 20,
                                    backgroundColor: const Color(0xFFEFF6FF),
                                    backgroundImage: p['avatar'] != null ? NetworkImage(p['avatar']) : null,
                                    child: p['avatar'] == null
                                        ? Text(
                                            (p['name'] as String).isNotEmpty ? p['name'][0].toUpperCase() : 'M',
                                            style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
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

                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      p['isCurrentUser'] == true ? 'You' : p['name'],
                                      style: const TextStyle(
                                        color: AppColors.textPrimary,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      isCreator
                                          ? 'Paid full bill'
                                          : isSettled
                                              ? 'Settled'
                                              : 'Pending',
                                      style: TextStyle(
                                        color: isSettled ? const Color(0xFF16A34A) : AppColors.textSecondary,
                                        fontSize: 12,
                                        fontWeight: isSettled ? FontWeight.w600 : FontWeight.normal,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              Text(
                                '₹${share.toStringAsFixed(2)}',
                                style: TextStyle(
                                  color: isSettled ? const Color(0xFF16A34A) : AppColors.textPrimary,
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
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
    ),
  );
}
}
