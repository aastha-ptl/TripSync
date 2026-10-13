import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../core/constants/api_endpoints.dart';
import '../../auth/services/auth_service.dart';
import '../models/message.dart';

class ChatService {
  final AuthService _authService = AuthService();

  Future<Map<String, dynamic>> getAnnouncements(String tripId) async {
    try {
      final token = await _authService.getAccessToken();
      if (token == null) {
        return {'success': false, 'message': 'Not authenticated'};
      }

      final baseUrl = await ApiEndpoints.getBaseUrl();
      final url = Uri.parse('$baseUrl${ApiEndpoints.announcements(tripId)}');

      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      final currentUserId = await _authService.getCurrentUserId();
      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['success'] == true) {
        final List rawList = data['data'] ?? [];
        final List<Message> announcements =
            rawList.map((e) => Message.fromJson(e, currentUserId: currentUserId)).toList();
        return {
          'success': true,
          'data': announcements,
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to load announcements',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error: ${e.toString()}'};
    }
  }

  Future<Map<String, dynamic>> postAnnouncement(
      String tripId, String message) async {
    try {
      final token = await _authService.getAccessToken();
      if (token == null) {
        return {'success': false, 'message': 'Not authenticated'};
      }

      final baseUrl = await ApiEndpoints.getBaseUrl();
      final url = Uri.parse('$baseUrl${ApiEndpoints.announcements(tripId)}');

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'message': message}),
      );

      final currentUserId = await _authService.getCurrentUserId();
      final data = jsonDecode(response.body);
      if (response.statusCode == 201 && data['success'] == true) {
        final newMsg = Message.fromJson(data['data'], currentUserId: currentUserId);
        return {
          'success': true,
          'data': newMsg,
          'message': data['message'] ?? 'Announcement posted successfully',
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to post announcement',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error: ${e.toString()}'};
    }
  }

  Future<Map<String, dynamic>> getGroupMessages(String tripId) async {
    try {
      final token = await _authService.getAccessToken();
      if (token == null) {
        return {'success': false, 'message': 'Not authenticated'};
      }

      final baseUrl = await ApiEndpoints.getBaseUrl();
      final url = Uri.parse('$baseUrl${ApiEndpoints.groupMessages(tripId)}');

      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      final currentUserId = await _authService.getCurrentUserId();
      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['success'] == true) {
        final List rawList = data['data'] ?? [];
        final List<Message> messages =
            rawList.map((e) => Message.fromJson(e, currentUserId: currentUserId)).toList();
        return {
          'success': true,
          'data': messages,
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to load group messages',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error: ${e.toString()}'};
    }
  }

  Future<Map<String, dynamic>> sendGroupMessage(
      String tripId, String message) async {
    try {
      final token = await _authService.getAccessToken();
      if (token == null) {
        return {'success': false, 'message': 'Not authenticated'};
      }

      final baseUrl = await ApiEndpoints.getBaseUrl();
      final url = Uri.parse('$baseUrl${ApiEndpoints.groupMessages(tripId)}');

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'message': message}),
      );

      final currentUserId = await _authService.getCurrentUserId();
      final data = jsonDecode(response.body);
      if (response.statusCode == 201 && data['success'] == true) {
        final newMsg = Message.fromJson(data['data'], currentUserId: currentUserId);
        return {
          'success': true,
          'data': newMsg,
          'message': data['message'] ?? 'Message sent successfully',
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to send message',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error: ${e.toString()}'};
    }
  }

  Future<Map<String, dynamic>> editMessage(
      String tripId, String messageId, String newContent) async {
    try {
      final token = await _authService.getAccessToken();
      if (token == null) {
        return {'success': false, 'message': 'Not authenticated'};
      }

      final baseUrl = await ApiEndpoints.getBaseUrl();
      final url = Uri.parse('$baseUrl/trips/$tripId/chat/messages/$messageId');

      final response = await http.put(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'message': newContent}),
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['success'] == true) {
        return {
          'success': true,
          'data': data['data'],
          'message': data['message'] ?? 'Message edited successfully',
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to edit message',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error: ${e.toString()}'};
    }
  }

  Future<Map<String, dynamic>> deleteMessages(
      String tripId, List<String> messageIds, {required String deleteType}) async {
    try {
      final token = await _authService.getAccessToken();
      if (token == null) {
        return {'success': false, 'message': 'Not authenticated'};
      }

      final baseUrl = await ApiEndpoints.getBaseUrl();
      final url = Uri.parse('$baseUrl/trips/$tripId/chat/messages/delete');

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'messageIds': messageIds,
          'deleteType': deleteType,
        }),
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['success'] == true) {
        return {
          'success': true,
          'data': data['data'],
          'message': data['message'] ?? 'Messages deleted successfully',
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to delete messages',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error: ${e.toString()}'};
    }
  }

  Future<Map<String, dynamic>> getUnreadCount(String tripId) async {
    try {
      final token = await _authService.getAccessToken();
      if (token == null) {
        return {'success': false, 'message': 'Not authenticated'};
      }

      final baseUrl = await ApiEndpoints.getBaseUrl();
      final url = Uri.parse('$baseUrl${ApiEndpoints.chatUnreadCount(tripId)}');

      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['success'] == true) {
        return {
          'success': true,
          'data': data['data'] ?? {},
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to fetch unread count',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error: ${e.toString()}'};
    }
  }

  Future<Map<String, dynamic>> markMessagesAsRead(String tripId, {String? chatType}) async {
    try {
      final token = await _authService.getAccessToken();
      if (token == null) {
        return {'success': false, 'message': 'Not authenticated'};
      }

      final baseUrl = await ApiEndpoints.getBaseUrl();
      final url = Uri.parse('$baseUrl${ApiEndpoints.chatMarkRead(tripId)}');

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          if (chatType != null) 'chatType': chatType,
        }),
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['success'] == true) {
        return {
          'success': true,
          'message': data['message'] ?? 'Marked as read',
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to mark as read',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error: ${e.toString()}'};
    }
  }
}
