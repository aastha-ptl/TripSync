import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/routes/app_routes.dart';

import '../../profile/screens/profile_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:tripsync/core/utils/image_utils.dart';
import '../../../core/utils/date_formatter.dart';
import '../../trip/models/photo_model.dart';
import '../../trip/services/photo_service.dart';
import '../../trip/screens/photo_gallery_screen.dart';
import '../services/document_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/api_endpoints.dart';
import '../../trip/services/trip_service.dart';
import '../../profile/services/user_service.dart';

class DocumentsScreen extends StatefulWidget {
  final VoidCallback? onBack;
  final Map<String, dynamic>? tripData;
  final String? profilePhotoUrl;
  final String? profileName;
  final bool isSoloTraveler;
  final bool isFamilyLeader;
  final bool isPhotoGalleryOnly;

  const DocumentsScreen({
    super.key, 
    this.onBack,
    this.tripData,
    this.profilePhotoUrl,
    this.profileName,
    this.isSoloTraveler = false,
    this.isFamilyLeader = false,
    this.isPhotoGalleryOnly = false,
  });

  @override
  State<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends State<DocumentsScreen> {
  String _selectedCategory = 'All';
  final List<String> _categories = ['All', 'Travel', 'Tickets', 'Bookings', 'Insurance', 'Visa', 'Other'];

  final PhotoService _photoService = PhotoService();
  final DocumentService _documentService = DocumentService();
  List<Photo> _recentPhotos = [];
  List<dynamic> _myDocuments = [];
  List<dynamic> _memberDocuments = [];
  List<dynamic> _tripDocuments = [];
  List<Map<String, dynamic>> _participants = [];
  int _totalPhotos = 0;
  bool _isLoadingPhotos = true;
  bool _isLoadingDocs = true;

  @override
  void initState() {
    super.initState();
    _fetchPhotos();
    _fetchDocuments();
    _fetchParticipants();
  }

  Future<void> _fetchParticipants() async {
    if (widget.tripData == null || widget.tripData!['_id'] == null) return;
    try {
      final tripService = TripService();
      final userService = UserService();
      
      final profileRes = await userService.getProfile();
      final currentUserId = profileRes['success'] == true ? profileRes['data']['_id'] : null;

      final response = await tripService.getTripParticipants(widget.tripData!['_id']);
      if (response['success'] == true && mounted) {
        final List<Map<String, dynamic>> allParticipants = List<Map<String, dynamic>>.from(response['data']);
        List<Map<String, dynamic>> list = [];
        
        if (widget.isFamilyLeader && currentUserId != null) {
          final myFamily = allParticipants.firstWhere(
            (p) => p['type'] == 'Family' && p['userId'] == currentUserId,
            orElse: () => <String, dynamic>{},
          );
          if (myFamily.isNotEmpty && myFamily['familyMembers'] != null) {
            list = List<Map<String, dynamic>>.from(myFamily['familyMembers']);
          }
        } else {
          for (var p in allParticipants) {
            final user = p['userId'];
            if (user != null && user == currentUserId) continue;
            list.add(p);
            if (p['familyMembers'] != null && p['familyMembers'] is List) {
              for (var fm in p['familyMembers']) {
                if (fm is Map) {
                  list.add(Map<String, dynamic>.from(fm));
                }
              }
            }
          }
        }

        setState(() {
          _participants = list;
        });
      }
    } catch (e) {
      debugPrint('Error fetching participants: $e');
    }
  }

  Future<void> _fetchDocuments() async {
    if (widget.tripData == null || widget.tripData!['_id'] == null) {
      if (mounted) setState(() => _isLoadingDocs = false);
      return;
    }
    try {
      final response = await _documentService.getTripDocuments(widget.tripData!['_id']);
      if (response['success'] == true) {
        final List<dynamic> allDocs = response['documents'];
        if (mounted) {
          setState(() {
            _myDocuments = allDocs.where((d) => d['type'] == 'Personal' && d['isMine'] == true).toList();
            _memberDocuments = allDocs.where((d) => 
              d['type'] == 'Family' || 
              (d['type'] == 'Personal' && d['isMine'] == false)
            ).toList();
            _tripDocuments = allDocs.where((d) => d['type'] == 'Trip').toList();
            _isLoadingDocs = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoadingDocs = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingDocs = false);
    }
  }

  Future<void> _fetchPhotos() async {
    if (widget.tripData == null || widget.tripData!['_id'] == null) {
      if (mounted) setState(() => _isLoadingPhotos = false);
      return;
    }
    try {
      final response = await _photoService.getTripPhotos(widget.tripData!['_id']);
      if (response['success'] == true) {
        final List<dynamic> photosData = response['photos'];
        final allPhotos = photosData.map((data) => Photo.fromJson(data)).toList();
        if (mounted) {
          setState(() {
            _totalPhotos = allPhotos.length;
            _recentPhotos = allPhotos.take(3).toList();
            _isLoadingPhotos = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _isLoadingPhotos = false;
          });
        }
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingPhotos = false);
    }
  }

  void _openDocument(dynamic doc) async {
    final fileUrl = doc['fileUrl']?.toString();
    if (fileUrl == null || fileUrl.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('File URL is not available')),
        );
      }
      return;
    }

    try {
      final baseUrl = await ApiEndpoints.getBaseUrl();
      // baseUrl is usually http://<ip>:5000/api, we just want http://<ip>:5000
      final rootUrl = baseUrl.replaceAll('/api', '');
      
      // Ensure the path uses forward slashes and avoid double slashes
      var cleanPath = fileUrl.replaceAll('\\', '/');
      if (cleanPath.startsWith('/')) {
        cleanPath = cleanPath.substring(1);
      }
      
      final fullUrl = '$rootUrl/$cleanPath';
      final uri = Uri.parse(fullUrl);

      // Bypass canLaunchUrl check because of Android 11+ package visibility rules
      bool launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched) {
        // Fallback to in-app browser if external fails
        launched = await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
      }
      
      if (!launched) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not open document')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error opening document: $e')),
        );
      }
    }
  }

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
                    if (!widget.isPhotoGalleryOnly) ...[
                      const SizedBox(height: 24),
                      _buildMyDocumentsSection(),
                      const SizedBox(height: 24),
                      if (!widget.isSoloTraveler) _buildMemberDocumentsSection(),
                      if (!widget.isSoloTraveler) const SizedBox(height: 24),
                      _buildTripDocumentsSection(),
                      const SizedBox(height: 24),
                      _buildUploadDocumentBox(),
                      if (widget.isFamilyLeader) ...[
                        const SizedBox(height: 16),
                        _buildAddFamilyMemberButton(),
                      ],
                    ],
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
    return GestureDetector(
      onTap: () {
        if (widget.tripData != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PhotoGalleryScreen(tripData: widget.tripData!),
            ),
          ).then((_) => _fetchPhotos());
        }
      },
      child: Container(
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
              onViewAll: () {
                if (widget.tripData != null) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => PhotoGalleryScreen(tripData: widget.tripData!),
                    ),
                  ).then((_) => _fetchPhotos());
                }
              },
            ),
            const SizedBox(height: 16),
            _isLoadingPhotos
                ? const Center(child: CircularProgressIndicator())
                : _totalPhotos == 0
                    ? Container(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        child: const Text('No photos yet', style: TextStyle(color: AppColors.textSecondary)),
                      )
                    : Row(
                        children: [
                          ..._recentPhotos.map((photo) {
                            return Expanded(
                              child: Container(
                                height: 100,
                                margin: const EdgeInsets.only(right: 8),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(10),
                                  image: DecorationImage(
                                    image: CachedNetworkImageProvider(photo.photoUrl),
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                          if (_totalPhotos > 3)
                            Expanded(
                              child: Container(
                                height: 100,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEFF6FF),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: const Color(0xFF0072FF).withOpacity(0.1)),
                                ),
                                child: Center(
                                  child: Text(
                                    '+${_totalPhotos - 3}\nPhotos',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF0072FF),
                                    ),
                                  ),
                                ),
                              ),
                            )
                          else if (_recentPhotos.length < 3)
                            ...List.generate(3 - _recentPhotos.length, (index) => const Expanded(child: SizedBox())),
                        ],
                      ),
          ],
        ),
      ),
    );
  }

  Widget _buildMyDocumentsSection() {
    if (_myDocuments.isEmpty && !_isLoadingDocs) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader(
              icon: Icons.assignment_outlined,
              iconBgColor: const Color(0xFFDCFCE7),
              iconColor: AppColors.secondary,
              title: 'My Documents (Your Personal Documents)',
              subtitle: 'Your important identity documents',
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Text('No personal documents uploaded yet. ', style: TextStyle(color: AppColors.textSecondary)),
                GestureDetector(
                  onTap: () => Navigator.pushNamed(context, AppRoutes.allDocuments, arguments: {
                    'title': 'My Documents',
                    'documents': _myDocuments,
                    'tripData': widget.tripData,
                    'isFamilyLeader': widget.isFamilyLeader
                  }).then((_) => _fetchDocuments()),
                  child: const Text(
                    'Add Document',
                    style: TextStyle(
                      color: Color(0xFF0072FF),
                      fontWeight: FontWeight.bold,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

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
            onViewAll: () => Navigator.pushNamed(context, AppRoutes.allDocuments, arguments: {
              'title': 'My Documents',
              'documents': _myDocuments,
              'tripData': widget.tripData,
              'isFamilyLeader': widget.isFamilyLeader
            }).then((_) => _fetchDocuments()),
          ),
          const SizedBox(height: 16),
          Row(
            children: _myDocuments.map((doc) {
              return Expanded(
                child: GestureDetector(
                  onTap: () => _openDocument(doc),
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
              ),
            );
          }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildMemberDocumentsSection() {
    if (_memberDocuments.isEmpty && !_isLoadingDocs) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader(
              icon: Icons.people_outline,
              iconBgColor: const Color(0xFFEFF6FF),
              iconColor: const Color(0xFF0072FF),
              title: widget.isFamilyLeader ? 'Family Member Documents' : 'Member Documents (Visible to Trip Leader Only)',
              subtitle: 'View documents shared by trip members',
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Text('No member documents uploaded yet. ', style: TextStyle(color: AppColors.textSecondary)),
                GestureDetector(
                  onTap: () => Navigator.pushNamed(context, AppRoutes.allDocuments, arguments: {
                    'title': widget.isFamilyLeader ? 'Family Member Documents' : 'Member Documents',
                    'documents': _memberDocuments,
                    'tripData': widget.tripData,
                    'isFamilyLeader': widget.isFamilyLeader
                  }).then((_) => _fetchDocuments()),
                  child: const Text(
                    'Add Document',
                    style: TextStyle(
                      color: Color(0xFF0072FF),
                      fontWeight: FontWeight.bold,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    // Group documents by member
    Map<String, List<dynamic>> memberGroups = {};
    for (var doc in _memberDocuments) {
      String owner = 'Unknown';
      String avatar = 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=100&auto=format&fit=crop&q=80'; // default avatar
      
      if (doc['memberName'] != null && doc['memberName'].toString().trim().isNotEmpty) {
        owner = doc['memberName'];
      } else if (doc['belongsTo'] != null) {
        if (doc['belongsTo'] is Map) {
          final fName = doc['belongsTo']['firstName'] ?? '';
          final lName = doc['belongsTo']['lastName'] ?? '';
          if (fName.isNotEmpty || lName.isNotEmpty) {
            owner = '$fName $lName'.trim();
          }
          if (doc['belongsTo']['profilePhoto'] != null && doc['belongsTo']['profilePhoto'].isNotEmpty) {
            avatar = doc['belongsTo']['profilePhoto'];
          }
        } else if (doc['belongsTo'] is String) {
          owner = doc['belongsTo'];
        }
      }

      // Check fallback using _participants list
      for (var p in _participants) {
        final pName = p['name']?.toString() ?? '';
        final pUserId = p['userId']?.toString() ?? '';
        final pId = p['_id']?.toString() ?? p['id']?.toString() ?? '';
        final docBelongsTo = doc['belongsTo'] is Map ? (doc['belongsTo']['_id']?.toString() ?? '') : doc['belongsTo']?.toString() ?? '';
        final docMemberName = doc['memberName']?.toString() ?? '';

        if (pName.isNotEmpty && (
            owner == pName || 
            docMemberName == pName ||
            (pUserId.isNotEmpty && (owner == pUserId || docBelongsTo == pUserId)) ||
            (pId.isNotEmpty && (owner == pId || docBelongsTo == pId))
          )) {
          owner = pName;
          if (p['avatar'] != null && p['avatar'].toString().isNotEmpty) {
            avatar = p['avatar'];
          }
          break;
        }
      }

      if (!memberGroups.containsKey(owner)) {
        memberGroups[owner] = [];
      }
      doc['extractedAvatar'] = avatar;
      memberGroups[owner]!.add(doc);
    }

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
            title: widget.isFamilyLeader ? 'Family Member Documents' : 'Member Documents (Visible to Trip Leader Only)',
            subtitle: 'View documents shared by trip members',
            onViewAll: () => Navigator.pushNamed(context, AppRoutes.allDocuments, arguments: {
              'title': widget.isFamilyLeader ? 'Family Member Documents' : 'Member Documents',
              'documents': _memberDocuments,
              'tripData': widget.tripData,
              'isFamilyLeader': widget.isFamilyLeader
            }).then((_) => _fetchDocuments()),
          ),
          const SizedBox(height: 16),
          
          ...memberGroups.entries.where((entry) => entry.value.isNotEmpty).map((entry) {
            String groupAvatar = entry.value.first['extractedAvatar'] ?? 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=100&auto=format&fit=crop&q=80';
            return _buildMemberAccordionItem(
              name: entry.key,
              subtitle: '${entry.value.length} Documents',
              avatar: groupAvatar,
              isExpanded: true,
              onToggle: () {},
              child: _buildMemberDocRow(
                entry.value.map<Map<String, String>>((doc) => {
                  'name': doc['name'] ?? 'Document',
                  'number': doc['number'] ?? 'N/A',
                  'fileUrl': doc['fileUrl'] ?? '',
                }).toList(),
              ),
            );
          }).toList(),
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
    String initials = '';
    if (name.isNotEmpty && name != 'Unknown') {
      List<String> parts = name.trim().split(RegExp(r'\s+'));
      if (parts.length > 1) {
        initials = '${parts[0][0]}${parts[1][0]}'.toUpperCase();
      } else {
        initials = parts[0][0].toUpperCase();
      }
    } else {
      initials = '?';
    }

    Widget avatarWidget;
    if (avatar.isNotEmpty && !avatar.contains('images.unsplash.com')) {
      avatarWidget = CircleAvatar(
        radius: 16,
        backgroundImage: CachedNetworkImageProvider(ImageUtils.getOptimizedImageUrl(avatar)),
      );
    } else {
      avatarWidget = CircleAvatar(
        radius: 16,
        backgroundColor: const Color(0xFF0072FF),
        child: Text(
          initials,
          style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold),
        ),
      );
    }

    return Column(
      children: [
        InkWell(
          onTap: onToggle,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12.0),
            child: Row(
              children: [
                avatarWidget,
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

  Widget _buildMemberDocRow(List<dynamic> docs) {
    return Row(
      children: docs.map((doc) {
        return Expanded(
          child: GestureDetector(
            onTap: () => _openDocument(doc),
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
        ),
      );
    }).toList(),
    );
  }

  Widget _buildTripDocItem(dynamic doc) {
    String title = doc['name'] ?? 'Document';
    String number = doc['number'] ?? 'N/A';
    String date = doc['createdAt'] != null 
        ? doc['createdAt'].toString().substring(0, 10) 
        : 'Recent';

    return GestureDetector(
      onTap: () => _openDocument(doc),
      child: Container(
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
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildTripDocumentsSection() {
    if (_tripDocuments.isEmpty && !_isLoadingDocs) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
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
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Text('No trip documents uploaded yet. ', style: TextStyle(color: AppColors.textSecondary)),
                GestureDetector(
                  onTap: () => Navigator.pushNamed(context, AppRoutes.allDocuments, arguments: {
                    'title': 'Trip Documents',
                    'documents': _tripDocuments,
                    'tripData': widget.tripData,
                    'isFamilyLeader': widget.isFamilyLeader
                  }).then((_) => _fetchDocuments()),
                  child: const Text(
                    'Add Document',
                    style: TextStyle(
                      color: Color(0xFF0072FF),
                      fontWeight: FontWeight.bold,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

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
            onViewAll: () => Navigator.pushNamed(context, AppRoutes.allDocuments, arguments: {
              'title': 'Trip Documents',
              'documents': _tripDocuments,
              'tripData': widget.tripData,
              'isFamilyLeader': widget.isFamilyLeader
            }).then((_) => _fetchDocuments()),
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
          ..._tripDocuments.map((doc) => _buildTripDocItem(doc)).toList(),
        ],
      ),
    );
  }

  Widget _buildUploadDocumentBox() {
    return GestureDetector(
      onTap: _showUploadDialog,
      child: CustomPaint(
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
      ),
    );
  }

  void _showUploadDialog() {
    String name = '';
    String number = '';
    String type = 'Personal';
    String? selectedFilePath;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 20,
                right: 20,
                top: 24,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Upload Document', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),
                  TextField(
                    decoration: const InputDecoration(labelText: 'Document Name', border: OutlineInputBorder()),
                    onChanged: (val) => name = val,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    decoration: const InputDecoration(labelText: 'Document Number (Optional)', border: OutlineInputBorder()),
                    onChanged: (val) => number = val,
                  ),
                  const SizedBox(height: 16),
                  if (widget.isFamilyLeader) ...[
                    DropdownButtonFormField<String>(
                      value: type,
                      decoration: const InputDecoration(labelText: 'Document Type', border: OutlineInputBorder()),
                      items: const [
                        DropdownMenuItem(value: 'Personal', child: Text('Personal')),
                        DropdownMenuItem(value: 'Family', child: Text('Family Member')),
                      ],
                      onChanged: (val) => setModalState(() => type = val!),
                    ),
                    const SizedBox(height: 16),
                  ],
                  GestureDetector(
                    onTap: () async {
                      PlatformFile? file = await FilePicker.pickFile(
                        type: FileType.custom,
                        allowedExtensions: ['pdf', 'jpg', 'png', 'jpeg'],
                      );
                      if (file != null) {
                        setModalState(() {
                          selectedFilePath = file.path;
                        });
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Center(
                        child: Text(
                          selectedFilePath != null ? 'File Selected' : 'Select File',
                          style: TextStyle(
                            color: selectedFilePath != null ? AppColors.primary : AppColors.textSecondary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        if (name.isEmpty || selectedFilePath == null) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please provide name and select a file')));
                          return;
                        }
                        Navigator.pop(context);
                        
                        try {
                          await _documentService.uploadDocument(
                            tripId: widget.tripData!['_id'],
                            filePath: selectedFilePath!,
                            name: name,
                            number: number,
                            type: type,
                          );
                          _fetchDocuments();
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Document uploaded successfully!')));
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to upload: $e')));
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Upload', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildAddFamilyMemberButton() {
    return GestureDetector(
      onTap: () {
        Navigator.pushNamed(context, AppRoutes.addTrip); // Or specific add member route, fallback to add trip as per UI logic
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        decoration: BoxDecoration(
          color: const Color(0xFF20C060).withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF20C060).withOpacity(0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.group_add_rounded, color: Color(0xFF20C060), size: 24),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: const [
                Text(
                  'Add Family Member Dashboard',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF15803D)),
                ),
                SizedBox(height: 2),
                Text(
                  'Invite or manage family members',
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
