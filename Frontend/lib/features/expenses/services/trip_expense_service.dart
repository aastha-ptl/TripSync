import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../core/constants/api_endpoints.dart';
import '../../auth/services/auth_service.dart';

class TripExpenseService {
  final AuthService _authService = AuthService();

  Future<Map<String, String>> _getHeaders() async {
    final token = await _authService.getAccessToken();
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer ${token ?? ''}',
    };
  }

  // 1. Get eligible members (including non-app family members)
  Future<Map<String, dynamic>> getMembers(String tripId) async {
    try {
      final baseUrl = await ApiEndpoints.getBaseUrl();
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/trips/$tripId/expenses/members'),
        headers: headers,
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  // 2. Get Expense Summary (Owed by you - Red, Owed to you - Green)
  Future<Map<String, dynamic>> getSummary(String tripId, {String? actingAsGuestId}) async {
    try {
      final baseUrl = await ApiEndpoints.getBaseUrl();
      final headers = await _getHeaders();
      String url = '$baseUrl/trips/$tripId/expenses/summary';
      if (actingAsGuestId != null && actingAsGuestId.isNotEmpty) {
        url += '?actingAsGuestId=$actingAsGuestId';
      }
      final response = await http.get(Uri.parse(url), headers: headers);
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  // 3. Get person-wise balances (Expenses tab)
  Future<Map<String, dynamic>> getBalances(String tripId, {String? actingAsGuestId}) async {
    try {
      final baseUrl = await ApiEndpoints.getBaseUrl();
      final headers = await _getHeaders();
      String url = '$baseUrl/trips/$tripId/expenses/balances';
      if (actingAsGuestId != null && actingAsGuestId.isNotEmpty) {
        url += '?actingAsGuestId=$actingAsGuestId';
      }
      final response = await http.get(Uri.parse(url), headers: headers);
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  // 4. Get balance detail for a specific person (Unpaid & Paid lists)
  Future<Map<String, dynamic>> getBalanceDetail(
    String tripId,
    String targetId, {
    bool isGuest = false,
    String? actingAsGuestId,
  }) async {
    try {
      final baseUrl = await ApiEndpoints.getBaseUrl();
      final headers = await _getHeaders();
      String url = '$baseUrl/trips/$tripId/expenses/balances/$targetId?isGuest=$isGuest';
      if (actingAsGuestId != null && actingAsGuestId.isNotEmpty) {
        url += '&actingAsGuestId=$actingAsGuestId';
      }
      final response = await http.get(Uri.parse(url), headers: headers);
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  // 5. Get list of expenses (Splits tab)
  Future<Map<String, dynamic>> getExpenses(
    String tripId, {
    String? actingAsGuestId,
    String filter = 'my',
  }) async {
    try {
      final baseUrl = await ApiEndpoints.getBaseUrl();
      final headers = await _getHeaders();
      String url = '$baseUrl/trips/$tripId/expenses?filter=$filter';
      if (actingAsGuestId != null && actingAsGuestId.isNotEmpty) {
        url += '&actingAsGuestId=$actingAsGuestId';
      }
      final response = await http.get(Uri.parse(url), headers: headers);
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  // 6. Get detail of a specific expense
  Future<Map<String, dynamic>> getExpenseDetail(
    String tripId,
    String expenseId, {
    String? actingAsGuestId,
  }) async {
    try {
      final baseUrl = await ApiEndpoints.getBaseUrl();
      final headers = await _getHeaders();
      String url = '$baseUrl/trips/$tripId/expenses/$expenseId';
      if (actingAsGuestId != null && actingAsGuestId.isNotEmpty) {
        url += '?actingAsGuestId=$actingAsGuestId';
      }
      final response = await http.get(
        Uri.parse(url),
        headers: headers,
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  // 7. Create a new expense (Split bill)
  Future<Map<String, dynamic>> createExpense(String tripId, Map<String, dynamic> data) async {
    try {
      final baseUrl = await ApiEndpoints.getBaseUrl();
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl/trips/$tripId/expenses'),
        headers: headers,
        body: jsonEncode(data),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  // 8. Settle participant in an expense
  Future<Map<String, dynamic>> settleParticipant(
    String tripId,
    String expenseId, {
    String? participantId,
  }) async {
    try {
      final baseUrl = await ApiEndpoints.getBaseUrl();
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl/trips/$tripId/expenses/$expenseId/settle'),
        headers: headers,
        body: jsonEncode({'participantId': participantId}),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  // 9. Settle all/selected expenses with a person
  Future<Map<String, dynamic>> settlePersonExpenses(
    String tripId,
    List<String> participantIds,
  ) async {
    try {
      final baseUrl = await ApiEndpoints.getBaseUrl();
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl/trips/$tripId/expenses/settle-person'),
        headers: headers,
        body: jsonEncode({'participantIds': participantIds}),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  // 10. Close / Delete an expense request
  Future<Map<String, dynamic>> deleteExpense(String tripId, String expenseId) async {
    try {
      final baseUrl = await ApiEndpoints.getBaseUrl();
      final headers = await _getHeaders();
      final response = await http.delete(
        Uri.parse('$baseUrl/trips/$tripId/expenses/$expenseId'),
        headers: headers,
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  // 11. Get PDF Expense Report Download URL
  Future<String> getPdfReportUrl(String tripId, {String? actingAsGuestId}) async {
    final baseUrl = await ApiEndpoints.getBaseUrl();
    final token = await _authService.getAccessToken();
    String url = '$baseUrl/trips/$tripId/expenses/report/pdf?token=${token ?? ''}';
    if (actingAsGuestId != null && actingAsGuestId.isNotEmpty) {
      url += '&actingAsGuestId=$actingAsGuestId';
    }
    return url;
  }
}
