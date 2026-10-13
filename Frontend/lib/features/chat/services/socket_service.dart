import 'dart:convert';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../../../core/constants/api_endpoints.dart';
import '../models/message.dart';
import '../models/poll.dart';

class SocketService {
  IO.Socket? _socket;
  String? _currentTripId;
  String? _currentUserId;
  final Set<String> _joinedRooms = {};
  static final List<Function(Map<String, dynamic>)> _globalAnnouncementListeners = [];
  static final List<Function(Map<String, dynamic>)> _globalGroupMessageListeners = [];

  void onNewAnnouncement(Function(Map<String, dynamic>) listener) {
    if (!_globalAnnouncementListeners.contains(listener)) {
      _globalAnnouncementListeners.add(listener);
    }
  }

  void onNewGroupMessage(Function(Map<String, dynamic>) listener) {
    if (!_globalGroupMessageListeners.contains(listener)) {
      _globalGroupMessageListeners.add(listener);
    }
  }

  void updateCurrentUserId(String? userId) {
    _currentUserId = userId;
  }

  Future<void> connect(
    String tripId, {
    String? currentUserId,
    List<String>? alternateTripIds,
    required Function(Message) onAnnouncement,
    required Function(Message) onGroupMessage,
    Function(String messageId, String newContent, bool isEdited)? onMessageEdited,
    Function(List<String> messageIds)? onMessagesDeleted,
    Function(Poll poll)? onPollCreated,
    Function(Poll poll)? onPollUpdated,
    Function(String pollId)? onPollDeleted,
  }) async {
    try {
      _currentTripId = tripId.trim();
      if (currentUserId != null && currentUserId.isNotEmpty) {
        _currentUserId = currentUserId;
      }

      if (_socket != null && _socket!.connected) {
        _joinRooms(_currentTripId!, alternateTripIds);
        return;
      }

      disconnect();

      final apiBaseUrl = await ApiEndpoints.getBaseUrl();
      // Remove '/api' suffix to get base server URL for socket.io
      final serverUrl = apiBaseUrl.replaceFirst(RegExp(r'/api/?$'), '');

      print('[SocketService] Connecting to Socket.IO server at $serverUrl');

      _socket = IO.io(
        serverUrl,
        IO.OptionBuilder()
            .setTransports(['websocket', 'polling'])
            .enableAutoConnect()
            .enableReconnection()
            .build(),
      );

      void handleJoinRooms() {
        if (_currentTripId != null && _currentTripId!.isNotEmpty) {
          _joinRooms(_currentTripId!, alternateTripIds);
        }
      }

      _socket!.onConnect((_) {
        print('[SocketService] Socket connected successfully.');
        handleJoinRooms();
      });

      _socket!.on('reconnect', (_) {
        print('[SocketService] Socket reconnected.');
        handleJoinRooms();
      });

      Map<String, dynamic>? parseData(dynamic data) {
        if (data == null) return null;
        if (data is Map<String, dynamic>) return data;
        if (data is Map) return Map<String, dynamic>.from(data);
        if (data is String) {
          try {
            final decoded = jsonDecode(data);
            if (decoded is Map) {
              return Map<String, dynamic>.from(decoded);
            }
          } catch (_) {}
        }
        return null;
      }

      _socket!.on('new_announcement', (data) {
        print('[SocketService] Received new announcement: $data');
        final map = parseData(data);
        if (map != null) {
          final msg = Message.fromJson(map, currentUserId: _currentUserId);
          onAnnouncement(msg);
          for (final l in _globalAnnouncementListeners) {
            try {
              l(map);
            } catch (_) {}
          }
        }
      });

      _socket!.on('new_group_message', (data) {
        print('[SocketService] Received new group message: $data');
        final map = parseData(data);
        if (map != null) {
          final msg = Message.fromJson(map, currentUserId: _currentUserId);
          onGroupMessage(msg);
          for (final l in _globalGroupMessageListeners) {
            try {
              l(map);
            } catch (_) {}
          }
        }
      });

      _socket!.on('message_edited', (data) {
        print('[SocketService] Received message_edited: $data');
        final map = parseData(data);
        if (map != null && onMessageEdited != null) {
          final msgId = (map['id'] ?? map['_id'] ?? '').toString();
          final content = (map['content'] ?? map['message'] ?? '').toString();
          final isEdited = map['isEdited'] == true;
          if (msgId.isNotEmpty) {
            onMessageEdited(msgId, content, isEdited);
          }
        }
      });

      _socket!.on('messages_deleted_for_everyone', (data) {
        print('[SocketService] Received messages_deleted_for_everyone: $data');
        final map = parseData(data);
        if (map != null && onMessagesDeleted != null) {
          final rawIds = map['messageIds'];
          if (rawIds is List) {
            final ids = rawIds.map((e) => e.toString()).toList();
            onMessagesDeleted(ids);
          }
        }
      });

      _socket!.on('poll_created', (data) {
        print('[SocketService] Received poll_created: $data');
        final map = parseData(data);
        if (map != null && onPollCreated != null) {
          try {
            final poll = Poll.fromJson(map);
            onPollCreated(poll);
          } catch (e) {
            print('[SocketService] Error parsing poll_created: $e');
          }
        }
      });

      _socket!.on('poll_updated', (data) {
        print('[SocketService] Received poll_updated: $data');
        final map = parseData(data);
        if (map != null && onPollUpdated != null) {
          try {
            final poll = Poll.fromJson(map);
            onPollUpdated(poll);
          } catch (e) {
            print('[SocketService] Error parsing poll_updated: $e');
          }
        }
      });

      _socket!.on('poll_deleted', (data) {
        print('[SocketService] Received poll_deleted: $data');
        final map = parseData(data);
        if (map != null && onPollDeleted != null) {
          final pollId = (map['pollId'] ?? map['id'] ?? '').toString();
          if (pollId.isNotEmpty) {
            onPollDeleted(pollId);
          }
        }
      });

      _socket!.onDisconnect((_) {
        print('[SocketService] Socket disconnected');
      });

      _socket!.onError((err) {
        print('[SocketService] Socket error: $err');
      });

      _socket!.connect();

      if (_socket!.connected) {
        handleJoinRooms();
      }
    } catch (e) {
      print('[SocketService] Exception initializing socket: $e');
    }
  }

  void _joinRooms(String mainTripId, List<String>? alternateTripIds) {
    if (_socket == null) return;
    final roomsToJoin = {mainTripId};
    if (alternateTripIds != null) {
      for (final alt in alternateTripIds) {
        if (alt.trim().isNotEmpty) roomsToJoin.add(alt.trim());
      }
    }

    for (final r in roomsToJoin) {
      if (!_joinedRooms.contains(r)) {
        print('[SocketService] Joining trip room: $r');
        _socket!.emit('join_trip_room', r);
        _joinedRooms.add(r);
      }
    }
  }

  void disconnect() {
    if (_socket != null) {
      for (final r in _joinedRooms) {
        _socket!.emit('leave_trip_room', r);
      }
      _joinedRooms.clear();
      _socket!.disconnect();
      _socket!.dispose();
      _socket = null;
      _currentTripId = null;
    }
  }
}
