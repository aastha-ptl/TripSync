import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/custom_app_bar.dart';
import '../../profile/screens/profile_screen.dart';

class SoloTravelerDashboardScreen extends StatelessWidget {
  final Map<String, dynamic> tripData;
  final String? profilePhotoUrl;

  const SoloTravelerDashboardScreen({
    super.key, 
    required this.tripData,
    this.profilePhotoUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Column(
          children: [
            CustomAppBar(
              title: tripData['title'] ?? 'Solo Trip',
              tripImageUrl: tripData['imageUrl'],
              profilePhotoUrl: profilePhotoUrl,
              showBackButton: true,
              onProfileTap: () {
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
            ),
            const Expanded(
              child: Center(
                child: Text('Solo Traveler Dashboard (Coming Soon)'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
