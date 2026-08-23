import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../services/trip_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:tripsync/core/utils/image_utils.dart';
import '../../../core/utils/date_formatter.dart';

class JoinTripScreen extends StatefulWidget {
  final String? inviteToken;
  const JoinTripScreen({super.key, this.inviteToken});

  @override
  State<JoinTripScreen> createState() => _JoinTripScreenState();
}

class _JoinTripScreenState extends State<JoinTripScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _tokenController = TextEditingController();
  final TripService _tripService = TripService();
  bool _isLoading = false;
  Map<String, dynamic>? _tripInfo;
  bool _showPreview = false;

  bool _addingFamilyMembers = false;
  final List<Map<String, TextEditingController>> _familyMemberControllers = [];

  bool get _isFamilyTrip {
    if (_tripInfo == null) return false;
    final type = _tripInfo!['tripType'];
    final bType = _tripInfo!['businessTripType'];
    return type == 'Family' || (type == 'Business' && bType == 'Employees + Family');
  }

  void _addFamilyMember() {
    setState(() {
      _familyMemberControllers.add({
        'name': TextEditingController(),
        'age': TextEditingController(),
        'relationship': TextEditingController(),
        'email': TextEditingController(),
        'phone': TextEditingController(),
      });
    });
  }

  void _removeFamilyMember(int index) {
    setState(() {
      final controllers = _familyMemberControllers.removeAt(index);
      controllers.values.forEach((c) => c.dispose());
    });
  }

  @override
  void initState() {
    super.initState();
    if (widget.inviteToken != null) {
      _tokenController.text = widget.inviteToken!;
      _fetchTripInfo(widget.inviteToken!);
    }
  }

  Future<void> _fetchTripInfo(String token) async {
    setState(() {
      _isLoading = true;
    });

    final response = await _tripService.getInviteInfo(token);

    if (!mounted) return;

    if (response['success'] == true && response['data'] != null) {
      setState(() {
        _tripInfo = response['data'];
        _showPreview = true;
        _isLoading = false;
      });
    } else {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(response['message'] ?? 'Invalid or expired invite token'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  void dispose() {
    _tokenController.dispose();
    for (var controllers in _familyMemberControllers) {
      controllers.values.forEach((c) => c.dispose());
    }
    super.dispose();
  }

  Future<void> _submitJoin() async {
    if (!_showPreview) {
      // If we aren't previewing yet, we just validate and fetch info
      if (!_formKey.currentState!.validate()) return;
      final token = _tokenController.text.trim();
      await _fetchTripInfo(token);
      return;
    }

    // Actually join the trip
    if (!_formKey.currentState!.validate()) return;
    
    setState(() {
      _isLoading = true;
    });

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

    final token = _tokenController.text.trim();
    final response = await _tripService.joinTrip(token, familyMembers: familyMembers);

    setState(() {
      _isLoading = false;
    });

    if (!mounted) return;

    if (response['success'] == true) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: Color(0xFFE6F7ED),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle,
                  color: AppColors.secondary,
                  size: 48,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Join Request Added!',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
               'Your trip join request has been added successfully. '
  'Please wait for the trip leader to approve your request.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context); // Pop dialog
                  Navigator.pushNamedAndRemoveUntil(
                    context, 
                    '/dashboard', 
                    (route) => false,
                  ); // Go to Home and clear deep link stack
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Go to Home'),
              ),
            ],
          ),
        ),
      );
    } else {
      final msg = response['message'] as String? ?? 'Failed to join trip';
      if (msg == "You are already part of an approved trip during these dates.") {
        _showOverlapDialog(context);
      } else if (msg.contains("is not registered in the system")) {
        _showMemberErrorDialog(
          context,
          'Unregistered Member Email',
          msg,
        );
      } else if (msg.contains("already has an approved trip clashing")) {
        _showMemberErrorDialog(
          context,
          'Member Schedule Conflict',
          msg,
        );
      } else {
        _showMemberErrorDialog(
          context,
          'Error Joining Trip',
          msg,
        );
      }
    }
  }

  void _showOverlapDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0xFFFEE2E2), // light red
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.event_busy,
                color: AppColors.error,
                size: 48,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Schedule Conflict',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'You are already part of an approved trip during these dates. Please check your schedule and try again.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Understood'),
            ),
          ],
        ),
      ),
    );
  }

  void _showMemberErrorDialog(BuildContext context, String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0xFFFEE2E2), // light red
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.warning_amber_rounded,
                color: AppColors.error,
                size: 48,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textPrimary,
                height: 1.5,
              ),
            ),

            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Understood'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Join a Trip',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                const Text(
                  'Have an Invite Token?',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Enter the invite token below to join an existing trip and start planning together.',
                  style: TextStyle(
                    fontSize: 15,
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
                ),
                if (_showPreview) ...[
                  const SizedBox(height: 24),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_tripInfo?['coverImage'] != null && _tripInfo!['coverImage'].toString().isNotEmpty) ...[
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: CachedNetworkImage(imageUrl: ImageUtils.getOptimizedImageUrl(_tripInfo!['coverImage']),
                              width: double.infinity,
                              height: 140,
                              fit: BoxFit.cover,
                              errorWidget: (context, url, error) => Container(
                                height: 140,
                                color: const Color(0xFFF1F5F9),
                                child: const Center(child: Icon(Icons.image_not_supported, color: Colors.grey)),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                        Text(
                          _tripInfo?['name'] ?? 'Trip Name',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        if (_tripInfo?['startDate'] != null && _tripInfo?['endDate'] != null) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(Icons.calendar_today_outlined, size: 14, color: Color(0xFF64748B)),
                              const SizedBox(width: 4),
                              Text(
                                _formatDates(_tripInfo!['startDate'], _tripInfo!['endDate']),
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                '•',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF94A3B8),
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Icon(Icons.wb_sunny_outlined, size: 14, color: Color(0xFF64748B)),
                              const SizedBox(width: 4),
                              Text(
                                '${TripInfoHelper.parseTripDate(_tripInfo!['endDate']).difference(TripInfoHelper.parseTripDate(_tripInfo!['startDate'])).inDays + 1} Days',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 12),
                        Text(
                          _tripInfo?['description'] ?? 'No description provided.',
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 40),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (!_showPreview) ...[
                          const Text(
                            'Invite Token',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _tokenController,
                            decoration: InputDecoration(
                              hintText: 'e.g. 7cf70f4e44de',
                              hintStyle: TextStyle(color: Colors.grey[400]),
                              prefixIcon: const Icon(Icons.vpn_key_outlined, color: AppColors.primary),
                              filled: true,
                              fillColor: const Color(0xFFF9FAFB),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: Color(0xFFF3F4F6), width: 1),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                              ),
                              errorBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: AppColors.error, width: 1),
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Please enter an invite token';
                              }
                              return null;
                            },
                          ),
                        ],
                        if (_showPreview && _isFamilyTrip) ...[
                          const SizedBox(height: 24),
                          const Text(
                            'Who is joining?',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: RadioListTile<bool>(
                                  title: const Text('Only Me', style: TextStyle(fontSize: 14)),
                                  value: false,
                                  groupValue: _addingFamilyMembers,
                                  contentPadding: EdgeInsets.zero,
                                  onChanged: (val) {
                                    setState(() {
                                      _addingFamilyMembers = val ?? false;
                                    });
                                  },
                                ),
                              ),
                              Expanded(
                                child: RadioListTile<bool>(
                                  title: const Text('Me + Family', style: TextStyle(fontSize: 14)),
                                  value: true,
                                  groupValue: _addingFamilyMembers,
                                  contentPadding: EdgeInsets.zero,
                                  onChanged: (val) {
                                    setState(() {
                                      _addingFamilyMembers = val ?? true;
                                      if (_addingFamilyMembers && _familyMemberControllers.isEmpty) {
                                        _addFamilyMember();
                                      }
                                    });
                                  },
                                ),
                              ),
                            ],
                          ),
                          if (_addingFamilyMembers) ...[
                            const SizedBox(height: 16),
                            for (int i = 0; i < _familyMemberControllers.length; i++)
                              Container(
                                margin: const EdgeInsets.only(bottom: 16),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF9FAFB),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFFEEF2F6)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'Family Member ${i + 1}',
                                          style: const TextStyle(fontWeight: FontWeight.bold),
                                        ),
                                        if (_familyMemberControllers.length > 1)
                                          IconButton(
                                            icon: const Icon(Icons.remove_circle_outline, color: AppColors.error),
                                            onPressed: () => _removeFamilyMember(i),
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    TextFormField(
                                      controller: _familyMemberControllers[i]['name'],
                                      decoration: const InputDecoration(labelText: 'Name', isDense: true),
                                      validator: (val) => val == null || val.trim().isEmpty ? 'Required' : null,
                                    ),
                                    const SizedBox(height: 12),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: TextFormField(
                                            controller: _familyMemberControllers[i]['age'],
                                            decoration: const InputDecoration(labelText: 'Age', isDense: true),
                                            keyboardType: TextInputType.number,
                                            validator: (val) => val == null || val.trim().isEmpty ? 'Required' : null,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: TextFormField(
                                            controller: _familyMemberControllers[i]['relationship'],
                                            decoration: const InputDecoration(labelText: 'Relation', isDense: true),
                                            validator: (val) => val == null || val.trim().isEmpty ? 'Required' : null,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    TextFormField(
                                      controller: _familyMemberControllers[i]['email'],
                                      decoration: const InputDecoration(labelText: 'Email (Optional)', isDense: true),
                                      keyboardType: TextInputType.emailAddress,
                                    ),
                                    const SizedBox(height: 12),
                                    TextFormField(
                                      controller: _familyMemberControllers[i]['phone'],
                                      decoration: const InputDecoration(labelText: 'Phone (Optional)', isDense: true),
                                      keyboardType: TextInputType.phone,
                                    ),
                                  ],
                                ),
                              ),
                            TextButton.icon(
                              onPressed: _addFamilyMember,
                              icon: const Icon(Icons.add),
                              label: const Text('Add Another Member'),
                            ),
                          ],
                        ],
                        const SizedBox(height: 32),
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _submitJoin,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    height: 24,
                                    width: 24,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Text(
                                    _showPreview ? 'Join This Trip' : 'Continue',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                        ),
                        if (_showPreview) ...[
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: OutlinedButton(
                              onPressed: () {
                                setState(() {
                                  _showPreview = false;
                                  _tripInfo = null;
                                  _tokenController.clear();
                                });
                              },
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.textSecondary,
                                side: const BorderSide(color: Color(0xFFE2E8F0)),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text('Change Token'),
                            ),
                          ),
                        ]
                      ],
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

  String _formatDates(String startStr, String endStr) {
    try {
      final start = TripInfoHelper.parseTripDate(startStr);
      final end = TripInfoHelper.parseTripDate(endStr);
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${months[start.month - 1]} ${start.day} – ${months[end.month - 1]} ${end.day}, ${end.year}';
    } catch (e) {
      return '';
    }
  }
}
