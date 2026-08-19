import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../core/constants/api_endpoints.dart';
import '../../auth/services/auth_service.dart';

class ItineraryService {
  final AuthService _authService = AuthService();

  Future<Map<String, dynamic>> getItinerary(String tripId) async {
    try {
      final token = await _authService.getAccessToken();
      if (token == null) {
        return {'success': false, 'message': 'Not authenticated'};
      }

      final baseUrl = await ApiEndpoints.getBaseUrl();
      // Remove '/api' from the end of baseUrl if it's there, because ApiEndpoints.trips already starts with '/'
      // Wait, ApiEndpoints.getBaseUrl returns '.../api'
      final url = Uri.parse('$baseUrl/trips/$tripId/itinerary');
      
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

  Future<Map<String, dynamic>> addActivity(String tripId, Map<String, dynamic> eventData) async {
    try {
      final token = await _authService.getAccessToken();
      if (token == null) {
        return {'success': false, 'message': 'Not authenticated'};
      }

      final baseUrl = await ApiEndpoints.getBaseUrl();
      final url = Uri.parse('$baseUrl/trips/$tripId/itinerary/events');
      
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(eventData),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Connection error: ${e.toString()}'};
    }
  }
}
