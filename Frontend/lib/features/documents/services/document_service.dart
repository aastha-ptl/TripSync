import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:mime/mime.dart';
import '../../../core/constants/api_endpoints.dart';
import '../../auth/services/auth_service.dart';

class DocumentService {
  final AuthService _authService = AuthService();

  // Get Trip Documents
  Future<Map<String, dynamic>> getTripDocuments(String tripId) async {
    try {
      final token = await _authService.getAccessToken();
      if (token == null) {
        return {'success': false, 'message': 'Not authenticated'};
      }

      final baseUrl = await ApiEndpoints.getBaseUrl();
      final response = await http.get(
        Uri.parse('$baseUrl${ApiEndpoints.documents}/trip/$tripId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Failed to fetch documents: $e'};
    }
  }

  // Upload Document
  Future<Map<String, dynamic>> uploadDocument({
    required String tripId,
    required String filePath,
    required String name,
    required String number,
    required String type,
    String? belongsTo,
    String? memberName,
  }) async {
    try {
      final token = await _authService.getAccessToken();
      if (token == null) throw Exception('Not authenticated');

      final baseUrl = await ApiEndpoints.getBaseUrl();
      final uri = Uri.parse('$baseUrl${ApiEndpoints.documents}/upload');
      
      final request = http.MultipartRequest('POST', uri);
      
      // Add headers
      request.headers.addAll({
        'Authorization': 'Bearer $token',
      });

      // Add text fields
      request.fields['tripId'] = tripId;
      request.fields['name'] = name;
      request.fields['number'] = number;
      request.fields['type'] = type;
      if (belongsTo != null) {
        request.fields['belongsTo'] = belongsTo;
      }
      if (memberName != null) {
        request.fields['memberName'] = memberName;
      }

      // Add file
      final mimeTypeData = lookupMimeType(filePath, headerBytes: [0xFF, 0xD8])?.split('/');
      
      final file = await http.MultipartFile.fromPath(
        'file',
        filePath,
        contentType: mimeTypeData != null ? MediaType(mimeTypeData[0], mimeTypeData[1]) : null,
      );
      
      request.files.add(file);

      // Send request
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      final responseData = json.decode(response.body);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return responseData;
      } else {
        throw Exception(responseData['message'] ?? 'Failed to upload document');
      }
    } catch (e) {
      throw Exception('Error uploading document: $e');
    }
  }
}
