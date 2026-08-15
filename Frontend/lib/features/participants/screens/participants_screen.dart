import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/routes/app_routes.dart';

class ParticipantsScreen extends StatefulWidget {
  final VoidCallback? onBack;

  const ParticipantsScreen({super.key, this.onBack});

  @override
  State<ParticipantsScreen> createState() => _ParticipantsScreenState();
}

class _ParticipantsScreenState extends State<ParticipantsScreen> {
  String _searchQuery = '';

  final List<Map<String, dynamic>> _participants = [
    {
      'name': 'Aastha Patel',
      'role': 'Trip Leader',
      'type': 'Family',
      'group': 'Patel Family',
      'avatar': 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=150&auto=format&fit=crop&q=80',
      'phone': '+91 98765 43210',
    },
    {
      'name': 'Rahul Verma',
      'role': 'Member',
      'type': 'Solo',
      'group': 'Solo Traveler',
      'avatar': 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=150&auto=format&fit=crop&q=80',
      'phone': '+91 99988 87766',
    },
    {
      'name': 'Priya Sharma',
      'role': 'Member',
      'type': 'Solo',
      'group': 'Solo Traveler',
      'avatar': 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=150&auto=format&fit=crop&q=80',
      'phone': '+91 98765 00112',
    },
    {
      'name': 'Vivek Mehta',
      'role': 'Member',
      'type': 'Family',
      'group': 'Mehta Family',
      'avatar': 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=150&auto=format&fit=crop&q=80',
      'phone': '+91 99112 23344',
    },
    {
      'name': 'Rohan Patel',
      'role': 'Member',
      'type': 'Family',
      'group': 'Patel Family',
      'avatar': 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=150&auto=format&fit=crop&q=80',
      'phone': '+91 98765 43211',
    },
    {
      'name': 'Kiran Patel',
      'role': 'Member',
      'type': 'Family',
      'group': 'Patel Family',
      'avatar': 'https://images.unsplash.com/photo-1438761681033-6461ffad8d80?w=150&auto=format&fit=crop&q=80',
      'phone': '+91 98765 43212',
    },
    {
      'name': 'Suresh Mehta',
      'role': 'Member',
      'type': 'Family',
      'group': 'Mehta Family',
      'avatar': 'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=150&auto=format&fit=crop&q=80',
      'phone': '+91 99112 23345',
    },
    {
      'name': 'Anjali Sen',
      'role': 'Member',
      'type': 'Solo',
      'group': 'Solo Traveler',
      'avatar': 'https://images.unsplash.com/photo-1544005313-94ddf0286df2?w=150&auto=format&fit=crop&q=80',
      'phone': '+91 99999 11111',
    },
  ];

  List<Map<String, dynamic>> get _filteredParticipants {
    if (_searchQuery.isEmpty) return _participants;
    return _participants.where((p) {
      return p['name'].toString().toLowerCase().contains(_searchQuery.toLowerCase()) ||
          p['group'].toString().toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();
  }



  @override
  Widget build(BuildContext context) {
    // Calculations for analytics
    final totalMembers = _participants.length;
    // Families count: unique group names that are not 'Solo Traveler'
    final uniqueFamilies = _participants
        .where((p) => p['type'] == 'Family')
        .map((p) => p['group'])
        .toSet()
        .length;
    final totalSolo = _participants.where((p) => p['type'] == 'Solo').length;

    final filtered = _filteredParticipants;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),

      body: SafeArea(
        child: Column(
          children: [
            // Custom Header (Unified with documents navbar style)
            Container(
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
                            child: Image.network(
                              'https://images.unsplash.com/photo-1502602898657-3e91760cbb34?w=150&auto=format&fit=crop&q=80',
                              height: 48,
                              width: 48,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => Container(
                                height: 48,
                                width: 48,
                                color: Colors.grey[200],
                                child: const Icon(Icons.image, color: Colors.grey),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Trip Members',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: const [
                                    Icon(
                                      Icons.calendar_today_outlined,
                                      size: 11,
                                      color: Color(0xFF64748B),
                                    ),
                                    SizedBox(width: 4),
                                    Text(
                                      'May 20 – May 27, 2025 • 8 Members',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Color(0xFF64748B),
                                        fontWeight: FontWeight.w500,
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
                  IconButton(
                    icon: const Icon(Icons.person_add_alt_1_outlined, color: AppColors.primary),
                    onPressed: () async {
                      final acceptedUser = await Navigator.pushNamed(context, AppRoutes.joinRequests);
                      if (acceptedUser != null && acceptedUser is Map<String, dynamic>) {
                        setState(() {
                          _participants.add(acceptedUser);
                        });
                      }
                    },
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: widget.onBack ?? () => Navigator.pop(context),
                    child: const CircleAvatar(
                      radius: 20,
                      backgroundImage: NetworkImage(
                        'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=150&auto=format&fit=crop&q=80',
                      ),
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Analytics Divs Row
                    Row(
                      children: [
                        // Total Members
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.01),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEFF6FF),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(Icons.groups_outlined, color: Color(0xFF1E5AE6), size: 18),
                                ),
                                const SizedBox(height: 10),
                                const Text(
                                  'Members',
                                  style: TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w500),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '$totalMembers Travelers',
                                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Total Families
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.01),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFECFDF5),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(Icons.family_restroom_outlined, color: Color(0xFF10B981), size: 18),
                                ),
                                const SizedBox(height: 10),
                                const Text(
                                  'Families',
                                  style: TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w500),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '$uniqueFamilies Groups',
                                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Total Solo
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.01),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFF7ED),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(Icons.person_outline, color: Color(0xFFF97316), size: 18),
                                ),
                                const SizedBox(height: 10),
                                const Text(
                                  'Solo Travelers',
                                  style: TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w500),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '$totalSolo Travelers',
                                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Search box
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.02),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: TextField(
                        onChanged: (val) {
                          setState(() {
                            _searchQuery = val;
                          });
                        },
                        decoration: const InputDecoration(
                          hintText: 'Search members or families...',
                          hintStyle: TextStyle(color: AppColors.textLight, fontSize: 14),
                          prefixIcon: Icon(Icons.search, color: AppColors.primary, size: 20),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Title
                    const Text(
                      'All Travelers List',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Members List
                    filtered.isEmpty
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 40),
                              child: Text('No members match your search'),
                            ),
                          )
                        : Column(
                            children: filtered.map((member) {
                              final isLeader = member['role'] == 'Trip Leader';
                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                ),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                  leading: CircleAvatar(
                                    radius: 22,
                                    backgroundImage: NetworkImage(member['avatar']),
                                  ),
                                  title: Row(
                                    children: [
                                      Text(
                                        member['name'],
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                      if (isLeader) ...[
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFEFF6FF),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: const Text(
                                            'Leader',
                                            style: TextStyle(
                                              fontSize: 8,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF1E5AE6),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  subtitle: Text(
                                    '${member['group']} • ${member['phone']}',
                                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                  ),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.call_outlined, color: AppColors.primary, size: 20),
                                    onPressed: () {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('Calling ${member['name']}...')),
                                      );
                                    },
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
