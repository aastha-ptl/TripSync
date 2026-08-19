import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/routes/app_routes.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:tripsync/core/utils/image_utils.dart';

class MembersListScreen extends StatefulWidget {
  const MembersListScreen({super.key});

  @override
  State<MembersListScreen> createState() => _MembersListScreenState();
}

class _MembersListScreenState extends State<MembersListScreen> {
  String _searchQuery = '';

  final List<Map<String, dynamic>> _allMembers = [
    {
      'name': 'Aastha Patel',
      'avatar': 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=150&auto=format&fit=crop&q=80',
      'subtitle': '3 Documents',
      'documents': [
        {
          'name': 'Aadhaar Card',
          'number': 'XXXX XXXX 1234',
          'category': 'Personal',
          'format': 'PDF',
          'size': '1.2 MB',
          'date': '10 Aug 2026',
          'icon': Icons.badge_outlined,
          'color': const Color(0xFF0284C7),
        },
        {
          'name': 'PAN Card',
          'number': 'XXXXX5678Z',
          'category': 'Personal',
          'format': 'PNG',
          'size': '850 KB',
          'date': '09 Aug 2026',
          'icon': Icons.badge_outlined,
          'color': const Color(0xFF0D9488),
        },
        {
          'name': 'Passport',
          'number': 'ZXXXX5678',
          'category': 'Personal',
          'format': 'PDF',
          'size': '2.4 MB',
          'date': '09 Aug 2026',
          'icon': Icons.menu_book_outlined,
          'color': const Color(0xFF4F46E5),
        },
      ]
    },
    {
      'name': 'Rahul Verma',
      'avatar': 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=150&auto=format&fit=crop&q=80',
      'subtitle': '2 Documents',
      'documents': [
        {
          'name': 'PAN Card',
          'number': 'XXXXX9012Y',
          'category': 'Personal',
          'format': 'PNG',
          'size': '780 KB',
          'date': '10 Aug 2026',
          'icon': Icons.badge_outlined,
          'color': const Color(0xFF0D9488),
        },
        {
          'name': 'Flight Ticket',
          'number': 'Air India - AI456',
          'category': 'Tickets',
          'format': 'PDF',
          'size': '1.5 MB',
          'date': '09 Aug 2026',
          'icon': Icons.local_activity_outlined,
          'color': const Color(0xFFEA580C),
        },
      ]
    },
    {
      'name': 'Priya Sharma',
      'avatar': 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=150&auto=format&fit=crop&q=80',
      'subtitle': '2 Documents',
      'documents': [
        {
          'name': 'Aadhaar Card',
          'number': 'XXXX XXXX 9988',
          'category': 'Personal',
          'format': 'PDF',
          'size': '1.3 MB',
          'date': '10 Aug 2026',
          'icon': Icons.badge_outlined,
          'color': const Color(0xFF0284C7),
        },
        {
          'name': 'Hotel Booking',
          'number': 'Booking ID: 112233',
          'category': 'Bookings',
          'format': 'PDF',
          'size': '1.1 MB',
          'date': '09 Aug 2026',
          'icon': Icons.apartment_outlined,
          'color': const Color(0xFF16A34A),
        },
      ]
    },
    {
      'name': 'Vivek Mehta',
      'avatar': 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=150&auto=format&fit=crop&q=80',
      'subtitle': '1 Document',
      'documents': [
        {
          'name': 'Passport',
          'number': 'ZXXXX9988',
          'category': 'Personal',
          'format': 'PDF',
          'size': '2.1 MB',
          'date': '10 Aug 2026',
          'icon': Icons.menu_book_outlined,
          'color': const Color(0xFF4F46E5),
        },
      ]
    },
  ];

  List<Map<String, dynamic>> get _filteredMembers {
    if (_searchQuery.isEmpty) return _allMembers;
    return _allMembers.where((m) {
      return m['name'].toString().toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredMembers;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 1.0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 12,
                offset: const Offset(0, 3),
              ),
            ],
          ),
        ),
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary, size: 20),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ),
        title: const Text(
          'Member Folders',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 17,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Container(
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
                  hintText: 'Search members...',
                  hintStyle: TextStyle(color: AppColors.textLight, fontSize: 14),
                  prefixIcon: Icon(Icons.search, color: AppColors.primary, size: 20),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                ),
              ),
            ),
          ),
          // List
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.folder_open_outlined, size: 48, color: AppColors.textLight),
                        SizedBox(height: 12),
                        Text(
                          'No folders found',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final member = filtered[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          leading: CircleAvatar(
                            radius: 24,
                            backgroundImage: CachedNetworkImageProvider(ImageUtils.getOptimizedImageUrl(member['avatar'])),
                          ),
                          title: Text(
                            member['name'],
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          subtitle: Row(
                            children: [
                              const Icon(Icons.folder_outlined, size: 14, color: AppColors.textSecondary),
                              const SizedBox(width: 4),
                              Text(
                                member['subtitle'],
                                style: const TextStyle(color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                          trailing: const Icon(Icons.chevron_right, color: AppColors.textSecondary),
                          onTap: () {
                            Navigator.pushNamed(
                              context,
                              AppRoutes.allDocuments,
                              arguments: {
                                'title': '${member['name']} Documents',
                                'documents': member['documents'],
                              },
                            );
                          },
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
