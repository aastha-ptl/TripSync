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
  File? _imageFile;
  final ImagePicker _picker = ImagePicker();
  final PhotoService _photoService = PhotoService();
  final TripService _tripService = TripService();
  final UserService _userService = UserService();
  String? _currentUserId;

  String _visibility = 'Everyone';
  List<Map<String, dynamic>> _participants = [];
  List<String> _selectedParticipants = [];
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
        _currentUserId = userResponse['data']['_id'];
      }
    } catch (e) {
      // Ignore error, _currentUserId will be null
    }

    final response = await _tripService.getTripParticipants(widget.tripData['_id']);
    if (response['success'] == true) {
      setState(() {
        final List<Map<String, dynamic>> fetchedParticipants = List<Map<String, dynamic>>.from(response['data']);
        final List<Map<String, dynamic>> flattenedParticipants = [];
        
        for (var p in fetchedParticipants) {
          if (p['userId'] != null && p['userId'] != _currentUserId) {
            flattenedParticipants.add({
              'userId': p['userId'],
              'name': p['name'],
              'role': p['role'],
            });
          }
          if (p['familyMembers'] != null) {
            for (var m in p['familyMembers']) {
              if (m['userId'] != null && m['userId'] != _currentUserId) {
                flattenedParticipants.add({
                  'userId': m['userId'],
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

  Future<void> _pickImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
      });
    }
  }

  Future<void> _uploadPhoto() async {
    if (_imageFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an image first')),
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
    
    final response = await _photoService.uploadPhoto(
      widget.tripData['_id'], 
      _imageFile!, 
      _visibility, 
      _selectedParticipants,
    );

    setState(() => _isLoading = false);

    if (response['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Photo uploaded successfully')),
      );
      Navigator.pop(context, true); // true indicates a photo was uploaded
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(response['message'] ?? 'Upload failed')),
      );
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
        title: const Text('Upload Photo', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.primary,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                width: double.infinity,
                height: 250,
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: _imageFile != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.file(_imageFile!, fit: BoxFit.cover),
                      )
                    : const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_photo_alternate, size: 60, color: AppColors.primary),
                          SizedBox(height: 10),
                          Text('Tap to select an image', style: TextStyle(color: AppColors.textSecondary)),
                        ],
                      ),
              ),
            ),
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
                          final userId = participant['userId'];
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
                onPressed: _isLoading ? null : _uploadPhoto,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        'Upload Photo',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
