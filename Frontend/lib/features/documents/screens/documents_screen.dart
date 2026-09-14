import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

import '../../profile/screens/profile_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:tripsync/core/utils/image_utils.dart';
import '../../../core/utils/date_formatter.dart';
import '../../trip/models/photo_model.dart';
import '../../trip/services/photo_service.dart';
import '../../trip/screens/photo_gallery_screen.dart';
import '../services/document_service.dart';
import '../../trip/services/trip_service.dart';
import '../../profile/services/user_service.dart';
import 'all_documents_screen.dart';

class DocumentsScreen extends StatefulWidget {
  final VoidCallback? onBack;
  final Map<String, dynamic>? tripData;
  final String? profilePhotoUrl;
  final String? profileName;
  final bool isSoloTraveler;
  final bool isFamilyLeader;
  final bool isTripLeader;
  final bool isPhotoGalleryOnly;

  const DocumentsScreen({
    super.key, 
    this.onBack,
    this.tripData,
    this.profilePhotoUrl,
    this.profileName,
    this.isSoloTraveler = false,
    this.isFamilyLeader = false,
    this.isTripLeader = false,
    this.isPhotoGalleryOnly = false,
  });

  @override
  State<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends State<DocumentsScreen> {
  final PhotoService _photoService = PhotoService();
  final DocumentService _documentService = DocumentService();
  final TripService _tripService = TripService();
  List<Photo> _recentPhotos = [];
  List<dynamic> _myDocuments = [];
  List<dynamic> _allFetchedDocuments = [];
  List<dynamic> _tripDocuments = [];
  int _totalPhotos = 0;
  bool _isLoadingPhotos = true;

  String? _tripType;
  String? _businessTripType;
  String? _userRole;
  bool _hasFamilyMembers = false;
  List<String> _myFamilyMemberNames = [];
  List<String> _myFamilyMemberIds = [];

  bool _isNameMatch(String name1, String name2) {
    final n1 = name1.trim().toLowerCase();
    final n2 = name2.trim().toLowerCase();
    if (n1.isEmpty || n2.isEmpty) return false;
    if (n1 == n2) return true;
    if (n1.contains(n2) || n2.contains(n1)) {
      final words1 = n1.split(RegExp(r'\s+'));
      final words2 = n2.split(RegExp(r'\s+'));
      if (words1.isNotEmpty && words2.isNotEmpty && words1.first == words2.first) {
        return true;
      }
      if (words1.contains(n2) || words2.contains(n1)) {
        return true;
      }
    }
    return false;
  }

  bool _isMyFamilyDocument(Map<String, dynamic> d) {
    if (d['isMine'] == true) return true;
    final mName = (d['memberName']?.toString().trim() ?? '').toLowerCase();
    final bId = (d['belongsTo'] is Map 
        ? (d['belongsTo']['_id']?.toString() ?? '') 
        : (d['belongsToId']?.toString() ?? d['belongsTo']?.toString() ?? '')).trim();

    if (mName.isNotEmpty) {
      for (var name in _myFamilyMemberNames) {
        if (_isNameMatch(name, mName)) return true;
      }
    }
    if (bId.isNotEmpty && _myFamilyMemberIds.contains(bId)) {
      return true;
    }
    return false;
  }

  List<dynamic> get _myFamilyDocuments {
    return _allFetchedDocuments.where((d) => d['type'] != 'Trip' && _isMyFamilyDocument(d)).toList();
  }

  List<dynamic> get _memberDocuments {
    return _allFetchedDocuments.where((d) => d['type'] != 'Trip' && !_isMyFamilyDocument(d)).toList();
  }

  bool get _isFamilyOrEmployeeWithFamily {
    final tType = _tripType ?? widget.tripData?['tripType']?.toString() ?? widget.tripData?['type']?.toString();
    final bType = _businessTripType ?? widget.tripData?['businessTripType']?.toString();
    return tType == 'Family' || (tType == 'Business' && bType == 'Employees + Family');
  }

  bool get _isTripLeaderOrCreator {
    if (widget.isTripLeader) return true;
    final role = widget.tripData?['role']?.toString().toLowerCase();
    final origRole = widget.tripData?['originalRole']?.toString().toLowerCase();
    return role == 'trip leader' || origRole == 'creator' || origRole == 'tripleader' || origRole == 'admin';
  }

  bool get _isFamilyMember {
    final role = widget.tripData?['role']?.toString().toLowerCase();
    final origRole = widget.tripData?['originalRole']?.toString().toLowerCase();
    if (role == 'familymember' || origRole == 'familymember' || role == 'family member' || origRole == 'family member') {
      return true;
    }
    if (_userRole?.toLowerCase() == 'familymember' || _userRole?.toLowerCase() == 'family member') {
      return true;
    }
    return false;
  }

  bool get _canViewDocuments {
    if (widget.isPhotoGalleryOnly) return false;
    if (_isFamilyMember) return false;
    return true;
  }

  bool get _shouldShowMemberDocuments {
    if (widget.isSoloTraveler) {
      return false;
    }

    // Only Trip Creator or Trip Leader can see the Member Documents card.
    // Family Leaders already manage their family members inside "My Family Documents", so they do not see this card.
    return _isTripLeaderOrCreator;
  }

  @override
  void initState() {
    super.initState();
    _tripType = widget.tripData?['tripType']?.toString() ?? widget.tripData?['type']?.toString();
    _businessTripType = widget.tripData?['businessTripType']?.toString();
    _fetchPhotos();
    _fetchDocuments();
    _fetchParticipants();
    _fetchTripAndFamilyDetails();
  }

  Future<void> _fetchTripAndFamilyDetails() async {
    final tripId = (widget.tripData?['_id'] ?? widget.tripData?['id'])?.toString();
    if (tripId == null) return;

    try {
      final familyRes = await _tripService.getMyFamily(tripId);
      if (familyRes['success'] == true && familyRes['data'] != null && mounted) {
        final data = familyRes['data'];
        final bool hasFam = data['hasFamily'] == true;
        final List<dynamic> members = (data['family'] != null && data['family']['members'] != null)
            ? data['family']['members']
            : [];

        List<String> famNames = [];
        List<String> famIds = [];
        for (var m in members) {
          if (m is Map) {
            final name = m['name']?.toString().trim();
            if (name != null && name.isNotEmpty) famNames.add(name.toLowerCase());
            final uId = m['userId']?.toString().trim();
            if (uId != null && uId.isNotEmpty) famIds.add(uId);
            final mId = (m['_id'] ?? m['id'])?.toString().trim();
            if (mId != null && mId.isNotEmpty) famIds.add(mId);
          }
        }

        setState(() {
          _hasFamilyMembers = hasFam && members.isNotEmpty;
          _myFamilyMemberNames = famNames;
          _myFamilyMemberIds = famIds;
          if (data['role'] != null) _userRole = data['role'].toString();
          if (data['tripType'] != null) _tripType = data['tripType'].toString();
          if (data['businessTripType'] != null) _businessTripType = data['businessTripType'].toString();
        });
      }
    } catch (e) {
      debugPrint('Error fetching my family details: $e');
    }
  }

  Future<void> _fetchParticipants() async {
    final tripId = (widget.tripData?['_id'] ?? widget.tripData?['id'])?.toString();
    if (tripId == null) return;
    try {
      final userService = UserService();
      
      final profileRes = await userService.getProfile();
      final currentUserId = profileRes['success'] == true ? profileRes['data']['_id']?.toString() : null;

      final response = await _tripService.getTripParticipants(tripId);
      if (response['success'] == true && mounted) {
        final List<Map<String, dynamic>> allParticipants = List<Map<String, dynamic>>.from(response['data']);
        
        if (currentUserId != null) {
          final myParticipant = allParticipants.firstWhere(
            (p) => p['userId']?.toString() == currentUserId || p['id']?.toString() == currentUserId,
            orElse: () => <String, dynamic>{},
          );
          if (myParticipant.isNotEmpty) {
            final fMembers = myParticipant['familyMembers'];
            if (fMembers is List && fMembers.isNotEmpty) {
              List<String> famNames = List<String>.from(_myFamilyMemberNames);
              List<String> famIds = List<String>.from(_myFamilyMemberIds);
              for (var fm in fMembers) {
                if (fm is Map) {
                  final name = fm['name']?.toString().trim();
                  if (name != null && name.isNotEmpty && !famNames.contains(name.toLowerCase())) {
                    famNames.add(name.toLowerCase());
                  }
                  final uId = fm['userId']?.toString().trim();
                  if (uId != null && uId.isNotEmpty && !famIds.contains(uId)) famIds.add(uId);
                  final mId = (fm['_id'] ?? fm['id'])?.toString().trim();
                  if (mId != null && mId.isNotEmpty && !famIds.contains(mId)) famIds.add(mId);
                }
              }
              setState(() {
                _hasFamilyMembers = true;
                _myFamilyMemberNames = famNames;
                _myFamilyMemberIds = famIds;
              });
            } else if (myParticipant['type'] == 'Solo' || myParticipant['type'] == 'Individual') {
              setState(() {
                _hasFamilyMembers = false;
              });
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error fetching participants: $e');
    }
  }

  Future<void> _fetchDocuments() async {
    final tripId = (widget.tripData?['_id'] ?? widget.tripData?['id'])?.toString();
    if (tripId == null) return;
    try {
      final response = await _documentService.getTripDocuments(tripId);
      if (response['success'] == true) {
        final List<dynamic> allDocs = response['documents'];
        if (mounted) {
          setState(() {
            _allFetchedDocuments = allDocs;
            _myDocuments = allDocs.where((d) => d['type'] != 'Trip' && (d['isMine'] == true || (d['memberName']?.toString().trim().toLowerCase() == 'you'))).toList();
            _tripDocuments = allDocs.where((d) => d['type'] == 'Trip').toList();
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching docs: $e');
    }
  }

  Future<void> _fetchPhotos() async {
    final tripId = (widget.tripData?['_id'] ?? widget.tripData?['id'])?.toString();
    if (tripId == null) {
      if (mounted) setState(() => _isLoadingPhotos = false);
      return;
    }
    try {
      final response = await _photoService.getTripPhotos(tripId);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  await Future.wait([
                    _fetchPhotos(),
                    _fetchDocuments(),
                    _fetchParticipants(),
                    _fetchTripAndFamilyDetails(),
                  ]);
                },
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildPhotoGallerySection(),
                      if (!widget.isPhotoGalleryOnly) ...[
                        if (_canViewDocuments) ...[
                          const SizedBox(height: 20),
                          _buildPersonalOrFamilyDocsCard(),
                          if (_shouldShowMemberDocuments) ...[
                            const SizedBox(height: 16),
                            _buildMemberDocsCard(),
                          ],
                          const SizedBox(height: 16),
                        ] else ...[
                          const SizedBox(height: 20),
                        ],
                        _buildTripDocsCard(),
                      ],
                      const SizedBox(height: 100), // Extra space for FAB
                    ],
                  ),
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

  bool get _isFamilyLeaderRole {
    if (widget.isFamilyLeader) return true;
    final role = widget.tripData?['role']?.toString().toLowerCase();
    final origRole = widget.tripData?['originalRole']?.toString().toLowerCase();
    if (role == 'family leader' || role == 'familyleader' || origRole == 'family leader' || origRole == 'familyleader') {
      return true;
    }
    if (_userRole?.toLowerCase() == 'familyleader' || _userRole?.toLowerCase() == 'family leader') {
      return true;
    }
    if (_isFamilyOrEmployeeWithFamily && _hasFamilyMembers) {
      return true;
    }
    return false;
  }

  String get _personalOrFamilyDocsTitle {
    if (_isFamilyOrEmployeeWithFamily && _hasFamilyMembers) {
      return 'My Family Documents';
    }
    return 'My Documents';
  }

  String get _personalOrFamilyDocsSubtitle {
    if (_isFamilyOrEmployeeWithFamily && _hasFamilyMembers) {
      return 'Manage your and your family\'s identity documents';
    }
    return 'Your important identity documents';
  }

  void _onPersonalOrFamilyDocsTap() {
    if (_isFamilyOrEmployeeWithFamily && _hasFamilyMembers) {
      // Person with Family: opens Image 2 layout with "You" folder + family member folders
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => AllDocumentsScreen(
            title: 'My Family Documents',
            documents: _myFamilyDocuments,
            tripData: widget.tripData,
            isFamilyLeader: _isFamilyLeaderRole,
          ),
        ),
      ).then((_) {
        _fetchDocuments();
        _fetchTripAndFamilyDetails();
      });
    } else {
      // Person is alone: directly opens Image 3 layout (personal documents)
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => AllDocumentsScreen(
            title: 'My Documents',
            documents: _myDocuments,
            tripData: widget.tripData,
            isFamilyLeader: _isFamilyLeaderRole,
          ),
        ),
      ).then((_) {
        _fetchDocuments();
        _fetchTripAndFamilyDetails();
      });
    }
  }

  Widget _buildPersonalOrFamilyDocsCard() {
    return _buildNavigationCard(
      icon: (_isFamilyOrEmployeeWithFamily && _hasFamilyMembers)
          ? Icons.family_restroom_outlined
          : Icons.assignment_outlined,
      iconBgColor: const Color(0xFFDCFCE7),
      iconColor: AppColors.secondary,
      title: _personalOrFamilyDocsTitle,
      subtitle: _personalOrFamilyDocsSubtitle,
      onTap: _onPersonalOrFamilyDocsTap,
    );
  }

  Widget _buildMemberDocsCard() {
    return _buildNavigationCard(
      icon: Icons.people_outline,
      iconBgColor: const Color(0xFFEFF6FF),
      iconColor: const Color(0xFF0072FF),
      title: 'Member Documents',
      subtitle: 'View documents shared by trip members',
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AllDocumentsScreen(
              title: 'Member Documents',
              documents: _memberDocuments,
              tripData: widget.tripData,
              isFamilyLeader: false,
              isFromMemberDocs: true,
            ),
          ),
        ).then((_) {
          _fetchDocuments();
          _fetchTripAndFamilyDetails();
        });
      },
    );
  }

  Widget _buildTripDocsCard() {
    return _buildNavigationCard(
      icon: Icons.folder_open_outlined,
      iconBgColor: const Color(0xFFF3E8FF),
      iconColor: const Color(0xFF7C3AED),
      title: 'Trip Documents',
      subtitle: 'Important documents shared with all trip members',
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AllDocumentsScreen(
              title: 'Trip Documents',
              documents: _tripDocuments,
              tripData: widget.tripData,
              isFamilyLeader: _isFamilyLeaderRole,
            ),
          ),
        ).then((_) {
          _fetchDocuments();
          _fetchTripAndFamilyDetails();
        });
      },
    );
  }

  Widget _buildNavigationCard({
    required IconData icon,
    required Color iconBgColor,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF1F5F9), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            child: Row(
              children: [
                Container(
                  height: 48,
                  width: 48,
                  decoration: BoxDecoration(
                    color: iconBgColor,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: iconColor, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 16,
                  color: Color(0xFF94A3B8),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
