import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String _profileName = 'Aastha Patel';
  String _profilePhone = '+91 98765 43210';
  String _profileGender = 'Not added';
  String _profileDob = 'Not added';
  String _profileCountry = 'Not added';
  String _profileCity = 'Not added';
  String _profileBio = 'Not added';

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          _buildHeader(title: 'Profile'),
          Expanded(
            child: SingleChildScrollView(
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

  Widget _buildHeader({String? title}) {
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
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
        Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.asset(
                'assets/images/logo.png',
                height: 56,
                width: 56,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  height: 56,
                  width: 56,
                  color: Colors.grey[200],
                  child: const Icon(Icons.map, color: AppColors.primary),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              title ?? 'Profile',
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        Row(
          children: [
            Stack(
              children: [
                IconButton(
                  icon: const Icon(
                    Icons.notifications_outlined,
                    color: AppColors.textPrimary,
                    size: 28,
                  ),
                  onPressed: () {},
                ),
                Positioned(
                  right: 12,
                  top: 12,
                  child: Container(
                    height: 8,
                    width: 8,
                    decoration: const BoxDecoration(
                      color: Color(0xFF1E5AE6),
                      shape: BoxShape.circle,
                    ),
                  ),
                )
              ],
            ),
            const SizedBox(width: 8),
            const CircleAvatar(
              radius: 20,
              backgroundImage: NetworkImage(
                'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=150&auto=format&fit=crop&q=80',
              ),
            ),
          ],
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
                    child: const CircleAvatar(
                      radius: 46,
                      backgroundImage: NetworkImage(
                        'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=300&auto=format&fit=crop&q=80',
                      ),
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
                      children: const [
                        Icon(Icons.mail_outline, size: 16, color: Color(0xFF64748B)),
                        SizedBox(width: 8),
                        Text(
                          'aastha.patel@gmail.com',
                          style: TextStyle(
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
            value: 'aastha.patel@gmail.com',
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

  void _showEditProfileForm() {
    final nameController = TextEditingController(text: _profileName);
    final phoneController = TextEditingController(text: _profilePhone == 'Not added' ? '' : _profilePhone);
    final genderController = TextEditingController(text: _profileGender == 'Not added' ? '' : _profileGender);
    final dobController = TextEditingController(text: _profileDob == 'Not added' ? '' : _profileDob);
    final countryController = TextEditingController(text: _profileCountry == 'Not added' ? '' : _profileCountry);
    final cityController = TextEditingController(text: _profileCity == 'Not added' ? '' : _profileCity);
    final bioController = TextEditingController(text: _profileBio == 'Not added' ? '' : _profileBio);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: EdgeInsets.only(
            top: 20,
            left: 24,
            right: 24,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 48,
                    height: 5,
                    decoration: BoxDecoration(
                      color: const Color(0xFFCBD5E1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Edit Profile Details',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Color(0xFF64748B)),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _buildField('Full Name', nameController, Icons.person_outline),
                _buildField('Phone Number', phoneController, Icons.phone_outlined, keyboardType: TextInputType.phone),
                _buildField('Gender', genderController, Icons.transgender_outlined),
                _buildField('Date of Birth', dobController, Icons.calendar_month_outlined),
                _buildField('Country', countryController, Icons.public_outlined),
                _buildField('City', cityController, Icons.location_city_outlined),
                _buildField('Bio / About Me', bioController, Icons.chat_bubble_outline_outlined, maxLines: 3),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _profileName = nameController.text.trim().isEmpty ? 'Aastha Patel' : nameController.text.trim();
                        _profilePhone = phoneController.text.trim().isEmpty ? 'Not added' : phoneController.text.trim();
                        _profileGender = genderController.text.trim().isEmpty ? 'Not added' : genderController.text.trim();
                        _profileDob = dobController.text.trim().isEmpty ? 'Not added' : dobController.text.trim();
                        _profileCountry = countryController.text.trim().isEmpty ? 'Not added' : countryController.text.trim();
                        _profileCity = cityController.text.trim().isEmpty ? 'Not added' : cityController.text.trim();
                        _profileBio = bioController.text.trim().isEmpty ? 'Not added' : bioController.text.trim();
                      });
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E5AE6),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Save Changes',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildField(String label, TextEditingController controller, IconData icon, {TextInputType? keyboardType, int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Color(0xFF475569),
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: controller,
            keyboardType: keyboardType,
            maxLines: maxLines,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF0F172A),
            ),
            decoration: InputDecoration(
              hintText: 'Enter your $label',
              prefixIcon: Icon(icon, size: 20, color: const Color(0xFF64748B)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF1E5AE6), width: 1.5),
              ),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
            ),
          ),
        ],
      ),
    );
  }
}
