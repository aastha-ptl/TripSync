import 'package:flutter/material.dart';
import '../models/member_location.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:tripsync/core/utils/image_utils.dart';

class MemberMapMarker extends StatelessWidget {
  final MemberLocation member;
  final bool isCurrentUser;

  const MemberMapMarker({
    super.key,
    required this.member,
    required this.isCurrentUser,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            // Outer glow/border ring
            Container(
              height: 44,
              width: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isCurrentUser
                    ? const Color(0xFF1E5AE6) // Blue for current user
                    : (member.isOnline ? const Color(0xFF20C060) : const Color(0xFF94A3B8)), // Green for online, Grey for offline
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 6,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
            ),
            // Circular profile image
            CircleAvatar(
              radius: 19,
              backgroundColor: Colors.white,
              child: CircleAvatar(
                radius: 17,
                backgroundImage: CachedNetworkImageProvider(ImageUtils.getOptimizedImageUrl(member.profileImage)),
              ),
            ),
            // Small online status dot indicator
            if (member.isOnline)
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  height: 10,
                  width: 10,
                  decoration: BoxDecoration(
                    color: const Color(0xFF20C060),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 3),
        // Name Label below marker
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.9),
            borderRadius: BorderRadius.circular(6),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 4,
              ),
            ],
          ),
          child: Text(
            isCurrentUser ? 'Me' : member.name.split(' ').first,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.bold,
              color: isCurrentUser ? const Color(0xFF1E5AE6) : const Color(0xFF0F172A),
            ),
          ),
        ),
      ],
    );
  }
}
