import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../services/notification_socket_manager.dart';
import '../../expenses/screens/trip_expense_screen.dart';
import '../../expenses/screens/trip_expense_detail_screen.dart';
import '../../chat/screens/chat_screen.dart';
import '../../itinerary/screens/itinerary_screen.dart';
import '../../trip/screens/trip_details_screen.dart';
import '../../trip/screens/solo_traveler_dashboard_screen.dart';
import '../../trip/screens/family_leader_dashboard_screen.dart';
import '../../trip/screens/family_member_dashboard_screen.dart';
import '../../trip/screens/member_dashboard_screen.dart';
import '../../trip/services/trip_service.dart';


class NotificationSheet extends StatefulWidget {
  const NotificationSheet({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const NotificationSheet(),
    );
  }

  @override
  State<NotificationSheet> createState() => _NotificationSheetState();
}

class _NotificationSheetState extends State<NotificationSheet> {
  final NotificationSocketManager _manager = NotificationSocketManager();
  String _selectedFilter = 'All';

  @override
  void initState() {
    super.initState();
    _manager.fetchNotifications();
  }

  List<Map<String, dynamic>> _filterNotifications(List<Map<String, dynamic>> items) {
    if (_selectedFilter == 'All') return items;
    if (_selectedFilter == 'Announcement') {
      return items.where((n) => n['type'] == 'announcement').toList();
    }
    if (_selectedFilter == 'Chat') {
      return items.where((n) => n['type'] == 'newMessage').toList();
    }
    if (_selectedFilter == 'Itinerary') {
      return items.where((n) => n['type'] == 'itineraryUpdate').toList();
    }
    if (_selectedFilter == 'Poll') {
      return items
          .where((n) =>
              n['type'] == 'pollCreated' ||
              n['type'] == 'pollUpdated' ||
              n['type'] == 'pollResult')
          .toList();
    }
    if (_selectedFilter == 'Splits') {
      return items
          .where((n) =>
              n['type'] == 'expenseAdded' || n['type'] == 'expenseUpdated')
          .toList();
    }
    return items;
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final maxHeight = mediaQuery.size.height * 0.85;

    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag Handle
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                const Icon(
                  Icons.notifications_active_rounded,
                  color: AppColors.primary,
                  size: 24,
                ),
                const SizedBox(width: 10),
                const Text(
                  'Notifications',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(width: 8),
                ValueListenableBuilder<int>(
                  valueListenable: _manager.unreadCount,
                  builder: (context, count, _) {
                    if (count == 0) return const SizedBox.shrink();
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '$count new',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    );
                  },
                ),
                const Spacer(),
                TextButton(
                  onPressed: () {
                    _manager.markAllAsRead();
                  },
                  child: const Text(
                    'Mark all read',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.grey),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1),

          // Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                _buildFilterChip('All'),
                _buildFilterChip('Announcement'),
                _buildFilterChip('Chat'),
                _buildFilterChip('Itinerary'),
                _buildFilterChip('Poll'),
                _buildFilterChip('Splits'),
              ],
            ),
          ),

          // Notifications List
          Expanded(
            child: ValueListenableBuilder<List<Map<String, dynamic>>>(
              valueListenable: _manager.notifications,
              builder: (context, list, _) {
                final filtered = _filterNotifications(list);

                if (filtered.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.notifications_none_rounded,
                            size: 64,
                            color: Colors.grey[300],
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'No notifications yet',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Real-time updates for itineraries, splits, and chats will appear here.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: filtered.length,
                  separatorBuilder: (context, index) => const Divider(height: 1, indent: 64),
                  itemBuilder: (context, index) {
                    final item = filtered[index];
                    return _buildNotificationTile(item);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label) {
    final isSelected = _selectedFilter == label;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        selected: isSelected,
        label: Text(label),
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : AppColors.textPrimary,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          fontSize: 13,
        ),
        selectedColor: AppColors.primary,
        backgroundColor: const Color(0xFFF1F5F9),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide.none,
        ),
        onSelected: (selected) {
          setState(() {
            _selectedFilter = label;
          });
        },
      ),
    );
  }

  Future<void> _handleNotificationTap(Map<String, dynamic> item) async {
    final String? notificationId = item['_id'];
    if (notificationId != null && item['isRead'] != true) {
      _manager.markAsRead(notificationId);
    }

    final String? tripId = item['tripId']?.toString();
    if (tripId == null || tripId.isEmpty) {
      return;
    }

    final String type = item['type']?.toString() ?? '';
    final String tripName = item['tripName']?.toString() ?? '';
    final String? referenceId = item['referenceId']?.toString();

    // Fetch full trip data if available so destination screen gets all trip fields
    Map<String, dynamic>? tripData;
    try {
      final res = await TripService().getTrips();
      if (res['success'] == true && res['data'] is List) {
        final trips = res['data'] as List;
        final found = trips.firstWhere(
          (t) => (t['_id'] ?? t['id'])?.toString() == tripId,
          orElse: () => null,
        );
        if (found != null) {
          tripData = Map<String, dynamic>.from(found);
        }
      }
    } catch (_) {}

    tripData ??= {
      '_id': tripId,
      'id': tripId,
      'name': tripName.isNotEmpty ? tripName : 'Trip',
      'title': tripName.isNotEmpty ? tripName : 'Trip',
    };

    if (!mounted) return;

    // Dismiss bottom sheet modal first
    Navigator.pop(context);

    final Map<String, dynamic> activeTrip = tripData;

    if (type == 'expenseAdded' || type == 'expenseUpdated') {
      if (referenceId != null && referenceId.isNotEmpty) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => TripExpenseDetailScreen(
              tripId: tripId,
              expenseId: referenceId,
              tripData: activeTrip,
            ),
          ),
        );
      } else {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => TripExpenseScreen(
              tripData: activeTrip,
              onBack: () => Navigator.pop(context),
            ),
          ),
        );
      }
    } else if (type == 'announcement') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChatScreen(
            tripId: tripId,
            tripName: tripName.isNotEmpty ? tripName : (activeTrip['name'] ?? 'Trip Chat'),
            tripData: activeTrip,
            initialTabIndex: 0,
          ),
        ),
      );
    } else if (type == 'newMessage') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChatScreen(
            tripId: tripId,
            tripName: tripName.isNotEmpty ? tripName : (activeTrip['name'] ?? 'Trip Chat'),
            tripData: activeTrip,
            initialTabIndex: 1,
          ),
        ),
      );
    } else if (type == 'pollCreated' || type == 'pollUpdated' || type == 'pollResult') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChatScreen(
            tripId: tripId,
            tripName: tripName.isNotEmpty ? tripName : (activeTrip['name'] ?? 'Trip Chat'),
            tripData: activeTrip,
            initialTabIndex: 2,
          ),
        ),
      );
    } else if (type == 'itineraryUpdate') {
      final role = (activeTrip['role'] ?? activeTrip['participantRole'])?.toString().toLowerCase();
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ItineraryScreen(
            tripData: activeTrip,
            isSoloTraveler: role == 'solotraveler' || role == 'solo_traveler',
          ),
        ),
      );
    } else {
      // Default / trip update: open trip dashboard according to role
      final role = (activeTrip['role'] ?? activeTrip['participantRole'])?.toString().toLowerCase() ?? 'member';
      if (role == 'admin' || role == 'creator' || role == 'tripleader') {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => TripDetailsScreen(tripData: activeTrip),
          ),
        );
      } else if (role == 'solotraveler' || role == 'solo_traveler') {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SoloTravelerDashboardScreen(tripData: activeTrip),
          ),
        );
      } else if (role == 'familyleader' || role == 'family_leader') {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => FamilyLeaderDashboardScreen(tripData: activeTrip),
          ),
        );
      } else if (role == 'familymember' || role == 'family_member') {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => FamilyMemberDashboardScreen(tripData: activeTrip),
          ),
        );
      } else {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MemberDashboardScreen(tripData: activeTrip),
          ),
        );
      }
    }

  }

  Widget _buildNotificationTile(Map<String, dynamic> item) {
    final isRead = item['isRead'] == true;
    final type = item['type'] ?? '';
    final title = item['title'] ?? 'Notification';
    final message = item['message'] ?? '';
    final String tripName = item['tripName']?.toString().trim() ?? '';
    final createdAt = item['createdAt'] != null
        ? DateTime.tryParse(item['createdAt'].toString())
        : null;

    IconData icon = Icons.notifications_rounded;
    Color iconBg = const Color(0xFFEFF6FF);
    Color iconColor = AppColors.primary;

    if (type == 'itineraryUpdate') {
      icon = Icons.calendar_month_rounded;
      iconBg = const Color(0xFFF3E8FF);
      iconColor = const Color(0xFF9333EA);
    } else if (type == 'expenseAdded' || type == 'expenseUpdated') {
      icon = Icons.account_balance_wallet_rounded;
      iconBg = const Color(0xFFE8F5E9);
      iconColor = const Color(0xFF2E7D32);
    } else if (type == 'announcement') {
      icon = Icons.campaign_rounded;
      iconBg = const Color(0xFFFEF3C7);
      iconColor = const Color(0xFFD97706);
    } else if (type == 'newMessage') {
      icon = Icons.chat_bubble_rounded;
      iconBg = const Color(0xFFE0F2FE);
      iconColor = const Color(0xFF0284C7);
    } else if (type == 'pollCreated' || type == 'pollUpdated' || type == 'pollResult') {
      icon = Icons.poll_rounded;
      iconBg = const Color(0xFFEFF6FF);
      iconColor = const Color(0xFF1E5AE6);
    }

    String timeAgo = 'Just now';
    if (createdAt != null) {
      final now = DateTime.now();
      final diff = now.difference(createdAt.toLocal());
      if (diff.inMinutes < 1) {
        timeAgo = 'Just now';
      } else if (diff.inMinutes < 60) {
        timeAgo = '${diff.inMinutes}m ago';
      } else if (diff.inHours < 24) {
        timeAgo = '${diff.inHours}h ago';
      } else if (diff.inDays < 7) {
        timeAgo = '${diff.inDays}d ago';
      } else {
        timeAgo = DateFormat('MMM d').format(createdAt.toLocal());
      }
    }

    return Dismissible(
      key: Key(item['_id'] ?? UniqueKey().toString()),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Colors.red[100],
        child: const Icon(Icons.delete_outline, color: Colors.red),
      ),
      onDismissed: (direction) {
        if (item['_id'] != null) {
          _manager.deleteNotification(item['_id']);
        }
      },
      child: InkWell(
        onTap: () => _handleNotificationTap(item),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            color: isRead ? Colors.transparent : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: iconBg,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (tripName.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFDBEAFE)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.card_travel, size: 11, color: AppColors.primary),
                              const SizedBox(width: 4),
                              Text(
                                tripName,
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: isRead ? FontWeight.w600 : FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          timeAgo,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      message,
                      style: TextStyle(
                        fontSize: 13,
                        color: isRead ? AppColors.textSecondary : AppColors.textPrimary,
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!isRead)
                    Container(
                      margin: const EdgeInsets.only(right: 6),
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: Color(0xFF94A3B8),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

}
