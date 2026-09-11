import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../../../core/constants/api_endpoints.dart';
import '../../auth/services/auth_service.dart';

class PhotoService {
  final AuthService _authService = AuthService();

  Future<Map<String, dynamic>> getTripPhotos(String tripId) async {
    try {
      final token = await _authService.getAccessToken();
      if (token == null) {
        return {'success': false, 'message': 'Not authenticated'};
      }

      final baseUrl = await ApiEndpoints.getBaseUrl();
      final url = Uri.parse('$baseUrl${ApiEndpoints.trips}/$tripId/photos');

      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {'success': true, 'photos': data['photos']};
      } else {
        return {'success': false, 'message': data['message'] ?? 'Failed to load photos'};
      }
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> uploadPhotos(
      String tripId, List<File> photoFiles, String visibility, List<String> permittedUsers) async {
    try {
      final token = await _authService.getAccessToken();
      if (token == null) {
        return {'success': false, 'message': 'Not authenticated'};
      }

      final baseUrl = await ApiEndpoints.getBaseUrl();
      final url = Uri.parse('$baseUrl${ApiEndpoints.trips}/$tripId/photos');

      var request = http.MultipartRequest('POST', url);
      request.headers['Authorization'] = 'Bearer $token';

      request.fields['visibility'] = visibility;
      if (visibility == 'SelectedMembers') {
        request.fields['permittedUsers'] = jsonEncode(permittedUsers);
      }

      for (var file in photoFiles) {
        request.files.add(await http.MultipartFile.fromPath('photos', file.path));
      }

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);
      final data = jsonDecode(response.body);

      if (response.statusCode == 201 || response.statusCode == 200) {
        return {
          'success': true,
          'message': data['message'] ?? 'Photos uploaded successfully',
          'photos': data['photos'] ?? (data['photo'] != null ? [data['photo']] : []),
        };
      } else {
        return {'success': false, 'message': data['message'] ?? 'Failed to upload photos'};
      }
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> uploadPhoto(
      String tripId, File photoFile, String visibility, List<String> permittedUsers) async {
    return uploadPhotos(tripId, [photoFile], visibility, permittedUsers);
  }

  Future<Map<String, dynamic>> deletePhoto(String tripId, String photoId) async {
    try {
      final token = await _authService.getAccessToken();
      if (token == null) {
        return {'success': false, 'message': 'Not authenticated'};
      }

      final baseUrl = await ApiEndpoints.getBaseUrl();
      final url = Uri.parse('$baseUrl${ApiEndpoints.trips}/$tripId/photos/$photoId');

      final response = await http.delete(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {'success': true, 'message': data['message'] ?? 'Photo deleted successfully'};
      } else {
        return {'success': false, 'message': data['message'] ?? 'Failed to delete photo'};
      }
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }
}
