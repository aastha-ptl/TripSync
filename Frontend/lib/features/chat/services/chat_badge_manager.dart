import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../../../core/constants/api_endpoints.dart';
import '../../auth/services/auth_service.dart';
import 'chat_service.dart';

class ChatBadgeManager {
  static final ChatBadgeManager _instance = ChatBadgeManager._internal();
  factory ChatBadgeManager() => _instance;
  ChatBadgeManager._internal();

  final ChatService _chatService = ChatService();
  final AuthService _authService = AuthService();

  final ValueNotifier<int> unreadCount = ValueNotifier<int>(0);

  io.Socket? _socket;
  String? _activeTripId;
  final Set<String> _tripRooms = {};
  String? _currentUserId;
  bool _isChatOpen = false;
  bool _isConnecting = false;

  void setChatOpen(bool isOpen) {
    _isChatOpen = isOpen;
    if (isOpen) {
      unreadCount.value = 0;
    }
  }

  Future<void> initForTrip(String tripId, {List<String>? alternateTripIds}) async {
    final cleanTripId = tripId.trim();
    if (cleanTripId.isEmpty) return;

    if (_activeTripId != cleanTripId) {
      _tripRooms.clear();
      _activeTripId = cleanTripId;
    }
    _tripRooms.add(cleanTripId);

    if (alternateTripIds != null) {
      for (final alt in alternateTripIds) {
        if (alt.trim().isNotEmpty) {
          _tripRooms.add(alt.trim());
        }
      }
    }

    _currentUserId ??= await _authService.getCurrentUserId();

    // Fetch initial unread count
    await fetchUnreadCount(_activeTripId!);

    // Connect socket and join trip rooms to receive live message events
    await _ensureSocketConnected();
  }

  Future<void> _ensureSocketConnected() async {
    if (_socket != null && _socket!.connected) {
      _joinAllRooms();
      return;
    }

    if (_isConnecting) return;
    _isConnecting = true;

    try {
      final apiBaseUrl = await ApiEndpoints.getBaseUrl();
      final serverUrl = apiBaseUrl.replaceFirst(RegExp(r'/api/?$'), '');

      debugPrint('[ChatBadgeManager] Connecting socket to $serverUrl');

      if (_socket != null) {
        try {
          _socket!.disconnect();
          _socket!.dispose();
        } catch (_) {}
        _socket = null;
      }

      _socket = io.io(
        serverUrl,
        io.OptionBuilder()
            .setTransports(['websocket', 'polling'])
            .enableAutoConnect()
            .enableReconnection()
            .build(),
      );

      _socket!.onConnect((_) {
        debugPrint('[ChatBadgeManager] Socket connected successfully');
        _joinAllRooms();
      });

      _socket!.on('reconnect', (_) {
        debugPrint('[ChatBadgeManager] Socket reconnected');
        _joinAllRooms();
        if (_activeTripId != null) {
          fetchUnreadCount(_activeTripId!);
        }
      });

      _socket!.on('new_announcement', (data) {
        debugPrint('[ChatBadgeManager] Real-time new_announcement: $data');
        _handleIncomingMessage(data);
      });

      _socket!.on('new_group_message', (data) {
        debugPrint('[ChatBadgeManager] Real-time new_group_message: $data');
        _handleIncomingMessage(data);
      });

      _socket!.on('new_notification', (data) {
        debugPrint('[ChatBadgeManager] Real-time new_notification: $data');
        _handleIncomingNotification(data);
      });

      _socket!.on('messages_deleted_for_everyone', (data) {
        debugPrint('[ChatBadgeManager] Real-time messages_deleted: $data');
        if (_activeTripId != null) {
          fetchUnreadCount(_activeTripId!);
        }
      });

      _socket!.onDisconnect((_) {
        debugPrint('[ChatBadgeManager] Socket disconnected');
      });

      _socket!.onError((err) {
        debugPrint('[ChatBadgeManager] Socket error: $err');
      });

      _socket!.connect();
    } catch (e) {
      debugPrint('[ChatBadgeManager] Error connecting socket: $e');
    } finally {
      _isConnecting = false;
    }
  }

  void _joinAllRooms() {
    if (_socket == null || !_socket!.connected) return;

    if (_currentUserId != null && _currentUserId!.isNotEmpty) {
      debugPrint('[ChatBadgeManager] Joining user room: user_$_currentUserId');
      _socket!.emit('join_user_room', _currentUserId);
    }

    for (final room in _tripRooms) {
      debugPrint('[ChatBadgeManager] Joining trip room: trip_$room');
      _socket!.emit('join_trip_room', room);
    }
  }

  Map<String, dynamic>? _parseData(dynamic data) {
    if (data == null) return null;
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    if (data is String) {
      try {
        final decoded = jsonDecode(data);
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
      } catch (_) {}
    }
    return null;
  }

  void _handleIncomingMessage(dynamic rawData) async {
    if (_isChatOpen) {
      unreadCount.value = 0;
      return;
    }

    final data = _parseData(rawData);
    if (data == null) return;

    _currentUserId ??= await _authService.getCurrentUserId();
    final senderId = (data['senderId'] ?? data['userId'])?.toString();
    final msgTripId = (data['tripId'] ?? data['trip'])?.toString();

    // Ignore messages sent by ourselves
    if (senderId != null && _currentUserId != null && senderId == _currentUserId) {
      return;
    }

    // Check if message belongs to the current trip
    bool matchesTrip = false;
    if (_activeTripId != null) {
      if (msgTripId == null || msgTripId.isEmpty) {
        matchesTrip = true;
      } else if (_tripRooms.contains(msgTripId) || msgTripId == _activeTripId) {
        matchesTrip = true;
      }
    }

    if (matchesTrip) {
      // Instantly update badge count in UI
      unreadCount.value = unreadCount.value + 1;
      // Sync exact database count in background
      if (_activeTripId != null) {
        fetchUnreadCount(_activeTripId!);
      }
    }
  }

  void _handleIncomingNotification(dynamic rawData) {
    if (_isChatOpen) return;

    final data = _parseData(rawData);
    if (data == null) return;

    final type = data['type']?.toString();
    if (type == 'announcement' || type == 'newMessage' || type == 'chat') {
      final notifTripId = data['tripId']?.toString();
      if (_activeTripId != null &&
          (notifTripId == null ||
              notifTripId.isEmpty ||
              _tripRooms.contains(notifTripId) ||
              notifTripId == _activeTripId)) {
        fetchUnreadCount(_activeTripId!);
      }
    }
  }

  Future<void> fetchUnreadCount(String tripId) async {
    if (_isChatOpen) {
      unreadCount.value = 0;
      return;
    }
    try {
      final res = await _chatService.getUnreadCount(tripId);
      if (res['success'] == true && res['data'] != null) {
        final total = (res['data']['total'] as num?)?.toInt() ?? 0;
        if (!_isChatOpen) {
          unreadCount.value = total;
        }
      }
    } catch (e) {
      debugPrint('[ChatBadgeManager] Error fetching unread count: $e');
    }
  }

  Future<void> markAsRead(String tripId, {String? chatType}) async {
    unreadCount.value = 0;
    try {
      await _chatService.markMessagesAsRead(tripId, chatType: chatType);
      if (!_isChatOpen) {
        await fetchUnreadCount(tripId);
      }
    } catch (e) {
      debugPrint('[ChatBadgeManager] Error marking as read: $e');
    }
  }

  void dispose() {
    try {
      _socket?.disconnect();
      _socket?.dispose();
      _socket = null;
    } catch (_) {}
    _tripRooms.clear();
  }
}
