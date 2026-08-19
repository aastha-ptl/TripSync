import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../core/constants/api_endpoints.dart';
import '../../auth/services/auth_service.dart';

class TripService {
  final AuthService _authService = AuthService();

  Future<Map<String, dynamic>> createTrip(Map<String, dynamic> tripData) async {
    try {
      final token = await _authService.getAccessToken();
      if (token == null) {
        return {'success': false, 'message': 'Not authenticated'};
      }

      final baseUrl = await ApiEndpoints.getBaseUrl();
      final url = Uri.parse('${baseUrl}${ApiEndpoints.trips}');
      
      if (tripData.containsKey('coverImage') && tripData['coverImage'] != null) {
        var request = http.MultipartRequest('POST', url);
        request.headers['Authorization'] = 'Bearer $token';
        
        tripData.forEach((key, value) {
          if (key != 'coverImage') {
            request.fields[key] = value.toString();
          }
        });
        
        request.files.add(await http.MultipartFile.fromPath(
          'coverImage',
          tripData['coverImage'],
        ));
        
        var streamedResponse = await request.send();
        var response = await http.Response.fromStream(streamedResponse);
        return jsonDecode(response.body);
      } else {
        final response = await http.post(
          url,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode(tripData),
        );
        return jsonDecode(response.body);
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error: ${e.toString()}'};
    }
  }

  Future<Map<String, dynamic>> getInviteInfo(String inviteToken) async {
    try {
      final baseUrl = await ApiEndpoints.getBaseUrl();
      final url = Uri.parse('${baseUrl}${ApiEndpoints.getInviteInfo(inviteToken)}');
      final response = await http.get(url);
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Connection error: ${e.toString()}'};
    }
  }

  Future<Map<String, dynamic>> getTrips() async {
    try {
      final token = await _authService.getAccessToken();
      if (token == null) {
        return {'success': false, 'message': 'Not authenticated'};
      }

      final baseUrl = await ApiEndpoints.getBaseUrl();
      final url = Uri.parse('${baseUrl}${ApiEndpoints.trips}');
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Connection error: ${e.toString()}'};
    }
  }

  Future<Map<String, dynamic>> joinTrip(String inviteToken) async {
    try {
      final token = await _authService.getAccessToken();
      if (token == null) {
        return {'success': false, 'message': 'Not authenticated'};
      }

      final baseUrl = await ApiEndpoints.getBaseUrl();
      final url = Uri.parse('${baseUrl}${ApiEndpoints.joinTrip}');
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'inviteToken': inviteToken}),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Connection error: ${e.toString()}'};
    }
  }

  Future<Map<String, dynamic>> getTripParticipants(String tripId) async {
    try {
      final token = await _authService.getAccessToken();
      if (token == null) {
        return {'success': false, 'message': 'Not authenticated'};
      }

      final baseUrl = await ApiEndpoints.getBaseUrl();
      final url = Uri.parse('${baseUrl}/trips/$tripId/participants');
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Connection error: ${e.toString()}'};
    }
  }

  Future<Map<String, dynamic>> getJoinRequests(String tripId) async {
    try {
      final token = await _authService.getAccessToken();
      if (token == null) {
        return {'success': false, 'message': 'Not authenticated'};
      }

      final baseUrl = await ApiEndpoints.getBaseUrl();
      final url = Uri.parse('${baseUrl}/trips/$tripId/requests');
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Connection error: ${e.toString()}'};
    }
  }

  Future<Map<String, dynamic>> updateJoinRequest(String tripId, String requestId, String status) async {
    try {
      final token = await _authService.getAccessToken();
      if (token == null) {
        return {'success': false, 'message': 'Not authenticated'};
      }

      final baseUrl = await ApiEndpoints.getBaseUrl();
      final url = Uri.parse('${baseUrl}/trips/$tripId/requests/$requestId');
      final response = await http.put(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'status': status}),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Connection error: ${e.toString()}'};
    }
  }
}
