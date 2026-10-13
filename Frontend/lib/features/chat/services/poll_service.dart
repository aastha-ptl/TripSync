import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../core/constants/api_endpoints.dart';
import '../../auth/services/auth_service.dart';
import '../models/poll.dart';

class PollService {
  final AuthService _authService = AuthService();

  Future<Map<String, String>> _getHeaders() async {
    final token = await _authService.getAccessToken();
    return {
      'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  // 1. Fetch polls for a trip
  Future<List<Poll>> getPolls(String tripId) async {
    try {
      final baseUrl = await ApiEndpoints.getBaseUrl();
      final url = Uri.parse('$baseUrl${ApiEndpoints.tripPolls(tripId)}');
      final headers = await _getHeaders();

      final response = await http.get(url, headers: headers);
      if (response.statusCode == 200) {
        final resData = jsonDecode(response.body);
        if (resData['success'] == true && resData['data'] is List) {
          final list = resData['data'] as List;
          return list
              .whereType<Map<String, dynamic>>()
              .map((p) => Poll.fromJson(p))
              .toList();
        }
      }
      return [];
    } catch (e) {
      print('[PollService] Error fetching polls: $e');
      return [];
    }
  }

  // 2. Create a poll (Trip Leader)
  Future<Map<String, dynamic>> createPoll(
    String tripId, {
    required String question,
    required List<String> options,
    bool allowMultipleAnswers = false,
  }) async {
    try {
      final baseUrl = await ApiEndpoints.getBaseUrl();
      final url = Uri.parse('$baseUrl${ApiEndpoints.tripPolls(tripId)}');
      final headers = await _getHeaders();

      final body = jsonEncode({
        'question': question.trim(),
        'options': options.map((o) => o.trim()).toList(),
        'allowMultipleAnswers': allowMultipleAnswers,
      });

      final response = await http.post(url, headers: headers, body: body);
      final resData = jsonDecode(response.body);

      if (response.statusCode == 201 && resData['success'] == true && resData['data'] != null) {
        return {
          'success': true,
          'poll': Poll.fromJson(resData['data']),
          'message': resData['message'] ?? 'Poll created successfully',
        };
      }
      return {
        'success': false,
        'message': resData['message'] ?? 'Failed to create poll',
      };
    } catch (e) {
      print('[PollService] Error creating poll: $e');
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  // 3. Vote on an option
  Future<Map<String, dynamic>> votePoll(
    String tripId,
    String pollId,
    String optionId,
  ) async {
    try {
      final baseUrl = await ApiEndpoints.getBaseUrl();
      final url = Uri.parse('$baseUrl${ApiEndpoints.tripPollVote(tripId, pollId)}');
      final headers = await _getHeaders();

      final body = jsonEncode({'optionId': optionId});
      final response = await http.post(url, headers: headers, body: body);
      final resData = jsonDecode(response.body);

      if (response.statusCode == 200 && resData['success'] == true && resData['data'] != null) {
        return {
          'success': true,
          'poll': Poll.fromJson(resData['data']),
        };
      }
      return {
        'success': false,
        'message': resData['message'] ?? 'Failed to vote',
      };
    } catch (e) {
      print('[PollService] Error voting on poll: $e');
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  // 4. Edit a poll (Trip Leader)
  Future<Map<String, dynamic>> editPoll(
    String tripId,
    String pollId, {
    required String question,
    required List<dynamic> options,
    bool allowMultipleAnswers = false,
  }) async {
    try {
      final baseUrl = await ApiEndpoints.getBaseUrl();
      final url = Uri.parse('$baseUrl${ApiEndpoints.tripPollDetail(tripId, pollId)}');
      final headers = await _getHeaders();

      final body = jsonEncode({
        'question': question.trim(),
        'options': options,
        'allowMultipleAnswers': allowMultipleAnswers,
      });

      final response = await http.put(url, headers: headers, body: body);
      final resData = jsonDecode(response.body);

      if (response.statusCode == 200 && resData['success'] == true && resData['data'] != null) {
        return {
          'success': true,
          'poll': Poll.fromJson(resData['data']),
          'message': resData['message'] ?? 'Poll updated successfully',
        };
      }
      return {
        'success': false,
        'message': resData['message'] ?? 'Failed to edit poll',
      };
    } catch (e) {
      print('[PollService] Error editing poll: $e');
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  // 5. Delete a poll (Trip Leader)
  Future<Map<String, dynamic>> deletePoll(String tripId, String pollId) async {
    try {
      final baseUrl = await ApiEndpoints.getBaseUrl();
      final url = Uri.parse('$baseUrl${ApiEndpoints.tripPollDetail(tripId, pollId)}');
      final headers = await _getHeaders();

      final response = await http.delete(url, headers: headers);
      final resData = jsonDecode(response.body);

      if (response.statusCode == 200 && resData['success'] == true) {
        return {'success': true, 'message': resData['message'] ?? 'Poll deleted'};
      }
      return {
        'success': false,
        'message': resData['message'] ?? 'Failed to delete poll',
      };
    } catch (e) {
      print('[PollService] Error deleting poll: $e');
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  // 6. Get poll voters breakdown (voted and not voted registered members)
  Future<Map<String, dynamic>> getPollVoters(String tripId, String pollId) async {
    try {
      final baseUrl = await ApiEndpoints.getBaseUrl();
      final url = Uri.parse('$baseUrl${ApiEndpoints.tripPollVoters(tripId, pollId)}');
      final headers = await _getHeaders();

      final response = await http.get(url, headers: headers);
      final resData = jsonDecode(response.body);

      if (response.statusCode == 200 && resData['success'] == true && resData['data'] != null) {
        return {
          'success': true,
          'data': resData['data'],
        };
      }
      return {
        'success': false,
        'message': resData['message'] ?? 'Failed to fetch voters',
      };
    } catch (e) {
      print('[PollService] Error getting poll voters: $e');
      return {'success': false, 'message': 'Network error: $e'};
    }
  }
}
