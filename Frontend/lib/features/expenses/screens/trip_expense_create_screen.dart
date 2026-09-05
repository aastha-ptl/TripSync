import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/trip_expense_service.dart';

class TripExpenseCreateScreen extends StatefulWidget {
  final Map<String, dynamic>? tripData;

  const TripExpenseCreateScreen({super.key, this.tripData});

  @override
  State<TripExpenseCreateScreen> createState() => _TripExpenseCreateScreenState();
}

class _TripExpenseCreateScreenState extends State<TripExpenseCreateScreen> {
  final TripExpenseService _expenseService = TripExpenseService();

  int _currentStep = 1; // 1 = Enter amount & title, 2 = Configure split
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _titleController = TextEditingController();

  bool _isLoading = true;
  bool _isSubmitting = false;
  List<Map<String, dynamic>> _allMembers = [];
  List<Map<String, dynamic>> _myFamilyMembers = [];
  bool _isFamilyLeader = false;

  // Selected payer (for family leader: can be myself or a non-app family member)
  String _selectedPayerType = 'myself'; // 'myself' or guestId
  String _selectedPayerName = 'You';

  // Split configuration
  bool _isCustomSplit = false; // false = equal, true = split by amounts
  final Map<String, bool> _selectedMembers = {}; // key -> isSelected
  final Map<String, TextEditingController> _shareControllers = {};

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _titleController.dispose();
    for (var controller in _shareControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadMembers() async {
    final tripId = widget.tripData?['_id'];
    if (tripId == null) {
      setState(() => _isLoading = false);
      return;
    }

    final res = await _expenseService.getMembers(tripId);
    if (res['success'] == true && mounted) {
      final List<dynamic> rawMembers = res['data']?['members'] ?? [];
      final List<dynamic> rawFamily = res['data']?['myNonAppFamilyMembers'] ?? [];
      final isLeader = res['data']?['isFamilyLeader'] == true;

      setState(() {
        _allMembers = rawMembers.cast<Map<String, dynamic>>();
        _myFamilyMembers = rawFamily.cast<Map<String, dynamic>>();
        _isFamilyLeader = isLeader;

        // By default, select all members
        for (var m in _allMembers) {
          final key = m['id'];
          _selectedMembers[key] = true;
          _shareControllers[key] = TextEditingController(text: '0.00');
        }
        _isLoading = false;
      });
    } else {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _recalculateEqualSplit() {
    final amount = double.tryParse(_amountController.text.trim()) ?? 0.0;
    final selectedCount = _selectedMembers.values.where((v) => v).length;

    if (selectedCount == 0 || amount <= 0) {
      for (var key in _shareControllers.keys) {
        _shareControllers[key]?.text = '0.00';
      }
      return;
    }

    final totalPaise = (amount * 100).round();
    final baseSharePaise = totalPaise ~/ selectedCount;
    final remainderPaise = totalPaise % selectedCount;

    int allocatedIndex = 0;
    for (var m in _allMembers) {
      final key = m['id'];
      if (_selectedMembers[key] == true) {
        final addPaisa = allocatedIndex < remainderPaise ? 1 : 0;
        final share = (baseSharePaise + addPaisa) / 100.0;
        _shareControllers[key]?.text = share.toStringAsFixed(2);
        allocatedIndex++;
      } else {
        _shareControllers[key]?.text = '0.00';
      }
    }
  }

  double _calculateTotalAllocated() {
    double total = 0.0;
    for (var m in _allMembers) {
      final key = m['id'];
      if (_selectedMembers[key] == true) {
        final share = double.tryParse(_shareControllers[key]?.text.trim() ?? '') ?? 0.0;
        total += share;
      }
    }
    return total;
  }

  Future<void> _submitExpense() async {
    final tripId = widget.tripData?['_id'];
    if (tripId == null) return;

    final totalAmount = double.tryParse(_amountController.text.trim()) ?? 0.0;
    if (totalAmount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid amount')),
      );
      return;
    }

    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter an expense title / note')),
      );
      return;
    }

    final selectedKeys = _selectedMembers.entries.where((e) => e.value).map((e) => e.key).toList();
    if (selectedKeys.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one participant')),
      );
      return;
    }

    final allocated = _calculateTotalAllocated();
    if ((allocated - totalAmount).abs() > 0.05) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Allocated total (₹${allocated.toStringAsFixed(2)}) does not match bill amount (₹${totalAmount.toStringAsFixed(2)})',
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    final participantsPayload = <Map<String, dynamic>>[];
    for (var m in _allMembers) {
      final key = m['id'];
      if (_selectedMembers[key] == true) {
        final share = double.tryParse(_shareControllers[key]?.text.trim() ?? '') ?? 0.0;
        participantsPayload.add({
          'type': m['type'],
          'userId': m['userId'],
          'guestId': m['guestId'],
          'guestName': m['type'] == 'guest' ? m['name'] : null,
          'name': m['name'],
          'shareAmount': share,
        });
      }
    }

    Map<String, dynamic>? customPaidBy;
    if (_selectedPayerType != 'myself') {
      final guest = _myFamilyMembers.firstWhere(
        (m) => m['id'] == _selectedPayerType,
        orElse: () => {},
      );
      customPaidBy = {
        'type': 'guest',
        'guestId': _selectedPayerType,
        'guestName': guest['name'] ?? _selectedPayerName,
      };
    }

    setState(() => _isSubmitting = true);

    final payload = {
      'title': title,
      'amount': totalAmount,
      'splitType': _isCustomSplit ? 'exact' : 'equal',
      'currency': 'INR',
      'participants': participantsPayload,
      if (customPaidBy != null) 'paidBy': customPaidBy,
    };

    final res = await _expenseService.createExpense(tripId, payload);
    if (!mounted) return;

    setState(() => _isSubmitting = false);

    if (res['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Expense split request sent!'),
          backgroundColor: Color(0xFF16A34A),
        ),
      );
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['message'] ?? 'Failed to create expense'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF0F172A)),
          onPressed: () {
            if (_currentStep == 2) {
              setState(() => _currentStep = 1);
            } else {
              Navigator.pop(context);
            }
          },
        ),
        title: Text(
          _currentStep == 1 ? 'New Split' : 'Split Details',
          style: const TextStyle(color: Color(0xFF0F172A), fontSize: 18, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert, color: Color(0xFF0F172A)),
            onPressed: () {},
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF1E5AE6)))
          : SafeArea(
              child: _currentStep == 1 ? _buildStep1Amount() : _buildStep2Split(),
            ),
    );
  }

  // STEP 1: Enter amount to split
  Widget _buildStep1Amount() {
    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Enter amount to split',
                  style: TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    const Text(
                      '₹ ',
                      style: TextStyle(
                        color: Color(0xFF0F172A),
                        fontSize: 44,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IntrinsicWidth(
                      child: TextField(
                        controller: _amountController,
                        autofocus: true,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                        ],
                        style: const TextStyle(
                          color: Color(0xFF0F172A),
                          fontSize: 52,
                          fontWeight: FontWeight.bold,
                        ),
                        decoration: const InputDecoration(
                          hintText: '0',
                          hintStyle: TextStyle(color: Color(0xFFCBD5E1)),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                // Title / note input
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _titleController,
                    style: const TextStyle(color: Color(0xFF0F172A), fontSize: 15),
                    decoration: const InputDecoration(
                      hintText: "What is this for? (e.g., Dinner, Taxi, Rent)",
                      hintStyle: TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
                      border: InputBorder.none,
                      icon: Icon(Icons.edit_note, color: Color(0xFF1E5AE6), size: 22),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        // Next button
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
              onPressed: () {
                final amount = double.tryParse(_amountController.text.trim()) ?? 0.0;
                if (amount <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter an amount greater than 0')),
                  );
                  return;
                }
                if (_titleController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please add a description / title')),
                  );
                  return;
                }
                _recalculateEqualSplit();
                setState(() => _currentStep = 2);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E5AE6),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25),
                ),
                elevation: 0,
              ),
              child: const Text(
                'Next',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // STEP 2: Configure Split (Member selection & custom shares)
  Widget _buildStep2Split() {
    final totalAmount = double.tryParse(_amountController.text.trim()) ?? 0.0;
    final allocated = _calculateTotalAllocated();
    final isDifference = (allocated - totalAmount).abs() > 0.05;

    return Column(
      children: [
        // Top summary
        Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          color: Colors.white,
          child: Column(
            children: [
              const Text(
                'Enter amount to split',
                style: TextStyle(color: Color(0xFF64748B), fontSize: 13, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 6),
              Text(
                '₹ ${totalAmount.toStringAsFixed(totalAmount.truncateToDouble() == totalAmount ? 0 : 2)}',
                style: const TextStyle(
                  color: Color(0xFF0F172A),
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              // Title Pill Chip
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFBFDBFE)),
                ),
                child: Text(
                  _titleController.text.trim(),
                  style: const TextStyle(
                    color: Color(0xFF1E5AE6),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Family Leader Dropdown (if applicable)
        if (_isFamilyLeader && _myFamilyMembers.isNotEmpty)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                const Icon(Icons.person_pin, color: Color(0xFF1E5AE6), size: 20),
                const SizedBox(width: 10),
                const Text(
                  'Paid by: ',
                  style: TextStyle(color: Color(0xFF64748B), fontSize: 13, fontWeight: FontWeight.w500),
                ),
                Expanded(
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedPayerType,
                      dropdownColor: Colors.white,
                      isExpanded: true,
                      icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF1E5AE6)),
                      items: [
                        const DropdownMenuItem(
                          value: 'myself',
                          child: Text(
                            'You (Myself)',
                            style: TextStyle(color: Color(0xFF0F172A), fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                        ),
                        ..._myFamilyMembers.map((m) => DropdownMenuItem(
                              value: m['id'].toString(),
                              child: Text(
                                '${m['name']} (Non-app Family)',
                                style: const TextStyle(color: Color(0xFF0F172A), fontSize: 13),
                              ),
                            )),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _selectedPayerType = val;
                            if (val == 'myself') {
                              _selectedPayerName = 'You';
                            } else {
                              final f = _myFamilyMembers.firstWhere((m) => m['id'] == val);
                              _selectedPayerName = f['name'];
                            }
                          });
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),

        // Split Mode Selector Header
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _isCustomSplit ? 'Split by amounts' : 'Split equally',
                style: const TextStyle(
                  color: Color(0xFF0F172A),
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _isCustomSplit = !_isCustomSplit;
                    if (!_isCustomSplit) {
                      _recalculateEqualSplit();
                    }
                  });
                },
                icon: Icon(
                  _isCustomSplit ? Icons.balance : Icons.edit,
                  color: const Color(0xFF1E5AE6),
                  size: 16,
                ),
                label: Text(
                  _isCustomSplit ? 'Split equally' : 'Custom split',
                  style: const TextStyle(color: Color(0xFF1E5AE6), fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),

        // Allocation difference alert if custom split
        if (_isCustomSplit && isDifference)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: Color(0xFFEF4444), size: 16),
                const SizedBox(width: 6),
                Text(
                  'Allocated: ₹${allocated.toStringAsFixed(2)} / ₹${totalAmount.toStringAsFixed(2)}',
                  style: const TextStyle(color: Color(0xFFEF4444), fontSize: 13, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),

        // Member List with checkboxes and inputs
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: _allMembers.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final member = _allMembers[index];
              final key = member['id'];
              final isSelected = _selectedMembers[key] ?? false;
              final isCurrentUser = member['isCurrentUser'] == true;
              final isGuest = member['type'] == 'guest';

              return Container(
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    // Checkbox
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedMembers[key] = !isSelected;
                          if (!_isCustomSplit) {
                            _recalculateEqualSplit();
                          } else if (!_selectedMembers[key]!) {
                            _shareControllers[key]?.text = '0.00';
                          }
                        });
                      },
                      child: Container(
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
                    ),
                    const SizedBox(width: 14),

                    // Avatar
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: const Color(0xFFEFF6FF),
                      backgroundImage: member['avatar'] != null ? NetworkImage(member['avatar']) : null,
                      child: member['avatar'] == null
                          ? Text(
                              (member['name'] as String).isNotEmpty ? member['name'][0].toUpperCase() : 'U',
                              style: const TextStyle(color: Color(0xFF1E5AE6), fontWeight: FontWeight.bold),
                            )
                          : null,
                    ),
                    const SizedBox(width: 14),

                    // Name + Guest Badge
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isCurrentUser ? 'You' : member['name'],
                            style: const TextStyle(
                              color: Color(0xFF0F172A),
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (isGuest)
                            Text(
                              'Family: ${member['leaderName'] ?? ''}',
                              style: const TextStyle(
                                color: Color(0xFF64748B),
                                fontSize: 11,
                              ),
                            ),
                        ],
                      ),
                    ),

                    // Share input
                    SizedBox(
                      width: 110,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            '₹ ',
                            style: TextStyle(
                              color: isSelected ? const Color(0xFF0F172A) : const Color(0xFF94A3B8),
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(
                            width: 75,
                            child: TextField(
                              controller: _shareControllers[key],
                              enabled: isSelected && _isCustomSplit,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                              ],
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                color: isSelected ? const Color(0xFF0F172A) : const Color(0xFF94A3B8),
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                              decoration: InputDecoration(
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(vertical: 4),
                                enabledBorder: UnderlineInputBorder(
                                  borderSide: BorderSide(
                                    color: _isCustomSplit ? const Color(0xFF1E5AE6) : Colors.transparent,
                                  ),
                                ),
                                disabledBorder: const UnderlineInputBorder(
                                  borderSide: BorderSide(color: Colors.transparent),
                                ),
                              ),
                              onChanged: (_) {
                                if (_isCustomSplit) {
                                  setState(() {});
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),

        // Bottom Send Request Button
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
              onPressed: _isSubmitting ? null : _submitExpense,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E5AE6),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25),
                ),
                elevation: 0,
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text(
                      'Send request',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
            ),
          ),
        ),
      ],
    );
  }
}
