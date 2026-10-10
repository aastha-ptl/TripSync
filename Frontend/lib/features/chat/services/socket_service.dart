import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../../../core/constants/api_endpoints.dart';
import '../models/message.dart';

class SocketService {
  IO.Socket? _socket;
  String? _currentTripId;

  Future<void> connect(
    String tripId, {
    required Function(Message) onAnnouncement,
    required Function(Message) onGroupMessage,
  }) async {
    try {
      if (_socket != null && _socket!.connected && _currentTripId == tripId) {
        return;
      }

      disconnect();

      _currentTripId = tripId;
      final apiBaseUrl = await ApiEndpoints.getBaseUrl();
      // Remove '/api' suffix to get base server URL for socket.io
      final serverUrl = apiBaseUrl.replaceFirst(RegExp(r'/api/?$'), '');

      print('[SocketService] Connecting to Socket.IO server at $serverUrl');

      _socket = IO.io(
        serverUrl,
        IO.OptionBuilder()
            .setTransports(['websocket', 'polling'])
            .disableAutoConnect()
            .build(),
      );

      _socket!.connect();

      _socket!.onConnect((_) {
        print('[SocketService] Socket connected successfully. Joining trip room: $tripId');
        _socket!.emit('join_trip_room', tripId);
      });

      _socket!.on('new_announcement', (data) {
        print('[SocketService] Received new announcement: $data');
        if (data is Map<String, dynamic>) {
          final msg = Message.fromJson(data);
          onAnnouncement(msg);
        }
      });

      _socket!.on('new_group_message', (data) {
        print('[SocketService] Received new group message: $data');
        if (data is Map<String, dynamic>) {
          final msg = Message.fromJson(data);
          onGroupMessage(msg);
        }
      });

      _socket!.onDisconnect((_) {
        print('[SocketService] Socket disconnected');
      });

      _socket!.onError((err) {
        print('[SocketService] Socket error: $err');
      });
    } catch (e) {
      print('[SocketService] Exception initializing socket: $e');
    }
  }

  void disconnect() {
    if (_socket != null) {
      if (_currentTripId != null) {
        _socket!.emit('leave_trip_room', _currentTripId);
      }
      _socket!.disconnect();
      _socket!.dispose();
      _socket = null;
      _currentTripId = null;
    }
  }
}
