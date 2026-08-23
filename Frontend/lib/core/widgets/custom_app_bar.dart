import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:tripsync/core/utils/image_utils.dart';

class CustomAppBar extends StatelessWidget {
  final String? title;
  final String? profilePhotoUrl;
  final String? tripImageUrl;
  final VoidCallback? onProfileTap;
  final List<Widget>? extraActions;
  final bool showBackButton;
  final String? profileName;
  final VoidCallback? onNotificationTap;
  final IconData notificationIcon;

  const CustomAppBar({
    super.key,
    this.title,
    this.profilePhotoUrl,
    this.tripImageUrl,
    this.onProfileTap,
    this.extraActions,
    this.showBackButton = false,
    this.profileName,
    this.onNotificationTap,
    this.notificationIcon = Icons.notifications_outlined,
  });

  @override
  Widget build(BuildContext context) {
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
          // App Logo and Title
          Expanded(
            child: Row(
              children: [
              if (showBackButton)
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Padding(
                    padding: EdgeInsets.only(right: 12),
                    child: Icon(Icons.arrow_back_ios_new, size: 20, color: AppColors.textPrimary),
                  ),
                ),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: tripImageUrl != null
                    ? CachedNetworkImage(imageUrl: ImageUtils.getOptimizedImageUrl(tripImageUrl!),
                        height: 56,
                        width: 56,
                        fit: BoxFit.cover,
                        errorWidget: (context, url, error) => Container(
                          height: 56,
                          width: 56,
                          color: Colors.grey[200],
                          child: const Icon(Icons.image, color: AppColors.primary),
                        ),
                      )
                    : Image.asset(
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
              if (title != null)
                Expanded(
                  child: Text(
                    title!,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                )
              else
                Row(
                  children: const [
                    Text(
                      'Trip',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      'Sync',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AppColors.secondary,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          ),

          // Notifications & Profile
          Row(
            children: [
              Stack(
                children: [
                  IconButton(
                    icon: Icon(
                      notificationIcon,
                      color: AppColors.textPrimary,
                      size: 28,
                    ),
                    onPressed: onNotificationTap ?? () {},
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
              if (extraActions != null) ...extraActions!,
              const SizedBox(width: 8),
              GestureDetector(
                onTap: onProfileTap,
                child: CircleAvatar(
                  radius: 20,
                  backgroundColor: const Color(0xFFE2E8F0),
                  backgroundImage: profilePhotoUrl != null && profilePhotoUrl!.isNotEmpty
                      ? CachedNetworkImageProvider(ImageUtils.getOptimizedImageUrl(profilePhotoUrl))
                      : null,
                  child: profilePhotoUrl == null || profilePhotoUrl!.isEmpty
                      ? Text(
                          _getInitials(profileName),
                          style: const TextStyle(
                            color: Color(0xFF475569),
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        )
                      : null,
                ),
              ),
            ],
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
}
