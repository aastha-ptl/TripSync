import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/app_colors.dart';
import '../services/photo_service.dart';
import '../services/trip_service.dart';
import '../../profile/services/user_service.dart';

class UploadPhotoScreen extends StatefulWidget {
  final Map<String, dynamic> tripData;

  const UploadPhotoScreen({super.key, required this.tripData});

  @override
  State<UploadPhotoScreen> createState() => _UploadPhotoScreenState();
}

class _UploadPhotoScreenState extends State<UploadPhotoScreen> {
  final List<File> _imageFiles = [];
  final ImagePicker _picker = ImagePicker();
  final PhotoService _photoService = PhotoService();
  final TripService _tripService = TripService();
  final UserService _userService = UserService();
  String? _currentUserId;

  String _visibility = 'Everyone';
  List<Map<String, dynamic>> _participants = [];
  final List<String> _selectedParticipants = [];
  bool _isLoading = false;
  bool _isLoadingParticipants = false;

  @override
  void initState() {
    super.initState();
    _fetchParticipants();
  }

  int _getRoleWeight(String role) {
    if (role == 'tripLeader' || role == 'familyLeader') return 0;
    return 1;
  }

  Future<void> _fetchParticipants() async {
    setState(() => _isLoadingParticipants = true);

    try {
      final userResponse = await _userService.getProfile();
      if (userResponse['success'] == true && userResponse['data'] != null) {
        _currentUserId = userResponse['data']['_id']?.toString();
      }
    } catch (_) {}

    final response = await _tripService.getTripParticipants(widget.tripData['_id']);
    if (response['success'] == true) {
      setState(() {
        final List<Map<String, dynamic>> fetchedParticipants =
            List<Map<String, dynamic>>.from(response['data']);
        final List<Map<String, dynamic>> flattenedParticipants = [];

        for (var p in fetchedParticipants) {
          final pUserId = p['userId']?.toString();
          if (pUserId != null && pUserId != _currentUserId) {
            flattenedParticipants.add({
              'userId': pUserId,
              'name': p['name'],
              'role': p['role'],
            });
          }
          if (p['familyMembers'] != null) {
            for (var m in p['familyMembers']) {
              final mUserId = m['userId']?.toString();
              if (mUserId != null && mUserId != _currentUserId) {
                flattenedParticipants.add({
                  'userId': mUserId,
                  'name': m['name'],
                  'role': m['relationship'] ?? 'Family Member',
                });
              }
            }
          }
        }

        flattenedParticipants.sort((a, b) {
          final roleA = a['role'] ?? 'Member';
          final roleB = b['role'] ?? 'Member';
          final weightA = _getRoleWeight(roleA);
          final weightB = _getRoleWeight(roleB);
          return weightA.compareTo(weightB);
        });
        _participants = flattenedParticipants;
        _isLoadingParticipants = false;
      });
    } else {
      setState(() => _isLoadingParticipants = false);
    }
  }

  Future<void> _pickImages() async {
    try {
      final List<XFile> pickedFiles = await _picker.pickMultiImage();
      if (pickedFiles.isNotEmpty) {
        setState(() {
          for (var xFile in pickedFiles) {
            final file = File(xFile.path);
            if (!_imageFiles.any((f) => f.path == file.path)) {
              _imageFiles.add(file);
            }
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking images: $e')),
        );
      }
    }
  }

  Future<void> _pickFromCamera() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(source: ImageSource.camera);
      if (pickedFile != null) {
        setState(() {
          _imageFiles.add(File(pickedFile.path));
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error taking photo: $e')),
        );
      }
    }
  }

  void _showImageSourceSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Add Photos',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.photo_library_rounded, color: AppColors.primary),
                  ),
                  title: const Text('Choose Multiple from Gallery', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Select one or more photos'),
                  onTap: () {
                    Navigator.pop(context);
                    _pickImages();
                  },
                ),
                const SizedBox(height: 8),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.camera_alt_rounded, color: Color(0xFF10B981)),
                  ),
                  title: const Text('Take a Photo with Camera', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Capture using camera'),
                  onTap: () {
                    Navigator.pop(context);
                    _pickFromCamera();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _uploadPhotos() async {
    if (_imageFiles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one photo')),
      );
      return;
    }
    if (_visibility == 'SelectedMembers' && _selectedParticipants.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one member')),
      );
      return;
    }

    setState(() => _isLoading = true);

    final response = await _photoService.uploadPhotos(
      widget.tripData['_id'],
      _imageFiles,
      _visibility,
      _selectedParticipants,
    );

    setState(() => _isLoading = false);

    if (response['success'] == true) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${_imageFiles.length} photo${_imageFiles.length > 1 ? 's' : ''} uploaded successfully',
            ),
          ),
        );
        Navigator.pop(context, true);
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(response['message'] ?? 'Upload failed')),
        );
      }
    }
  }

  String _formatRole(String role) {
    if (role == 'familyLeader') return 'Family Leader';
    if (role == 'tripLeader') return 'Trip Leader';
    if (role == 'familyMember') return 'Family Member';
    if (role == 'soloTraveler') return 'Solo Traveler';
    return role;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Upload Photos', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.primary,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Selected Images Section
            if (_imageFiles.isEmpty)
              GestureDetector(
                onTap: _showImageSourceSheet,
                child: Container(
                  width: double.infinity,
                  height: 220,
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.primary.withOpacity(0.3), width: 1.5),
                  ),
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_photo_alternate_rounded, size: 60, color: AppColors.primary),
                      SizedBox(height: 12),
                      Text(
                        'Tap to Select Photos',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Multiple photos supported from gallery',
                        style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              )
            else ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${_imageFiles.length} Photo${_imageFiles.length > 1 ? 's' : ''} Selected',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                  TextButton.icon(
                    onPressed: _showImageSourceSheet,
                    icon: const Icon(Icons.add, size: 18, color: AppColors.primary),
                    label: const Text('Add More', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                height: 140,
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                padding: const EdgeInsets.all(10),
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _imageFiles.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (context, index) {
                    final file = _imageFiles[index];
                    return Stack(
                      clipBehavior: Clip.none,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.file(
                            file,
                            width: 120,
                            height: 120,
                            fit: BoxFit.cover,
                          ),
                        ),
                        Positioned(
                          top: 4,
                          right: 4,
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _imageFiles.removeAt(index);
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Colors.black87,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.close, color: Colors.white, size: 14),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],

            const SizedBox(height: 30),
            const Text('Visibility', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: RadioListTile<String>(
                    title: const Text('Everyone'),
                    value: 'Everyone',
                    groupValue: _visibility,
                    activeColor: AppColors.primary,
                    contentPadding: EdgeInsets.zero,
                    onChanged: (value) {
                      setState(() {
                        _visibility = value!;
                      });
                    },
                  ),
                ),
                Expanded(
                  child: RadioListTile<String>(
                    title: const Text('Selected Members'),
                    value: 'SelectedMembers',
                    groupValue: _visibility,
                    activeColor: AppColors.primary,
                    contentPadding: EdgeInsets.zero,
                    onChanged: (value) {
                      setState(() {
                        _visibility = value!;
                      });
                    },
                  ),
                ),
              ],
            ),
            if (_visibility == 'SelectedMembers') ...[
              const SizedBox(height: 20),
              const Text('Select Members', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              _isLoadingParticipants
                  ? const Center(child: CircularProgressIndicator())
                  : Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.border),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _participants.length,
                        itemBuilder: (context, index) {
                          final participant = _participants[index];
                          final userId = participant['userId']?.toString() ?? '';
                          final userName = participant['name'] ?? 'Unknown User';
                          final role = participant['role'] ?? 'Member';

                          return CheckboxListTile(
                            title: Text(userName),
                            subtitle: Text(
                              _formatRole(role),
                              style: const TextStyle(color: Colors.grey, fontSize: 13),
                            ),
                            value: _selectedParticipants.contains(userId),
                            activeColor: AppColors.primary,
                            onChanged: (bool? selected) {
                              setState(() {
                                if (selected == true) {
                                  _selectedParticipants.add(userId);
                                } else {
                                  _selectedParticipants.remove(userId);
                                }
                              });
                            },
                          );
                        },
                      ),
                    ),
            ],
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _uploadPhotos,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isLoading
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          ),
                          SizedBox(width: 12),
                          Text('Uploading Photos...', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ],
                      )
                    : Text(
                        _imageFiles.isEmpty
                            ? 'Upload Photos'
                            : 'Upload ${_imageFiles.length} Photo${_imageFiles.length > 1 ? 's' : ''}',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
