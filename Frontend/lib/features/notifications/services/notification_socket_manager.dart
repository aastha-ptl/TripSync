import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../../../core/constants/api_endpoints.dart';
import '../../profile/services/user_service.dart';
import 'notification_service.dart';

class NotificationSocketManager {
  static final NotificationSocketManager _instance = NotificationSocketManager._internal();
  factory NotificationSocketManager() => _instance;
  NotificationSocketManager._internal();

  IO.Socket? _socket;
  String? _currentUserId;
  bool _isInitialized = false;

  final ValueNotifier<int> unreadCount = ValueNotifier<int>(0);
  final ValueNotifier<List<Map<String, dynamic>>> notifications = ValueNotifier<List<Map<String, dynamic>>>([]);
  final NotificationService _notificationService = NotificationService();
  final UserService _userService = UserService();

  Future<void> init() async {
    if (_isInitialized && _socket != null && _socket!.connected) return;

    try {
      final profileRes = await _userService.getProfile();
      if (profileRes['success'] == true && profileRes['data'] != null) {
        _currentUserId = profileRes['data']['_id']?.toString();
      }

      await fetchNotifications();

      if (_currentUserId != null && _currentUserId!.isNotEmpty) {
        _connectSocket();
      }
      _isInitialized = true;
    } catch (e) {
      debugPrint('[NotificationSocketManager] Error initializing: $e');
    }
  }

  void _connectSocket() async {
    try {
      if (_socket != null && _socket!.connected) return;

      final apiBaseUrl = await ApiEndpoints.getBaseUrl();
      final serverUrl = apiBaseUrl.replaceFirst(RegExp(r'/api/?$'), '');

      debugPrint('[NotificationSocketManager] Connecting socket to $serverUrl');

      _socket = IO.io(
        serverUrl,
        IO.OptionBuilder()
            .setTransports(['websocket', 'polling'])
            .disableAutoConnect()
            .build(),
      );

      _socket!.onConnect((_) {
        debugPrint('[NotificationSocketManager] Connected. Joining user room: user_$_currentUserId');
        if (_currentUserId != null) {
          _socket!.emit('join_user_room', _currentUserId);
        }
      });

      _socket!.on('new_notification', (data) {
        debugPrint('[NotificationSocketManager] Realtime new_notification received: $data');
        if (data is Map<String, dynamic>) {
          _onRealtimeNotificationReceived(data);
        }
      });

      _socket!.on('new_announcement', (data) {
        debugPrint('[NotificationSocketManager] Realtime new_announcement received: $data');
        fetchNotifications();
      });

      _socket!.on('new_group_message', (data) {
        debugPrint('[NotificationSocketManager] Realtime new_group_message received: $data');
        fetchNotifications();
      });

      _socket!.on('itinerary_updated', (data) {
        debugPrint('[NotificationSocketManager] Realtime itinerary_updated received: $data');
        fetchNotifications();
      });

      _socket!.on('expense_added', (data) {
        debugPrint('[NotificationSocketManager] Realtime expense_added received: $data');
        fetchNotifications();
      });

      _socket!.onDisconnect((_) {
        debugPrint('[NotificationSocketManager] Socket disconnected');
      });

      _socket!.onError((err) {
        debugPrint('[NotificationSocketManager] Socket error: $err');
      });

      _socket!.connect();
    } catch (e) {
      debugPrint('[NotificationSocketManager] Connection exception: $e');
    }
  }


  void joinTripRoom(String tripId) {
    if (_socket != null && _socket!.connected && tripId.isNotEmpty) {
      _socket!.emit('join_trip_room', tripId);
    }
  }

  void leaveTripRoom(String tripId) {
    if (_socket != null && _socket!.connected && tripId.isNotEmpty) {
      _socket!.emit('leave_trip_room', tripId);
    }
  }

  void _onRealtimeNotificationReceived(Map<String, dynamic> data) {
    final currentList = List<Map<String, dynamic>>.from(notifications.value);
    
    // Check if duplicate
    final existsIndex = currentList.indexWhere((n) => n['_id'] == data['_id']);
    if (existsIndex != -1) {
      currentList[existsIndex] = data;
    } else {
      currentList.insert(0, data);
    }

    notifications.value = currentList;
    unreadCount.value = unreadCount.value + 1;
  }

  Future<void> fetchNotifications() async {
    try {
      final response = await _notificationService.getNotifications();
      if (response['success'] == true) {
        final List raw = response['data'] ?? [];
        notifications.value = List<Map<String, dynamic>>.from(raw);
        unreadCount.value = response['unreadCount'] ?? 0;
      }
    } catch (e) {
      debugPrint('[NotificationSocketManager] Error fetching notifications: $e');
    }
  }

  Future<void> markAsRead(String id) async {
    try {
      final currentList = List<Map<String, dynamic>>.from(notifications.value);
      final index = currentList.indexWhere((n) => n['_id'] == id);
      if (index != -1 && currentList[index]['isRead'] != true) {
        currentList[index]['isRead'] = true;
        notifications.value = currentList;
        unreadCount.value = (unreadCount.value > 0) ? unreadCount.value - 1 : 0;
      }
      await _notificationService.markAsRead(id);
    } catch (e) {
      debugPrint('[NotificationSocketManager] Error marking read: $e');
    }
  }

  Future<void> markAllAsRead() async {
    try {
      final currentList = List<Map<String, dynamic>>.from(notifications.value);
      for (var n in currentList) {
        n['isRead'] = true;
      }
      notifications.value = currentList;
      unreadCount.value = 0;
      await _notificationService.markAllAsRead();
    } catch (e) {
      debugPrint('[NotificationSocketManager] Error marking all read: $e');
    }
  }

  Future<void> deleteNotification(String id) async {
    try {
      final currentList = List<Map<String, dynamic>>.from(notifications.value);
      final index = currentList.indexWhere((n) => n['_id'] == id);
      if (index != -1) {
        final wasUnread = currentList[index]['isRead'] != true;
        currentList.removeAt(index);
        notifications.value = currentList;
        if (wasUnread) {
          unreadCount.value = (unreadCount.value > 0) ? unreadCount.value - 1 : 0;
        }
      }
      await _notificationService.deleteNotification(id);
    } catch (e) {
      debugPrint('[NotificationSocketManager] Error deleting: $e');
    }
  }
}
