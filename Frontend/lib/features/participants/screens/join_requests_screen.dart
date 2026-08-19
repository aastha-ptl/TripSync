import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

import '../../trip/services/trip_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:tripsync/core/utils/image_utils.dart';

class JoinRequestsScreen extends StatefulWidget {
  final Map<String, dynamic>? tripData;

  const JoinRequestsScreen({super.key, this.tripData});

  @override
  State<JoinRequestsScreen> createState() => _JoinRequestsScreenState();
}

class _JoinRequestsScreenState extends State<JoinRequestsScreen> {
  final TripService _tripService = TripService();
  bool _isLoading = true;
  List<Map<String, dynamic>> _pendingRequests = [];

  @override
  void initState() {
    super.initState();
    _fetchJoinRequests();
  }

  Future<void> _fetchJoinRequests() async {
    if (widget.tripData == null || widget.tripData!['id'] == null) {
      setState(() => _isLoading = false);
      return;
    }

    final response = await _tripService.getJoinRequests(widget.tripData!['id']);
    if (response['success'] == true) {
      setState(() {
        _pendingRequests = List<Map<String, dynamic>>.from(response['data']);
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(response['message'] ?? 'Failed to load requests')),
        );
      }
    }
  }


  Future<void> _acceptRequest(int index) async {
    if (widget.tripData == null) return;
    
    final acceptedUser = _pendingRequests[index];
    final requestId = acceptedUser['id'];

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => _buildConfirmationDialog(
        title: 'Approve Request',
        message: 'Are you sure you want to approve ${acceptedUser['name']}\'s request to join?',
        confirmText: 'Approve',
        confirmColor: const Color(0xFF20C060),
        icon: Icons.check_circle_outline,
      ),
    );

    if (confirmed != true) return;

    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    final response = await _tripService.updateJoinRequest(widget.tripData!['id'], requestId, 'approved');
    
    // Hide loading
    Navigator.pop(context);

    if (response['success'] == true) {
      setState(() {
        _pendingRequests.removeAt(index);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${acceptedUser['name']} has been added to the trip!'),
            backgroundColor: const Color(0xFF20C060),
          ),
        );
        // We will return the accepted user back so the parent screen knows it was accepted
        Navigator.pop(context, acceptedUser);
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(response['message'] ?? 'Failed to approve request')),
        );
      }
    }
  }

  Future<void> _declineRequest(int index) async {
    if (widget.tripData == null) return;

    final declinedUser = _pendingRequests[index];
    final requestId = declinedUser['id'];

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => _buildConfirmationDialog(
        title: 'Reject Request',
        message: 'Are you sure you want to reject ${declinedUser['name']}\'s request?',
        confirmText: 'Reject',
        confirmColor: const Color(0xFFEF4444),
        icon: Icons.cancel_outlined,
      ),
    );

    if (confirmed != true) return;

    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    final response = await _tripService.updateJoinRequest(widget.tripData!['id'], requestId, 'rejected');
    
    // Hide loading
    Navigator.pop(context);

    if (response['success'] == true) {
      setState(() {
        _pendingRequests.removeAt(index);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Declined request from ${declinedUser['name']}'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(response['message'] ?? 'Failed to decline request')),
        );
      }
    }
  }

  void _showAddMemberDialog() {
    final nameController = TextEditingController();
    String selectedType = 'Solo';
    String selectedGroup = 'Solo Traveler';

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              title: const Text('Add Trip Member Manually', style: TextStyle(fontWeight: FontWeight.bold)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Full Name',
                      hintText: 'Enter name',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: selectedType,
                    decoration: const InputDecoration(
                      labelText: 'Traveler Type',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'Solo', child: Text('Solo Traveler')),
                      DropdownMenuItem(value: 'Family', child: Text('Family Member')),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() {
                          selectedType = val;
                          if (val == 'Solo') {
                            selectedGroup = 'Solo Traveler';
                          } else {
                            selectedGroup = 'Patel Family';
                          }
                        });
                      }
                    },
                  ),
                  if (selectedType == 'Family') ...[
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: selectedGroup,
                      decoration: const InputDecoration(
                        labelText: 'Select Family Group',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'Patel Family', child: Text('Patel Family')),
                        DropdownMenuItem(value: 'Mehta Family', child: Text('Mehta Family')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() {
                            selectedGroup = val;
                          });
                        }
                      },
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (nameController.text.isNotEmpty) {
                      final newUser = {
                        'name': nameController.text.trim(),
                        'role': 'Member',
                        'type': selectedType,
                        'group': selectedGroup,
                        'avatar': 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=150&auto=format&fit=crop&q=80',
                        'phone': '+91 99900 11223',
                      };
                      Navigator.pop(context); // Pop dialog
                      Navigator.pop(context, newUser); // Pop screen and return new member
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                  child: const Text('Add', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildConfirmationDialog({
    required String title,
    required String message,
    required String confirmText,
    required Color confirmColor,
    required IconData icon,
  }) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Icon(icon, color: confirmColor, size: 28),
          const SizedBox(width: 10),
          Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18))),
        ],
      ),
      content: Text(
        message,
        style: const TextStyle(color: Color(0xFF64748B), fontSize: 15, height: 1.4),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          ),
          child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.bold)),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          style: ElevatedButton.styleFrom(
            backgroundColor: confirmColor,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 0,
          ),
          child: Text(
            confirmText,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  void _showUserInfoModal(Map<String, dynamic> user) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Avatar
            Hero(
              tag: 'avatar_${user['id']}',
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.grey[100],
                  image: user['avatar'] != null
                      ? DecorationImage(
                          image: CachedNetworkImageProvider(ImageUtils.getOptimizedImageUrl(user['avatar'])),
                          fit: BoxFit.cover,
                        )
                      : null,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: user['avatar'] == null
                    ? const Center(child: Text('👤', style: TextStyle(fontSize: 40)))
                    : null,
              ),
            ),
            const SizedBox(height: 16),
            // Name
            Text(
              user['name'] ?? 'Unknown User',
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 8),
            // Role / Group badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                user['group'] ?? 'Member',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ),
            const SizedBox(height: 24),
            // Contact info
            _buildUserInfoRow(Icons.phone_outlined, 'Phone', user['phone'] ?? 'N/A'),
            const SizedBox(height: 16),
            _buildUserInfoRow(Icons.access_time_outlined, 'Requested', user['time'] != null ? _formatDate(user['time']) : 'Unknown'),
            const SizedBox(height: 32),
            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      int idx = _pendingRequests.indexWhere((r) => r['id'] == user['id']);
                      if (idx != -1) _declineRequest(idx);
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: const BorderSide(color: Color(0xFFEF4444)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: const Text('Reject', style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      int idx = _pendingRequests.indexWhere((r) => r['id'] == user['id']);
                      if (idx != -1) _acceptRequest(idx);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF20C060),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: const Text('Accept', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildUserInfoRow(IconData icon, String title, String value) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: const Color(0xFF64748B), size: 20),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF0F172A),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatDate(String isoString) {
    try {
      final date = DateTime.parse(isoString);
      final now = DateTime.now();
      final diff = now.difference(date);
      if (diff.inDays == 0) {
        if (diff.inHours == 0) {
          return '${diff.inMinutes} minutes ago';
        }
        return '${diff.inHours} hours ago';
      }
      return '${diff.inDays} days ago';
    } catch (e) {
      return isoString;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF00C6FF), Color(0xFF0072FF)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ),
        title: const Text(
          'Join Requests',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 17,
          ),
        ),
        centerTitle: true,
      ),
      body: _pendingRequests.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: const BoxDecoration(
                      color: Color(0xFFEFF6FF),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.people_outline,
                      size: 40,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No Pending Requests',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'All travelers have been reviewed.',
                    style: TextStyle(
                      fontSize: 13,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _pendingRequests.length,
              itemBuilder: (context, index) {
                final req = _pendingRequests[index];
                return GestureDetector(
                  onTap: () => _showUserInfoModal(req),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.01),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                  child: Row(
                    children: [
                      // Avatar
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: Colors.grey[200],
                        backgroundImage: CachedNetworkImageProvider(ImageUtils.getOptimizedImageUrl(req['avatar'], fallbackName: req['name'])),
                        child: null,
                      ),
                      const SizedBox(width: 12),
                      // Details
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              req['name'],
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 3),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEFF6FF),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    req['group'],
                                    style: const TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    req['time'],
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: Color(0xFF94A3B8),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      // Actions
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.close, color: Color(0xFFEF4444), size: 20),
                            onPressed: () => _declineRequest(index),
                          ),
                          const SizedBox(width: 4),
                          IconButton(
                            icon: const Icon(Icons.check, color: Color(0xFF20C060), size: 20),
                            onPressed: () => _acceptRequest(index),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
      floatingActionButton: Container(
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: [Color(0xFF00C6FF), Color(0xFF0072FF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: FloatingActionButton(
          onPressed: _showAddMemberDialog,
          backgroundColor: Colors.transparent,
          elevation: 0,
          highlightElevation: 0,
          child: const Icon(Icons.add, color: Colors.white),
        ),
      ),
    );
  }
}
