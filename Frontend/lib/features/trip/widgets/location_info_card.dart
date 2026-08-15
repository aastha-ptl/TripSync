import 'package:flutter/material.dart';
import '../models/member_location.dart';
import '../models/trip_location.dart';
import '../../../core/theme/app_colors.dart';

class LocationInfoCard extends StatelessWidget {
  final MemberLocation? member;
  final TripLocation? tripLocation;
  final VoidCallback onClose;

  const LocationInfoCard({
    super.key,
    this.member,
    this.tripLocation,
    required this.onClose,
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

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Close and Type Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                member != null ? 'Member Location' : 'Trip Location',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF64748B),
                ),
              ),
              GestureDetector(
                onTap: onClose,
                child: const Icon(Icons.close, size: 20, color: Color(0xFF64748B)),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Main details
          if (member != null) ...[
            Row(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundImage: NetworkImage(member!.profileImage),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        member!.name,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        member!.familyName,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                // Online badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: member!.isOnline
                        ? const Color(0xFFEFFDF5)
                        : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
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
                      const SizedBox(width: 6),
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
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.access_time, size: 14, color: Color(0xFF94A3B8)),
                    const SizedBox(width: 6),
                    Text(
                      'Updated ${_formatTimeAgo(member!.lastUpdated)}',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                    ),
                  ],
                ),
                TextButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Opening profile of ${member!.name}...')),
                    );
                  },
                  icon: const Icon(Icons.person_outline, size: 14),
                  label: const Text('View Profile', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ] else if (tripLocation != null) ...[
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _getLocationColor(tripLocation!.type).withOpacity(0.1),
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
                        tripLocation!.title,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        tripLocation!.description,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ElevatedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Getting directions to ${tripLocation!.title}...')),
                    );
                  },
                  icon: const Icon(Icons.directions, size: 16, color: Colors.white),
                  label: const Text('Get Directions', style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  IconData _getLocationIcon(LocationType type) {
    switch (type) {
      case LocationType.hotel:
        return Icons.hotel;
      case LocationType.airport:
        return Icons.local_airport;
      case LocationType.activity:
        return Icons.local_activity;
      case LocationType.general:
        return Icons.location_on;
    }
  }

  Color _getLocationColor(LocationType type) {
    switch (type) {
      case LocationType.hotel:
        return const Color(0xFF20C060); // Green
      case LocationType.airport:
        return const Color(0xFFEA580C); // Orange
      case LocationType.activity:
        return const Color(0xFF9333EA); // Purple
      case LocationType.general:
        return const Color(0xFF1E5AE6); // Blue
    }
  }
}
