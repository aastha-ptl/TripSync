import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/trip_expense_service.dart';
import 'trip_expense_detail_screen.dart';

class TripExpenseReportsScreen extends StatefulWidget {
  final String tripId;
  final Map<String, dynamic>? tripData;

  const TripExpenseReportsScreen({
    super.key,
    required this.tripId,
    this.tripData,
  });

  @override
  State<TripExpenseReportsScreen> createState() => _TripExpenseReportsScreenState();
}

class _TripExpenseReportsScreenState extends State<TripExpenseReportsScreen> {
  final TripExpenseService _expenseService = TripExpenseService();
  bool _isLoading = true;
  List<Map<String, dynamic>> _reports = [];

  @override
  void initState() {
    super.initState();
    _fetchReports();
  }

  Future<void> _fetchReports() async {
    setState(() => _isLoading = true);
    final res = await _expenseService.getExpenseReports(widget.tripId);
    if (!mounted) return;

    if (res['success'] == true && res['data'] is List) {
      setState(() {
        _reports = (res['data'] as List).cast<Map<String, dynamic>>();
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateStatus(String reportId, String newStatus) async {
    final res = await _expenseService.updateReportStatus(
      widget.tripId,
      reportId,
      status: newStatus,
    );
    if (!mounted) return;

    if (res['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(newStatus == 'resolved' ? 'Report marked as resolved' : 'Report updated'),
          backgroundColor: const Color(0xFF16A34A),
        ),
      );
      _fetchReports();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['message'] ?? 'Failed to update status'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  void _openExpenseDetail(String expenseId) async {
    final res = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => TripExpenseDetailScreen(
          tripId: widget.tripId,
          expenseId: expenseId,
          tripData: widget.tripData,
        ),
      ),
    );
    if (res == true && mounted) {
      _fetchReports();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFF0F172A), size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Split Dispute Reports',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
            ),
            Text(
              widget.tripData?['title'] ?? widget.tripData?['name'] ?? 'Trip Expenses',
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFF1E5AE6)),
            onPressed: _fetchReports,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: const Color(0xFFE2E8F0), height: 1),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF1E5AE6)))
          : RefreshIndicator(
              onRefresh: _fetchReports,
              color: const Color(0xFF1E5AE6),
              child: _reports.isEmpty ? _buildEmptyState() : _buildReportsList(),
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFBFDBFE), width: 1.5),
              ),
              child: const Icon(
                Icons.verified_user_outlined,
                size: 52,
                color: Color(0xFF1E5AE6),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'No Split Reports',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Only you (the expense owner) can view member split reports filed against expenses you paid or created. Everything looks clear right now!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF64748B),
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportsList() {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _reports.length,
      separatorBuilder: (_, __) => const SizedBox(height: 14),
      itemBuilder: (context, index) {
        final report = _reports[index];
        final expense = report['expenseId'] as Map<String, dynamic>? ?? {};
        final reporter = report['reportedBy'] as Map<String, dynamic>? ?? {};
        final reporterName = reporter['firstName'] != null
            ? '${reporter['firstName']} ${reporter['lastName'] ?? ''}'.trim()
            : 'Member';
        final participantName = report['participantName'] ?? 'Member';
        final shareAmount = (report['participantShare'] as num?)?.toDouble() ?? 0.0;
        final message = report['message'] ?? '';
        final status = report['status'] ?? 'pending';
        final isResolved = status == 'resolved';
        final createdAt = report['createdAt'] != null
            ? DateTime.tryParse(report['createdAt'].toString())
            : null;

        String formattedDate = '';
        if (createdAt != null) {
          formattedDate = DateFormat('MMM d, h:mm a').format(createdAt.toLocal());
        }

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isResolved ? const Color(0xFFE2E8F0) : const Color(0xFFFECACA),
              width: isResolved ? 1 : 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row: Expense Title & Status Chip
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: isResolved ? const Color(0xFFF1F5F9) : const Color(0xFFFEE2E2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            isResolved ? Icons.check_circle_outline : Icons.report_problem_rounded,
                            size: 16,
                            color: isResolved ? const Color(0xFF64748B) : const Color(0xFFDC2626),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            expense['title'] ?? 'Expense',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isResolved ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      isResolved ? 'Resolved' : 'Pending Review',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isResolved ? const Color(0xFF16A34A) : const Color(0xFFD97706),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Split Details Banner
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Reported Split: $participantName',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF334155),
                      ),
                    ),
                    Text(
                      '₹${shareAmount.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Report Message Box
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFDE68A)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.chat_bubble_outline, size: 14, color: Color(0xFFB45309)),
                        SizedBox(width: 6),
                        Text(
                          'Member Dispute Reason:',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFB45309),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      message,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF78350F),
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Reporter & Date Info
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 12,
                        backgroundColor: const Color(0xFFE2E8F0),
                        backgroundImage: reporter['profilePhoto'] != null &&
                                reporter['profilePhoto'].toString().isNotEmpty
                            ? NetworkImage(reporter['profilePhoto'])
                            : null,
                        child: reporter['profilePhoto'] == null
                            ? Text(
                                reporterName.isNotEmpty ? reporterName[0].toUpperCase() : 'M',
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF475569),
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Reported by $reporterName',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  if (formattedDate.isNotEmpty)
                    Text(
                      formattedDate,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 14),

              // Actions
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        final expId = expense['_id']?.toString() ?? report['expenseId']?.toString();
                        if (expId != null) {
                          _openExpenseDetail(expId);
                        }
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF1E5AE6),
                        side: const BorderSide(color: Color(0xFFBFDBFE)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      icon: const Icon(Icons.visibility_outlined, size: 16),
                      label: const Text('View Split', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    ),
                  ),
                  if (!isResolved) ...[
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _updateStatus(report['_id'], 'resolved'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF16A34A),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        icon: const Icon(Icons.check, size: 16),
                        label: const Text('Resolve', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
