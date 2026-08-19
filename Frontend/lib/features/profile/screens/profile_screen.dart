import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/routes/app_routes.dart';
import '../../auth/services/auth_service.dart';
import '../services/user_service.dart';
import 'edit_profile_screen.dart';
import '../../../core/widgets/custom_app_bar.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:tripsync/core/utils/image_utils.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _profileData;
  bool _isLoading = true;
  final UserService _userService = UserService();

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  Future<void> _fetchProfile() async {
    setState(() {
      _isLoading = true;
    });
    
    final response = await _userService.getProfile();
    
    if (mounted) {
      setState(() {
        _isLoading = false;
        if (response['success'] == true) {
          _profileData = response['data'];
        }
      });
    }
  }

  String _getProfileValue(String key) {
    if (_profileData == null) return 'Not added';
    final val = _profileData![key];
    if (val == null || val.toString().trim().isEmpty) return 'Not added';
    if (key == 'dateOfBirth') {
      DateTime dob = DateTime.parse(val.toString());
      return '${dob.year}-${dob.month.toString().padLeft(2, '0')}-${dob.day.toString().padLeft(2, '0')}';
    }
    return val.toString();
  }

  String get _profileName => _profileData != null ? '${_profileData!['firstName']} ${_profileData!['lastName']}' : 'Loading...';
  String get _profileEmail => _profileData != null ? _profileData!['email'] ?? 'Not added' : 'Loading...';
  String get _profilePhone => _getProfileValue('phone');
  String get _profileGender => _getProfileValue('gender');
  String get _profileDob => _getProfileValue('dateOfBirth');
  String get _profileCountry => _getProfileValue('country');
  String get _profileCity => _getProfileValue('city');
  String get _profileBio => _getProfileValue('bio');

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          CustomAppBar(
            title: 'Profile',
            profilePhotoUrl: _profileData?['profilePhoto'],
            extraActions: [
              IconButton(
                icon: const Icon(
                  Icons.logout,
                  color: AppColors.textPrimary,
                  size: 24,
                ),
                onPressed: () async {
                  await AuthService().logout();
                  if (context.mounted) {
                    Navigator.pushReplacementNamed(context, AppRoutes.login);
                  }
                },
              ),
            ],
          ),
          Expanded(
            child: _isLoading 
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 20),
                    _buildProfileHeaderCard(),
                    const SizedBox(height: 24),
                    _buildPersonalInfoHeader(),
                    const SizedBox(height: 12),
                    _buildPersonalInfoCard(),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }



  Widget _buildProfileHeaderCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFF3F4FD),
            Color(0xFFE5E7FA),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E5AE6).withOpacity(0.02),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                    ),
                    child: CircleAvatar(
                      radius: 46,
                      backgroundColor: const Color(0xFFE2E8F0),
                      backgroundImage: CachedNetworkImageProvider(ImageUtils.getOptimizedImageUrl(_profileData!['profilePhoto'], fallbackName: _profileData!['name'])),
                      child: null,
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Color(0x1F000000),
                            blurRadius: 4,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.camera_alt,
                        size: 16,
                        color: Color(0xFF1E5AE6),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          _profileName,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(
                          Icons.verified,
                          color: Color(0xFF10B981),
                          size: 20,
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: const [
                        Text(
                          'Travel Enthusiast ',
                          style: TextStyle(
                            fontSize: 13,
                            color: Color(0xFF475569),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Icon(
                          Icons.flight_takeoff,
                          size: 14,
                          color: Color(0xFF1E5AE6),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Icon(Icons.mail_outline, size: 16, color: Color(0xFF64748B)),
                        const SizedBox(width: 8),
                        Text(
                          _profileEmail,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.phone_outlined, size: 16, color: Color(0xFF64748B)),
                        const SizedBox(width: 8),
                        Text(
                          _profilePhone,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: _showEditProfileForm,
            child: Container(
              width: double.infinity,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.02),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.edit_outlined, color: Color(0xFF1E5AE6), size: 18),
                  SizedBox(width: 8),
                  Text(
                    'Edit Profile',
                    style: TextStyle(
                      color: Color(0xFF1E5AE6),
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPersonalInfoHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: const [
            Text(
              'Personal Information',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
            ),
            SizedBox(width: 6),
            Icon(
              Icons.info_outline,
              color: Color(0xFF94A3B8),
              size: 16,
            ),
          ],
        ),
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Optional',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E5AE6),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.keyboard_arrow_up,
                size: 18,
                color: Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPersonalInfoCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white,
            Color(0xFFFCFDFF),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFEEF2F6), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.015),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildInfoRow(
            icon: Icons.person_outline,
            label: 'Full Name',
            value: _profileName,
            iconBgColor: const Color(0xFFE8FDF0),
            iconColor: const Color(0xFF10B981),
          ),
          _buildInfoRow(
            icon: Icons.mail_outline,
            label: 'Email (Read Only)',
            value: _profileEmail,
            iconBgColor: const Color(0xFFEFF6FF),
            iconColor: const Color(0xFF1E5AE6),
          ),
          _buildInfoRow(
            icon: Icons.phone_outlined,
            label: 'Phone Number',
            value: _profilePhone,
            iconBgColor: const Color(0xFFFFF7ED),
            iconColor: const Color(0xFFF59E0B),
            isNotAdded: _profilePhone == 'Not added',
          ),
          _buildInfoRow(
            icon: Icons.transgender_outlined,
            label: 'Gender',
            value: _profileGender,
            iconBgColor: const Color(0xFFF5F3FF),
            iconColor: const Color(0xFF8B5CF6),
            isNotAdded: _profileGender == 'Not added',
          ),
          _buildInfoRow(
            icon: Icons.calendar_month_outlined,
            label: 'Date of Birth',
            value: _profileDob,
            iconBgColor: const Color(0xFFFDF2F8),
            iconColor: const Color(0xFFEC4899),
            isNotAdded: _profileDob == 'Not added',
          ),
          _buildInfoRow(
            icon: Icons.public_outlined,
            label: 'Country',
            value: _profileCountry,
            iconBgColor: const Color(0xFFEEF2FF),
            iconColor: const Color(0xFF6366F1),
            isNotAdded: _profileCountry == 'Not added',
          ),
          _buildInfoRow(
            icon: Icons.location_city_outlined,
            label: 'City',
            value: _profileCity,
            iconBgColor: const Color(0xFFECFDF5),
            iconColor: const Color(0xFF0D9488),
            isNotAdded: _profileCity == 'Not added',
          ),
          _buildInfoRow(
            icon: Icons.chat_bubble_outline_outlined,
            label: 'Bio / About Me',
            value: _profileBio,
            iconBgColor: const Color(0xFFF0FDF4),
            iconColor: const Color(0xFF15803D),
            isNotAdded: _profileBio == 'Not added',
            isLast: true,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    required Color iconBgColor,
    required Color iconColor,
    bool isNotAdded = false,
    bool isLast = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : const Border(
                bottom: BorderSide(color: Color(0xFFF1F5F9), width: 1),
              ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconBgColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: iconColor,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              color: isNotAdded ? const Color(0xFF94A3B8) : const Color(0xFF475569),
              fontStyle: isNotAdded ? FontStyle.italic : FontStyle.normal,
              fontWeight: isNotAdded ? FontWeight.w500 : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  void _showEditProfileForm() async {
    if (_profileData == null) return;
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditProfileScreen(initialData: _profileData!),
      ),
    );
    
    if (result == true) {
      _fetchProfile(); // Refresh after edit
    }
  }
}
