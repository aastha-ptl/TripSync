import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/constants/api_endpoints.dart';
import '../../../core/utils/date_formatter.dart';
import '../../itinerary/services/itinerary_service.dart';
import '../services/trip_expense_service.dart';

class TripExpenseCreateScreen extends StatefulWidget {
  final Map<String, dynamic>? tripData;
  final Map<String, dynamic>? existingExpense;

  const TripExpenseCreateScreen({
    super.key,
    this.tripData,
    this.existingExpense,
  });

  @override
  State<TripExpenseCreateScreen> createState() => _TripExpenseCreateScreenState();
}

class _TripExpenseCreateScreenState extends State<TripExpenseCreateScreen> {
  final TripExpenseService _expenseService = TripExpenseService();
  final ItineraryService _itineraryService = ItineraryService();
  final ImagePicker _picker = ImagePicker();

  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  bool _isLoading = true;
  bool _isSubmitting = false;

  // Days & Itinerary activities
  List<Map<String, dynamic>> _tripDays = [];
  int _selectedDayNumber = 1;
  List<Map<String, dynamic>> _allItineraryDaysData = [];
  List<Map<String, dynamic>> _currentDayActivities = [];
  String? _selectedActivityId; // null (Select Activity hint), 'other', or activity _id
  double? _estimatedAmount; // Total estimated amount for the expense
  double? _activityEstimatedPerPerson; // Base per-person cost from itinerary
  bool _isEstimatedPerPerson = true; // Default: itinerary cost is per person
  bool _hasUserManuallyChangedAmount = false; // Tracks if user typed custom actual amount

  // Category
  String _selectedCategory = 'food';
  final List<Map<String, dynamic>> _categories = [
    {'id': 'food', 'label': 'Food', 'icon': Icons.restaurant_outlined, 'color': Color(0xFF20C060)},
    {'id': 'travel', 'label': 'Travel', 'icon': Icons.directions_car_outlined, 'color': Color(0xFF0EA5E9)},
    {'id': 'accommodation', 'label': 'Stay', 'icon': Icons.hotel_outlined, 'color': Color(0xFF9333EA)},
    {'id': 'activities', 'label': 'Activities', 'icon': Icons.local_activity_outlined, 'color': Color(0xFFEC4899)},
    {'id': 'shopping', 'label': 'Shopping', 'icon': Icons.shopping_bag_outlined, 'color': Color(0xFFF59E0B)},
    {'id': 'tickets', 'label': 'Tickets', 'icon': Icons.confirmation_number_outlined, 'color': Color(0xFF6366F1)},
    {'id': 'medical', 'label': 'Medical', 'icon': Icons.medical_services_outlined, 'color': Color(0xFFEF4444)},
    {'id': 'other', 'label': 'Other', 'icon': Icons.more_horiz_outlined, 'color': Color(0xFF64748B)},
  ];

  // Members & Split
  List<Map<String, dynamic>> _allMembers = [];
  List<Map<String, dynamic>> _myFamilyMembers = [];
  bool _isFamilyLeader = false;
  String _selectedPayerType = 'myself'; // 'myself' or guestId
  String _selectedPayerName = 'You';

  bool _isCustomSplit = false;
  final Map<String, bool> _selectedMembers = {};
  final Map<String, TextEditingController> _shareControllers = {};

  // Receipt Proof File
  File? _proofFile;
  String? _existingReceiptUrl;
  bool _removeReceipt = false;

  @override
  void initState() {
    super.initState();
    _initData();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _titleController.dispose();
    _notesController.dispose();
    for (var controller in _shareControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _initData() async {
    final tripId = widget.tripData?['_id'];
    if (tripId == null) {
      setState(() => _isLoading = false);
      return;
    }

    _calculateTripDays();

    // Fetch members and itinerary in parallel
    final results = await Future.wait([
      _expenseService.getMembers(tripId),
      _itineraryService.getItinerary(tripId),
    ]);

    final membersRes = results[0];
    final itineraryRes = results[1];

    if (mounted) {
      // Members setup
      if (membersRes['success'] == true) {
        final List<dynamic> rawMembers = membersRes['data']?['members'] ?? [];
        final List<dynamic> rawFamily = membersRes['data']?['myNonAppFamilyMembers'] ?? [];
        _isFamilyLeader = membersRes['data']?['isFamilyLeader'] == true;
        _allMembers = rawMembers.cast<Map<String, dynamic>>();
        _myFamilyMembers = rawFamily.cast<Map<String, dynamic>>();

        for (var m in _allMembers) {
          final key = m['id'];
          _selectedMembers[key] = true;
          _shareControllers[key] = TextEditingController(text: '0.00');
        }
      }

      // Itinerary setup
      if (itineraryRes['success'] == true) {
        final List<dynamic> daysData = itineraryRes['data'] ?? [];
        _allItineraryDaysData = daysData.cast<Map<String, dynamic>>();
      }

      // Populate existing expense data if editing
      if (widget.existingExpense != null) {
        final exp = widget.existingExpense!;
        _selectedDayNumber = exp['dayNumber'] ?? 1;
        _titleController.text = exp['title'] ?? '';
        _notesController.text = exp['description'] ?? exp['notes'] ?? '';
        _amountController.text = (exp['amount'] ?? '').toString();
        _selectedCategory = exp['category'] ?? 'other';
        _existingReceiptUrl = exp['receiptUrl'];

        if (exp['expenseType'] == 'itinerary' && exp['itineraryId'] != null) {
          _selectedActivityId = exp['itineraryId'].toString();
          _estimatedAmount = exp['estimatedAmount'] != null ? (exp['estimatedAmount'] as num).toDouble() : null;
          _hasUserManuallyChangedAmount = true;
        } else {
          _selectedActivityId = 'other';
        }

        if (exp['splitType'] == 'exact') {
          _isCustomSplit = true;
        }
      }

      _updateActivitiesForDay(_selectedDayNumber);
      _recalculateEqualSplit();

      setState(() => _isLoading = false);
    }
  }

  void _calculateTripDays() {
    if (widget.tripData?['startDate'] != null && widget.tripData?['endDate'] != null) {
      try {
        final start = TripInfoHelper.parseTripDate(widget.tripData!['startDate'].toString());
        final end = TripInfoHelper.parseTripDate(widget.tripData!['endDate'].toString());

        final duration = end.difference(start).inDays + 1;
        _tripDays = List.generate(duration, (i) {
          final dayDate = start.add(Duration(days: i));
          return {
            'dayNumber': i + 1,
            'label': 'Day ${i + 1} (${DateFormat('MMM d').format(dayDate)})',
            'date': dayDate,
          };
        });
      } catch (e) {
        debugPrint('Error calculating trip days: $e');
      }
    }

    if (_tripDays.isEmpty) {
      _tripDays = [
        {'dayNumber': 1, 'label': 'Day 1', 'date': DateTime.now()}
      ];
    }
  }

  String _toTitleCase(String? text) {
    if (text == null || text.trim().isEmpty) return '';
    return text.trim().split(RegExp(r'\s+')).map((word) {
      if (word.isEmpty) return '';
      return word[0].toUpperCase() + (word.length > 1 ? word.substring(1).toLowerCase() : '');
    }).join(' ');
  }

  void _updateActivitiesForDay(int dayNum) {
    List<Map<String, dynamic>> activities = [];
    for (var day in _allItineraryDaysData) {
      if (day['dayNumber'] == dayNum) {
        final List<dynamic> acts = day['activities'] ?? [];
        for (var act in acts) {
          double? estCost;
          if (act['estimatedCost'] != null && act['estimatedCost'] > 0) {
            estCost = (act['estimatedCost'] as num).toDouble();
          }
          activities.add({
            '_id': act['_id'].toString(),
            'title': act['title'] ?? 'Activity',
            'type': act['type'] ?? 'other',
            'estimatedCost': estCost,
            'location': act['location']?['name'] ?? '',
          });
        }
        break;
      }
    }

    setState(() {
      _selectedDayNumber = dayNum;
      _currentDayActivities = activities;

      // Reset activity if not present in current day or new expense
      if (widget.existingExpense == null) {
        _selectedActivityId = null;
        _estimatedAmount = null;
        _activityEstimatedPerPerson = null;
      } else if (_selectedActivityId != 'other' && _selectedActivityId != null) {
        final exists = _currentDayActivities.any((a) => a['_id'] == _selectedActivityId);
        if (!exists) {
          _selectedActivityId = 'other';
          _estimatedAmount = null;
          _activityEstimatedPerPerson = null;
        } else {
          final act = _currentDayActivities.firstWhere((a) => a['_id'] == _selectedActivityId, orElse: () => {});
          _activityEstimatedPerPerson = act['estimatedCost'];
        }
      }
    });
  }

  void _syncEstimatedAndActualAmount({bool forceUpdateActual = false}) {
    if (_selectedActivityId == null || _selectedActivityId == 'other' || _activityEstimatedPerPerson == null || _activityEstimatedPerPerson! <= 0) {
      if (_selectedActivityId == 'other') {
        _estimatedAmount = null;
      }
      return;
    }

    final selectedCount = _selectedMembers.values.where((v) => v).length;
    final multiplier = _isEstimatedPerPerson ? (selectedCount > 0 ? selectedCount : 1) : 1;
    _estimatedAmount = _activityEstimatedPerPerson! * multiplier;

    if (forceUpdateActual || !_hasUserManuallyChangedAmount || _amountController.text.trim().isEmpty) {
      _amountController.text = _estimatedAmount!.toStringAsFixed(0);
      _recalculateEqualSplit();
    }
  }

  void _onActivityChanged(String? val) {
    if (val == null) return;
    setState(() {
      _selectedActivityId = val;
      if (val == 'other') {
        _estimatedAmount = null;
        _activityEstimatedPerPerson = null;
        if (widget.existingExpense == null || widget.existingExpense!['expenseType'] != 'other') {
          _titleController.clear();
        }
      } else {
        final act = _currentDayActivities.firstWhere((a) => a['_id'] == val, orElse: () => {});
        _titleController.text = act['title'] ?? '';
        _activityEstimatedPerPerson = act['estimatedCost'];

        // Automatically select matching category if applicable
        final actType = act['type']?.toString().toLowerCase();
        if (actType != null) {
          if (actType == 'transport') {
            _selectedCategory = 'travel';
          } else if (actType == 'lodging') {
            _selectedCategory = 'accommodation';
          } else if (actType == 'food') {
            _selectedCategory = 'food';
          } else if (actType == 'sightseeing') {
            _selectedCategory = 'activities';
          } else if (_categories.any((c) => c['id'] == actType)) {
            _selectedCategory = actType;
          }
        }

        _syncEstimatedAndActualAmount(forceUpdateActual: true);
      }
    });
  }

  void _recalculateEqualSplit() {
    if (_isCustomSplit) return;
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

  Future<void> _pickReceiptImage(ImageSource source) async {
    try {
      final XFile? picked = await _picker.pickImage(
        source: source,
        imageQuality: 80,
      );
      if (picked != null) {
        setState(() {
          _proofFile = File(picked.path);
          _removeReceipt = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick image: $e')),
        );
      }
    }
  }

  Future<void> _pickReceiptDocument() async {
    try {
      final platformFile = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'webp', 'heic', 'heif'],
      );
      if (platformFile != null && platformFile.path != null) {
        final pickedFile = File(platformFile.path!);
        final length = await pickedFile.length();
        if (length > 50 * 1024 * 1024) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('File exceeds 50MB limit. Please choose a smaller file.')),
            );
          }
          return;
        }
        setState(() {
          _proofFile = pickedFile;
          _removeReceipt = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick document: $e')),
        );
      }
    }
  }

  Future<void> _saveExpense() async {
    final tripId = widget.tripData?['_id'];
    if (tripId == null) return;

    final actualAmount = double.tryParse(_amountController.text.trim()) ?? 0.0;
    if (actualAmount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid actual expense amount')),
      );
      return;
    }

    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter an expense title / name')),
      );
      return;
    }

    final selectedKeys = _selectedMembers.entries.where((e) => e.value).map((e) => e.key).toList();
    if (selectedKeys.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one participating member')),
      );
      return;
    }

    final allocated = _calculateTotalAllocated();
    if ((allocated - actualAmount).abs() > 0.05) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Sum of member shares (₹${allocated.toStringAsFixed(2)}) must equal total actual expense (₹${actualAmount.toStringAsFixed(2)})',
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
          'guestName': m['type'] == 'guest' ? (m['actualName'] ?? m['name']) : null,
          'name': m['actualName'] ?? m['name'],
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

    final isOther = _selectedActivityId == 'other' || _selectedActivityId == null;
    final payload = {
      'dayNumber': _selectedDayNumber,
      'expenseType': isOther ? 'other' : 'itinerary',
      if (!isOther) 'itineraryId': _selectedActivityId,
      if (!isOther && _estimatedAmount != null) 'estimatedAmount': _estimatedAmount,
      'title': title,
      'description': _notesController.text.trim(),
      'amount': actualAmount,
      'category': _selectedCategory,
      'splitType': _isCustomSplit ? 'exact' : 'equal',
      'currency': 'INR',
      'participants': participantsPayload,
      if (customPaidBy != null) 'paidBy': customPaidBy,
    };

    Map<String, dynamic> res;
    final isEdit = widget.existingExpense != null;

    if (isEdit) {
      final expenseId = widget.existingExpense!['_id'];
      res = await _expenseService.updateExpenseWithFile(
        tripId,
        expenseId,
        payload,
        filePath: _proofFile?.path,
        removeReceipt: _removeReceipt,
      );
    } else {
      res = await _expenseService.createExpenseWithFile(
        tripId,
        payload,
        filePath: _proofFile?.path,
      );
    }

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (res['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_outline, color: Colors.white),
              const SizedBox(width: 10),
              Text(isEdit ? 'Expense successfully updated!' : 'Expense successfully saved!'),
            ],
          ),
          backgroundColor: AppColors.secondary,
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['message'] ?? 'Failed to ${isEdit ? 'update' : 'create'} expense'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: _buildAppBar(),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionTitle('Day & Activity Selection'),
                  const SizedBox(height: 12),
                  _buildDaySelector(),
                  const SizedBox(height: 16),
                  _buildActivitySelector(),
                  if (_selectedActivityId == 'other') ...[
                    const SizedBox(height: 16),
                    _buildInputField(
                      controller: _titleController,
                      label: 'Other Expense Name',
                      hint: 'What is this expense for? (e.g. Snacks, Souvenirs, Taxi fare, Tip)',
                      icon: Icons.edit_note_outlined,
                    ),
                  ],
                  const SizedBox(height: 24),

                  _buildSectionTitle('Expense Notes'),
                  const SizedBox(height: 12),
                  _buildInputField(
                    controller: _notesController,
                    label: 'Description / Notes (Optional)',
                    hint: 'Details, restaurant name, vendor info...',
                    icon: Icons.description_outlined,
                  ),
                  const SizedBox(height: 24),

                  _buildSectionTitle('Category'),
                  const SizedBox(height: 12),
                  _buildCategoryGrid(),
                  const SizedBox(height: 24),

                  _buildSectionTitle('Actual Amount & Difference'),
                  const SizedBox(height: 12),
                  _buildActualAmountSection(),
                  const SizedBox(height: 24),

                  _buildSectionTitle('Participants & Split Shares'),
                  const SizedBox(height: 12),
                  _buildSplitSection(),
                  const SizedBox(height: 24),

                  _buildSectionTitle('Bill / Receipt Proof (Optional)'),
                  const SizedBox(height: 12),
                  _buildProofUploadSection(),
                  const SizedBox(height: 24),

                  _buildSectionTitle('Expense Summary Preview'),
                  const SizedBox(height: 12),
                  _buildSummaryPreviewCard(),
                  const SizedBox(height: 32),

                  _buildSaveButton(),
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    final isEdit = widget.existingExpense != null;
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 4,
      shadowColor: Colors.black.withOpacity(0.12),
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
      title: Text(
        isEdit ? 'Edit Expense' : 'Add Expense',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.bold,
        color: AppColors.textPrimary,
      ),
    );
  }

  Widget _buildDaySelector() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.01),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: DropdownButtonFormField<int>(
        isExpanded: true,
        value: _selectedDayNumber,
        decoration: const InputDecoration(
          labelText: 'Select Day',
          labelStyle: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          prefixIcon: Icon(Icons.calendar_today_outlined, color: AppColors.textSecondary, size: 18),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.textSecondary),
        dropdownColor: Colors.white,
        borderRadius: BorderRadius.circular(16),
        items: _tripDays.map((day) {
          return DropdownMenuItem<int>(
            value: day['dayNumber'] as int,
            child: Text(
              day['label'] as String,
              style: const TextStyle(fontSize: 14, color: AppColors.textPrimary, fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
          );
        }).toList(),
        onChanged: (val) {
          if (val != null) {
            _updateActivitiesForDay(val);
          }
        },
      ),
    );
  }

  Widget _buildActivitySelector() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.01),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: DropdownButtonFormField<String>(
        isExpanded: true,
        value: _selectedActivityId,
        hint: const Text('Select Activity', style: TextStyle(color: AppColors.textLight, fontSize: 14)),
        decoration: const InputDecoration(
          labelText: 'Select Activity',
          labelStyle: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          prefixIcon: Icon(Icons.explore_outlined, color: AppColors.textSecondary, size: 18),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.textSecondary),
        dropdownColor: Colors.white,
        borderRadius: BorderRadius.circular(16),
        items: [
          ..._currentDayActivities.map((act) {
            final estCost = act['estimatedCost'];
            final estStr = estCost != null ? ' (Est: ₹${(estCost as num).toStringAsFixed(0)}/person)' : '';
            return DropdownMenuItem<String>(
              value: act['_id'] as String,
              child: Text(
                '${act['title']}$estStr',
                style: const TextStyle(fontSize: 14, color: AppColors.textPrimary, fontWeight: FontWeight.w500),
                overflow: TextOverflow.ellipsis,
              ),
            );
          }),
          const DropdownMenuItem<String>(
            value: 'other',
            child: Text(
              'Other',
              style: TextStyle(fontSize: 14, color: AppColors.textPrimary, fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
        onChanged: _onActivityChanged,
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.01),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
          hintText: hint,
          hintStyle: const TextStyle(color: AppColors.textLight, fontSize: 13),
          prefixIcon: Icon(icon, color: AppColors.textSecondary, size: 18),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }

  Widget _buildCategoryGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.1,
      ),
      itemCount: _categories.length,
      itemBuilder: (context, index) {
        final cat = _categories[index];
        final isSelected = _selectedCategory == cat['id'];
        final Color catColor = cat['color'];
        return GestureDetector(
          onTap: () => setState(() => _selectedCategory = cat['id']),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: isSelected ? catColor.withOpacity(0.15) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected ? catColor : const Color(0xFFE2E8F0),
                width: isSelected ? 2.0 : 1.0,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(cat['icon'], color: isSelected ? catColor : AppColors.textSecondary, size: 22),
                const SizedBox(height: 6),
                Text(
                  cat['label'],
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected ? catColor : AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildActualAmountSection() {
    final actualAmount = double.tryParse(_amountController.text.trim()) ?? 0.0;
    final selectedCount = _selectedMembers.values.where((v) => v).length;

    String? diffText;
    Color diffColor = Colors.grey;
    IconData diffIcon = Icons.info_outline;

    if (_selectedActivityId != 'other') {
      if (_estimatedAmount != null && _estimatedAmount! > 0) {
        final diff = actualAmount - _estimatedAmount!;
        if (diff > 0) {
          diffText = '₹${diff.toStringAsFixed(0)} more than estimated';
          diffColor = const Color(0xFFEA580C);
          diffIcon = Icons.arrow_upward;
        } else if (diff < 0) {
          diffText = '₹${(-diff).toStringAsFixed(0)} less than estimated';
          diffColor = const Color(0xFF20C060);
          diffIcon = Icons.arrow_downward;
        } else {
          diffText = 'Same as estimated';
          diffColor = const Color(0xFF0EA5E9);
          diffIcon = Icons.check;
        }
      } else {
        diffText = 'Estimated cost not available';
      }
    } else {
      diffText = 'Estimated: Not applicable';
    }

    final hasActivityCost = _selectedActivityId != null &&
        _selectedActivityId != 'other' &&
        _activityEstimatedPerPerson != null &&
        _activityEstimatedPerPerson! > 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.01),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Estimated info reference & difference
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _selectedActivityId != 'other'
                          ? 'Estimated: ${_estimatedAmount != null && _estimatedAmount! > 0 ? "₹${_estimatedAmount!.toStringAsFixed(0)}" : "N/A"}'
                          : 'Estimated: Not applicable',
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (hasActivityCost) ...[
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          const Icon(Icons.people_outline, size: 13, color: AppColors.textSecondary),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              _isEstimatedPerPerson
                                  ? '₹${_activityEstimatedPerPerson!.toStringAsFixed(0)} / person × $selectedCount participants'
                                  : 'Fixed group total (₹${_activityEstimatedPerPerson!.toStringAsFixed(0)})',
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: diffColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(diffIcon, size: 12, color: diffColor),
                    const SizedBox(width: 4),
                    Text(
                      diffText,
                      style: TextStyle(color: diffColor, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Estimation mode toggle chips (Per person vs fixed total)
          if (hasActivityCost) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                GestureDetector(
                  onTap: () {
                    if (!_isEstimatedPerPerson) {
                      setState(() {
                        _isEstimatedPerPerson = true;
                        _syncEstimatedAndActualAmount(forceUpdateActual: !_hasUserManuallyChangedAmount);
                      });
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: _isEstimatedPerPerson ? AppColors.primary.withOpacity(0.12) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _isEstimatedPerPerson ? AppColors.primary : const Color(0xFFCBD5E1),
                        width: _isEstimatedPerPerson ? 1.5 : 1.0,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_isEstimatedPerPerson) ...[
                          const Icon(Icons.check, size: 12, color: AppColors.primary),
                          const SizedBox(width: 4),
                        ],
                        Text(
                          'Per Person (₹${(_activityEstimatedPerPerson! * (selectedCount > 0 ? selectedCount : 1)).toStringAsFixed(0)})',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: _isEstimatedPerPerson ? FontWeight.bold : FontWeight.w500,
                            color: _isEstimatedPerPerson ? AppColors.primary : AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () {
                    if (_isEstimatedPerPerson) {
                      setState(() {
                        _isEstimatedPerPerson = false;
                        _syncEstimatedAndActualAmount(forceUpdateActual: !_hasUserManuallyChangedAmount);
                      });
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: !_isEstimatedPerPerson ? AppColors.primary.withOpacity(0.12) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: !_isEstimatedPerPerson ? AppColors.primary : const Color(0xFFCBD5E1),
                        width: !_isEstimatedPerPerson ? 1.5 : 1.0,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (!_isEstimatedPerPerson) ...[
                          const Icon(Icons.check, size: 12, color: AppColors.primary),
                          const SizedBox(width: 4),
                        ],
                        Text(
                          'Fixed Total (₹${_activityEstimatedPerPerson!.toStringAsFixed(0)})',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: !_isEstimatedPerPerson ? FontWeight.bold : FontWeight.w500,
                            color: !_isEstimatedPerPerson ? AppColors.primary : AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 14),

          // Actual Amount Input Field
          TextFormField(
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
            ],
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            decoration: InputDecoration(
              labelText: 'Actual Amount Spent (₹)',
              labelStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
              hintText: 'e.g. 750',
              prefixIcon: const Icon(Icons.currency_rupee, color: AppColors.primary, size: 22),
              suffixIcon: (_hasUserManuallyChangedAmount && _estimatedAmount != null && _estimatedAmount! > 0)
                  ? TextButton(
                      onPressed: () {
                        setState(() {
                          _hasUserManuallyChangedAmount = false;
                          _amountController.text = _estimatedAmount!.toStringAsFixed(0);
                          if (!_isCustomSplit) {
                            _recalculateEqualSplit();
                          }
                        });
                      },
                      child: const Text('Reset', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary)),
                    )
                  : null,
              border: const OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(12)),
              ),
            ),
            onChanged: (_) {
              _hasUserManuallyChangedAmount = true;
              if (!_isCustomSplit) {
                _recalculateEqualSplit();
              }
              setState(() {});
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSplitSection() {
    final actualAmount = double.tryParse(_amountController.text.trim()) ?? 0.0;
    final allocated = _calculateTotalAllocated();
    final remaining = actualAmount - allocated;
    final isBalanced = remaining.abs() <= 0.05;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header + Toggle
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _isCustomSplit ? 'Custom Split Shares' : 'Equal Split Shares',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
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
                icon: Icon(_isCustomSplit ? Icons.balance : Icons.edit_note, size: 16, color: AppColors.primary),
                label: Text(
                  _isCustomSplit ? 'Equal Split' : 'Edit Shares',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Payer selection dropdown
          if ((_isFamilyLeader || _myFamilyMembers.isNotEmpty) && _myFamilyMembers.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.payment_outlined, size: 16, color: AppColors.textSecondary),
                  const SizedBox(width: 8),
                  const Text('Paid by: ', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  Expanded(
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedPayerType,
                        dropdownColor: Colors.white,
                        isExpanded: true,
                        items: [
                          const DropdownMenuItem(
                            value: 'myself',
                            child: Text('You (Myself)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                          ),
                          ..._myFamilyMembers.map((m) => DropdownMenuItem(
                                value: m['id'].toString(),
                                child: Text('${m['name']} (Family Member)', style: const TextStyle(fontSize: 13)),
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
            const SizedBox(height: 12),
          ],

          // Balance Validation Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isBalanced ? const Color(0xFFF0FDF4) : const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isBalanced ? const Color(0xFFBBF7D0) : const Color(0xFFFCA5A5)),
            ),
            child: Row(
              children: [
                Icon(
                  isBalanced ? Icons.check_circle : Icons.warning_amber_rounded,
                  size: 16,
                  color: isBalanced ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isBalanced
                        ? 'Split total matches actual expense (₹${actualAmount.toStringAsFixed(2)})'
                        : remaining > 0
                            ? 'Remaining to allocate: ₹${remaining.toStringAsFixed(2)}'
                            : 'Over-allocated by: ₹${(-remaining).toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isBalanced ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Member List
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _allMembers.length,
            separatorBuilder: (_, __) => const Divider(height: 16, color: Color(0xFFF1F5F9)),
            itemBuilder: (context, index) {
              final member = _allMembers[index];
              final key = member['id'];
              final isSelected = _selectedMembers[key] ?? false;
              final isCurrentUser = member['isCurrentUser'] == true;
              final isFamilyMember = member['isFamilyMember'] == true;
              final leaderName = member['leaderName']?.toString().trim();
              final displayName = isCurrentUser ? 'You' : (member['name'] ?? 'User').toString();

              return Row(
                children: [
                  Checkbox(
                    value: isSelected,
                    activeColor: AppColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    onChanged: (val) {
                      setState(() {
                        _selectedMembers[key] = val ?? false;
                        if (_selectedActivityId != null && _selectedActivityId != 'other' && _activityEstimatedPerPerson != null) {
                          _syncEstimatedAndActualAmount(forceUpdateActual: !_hasUserManuallyChangedAmount);
                        }
                        if (!_isCustomSplit) {
                          _recalculateEqualSplit();
                        }
                      });
                    },
                  ),
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: const Color(0xFFEFF6FF),
                    backgroundImage: member['avatar'] != null ? NetworkImage(member['avatar']) : null,
                    child: member['avatar'] == null
                        ? Text(
                            displayName.isNotEmpty ? displayName[0].toUpperCase() : 'M',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary),
                          )
                        : null,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          displayName,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                        ),
                        if (isFamilyMember && leaderName != null && leaderName.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            'Family Leader: ${_toTitleCase(leaderName)}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF64748B),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  SizedBox(
                    width: 100,
                    child: TextField(
                      controller: _shareControllers[key],
                      enabled: isSelected && _isCustomSplit,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                      ],
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: isSelected ? AppColors.textPrimary : AppColors.textLight,
                      ),
                      decoration: const InputDecoration(
                        prefixText: '₹ ',
                        prefixStyle: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(vertical: 4),
                        border: InputBorder.none,
                      ),
                      onChanged: (_) {
                        if (_isCustomSplit) {
                          setState(() {});
                        }
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  bool _isPdfPath(String? path) {
    if (path == null) return false;
    return path.toLowerCase().contains('.pdf');
  }

  Future<void> _openLocalOrRemotePdf({String? localPath, String? remoteUrl}) async {
    try {
      Uri? uri;
      if (localPath != null && localPath.isNotEmpty) {
        uri = Uri.file(localPath);
      } else if (remoteUrl != null && remoteUrl.isNotEmpty) {
        final cleanUrl = remoteUrl.trim().replaceAll('\\', '/');
        final fullUrl = ApiEndpoints.buildImageUrl(cleanUrl);
        uri = Uri.parse(fullUrl);
      }

      if (uri == null) return;

      bool launched = false;
      try {
        launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (_) {}

      if (!launched) {
        try {
          launched = await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
        } catch (_) {}
      }

      if (!launched) {
        try {
          launched = await launchUrl(uri, mode: LaunchMode.platformDefault);
        } catch (_) {}
      }

      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open PDF file'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error opening PDF: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  void _showReplaceProofBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Replace Proof File',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined, color: AppColors.primary),
                title: const Text('Take Photo with Camera'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickReceiptImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined, color: AppColors.primary),
                title: const Text('Choose Image from Gallery'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickReceiptImage(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(Icons.picture_as_pdf_outlined, color: Colors.redAccent),
                title: const Text('Select PDF / Document File'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickReceiptDocument();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProofUploadSection() {
    final isLocalPdf = _proofFile != null && _isPdfPath(_proofFile!.path);
    final isExistingPdf = _existingReceiptUrl != null && _isPdfPath(_existingReceiptUrl) && !_removeReceipt;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_proofFile != null || (_existingReceiptUrl != null && !_removeReceipt)) ...[
            if (isLocalPdf || isExistingPdf) ...[
              InkWell(
                onTap: () {
                  if (_proofFile != null) {
                    _openLocalOrRemotePdf(localPath: _proofFile!.path);
                  } else if (_existingReceiptUrl != null) {
                    _openLocalOrRemotePdf(remoteUrl: _existingReceiptUrl);
                  }
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  height: 120,
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFCA5A5)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.picture_as_pdf, size: 44, color: Color(0xFFDC2626)),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _proofFile != null
                                  ? _proofFile!.path.split(Platform.pathSeparator).last
                                  : _existingReceiptUrl!.split('/').last,
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            const Text('PDF Document attached (Tap to view)', style: TextStyle(fontSize: 11, color: Color(0xFFDC2626), fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                      const Icon(Icons.open_in_new, size: 18, color: Color(0xFFDC2626)),
                    ],
                  ),
                ),
              ),
            ] else ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  height: 180,
                  width: double.infinity,
                  color: const Color(0xFFF1F5F9),
                  child: _proofFile != null
                      ? Image.file(_proofFile!, fit: BoxFit.cover)
                      : Image.network(
                          ApiEndpoints.buildImageUrl(_existingReceiptUrl!),
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.receipt_long, size: 40, color: Colors.grey)),
                        ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                if (isLocalPdf || isExistingPdf) ...[
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        if (_proofFile != null) {
                          _openLocalOrRemotePdf(localPath: _proofFile!.path);
                        } else if (_existingReceiptUrl != null) {
                          _openLocalOrRemotePdf(remoteUrl: _existingReceiptUrl);
                        }
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFDC2626),
                        side: const BorderSide(color: Color(0xFFFCA5A5)),
                      ),
                      icon: const Icon(Icons.visibility_outlined, size: 16),
                      label: const Text('View PDF'),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _showReplaceProofBottomSheet,
                    icon: const Icon(Icons.swap_horiz, size: 16),
                    label: const Text('Replace'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      setState(() {
                        _proofFile = null;
                        _removeReceipt = true;
                      });
                    },
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                    icon: const Icon(Icons.delete_outline, size: 16),
                    label: const Text('Remove'),
                  ),
                ),
              ],
            ),
          ] else ...[
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => _pickReceiptImage(ImageSource.camera),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: const Column(
                        children: [
                          Icon(Icons.camera_alt_outlined, color: AppColors.primary, size: 20),
                          SizedBox(height: 4),
                          Text('Camera', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary)),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: InkWell(
                    onTap: () => _pickReceiptImage(ImageSource.gallery),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: const Column(
                        children: [
                          Icon(Icons.photo_library_outlined, color: AppColors.primary, size: 20),
                          SizedBox(height: 4),
                          Text('Gallery', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary)),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: InkWell(
                    onTap: _pickReceiptDocument,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFFCA5A5)),
                      ),
                      child: const Column(
                        children: [
                          Icon(Icons.picture_as_pdf_outlined, color: Colors.redAccent, size: 20),
                          SizedBox(height: 4),
                          Text('PDF / File', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.redAccent)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSummaryPreviewCard() {
    final actualAmount = double.tryParse(_amountController.text.trim()) ?? 0.0;
    final selectedCount = _selectedMembers.values.where((v) => v).length;
    final title = _titleController.text.trim().isEmpty ? 'Untitled Expense' : _titleController.text.trim();
    final hasProof = _proofFile != null || (_existingReceiptUrl != null && !_removeReceipt);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFCBD5E1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Day $_selectedDayNumber • $title',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '₹${actualAmount.toStringAsFixed(2)}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primary),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text('Category: ${_selectedCategory == "accommodation" ? "STAY" : _selectedCategory.toUpperCase()}', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              const Spacer(),
              Text('Participants: $selectedCount', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(hasProof ? Icons.attachment : Icons.link_off, size: 14, color: hasProof ? Colors.green : Colors.grey),
              const SizedBox(width: 4),
              Text(
                hasProof ? 'Bill receipt attached' : 'No bill attached',
                style: TextStyle(fontSize: 11, color: hasProof ? Colors.green : Colors.grey, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSaveButton() {
    final actualAmount = double.tryParse(_amountController.text.trim()) ?? 0.0;
    final allocated = _calculateTotalAllocated();
    final isBalanced = (allocated - actualAmount).abs() <= 0.05 && actualAmount > 0;

    return Container(
      width: double.infinity,
      height: 52,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: isBalanced
              ? [const Color(0xFF00C6FF), const Color(0xFF0072FF)]
              : [Colors.grey.shade400, Colors.grey.shade600],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: ElevatedButton(
        onPressed: (_isSubmitting || !isBalanced) ? null : _saveExpense,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: _isSubmitting
            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : Text(
                widget.existingExpense != null ? 'Update Expense' : 'Save Expense',
                style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
              ),
      ),
    );
  }
}
