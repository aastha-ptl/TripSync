import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/routes/app_routes.dart';

import '../../profile/screens/profile_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:tripsync/core/utils/image_utils.dart';
import '../../../core/utils/date_formatter.dart';

class DocumentsScreen extends StatefulWidget {
  final VoidCallback? onBack;
  final Map<String, dynamic>? tripData;
  final String? profilePhotoUrl;
  final String? profileName;
  final bool isSoloTraveler;

  const DocumentsScreen({
    super.key, 
    this.onBack,
    this.tripData,
    this.profilePhotoUrl,
    this.profileName,
    this.isSoloTraveler = false,
  });

  @override
  State<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends State<DocumentsScreen> {
  String _selectedCategory = 'All';
  final List<String> _categories = ['All', 'Travel', 'Tickets', 'Bookings', 'Insurance', 'Visa', 'Other'];

  // Accordion open/close state
  bool _aasthaExpanded = true;
  bool _rahulExpanded = false;
  bool _priyaExpanded = false;
  bool _vivekExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildPhotoGallerySection(),
                    const SizedBox(height: 24),
                    _buildMyDocumentsSection(),
                    const SizedBox(height: 24),
                    if (!widget.isSoloTraveler) _buildMemberDocumentsSection(),
                    if (!widget.isSoloTraveler) const SizedBox(height: 24),
                    _buildTripDocumentsSection(),
                    const SizedBox(height: 24),
                    _buildUploadDocumentBox(),
                    const SizedBox(height: 100), // Extra space for FAB
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
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
                    child: widget.tripData != null && widget.tripData!['imageUrl'] != null
                        ? CachedNetworkImage(imageUrl: ImageUtils.getOptimizedImageUrl(widget.tripData!['imageUrl']),
                            height: 48,
                            width: 48,
                            fit: BoxFit.cover,
                            errorWidget: (context, url, error) => Container(
                              height: 48,
                              width: 48,
                              color: Colors.grey[200],
                              child: const Icon(Icons.image, color: Colors.grey),
                            ),
                          )
                        : CachedNetworkImage(imageUrl: ImageUtils.getOptimizedImageUrl('https://images.unsplash.com/photo-1502602898657-3e91760cbb34?w=150&auto=format&fit=crop&q=80'),
                            height: 48,
                            width: 48,
                            fit: BoxFit.cover,
                          ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: const [
                            Text(
                              'Documents',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(
                              Icons.calendar_today_outlined,
                              size: 11,
                              color: Color(0xFF64748B),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                TripInfoHelper.formatTripHeader(
                                  widget.tripData,
                                  defaultText: 'May 20 – May 27, 2025 • 8 Members',
                                  showMembers: true,
                                ),
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF64748B),
                                  fontWeight: FontWeight.w500,
                                ),
                                overflow: TextOverflow.ellipsis,
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
          // Profile Picture
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const Scaffold(
                    backgroundColor: Color(0xFFF8FAFC),
                    body: ProfileScreen(),
                  ),
                ),
              );
            },
            child: CircleAvatar(
              radius: 16,
              backgroundColor: const Color(0xFFE2E8F0),
              backgroundImage: widget.profilePhotoUrl != null && widget.profilePhotoUrl!.isNotEmpty
                  ? CachedNetworkImageProvider(ImageUtils.getOptimizedImageUrl(widget.profilePhotoUrl))
                  : null,
              child: widget.profilePhotoUrl == null || widget.profilePhotoUrl!.isEmpty
                  ? Text(
                      _getInitials(widget.profileName),
                      style: const TextStyle(
                        color: Color(0xFF475569),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    )
                  : null,
            ),
          ),
        ],
      ),
    );
  }

  String _getInitials(String? name) {
    if (name == null || name.trim().isEmpty) return '';
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length > 1) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return parts[0][0].toUpperCase();
  }

  Widget _buildSectionHeader({
    required IconData icon,
    required Color iconBgColor,
    required Color iconColor,
    required String title,
    required String subtitle,
    VoidCallback? onViewAll,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconBgColor,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: iconColor, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        if (onViewAll != null)
          GestureDetector(
            onTap: onViewAll,
            child: Row(
              children: const [
                Text(
                  'View All',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0072FF),
                  ),
                ),
                SizedBox(width: 4),
                Icon(Icons.arrow_forward, size: 12, color: Color(0xFF0072FF)),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildPhotoGallerySection() {
    final List<String> images = [
      'https://images.unsplash.com/photo-1502602898657-3e91760cbb34?w=150&auto=format&fit=crop&q=80',
      'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=150&auto=format&fit=crop&q=80',
      'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=150&auto=format&fit=crop&q=80',
      'https://images.unsplash.com/photo-1499856871958-5b9627545d1a?w=150&auto=format&fit=crop&q=80',
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildSectionHeader(
            icon: Icons.photo_library_outlined,
            iconBgColor: const Color(0xFFEFF6FF),
            iconColor: const Color(0xFF0072FF),
            title: 'Photo Gallery',
            subtitle: 'All trip memories in one place',
            onViewAll: () => Navigator.pushNamed(context, AppRoutes.gallery),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              ...images.map((url) {
                return Expanded(
                  child: Container(
                    height: 60,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      image: DecorationImage(
                        image: CachedNetworkImageProvider(ImageUtils.getOptimizedImageUrl(url)),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                );
              }).toList(),
              // Count Card
              Expanded(
                child: Container(
                  height: 60,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF0072FF).withOpacity(0.1)),
                  ),
                  child: Center(
                    child: Text(
                      '+128\nPhotos',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF0072FF),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMyDocumentsSection() {
    final docs = [
      {'name': 'Aadhaar Card', 'number': 'XXXX XXXX 4821'},
      {'name': 'PAN Card', 'number': 'XXXXX1234X'},
      {'name': 'Passport', 'number': 'ZXXXX1234'},
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildSectionHeader(
            icon: Icons.assignment_outlined,
            iconBgColor: const Color(0xFFDCFCE7),
            iconColor: AppColors.secondary,
            title: 'My Documents (Your Personal Documents)',
            subtitle: 'Your important identity documents',
            onViewAll: () => Navigator.pushNamed(context, AppRoutes.allDocuments),
          ),
          const SizedBox(height: 16),
          Row(
            children: docs.map((doc) {
              return Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  padding: const EdgeInsets.all(10),
                  height: 110,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Icon(
                            doc['name'] == 'Passport' ? Icons.menu_book_outlined : Icons.badge_outlined,
                            color: const Color(0xFF0072FF),
                            size: 20,
                          ),
                          const Icon(Icons.more_vert, color: AppColors.textLight, size: 16),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            doc['name']!,
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            doc['number']!,
                            style: const TextStyle(fontSize: 8, color: AppColors.textSecondary),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Container(
                            height: 6,
                            width: 6,
                            decoration: const BoxDecoration(
                              color: AppColors.secondary,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Expanded(
                            child: Text(
                              '10 Aug 2026',
                              style: TextStyle(fontSize: 7, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildMemberDocumentsSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildSectionHeader(
            icon: Icons.people_outline,
            iconBgColor: const Color(0xFFEFF6FF),
            iconColor: const Color(0xFF0072FF),
            title: 'Member Documents (Visible to Trip Leader Only)',
            subtitle: 'View documents shared by trip members',
            onViewAll: () => Navigator.pushNamed(context, AppRoutes.membersList),
          ),
          const SizedBox(height: 16),
          
          // Aastha Patel Expansion
          _buildMemberAccordionItem(
            name: 'Aastha Patel',
            subtitle: '3 Documents',
            avatar: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=100&auto=format&fit=crop&q=80',
            isExpanded: _aasthaExpanded,
            onToggle: () => setState(() => _aasthaExpanded = !_aasthaExpanded),
            child: _buildMemberDocRow([
              {'name': 'Aadhaar Card', 'number': 'XXXX XXXX 1234'},
              {'name': 'PAN Card', 'number': 'XXXXX5678Z'},
              {'name': 'Passport', 'number': 'ZXXXX5678'},
            ]),
          ),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),

          // Rahul Verma
          _buildMemberAccordionItem(
            name: 'Rahul Verma',
            subtitle: '3 Documents',
            avatar: 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=100&auto=format&fit=crop&q=80',
            isExpanded: _rahulExpanded,
            onToggle: () => setState(() => _rahulExpanded = !_rahulExpanded),
            child: _buildMemberDocRow([
              {'name': 'PAN Card', 'number': 'XXXXX9012Y'},
              {'name': 'Flight Ticket', 'number': 'Air India - AI456'},
              {'name': 'Passport', 'number': 'ZXXXX9012'},
            ]),
          ),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),

          // Priya Sharma
          _buildMemberAccordionItem(
            name: 'Priya Sharma',
            subtitle: '3 Documents',
            avatar: 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=100&auto=format&fit=crop&q=80',
            isExpanded: _priyaExpanded,
            onToggle: () => setState(() => _priyaExpanded = !_priyaExpanded),
            child: _buildMemberDocRow([
              {'name': 'Aadhaar Card', 'number': 'XXXX XXXX 9988'},
              {'name': 'Hotel Booking', 'number': 'Booking ID: 112233'},
              {'name': 'PAN Card', 'number': 'XXXXX9988Z'},
            ]),
          ),
        ],
      ),
    );
  }

  Widget _buildMemberAccordionItem({
    required String name,
    required String subtitle,
    required String avatar,
    required bool isExpanded,
    required VoidCallback onToggle,
    required Widget child,
  }) {
    return Column(
      children: [
        InkWell(
          onTap: onToggle,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12.0),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundImage: CachedNetworkImageProvider(ImageUtils.getOptimizedImageUrl(avatar)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                Icon(
                  isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                  color: AppColors.textSecondary,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
        if (isExpanded)
          Padding(
            padding: const EdgeInsets.only(bottom: 12.0),
            child: child,
          ),
      ],
    );
  }

  Widget _buildMemberDocRow(List<Map<String, String>> docs) {
    return Row(
      children: docs.map((doc) {
        return Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            padding: const EdgeInsets.all(8),
            height: 105,
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Icon(
                      doc['name'] == 'Passport' || doc['name'] == 'Flight Ticket' || doc['name'] == 'Hotel Booking'
                          ? (doc['name'] == 'Passport' 
                              ? Icons.menu_book_outlined 
                              : (doc['name'] == 'Flight Ticket' ? Icons.local_activity_outlined : Icons.apartment_outlined))
                          : Icons.badge_outlined,
                      color: const Color(0xFF0072FF),
                      size: 16,
                    ),
                    const Icon(Icons.more_vert, color: AppColors.textLight, size: 14),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      doc['name']!,
                      style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      doc['number']!,
                      style: const TextStyle(fontSize: 7, color: AppColors.textSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
                Row(
                  children: [
                    Container(
                      height: 5,
                      width: 5,
                      decoration: const BoxDecoration(
                        color: AppColors.secondary,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Expanded(
                      child: Text(
                        '10 Aug 2026',
                        style: TextStyle(fontSize: 7, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildMiniDocCard(String title, String number, String date) {
    return Container(
      width: 135,
      margin: const EdgeInsets.only(right: 10),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(
                title.contains('Aadhaar') ? Icons.badge_outlined : Icons.credit_card_outlined,
                color: const Color(0xFF0072FF),
                size: 16,
              ),
              const Icon(Icons.more_vert, color: AppColors.textLight, size: 14),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            title,
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
          ),
          Text(
            number,
            style: const TextStyle(fontSize: 8, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Container(
                height: 5,
                width: 5,
                decoration: const BoxDecoration(
                  color: AppColors.secondary,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  'Uploaded on $date',
                  style: const TextStyle(fontSize: 7, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTripDocumentsSection() {
    final tripDocs = [
      {
        'title': 'Flight Ticket',
        'desc': 'Delhi (DEL) -> Paris (CDG)',
        'date': 'May 20, 2026 • Uploaded by You',
        'type': 'flight'
      },
      {
        'title': 'Hotel Booking',
        'desc': 'Hotel Le Meurice, Paris',
        'date': 'May 20 – May 23, 2026 • Uploaded by You',
        'type': 'hotel'
      },
      {
        'title': 'Travel Insurance',
        'desc': 'ACKO Travel Insurance',
        'date': 'May 20 – May 27, 2026 • Uploaded by You',
        'type': 'insurance'
      },
      {
        'title': 'Visa Document',
        'desc': 'Schengen Tourist Visa',
        'date': 'May 15, 2026 • Uploaded by You',
        'type': 'visa'
      },
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            icon: Icons.folder_open_outlined,
            iconBgColor: const Color(0xFFF3E8FF),
            iconColor: const Color(0xFF0072FF),
            title: 'Trip Documents (Shared with All Members)',
            subtitle: 'Important documents for this trip',
            onViewAll: () {
              Navigator.pushNamed(
                context,
                AppRoutes.allDocuments,
                arguments: {
                  'title': 'Travel Documents',
                  'documents': [
                    {
                      'name': 'Flight Ticket',
                      'number': 'Delhi (DEL) -> Paris (CDG)',
                      'category': 'Tickets',
                      'format': 'PDF',
                      'size': '1.8 MB',
                      'date': 'May 20, 2026',
                      'icon': Icons.flight_takeoff,
                      'color': const Color(0xFFEA580C),
                    },
                    {
                      'name': 'Hotel Booking',
                      'number': 'Hotel Le Meurice, Paris',
                      'category': 'Bookings',
                      'format': 'PDF',
                      'size': '1.1 MB',
                      'date': 'May 20 – May 23, 2026',
                      'icon': Icons.hotel_outlined,
                      'color': const Color(0xFF9333EA),
                    },
                    {
                      'name': 'Travel Insurance',
                      'number': 'ACKO Travel Insurance',
                      'category': 'Insurance',
                      'format': 'PDF',
                      'size': '2.1 MB',
                      'date': 'May 20 – May 27, 2026',
                      'icon': Icons.security,
                      'color': const Color(0xFF16A34A),
                    },
                    {
                      'name': 'Visa Document',
                      'number': 'Schengen Tourist Visa',
                      'category': 'Visa',
                      'format': 'PDF',
                      'size': '3.2 MB',
                      'date': 'May 15, 2026',
                      'icon': Icons.description,
                      'color': const Color(0xFFE11D48),
                    },
                  ],
                },
              );
            },
          ),
          const SizedBox(height: 16),

          // Horizontal Filter Pills (No Purple - use blue gradient for selected)
          SizedBox(
            height: 32,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: _categories.length,
              itemBuilder: (context, index) {
                final category = _categories[index];
                final isSelected = _selectedCategory == category;
                return GestureDetector(
                  onTap: () => setState(() => _selectedCategory = category),
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      gradient: isSelected
                          ? const LinearGradient(
                              colors: [Color(0xFF00C6FF), Color(0xFF0072FF)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            )
                          : null,
                      color: isSelected ? null : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Center(
                      child: Text(
                        category,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isSelected ? Colors.white : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),

          // Vertical list of Trip Documents
          ...tripDocs.map((doc) => _buildTripDocItem(doc)).toList(),
        ],
      ),
    );
  }

  Widget _buildTripDocItem(Map<String, String> doc) {
    IconData itemIcon = Icons.insert_drive_file_outlined;
    Color iconBg = const Color(0xFFEFF6FF);
    Color iconColor = const Color(0xFF0072FF);

    switch (doc['type']) {
      case 'flight':
        itemIcon = Icons.flight_takeoff;
        iconBg = const Color(0xFFFFF2E6);
        iconColor = const Color(0xFFEA580C);
        break;
      case 'hotel':
        itemIcon = Icons.hotel_outlined;
        iconBg = const Color(0xFFF3E8FF);
        iconColor = const Color(0xFF9333EA);
        break;
      case 'insurance':
        itemIcon = Icons.security;
        iconBg = const Color(0xFFDCFCE7);
        iconColor = AppColors.secondary;
        break;
      case 'visa':
        itemIcon = Icons.description;
        iconBg = const Color(0xFFFFE4E6);
        iconColor = AppColors.error;
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(itemIcon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  doc['title']!,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 2),
                Text(
                  doc['desc']!,
                  style: const TextStyle(fontSize: 10, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 2),
                Text(
                  doc['date']!,
                  style: const TextStyle(fontSize: 8, color: AppColors.textLight),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'Uploaded',
                  style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Color(0xFF15803D)),
                ),
              ),
              const SizedBox(height: 6),
              GestureDetector(
                onTap: () {},
                child: Row(
                  children: const [
                    Icon(Icons.remove_red_eye_outlined, size: 12, color: Color(0xFF0072FF)),
                    SizedBox(width: 4),
                    Text(
                      'View',
                      style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF0072FF)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(width: 4),
          const Icon(Icons.more_vert, color: AppColors.textLight, size: 18),
        ],
      ),
    );
  }

  Widget _buildUploadDocumentBox() {
    return CustomPaint(
      painter: DashedBorderPainter(color: const Color(0xFF0072FF).withOpacity(0.3), strokeWidth: 1.5, gap: 5),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        decoration: BoxDecoration(
          color: const Color(0xFF0072FF).withOpacity(0.02),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_upload_outlined, color: Color(0xFF0072FF), size: 24),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: const [
                Text(
                  'Upload Document',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0072FF)),
                ),
                SizedBox(height: 2),
                Text(
                  'PDF, JPG, PNG up to 10MB',
                  style: TextStyle(fontSize: 10, color: AppColors.textSecondary),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class DashedBorderPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double gap;

  DashedBorderPainter({required this.color, this.strokeWidth = 1.0, this.gap = 5.0});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final RRect rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      const Radius.circular(16),
    );

    final Path path = Path()..addRRect(rrect);
    final Path dashedPath = _buildDashedPath(path, gap);

    canvas.drawPath(dashedPath, paint);
  }

  Path _buildDashedPath(Path source, double gap) {
    final Path path = Path();
    for (final PathMetric metric in source.computeMetrics()) {
      double distance = 0.0;
      bool draw = true;
      while (distance < metric.length) {
        final double len = draw ? gap : gap;
        if (draw) {
          path.addPath(
            metric.extractPath(distance, distance + len),
            Offset.zero,
          );
        }
        distance += len;
        draw = !draw;
      }
    }
    return path;
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
