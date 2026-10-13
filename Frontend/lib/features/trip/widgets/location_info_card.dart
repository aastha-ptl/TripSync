import 'package:flutter/material.dart';
import '../models/member_location.dart';
import '../models/trip_location.dart';
import '../../../core/theme/app_colors.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:tripsync/core/utils/image_utils.dart';

class LocationInfoCard extends StatelessWidget {
  final MemberLocation? member;
  final TripLocation? tripLocation;
  final String? distanceText;
  final VoidCallback onClose;
  final VoidCallback? onNavigate;
  final VoidCallback? onAddToItinerary;
  final VoidCallback? onEditEvent;
  final VoidCallback? onViewEvent;
  final VoidCallback? onFocusMember;

  const LocationInfoCard({
    super.key,
    this.member,
    this.tripLocation,
    this.distanceText,
    required this.onClose,
    this.onNavigate,
    this.onAddToItinerary,
    this.onEditEvent,
    this.onViewEvent,
    this.onFocusMember,
  });

  String _formatTimeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) {
      return '${diff.inSeconds} seconds ago';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes} minutes ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours} hours ago';
    } else {
      return '${diff.inDays} days ago';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (member == null && tripLocation == null) {
      return const SizedBox.shrink();
    }

    final title = member != null ? member!.name : tripLocation!.title;
    final subtitle = member != null
        ? member!.familyName
        : (tripLocation!.address ?? tripLocation!.description);

    final isPublicPlace = tripLocation?.isPublicPlace == true;
    final isItineraryEvent = tripLocation != null && !isPublicPlace;

    final placeDetails = tripLocation?.placeDetails;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Type Label, Distance Chip, Close Button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: member != null
                          ? const Color(0xFFEFF6FF)
                          : _getLocationColor(tripLocation!.type).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      member != null
                          ? 'MEMBER'
                          : (isPublicPlace
                              ? (placeDetails?.categoryLabel.toUpperCase() ?? 'POINT OF INTEREST')
                              : 'ITINERARY: ${_getLocationLabel(tripLocation!.type).toUpperCase()}'),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: member != null
                            ? AppColors.primary
                            : _getLocationColor(tripLocation!.type),
                      ),
                    ),
                  ),
                  if (distanceText != null && distanceText!.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.navigation, size: 10, color: Color(0xFF059669)),
                          const SizedBox(width: 4),
                          Text(
                            distanceText!,
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF059669),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
              GestureDetector(
                onTap: onClose,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF1F5F9),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, size: 16, color: Color(0xFF64748B)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Main Details Row
          Row(
            children: [
              if (member != null)
                GestureDetector(
                  onTap: onFocusMember,
                  child: CircleAvatar(
                    radius: 26,
                    backgroundImage: CachedNetworkImageProvider(
                      ImageUtils.getOptimizedImageUrl(member!.profileImage),
                    ),
                  ),
                )
              else if (tripLocation != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _getLocationColor(tripLocation!.type).withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _getLocationIcon(tripLocation!.type),
                    color: _getLocationColor(tripLocation!.type),
                    size: 26,
                  ),
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
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              if (member != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: member!.isOnline
                        ? const Color(0xFFEFFDF5)
                        : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        height: 6,
                        width: 6,
                        decoration: BoxDecoration(
                          color: member!.isOnline ? const Color(0xFF20C060) : const Color(0xFF64748B),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        member!.isOnline ? 'Online' : 'Offline',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: member!.isOnline ? const Color(0xFF20C060) : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),

          // Member last updated row
          if (member != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.access_time, size: 12, color: Color(0xFF94A3B8)),
                const SizedBox(width: 5),
                Text(
                  'Last updated ${_formatTimeAgo(member!.lastUpdated)}',
                  style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                ),
              ],
            ),
          ],

          // Genuine Details (Only when genuinely available from data source)
          if (placeDetails != null) ...[
            if (placeDetails.openingHours != null && placeDetails.openingHours!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.schedule, size: 13, color: Color(0xFF64748B)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Hours: ${placeDetails.openingHours}',
                      style: const TextStyle(fontSize: 11.5, color: Color(0xFF475569)),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
            if (placeDetails.phone != null && placeDetails.phone!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.phone_outlined, size: 13, color: Color(0xFF64748B)),
                  const SizedBox(width: 6),
                  Text(
                    placeDetails.phone!,
                    style: const TextStyle(fontSize: 11.5, color: Color(0xFF475569)),
                  ),
                ],
              ),
            ],
          ],

          const SizedBox(height: 16),

          // Actions Row: Primary Action (Add to Itinerary / Edit Event / Focus Member) + External Maps Navigation
          Row(
            children: [
              // 1. Add to Itinerary Button (For public places)
              if (onAddToItinerary != null)
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onAddToItinerary,
                    icon: const Icon(Icons.add_location_alt_rounded, size: 18, color: Colors.white),
                    label: const Text(
                      'Add to Itinerary',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0072FF),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                  ),
                ),

              // 2. Edit Event Button (For existing itinerary events)
              if (isItineraryEvent && onEditEvent != null)
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onEditEvent,
                    icon: const Icon(Icons.edit_calendar_rounded, size: 18, color: Colors.white),
                    label: const Text(
                      'Edit Event',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F172A),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                  ),
                ),

              // 3. Focus on Member (For members when selected)
              if (member != null && onFocusMember != null)
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onFocusMember,
                    icon: const Icon(Icons.center_focus_strong_rounded, size: 18, color: Colors.white),
                    label: const Text(
                      'Focus on Member',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0072FF),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                  ),
                ),

              // 4. External Maps Navigation Button
              if (onNavigate != null) ...[
                if (onAddToItinerary != null || (isItineraryEvent && onEditEvent != null) || (member != null && onFocusMember != null)) ...[
                  const SizedBox(width: 10),
                  IconButton.filledTonal(
                    onPressed: onNavigate,
                    icon: const Icon(Icons.open_in_new_rounded, size: 20, color: Color(0xFF0F172A)),
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(0xFFF1F5F9),
                      padding: const EdgeInsets.all(13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    tooltip: 'Open in Navigation App',
                  ),
                ] else ...[
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: onNavigate,
                      icon: const Icon(Icons.open_in_new_rounded, size: 18, color: Color(0xFF0F172A)),
                      label: const Text(
                        'Open in Navigation App',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF1F5F9),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ],
            ],
          ),
        ],
      ),
    );
  }

  String _getLocationLabel(LocationType type) {
    switch (type) {
      case LocationType.hotel:
        return 'Hotel';
      case LocationType.airport:
        return 'Travel';
      case LocationType.restaurant:
        return 'Restaurant';
      case LocationType.sightseeing:
        return 'Sightseeing';
      case LocationType.activity:
        return 'Activity';
      case LocationType.general:
        return 'Place';
    }
  }

  IconData _getLocationIcon(LocationType type) {
    switch (type) {
      case LocationType.hotel:
        return Icons.hotel_rounded;
      case LocationType.airport:
        return Icons.flight_takeoff_rounded;
      case LocationType.restaurant:
        return Icons.restaurant_rounded;
      case LocationType.sightseeing:
        return Icons.photo_camera_rounded;
      case LocationType.activity:
        return Icons.local_activity_rounded;
      case LocationType.general:
        return Icons.location_on_rounded;
    }
  }

  Color _getLocationColor(LocationType type) {
    switch (type) {
      case LocationType.hotel:
        return const Color(0xFF20C060);
      case LocationType.airport:
        return const Color(0xFFEA580C);
      case LocationType.restaurant:
        return const Color(0xFFF59E0B);
      case LocationType.sightseeing:
        return const Color(0xFF0EA5E9);
      case LocationType.activity:
        return const Color(0xFF9333EA);
      case LocationType.general:
        return const Color(0xFF1E5AE6);
    }
  }
}
