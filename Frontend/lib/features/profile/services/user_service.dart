import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../core/constants/api_endpoints.dart';
import '../../auth/services/auth_service.dart';

class UserService {
  final AuthService _authService = AuthService();

  Future<Map<String, dynamic>> getProfile() async {
    try {
      final token = await _authService.getAccessToken();
      if (token == null) {
        return {'success': false, 'message': 'Not authenticated'};
      }

      final baseUrl = await ApiEndpoints.getBaseUrl();
      final url = Uri.parse('$baseUrl${ApiEndpoints.profile}');
      
      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $token',
        },
      );
      
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Connection error: ${e.toString()}'};
    }
  }

  Future<Map<String, dynamic>> updateProfile(Map<String, dynamic> data) async {
    try {
      final token = await _authService.getAccessToken();
      if (token == null) {
        return {'success': false, 'message': 'Not authenticated'};
      }

      final baseUrl = await ApiEndpoints.getBaseUrl();
      final url = Uri.parse('$baseUrl${ApiEndpoints.profile}');

      if (data.containsKey('profilePhoto') && data['profilePhoto'] != null) {
        var request = http.MultipartRequest('PUT', url);
        request.headers['Authorization'] = 'Bearer $token';

        data.forEach((key, value) {
          if (key != 'profilePhoto' && value != null) {
            request.fields[key] = value.toString();
          }
        });

        request.files.add(await http.MultipartFile.fromPath(
          'profilePhoto',
          data['profilePhoto'],
        ));

        var streamedResponse = await request.send();
        var response = await http.Response.fromStream(streamedResponse);
        return jsonDecode(response.body);
      } else {
        final response = await http.put(
          url,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode(data),
        );
        return jsonDecode(response.body);
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error: ${e.toString()}'};
    }
  }
}
