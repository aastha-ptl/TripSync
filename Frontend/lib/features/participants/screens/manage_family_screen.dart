import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../trip/services/trip_service.dart';

class ManageFamilyScreen extends StatefulWidget {
  final Map<String, dynamic>? tripData;

  const ManageFamilyScreen({super.key, required this.tripData});

  @override
  State<ManageFamilyScreen> createState() => _ManageFamilyScreenState();
}

class _ManageFamilyScreenState extends State<ManageFamilyScreen> {
  final _formKey = GlobalKey<FormState>();
  final TripService _tripService = TripService();

  bool _isLoading = true;
  bool _isSaving = false;
  bool _addingFamilyMembers = false;

  final List<Map<String, TextEditingController>> _familyMemberControllers = [];

  @override
  void initState() {
    super.initState();
    _loadFamilyData();
  }

  void _addFamilyMember({
    String name = '',
    String age = '',
    String relationship = '',
    String email = '',
    String phone = '',
  }) {
    setState(() {
      _familyMemberControllers.add({
        'name': TextEditingController(text: name),
        'age': TextEditingController(text: age),
        'relationship': TextEditingController(text: relationship),
        'email': TextEditingController(text: email),
        'phone': TextEditingController(text: phone),
      });
    });
  }

  void _removeFamilyMember(int index) {
    setState(() {
      final removed = _familyMemberControllers.removeAt(index);
      for (var controller in removed.values) {
        controller.dispose();
      }
    });
  }

  Future<void> _loadFamilyData() async {
    final tripId = widget.tripData?['id'] ?? widget.tripData?['_id'];
    if (tripId == null) {
      setState(() => _isLoading = false);
      return;
    }

    final res = await _tripService.getMyFamily(tripId.toString());
    if (!mounted) return;

    if (res['success'] == true && res['data'] != null) {
      final data = res['data'];
      final family = data['family'];

      final List membersList = (family != null && family['members'] is List)
          ? family['members']
          : [];

      if (membersList.isNotEmpty) {
        _addingFamilyMembers = true;
        for (var m in membersList) {
          _addFamilyMember(
            name: m['name'] ?? '',
            age: m['age']?.toString() ?? '',
            relationship: m['relationship'] ?? '',
            email: m['email'] ?? '',
            phone: m['phone'] ?? '',
          );
        }
      } else {
        // If no members are saved, default to "Only Me"
        _addingFamilyMembers = false;
      }
    } else {
      _addingFamilyMembers = false;
    }

    setState(() {
      _isLoading = false;
    });
  }

  @override
  void dispose() {
    for (var controllers in _familyMemberControllers) {
      for (var c in controllers.values) {
        c.dispose();
      }
    }
    super.dispose();
  }

  Future<void> _submitFamilyDetails() async {
    final tripId = widget.tripData?['id'] ?? widget.tripData?['_id'];
    if (tripId == null) return;

    if (_addingFamilyMembers) {
      if (!_formKey.currentState!.validate()) return;
      if (_familyMemberControllers.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please add at least one family member or select "Only Me".'),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }
    }

    setState(() => _isSaving = true);

    // Validate email registration for each member if provided
    if (_addingFamilyMembers) {
      // 1. Check duplicate emails in the form
      final enteredEmails = <String>{};
      for (int i = 0; i < _familyMemberControllers.length; i++) {
        final emailText = _familyMemberControllers[i]['email']!.text.trim().toLowerCase();
        if (emailText.isNotEmpty) {
          if (enteredEmails.contains(emailText)) {
            setState(() => _isSaving = false);
            if (!mounted) return;
            showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                title: const Row(
                  children: [
                    Icon(Icons.error_outline, color: AppColors.error),
                    SizedBox(width: 8),
                    Text('Duplicate Email', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ],
                ),
                content: Text(
                  'Email $emailText cannot be added more than once in the same family.',
                  style: const TextStyle(fontSize: 14),
                ),
                actions: [
                  ElevatedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                    child: const Text('OK', style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            );
            return;
          }
          enteredEmails.add(emailText);
        }
      }

      // 2. Validate email registration, schedule conflict, and existing trip membership
      for (int i = 0; i < _familyMemberControllers.length; i++) {
        final emailText = _familyMemberControllers[i]['email']!.text.trim();
        if (emailText.isNotEmpty) {
          final checkRes = await _tripService.checkFamilyMemberEmail(tripId.toString(), emailText);
          if (checkRes['success'] != true) {
            setState(() => _isSaving = false);
            if (!mounted) return;
            showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                title: const Row(
                  children: [
                    Icon(Icons.error_outline, color: AppColors.error),
                    SizedBox(width: 8),
                    Text('Cannot Add Member', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ],
                ),
                content: Text(
                  checkRes['message'] ?? 'Email $emailText cannot be added.',
                  style: const TextStyle(fontSize: 14),
                ),
                actions: [
                  ElevatedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                    child: const Text('OK', style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            );
            return;
          }
        }
      }
    }

    List<Map<String, dynamic>> familyMembers = [];
    if (_addingFamilyMembers) {
      for (var controllers in _familyMemberControllers) {
        familyMembers.add({
          'name': controllers['name']!.text.trim(),
          'age': int.tryParse(controllers['age']!.text.trim()) ?? 0,
          'relationship': controllers['relationship']!.text.trim(),
          'email': controllers['email']!.text.trim().isEmpty ? null : controllers['email']!.text.trim(),
          'phone': controllers['phone']!.text.trim().isEmpty ? null : controllers['phone']!.text.trim(),
        });
      }
    }

    final res = await _tripService.saveFamilyMembers(tripId.toString(), familyMembers);

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (res['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['message'] ?? 'Family details saved successfully!'),
          backgroundColor: const Color(0xFF10B981),
        ),
      );
      Navigator.pop(context, true);
    } else {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Cannot Save Family', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.error)),
          content: Text(res['message'] ?? 'Failed to update family details'),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              child: const Text('OK', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final tripName = widget.tripData?['name'] ?? widget.tripData?['title'] ?? 'Trip';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF0F172A)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Family Details',
              style: TextStyle(
                color: Color(0xFF0F172A),
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              tripName,
              style: const TextStyle(
                color: Color(0xFF64748B),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Status Notice
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
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
                            const Text(
                              'Who is joining with you?',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Choose whether you are traveling alone or with family members.',
                              style: TextStyle(
                                fontSize: 13,
                                color: Color(0xFF64748B),
                              ),
                            ),
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                Expanded(
                                  child: InkWell(
                                    onTap: () {
                                      setState(() {
                                        _addingFamilyMembers = false;
                                      });
                                    },
                                    borderRadius: BorderRadius.circular(12),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                      decoration: BoxDecoration(
                                        color: !_addingFamilyMembers
                                            ? const Color(0xFFEFF6FF)
                                            : const Color(0xFFF8FAFC),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: !_addingFamilyMembers
                                              ? AppColors.primary
                                              : const Color(0xFFE2E8F0),
                                          width: !_addingFamilyMembers ? 1.5 : 1,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            !_addingFamilyMembers
                                                ? Icons.radio_button_checked
                                                : Icons.radio_button_off,
                                            size: 18,
                                            color: !_addingFamilyMembers
                                                ? AppColors.primary
                                                : const Color(0xFF94A3B8),
                                          ),
                                          const SizedBox(width: 8),
                                          const Text(
                                            'Only Me',
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF0F172A),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: InkWell(
                                    onTap: () {
                                      setState(() {
                                        _addingFamilyMembers = true;
                                        if (_familyMemberControllers.isEmpty) {
                                          _addFamilyMember();
                                        }
                                      });
                                    },
                                    borderRadius: BorderRadius.circular(12),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                      decoration: BoxDecoration(
                                        color: _addingFamilyMembers
                                            ? const Color(0xFFEFF6FF)
                                            : const Color(0xFFF8FAFC),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: _addingFamilyMembers
                                              ? AppColors.primary
                                              : const Color(0xFFE2E8F0),
                                          width: _addingFamilyMembers ? 1.5 : 1,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            _addingFamilyMembers
                                                ? Icons.radio_button_checked
                                                : Icons.radio_button_off,
                                            size: 18,
                                            color: _addingFamilyMembers
                                                ? AppColors.primary
                                                : const Color(0xFF94A3B8),
                                          ),
                                          const SizedBox(width: 8),
                                          const Text(
                                            'Me + Family',
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF0F172A),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Family Members Section
                      if (_addingFamilyMembers) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Family Members (${_familyMemberControllers.length})',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            TextButton.icon(
                              onPressed: () => _addFamilyMember(),
                              icon: const Icon(Icons.add, size: 18),
                              label: const Text('Add Member'),
                              style: TextButton.styleFrom(
                                foregroundColor: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        for (int i = 0; i < _familyMemberControllers.length; i++)
                          Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
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
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(6),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFECFDF5),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: const Icon(
                                            Icons.person_outline,
                                            size: 16,
                                            color: Color(0xFF10B981),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Family Member ${i + 1}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                            color: Color(0xFF0F172A),
                                          ),
                                        ),
                                      ],
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, color: Color(0xFFEF4444), size: 20),
                                      onPressed: () => _removeFamilyMember(i),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 14),
                                TextFormField(
                                  controller: _familyMemberControllers[i]['name'],
                                  decoration: const InputDecoration(
                                    labelText: 'Full Name *',
                                    isDense: true,
                                    prefixIcon: Icon(Icons.person, size: 18),
                                  ),
                                  validator: (val) => val == null || val.trim().isEmpty ? 'Name is required' : null,
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextFormField(
                                        controller: _familyMemberControllers[i]['age'],
                                        decoration: const InputDecoration(
                                          labelText: 'Age *',
                                          isDense: true,
                                          prefixIcon: Icon(Icons.cake_outlined, size: 18),
                                        ),
                                        keyboardType: TextInputType.number,
                                        validator: (val) {
                                          if (val == null || val.trim().isEmpty) return 'Age required';
                                          if (int.tryParse(val.trim()) == null) return 'Invalid age';
                                          return null;
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: TextFormField(
                                        controller: _familyMemberControllers[i]['relationship'],
                                        decoration: const InputDecoration(
                                          labelText: 'Relationship *',
                                          hintText: 'e.g. Spouse, Child',
                                          isDense: true,
                                          prefixIcon: Icon(Icons.people_outline, size: 18),
                                        ),
                                        validator: (val) => val == null || val.trim().isEmpty ? 'Relationship required' : null,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: _familyMemberControllers[i]['email'],
                                  decoration: const InputDecoration(
                                    labelText: 'Email (Optional)',
                                    helperText: 'Must be registered in TripSync if provided',
                                    isDense: true,
                                    prefixIcon: Icon(Icons.email_outlined, size: 18),
                                  ),
                                  keyboardType: TextInputType.emailAddress,
                                  validator: (val) {
                                    if (val != null && val.trim().isNotEmpty) {
                                      final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                                      if (!emailRegex.hasMatch(val.trim())) {
                                        return 'Please enter a valid email';
                                      }
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: _familyMemberControllers[i]['phone'],
                                  decoration: const InputDecoration(
                                    labelText: 'Phone (Optional)',
                                    isDense: true,
                                    prefixIcon: Icon(Icons.phone_outlined, size: 18),
                                  ),
                                  keyboardType: TextInputType.phone,
                                ),
                              ],
                            ),
                          ),

                        OutlinedButton.icon(
                          onPressed: () => _addFamilyMember(),
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Add Another Member'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primary,
                            side: const BorderSide(color: AppColors.primary),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            minimumSize: const Size(double.infinity, 45),
                          ),
                        ),
                      ] else ...[
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Center(
                            child: Column(
                              children: [
                                const Icon(Icons.person_pin_circle_outlined, size: 48, color: Color(0xFF94A3B8)),
                                const SizedBox(height: 12),
                                const Text(
                                  'Traveling as Solo Traveler',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                const Text(
                                  'You are registered individually. If your family joins this trip later, switch to "Me + Family" above to add their details.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],

                      const SizedBox(height: 32),

                      // Submit Button
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _isSaving ? null : _submitFamilyDetails,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          child: _isSaving
                              ? const SizedBox(
                                  height: 22,
                                  width: 22,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                )
                              : const Text(
                                  'Save Details',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}
