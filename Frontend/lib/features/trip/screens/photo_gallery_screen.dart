import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../models/photo_model.dart';
import '../services/photo_service.dart';
import '../services/trip_service.dart';
import '../../profile/services/user_service.dart';
import 'upload_photo_screen.dart';

class PhotoGalleryScreen extends StatefulWidget {
  final Map<String, dynamic> tripData;

  const PhotoGalleryScreen({super.key, required this.tripData});

  @override
  State<PhotoGalleryScreen> createState() => _PhotoGalleryScreenState();
}

class _PhotoGalleryScreenState extends State<PhotoGalleryScreen> with SingleTickerProviderStateMixin {
  final PhotoService _photoService = PhotoService();
  final UserService _userService = UserService();
  final TripService _tripService = TripService();

  bool _isLoading = true;
  String? _currentUserId;
  Map<String, String> _memberNames = {};
  List<Photo> _publicPhotos = [];
  List<Photo> _privatePhotos = [];
  late TabController _tabController;

  // Multiple selection for photos uploaded by the user
  final Set<String> _selectedPhotoIds = {};
  bool _isSelectionMode = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        if (_selectedPhotoIds.isNotEmpty || _isSelectionMode) {
          setState(() {
            _selectedPhotoIds.clear();
            _isSelectionMode = false;
          });
        }
      }
    });
    _initializeData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _initializeData() async {
    await _fetchUserData();
    await _fetchPhotos();
  }

  Future<void> _fetchUserData() async {
    try {
      final userResponse = await _userService.getProfile();
      if (userResponse['success'] == true && userResponse['data'] != null) {
        if (mounted) {
          setState(() {
            _currentUserId = userResponse['data']['_id']?.toString();
          });
        }
      }
    } catch (_) {}

    try {
      final tripId = widget.tripData['_id']?.toString() ?? '';
      if (tripId.isNotEmpty) {
        final response = await _tripService.getTripParticipants(tripId);
        if (response['success'] == true && response['data'] != null) {
          final List<dynamic> fetchedParticipants = response['data'];
          final Map<String, String> namesMap = {};

          for (var p in fetchedParticipants) {
            if (p['userId'] != null && p['name'] != null) {
              namesMap[p['userId'].toString()] = p['name'].toString();
            }
            if (p['familyMembers'] != null && p['familyMembers'] is List) {
              for (var m in p['familyMembers']) {
                if (m['userId'] != null && m['name'] != null) {
                  namesMap[m['userId'].toString()] = m['name'].toString();
                }
              }
            }
          }

          if (mounted) {
            setState(() {
              _memberNames = namesMap;
            });
          }
        }
      }
    } catch (_) {}
  }

  String _getDisplayName(Photo photo) {
    final uId = photo.uploader.id;
    if (_memberNames.containsKey(uId) && _memberNames[uId]!.trim().isNotEmpty) {
      return _memberNames[uId]!;
    }
    return photo.uploader.name;
  }

  Future<void> _fetchPhotos() async {
    setState(() => _isLoading = true);
    try {
      final response = await _photoService.getTripPhotos(widget.tripData['_id']);

      if (response['success'] == true) {
        final List<dynamic> photosData = response['photos'];
        final allPhotos = photosData.map((data) => Photo.fromJson(data)).toList();

        setState(() {
          _publicPhotos = allPhotos.where((p) => p.visibility == 'Everyone').toList();
          _privatePhotos = allPhotos.where((p) => p.visibility != 'Everyone').toList();
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(response['message'] ?? 'Failed to load photos')),
          );
        }
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error parsing photos: $e')),
        );
      }
    }
  }

  void _togglePhotoSelection(String photoId) {
    setState(() {
      if (_selectedPhotoIds.contains(photoId)) {
        _selectedPhotoIds.remove(photoId);
        if (_selectedPhotoIds.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        _selectedPhotoIds.add(photoId);
      }
    });
  }

  Future<void> _confirmDeleteSelectedPhotos() async {
    if (_selectedPhotoIds.isEmpty) return;

    final count = _selectedPhotoIds.length;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.delete_outline_rounded, color: Colors.red),
            const SizedBox(width: 8),
            Text(
              'Delete $count Photo${count > 1 ? 's' : ''}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to delete $count selected photo${count > 1 ? 's' : ''}? This action cannot be undone.',
          style: const TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Delete', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      try {
        final tripId = widget.tripData['_id']?.toString() ?? '';
        int successCount = 0;
        for (final photoId in _selectedPhotoIds.toList()) {
          final res = await _photoService.deletePhoto(tripId, photoId);
          if (res['success'] == true) successCount++;
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$successCount photo${successCount > 1 ? 's' : ''} deleted successfully')),
          );
        }
        setState(() {
          _selectedPhotoIds.clear();
          _isSelectionMode = false;
        });
        _fetchPhotos();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting photos: $e')),
          );
          setState(() => _isLoading = false);
        }
      }
    }
  }

  Future<void> _confirmDeleteSinglePhoto(Photo photo) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.delete_outline_rounded, color: Colors.red),
            SizedBox(width: 8),
            Text('Delete Photo', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: const Text(
          'Are you sure you want to delete this photo? This action cannot be undone.',
          style: TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Delete', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final res = await _photoService.deletePhoto(widget.tripData['_id'], photo.id);
        if (res['success'] == true) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Photo deleted successfully')),
            );
          }
          _fetchPhotos();
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(res['message'] ?? 'Failed to delete photo')),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting photo: $e')),
          );
        }
      }
    }
  }

  void _showPhotoDetails(Photo photo) {
    final isUploadedByMe = _currentUserId != null && photo.uploader.id == _currentUserId;
    final displayName = isUploadedByMe ? 'You' : _getDisplayName(photo);

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(10),
          child: Stack(
            alignment: Alignment.center,
            children: [
              InteractiveViewer(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    photo.photoUrl,
                    fit: BoxFit.contain,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return const Center(child: CircularProgressIndicator(color: Colors.white));
                    },
                    errorBuilder: (context, error, stackTrace) =>
                        const Icon(Icons.error, color: Colors.white, size: 50),
                  ),
                ),
              ),
              Positioned(
                top: 10,
                right: 10,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Red delete button is as it is in when particular photo is open
                    if (isUploadedByMe) ...[
                      Container(
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.white, size: 22),
                          onPressed: () {
                            Navigator.pop(context);
                            _confirmDeleteSinglePhoto(photo);
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Container(
                      decoration: const BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.close, color: Colors.white, size: 24),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                bottom: 20,
                left: 20,
                right: 20,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.75),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withOpacity(0.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Icon(
                            isUploadedByMe ? Icons.check_circle_outline : Icons.person,
                            color: Colors.white70,
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              displayName,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            photo.visibility == 'Everyone' ? Icons.public : Icons.lock,
                            color: Colors.white70,
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            photo.visibility == 'Everyone' ? 'Public (Everyone)' : 'Private (Selected Members)',
                            style: const TextStyle(color: Colors.white70, fontSize: 13),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              )
            ],
          ),
        );
      },
    );
  }

  Widget _buildUploadedByMeHeader({
    required int totalCount,
    required List<Photo> uploadedPhotos,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF0072FF).withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.cloud_upload_rounded, size: 18, color: Color(0xFF0072FF)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Row(
                children: [
                  const Flexible(
                    child: Text(
                      'Uploaded by You',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0072FF).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$totalCount',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0072FF),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (totalCount > 0 && _selectedPhotoIds.isEmpty) ...[
              TextButton(
                onPressed: () {
                  setState(() {
                    _isSelectionMode = true;
                  });
                },
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(
                  'Select',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0072FF),
                  ),
                ),
              ),
            ],
          ],
        ),
        // Action bar when photos are selected
        if (_selectedPhotoIds.isNotEmpty) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.red.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${_selectedPhotoIds.length} photo${_selectedPhotoIds.length > 1 ? 's' : ''} selected',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.red,
                    ),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _confirmDeleteSelectedPhotos,
                  icon: const Icon(Icons.delete_outline_rounded, size: 16, color: Colors.white),
                  label: Text(
                    'Delete (${_selectedPhotoIds.length})',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    elevation: 1,
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: () {
                    setState(() {
                      _selectedPhotoIds.clear();
                      _isSelectionMode = false;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSectionHeader({
    required String title,
    required int count,
    required IconData icon,
    required Color color,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: color),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Row(
            children: [
              Flexible(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPhotoTile(Photo photo, {required bool isUploadedByMe}) {
    final displayName = isUploadedByMe ? 'You' : _getDisplayName(photo);
    final isSelected = _selectedPhotoIds.contains(photo.id);

    return GestureDetector(
      onTap: () {
        if (isUploadedByMe && _isSelectionMode) {
          _togglePhotoSelection(photo.id);
        } else {
          _showPhotoDetails(photo);
        }
      },
      onLongPress: isUploadedByMe
          ? () {
              if (!_isSelectionMode) {
                setState(() {
                  _isSelectionMode = true;
                  _selectedPhotoIds.add(photo.id);
                });
              } else {
                _togglePhotoSelection(photo.id);
              }
            }
          : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: isSelected
              ? Border.all(color: const Color(0xFF0072FF), width: 3)
              : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(isSelected ? 9 : 12),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.network(
                photo.photoUrl,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Container(
                    color: Colors.grey[200],
                    child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                  );
                },
                errorBuilder: (context, error, stackTrace) => Container(
                  color: Colors.grey[200],
                  child: const Icon(Icons.broken_image, color: Colors.grey, size: 30),
                ),
              ),
              // Subtle blue overlay when photo is selected
              if (isSelected)
                Container(
                  color: const Color(0xFF0072FF).withOpacity(0.25),
                ),
              // Gradient bottom banner with uploader's name
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withOpacity(0.75),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isUploadedByMe ? Icons.check_circle_outline : Icons.person,
                        color: Colors.white,
                        size: 10,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          displayName,
                          style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Selection indicator checkbox in selection mode (NO red delete box!)
              if (isUploadedByMe && _isSelectionMode)
                Positioned(
                  top: 6,
                  right: 6,
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFF0072FF) : Colors.black45,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                    child: isSelected
                        ? const Icon(Icons.check, size: 14, color: Colors.white)
                        : null,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPhotoGrid(List<Photo> photos, {required bool isUploadedByMe}) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1,
      ),
      itemCount: photos.length,
      itemBuilder: (context, index) {
        return _buildPhotoTile(photos[index], isUploadedByMe: isUploadedByMe);
      },
    );
  }

  Widget _buildTabContent({
    required List<Photo> photos,
    required String emptyMessage,
    required String tabLabel,
  }) {
    if (photos.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.photo_library_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              emptyMessage,
              style: TextStyle(color: Colors.grey[600], fontSize: 16, fontWeight: FontWeight.w500),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    final uploadedByMe = photos.where((p) => _currentUserId != null && p.uploader.id == _currentUserId).toList();
    final sharedWithMe = photos.where((p) => _currentUserId == null || p.uploader.id != _currentUserId).toList();

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section 1: Uploaded by You (Above)
          _buildUploadedByMeHeader(
            totalCount: uploadedByMe.length,
            uploadedPhotos: uploadedByMe,
          ),
          const SizedBox(height: 12),
          if (uploadedByMe.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Center(
                child: Text(
                  'You haven\'t uploaded any $tabLabel photos yet.',
                  style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
              ),
            )
          else
            _buildPhotoGrid(uploadedByMe, isUploadedByMe: true),

          const SizedBox(height: 28),

          // Section 2: Shared with You (Below)
          _buildSectionHeader(
            title: 'Shared with You',
            count: sharedWithMe.length,
            icon: Icons.people_alt_rounded,
            color: const Color(0xFF10B981),
          ),
          const SizedBox(height: 12),
          if (sharedWithMe.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Center(
                child: Text(
                  'No $tabLabel photos shared with you yet.',
                  style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
              ),
            )
          else
            _buildPhotoGrid(sharedWithMe, isUploadedByMe: false),

          const SizedBox(height: 80), // Extra space for FAB
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Photo Gallery', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Custom Tab Bar below the AppBar
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Container(
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: TabBar(
                      controller: _tabController,
                      labelColor: Colors.white,
                      unselectedLabelColor: AppColors.textSecondary,
                      indicatorSize: TabBarIndicatorSize.tab,
                      indicator: BoxDecoration(
                        borderRadius: BorderRadius.circular(22),
                        color: AppColors.primary,
                      ),
                      dividerColor: Colors.transparent,
                      tabs: const [
                        Tab(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.public, size: 18),
                              SizedBox(width: 8),
                              Text('Public', style: TextStyle(fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                        Tab(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.lock, size: 18),
                              SizedBox(width: 8),
                              Text('Private', style: TextStyle(fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildTabContent(
                        photos: _publicPhotos,
                        emptyMessage: 'No public photos yet.\nBe the first to upload!',
                        tabLabel: 'public',
                      ),
                      _buildTabContent(
                        photos: _privatePhotos,
                        emptyMessage: 'No private photos yet.\nUpload photos visible only to selected members.',
                        tabLabel: 'private',
                      ),
                    ],
                  ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add_a_photo, color: Colors.white),
        label: const Text('Add Photo', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        elevation: 4,
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => UploadPhotoScreen(tripData: widget.tripData),
            ),
          );
          if (result == true) {
            _fetchPhotos();
          }
        },
      ),
    );
  }
}
