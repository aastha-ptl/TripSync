import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:device_info_plus/device_info_plus.dart';
import 'app_constants.dart';

class ApiEndpoints {
  static final String? _pcIp = AppConstants.pcIp;
  static final int? _port = AppConstants.port;
  static final String? _emulatorIp = AppConstants.emulatorIp;
  static final String? _localhostIp = AppConstants.localhostIp;
  static final String? _apiProtocol = AppConstants.apiProtocol;

  static Future<String> getBaseUrl() async {
    if (kIsWeb) {
      print('Using localhost IP: $_localhostIp');
      return '$_apiProtocol://$_localhostIp:$_port/api';
    }

    // Always use PC IP for both emulators and physical devices
    // This ensures generated share links are always accessible on the local network
    print('Using PC IP: $_pcIp');
    return '$_apiProtocol://$_pcIp:$_port/api';
  }

  static String buildImageUrl(String path) {
    if (path.isEmpty) return '';
    final normalized = path.replaceAll('\\', '/');
    if (normalized.startsWith('http://') || normalized.startsWith('https://')) {
      return normalized;
    }
    final host = kIsWeb ? _localhostIp : _pcIp;
    final cleanPath = normalized.startsWith('/') ? normalized : '/$normalized';
    return '$_apiProtocol://$host:$_port$cleanPath';
  }

  // Auth
  static const String login = '/auth/login';
  static const String register = '/auth/register';
  static const String googleLogin = '/auth/google';
  static const String verifyOtp = '/auth/verify-otp';
  static const String resendOtp = '/auth/resend-otp';
  static const String forgotPassword = '/auth/forgot-password';
  static const String verifyForgotPasswordOtp =
      '/auth/verify-forgot-password-otp';
  static const String resetPassword = '/auth/reset-password';
  // Trips
  static const String trips = '/trips';
  static const String joinTrip = '/trips/join';
  static String getInviteInfo(String token) => '/trips/invite/$token';

  // Users
  static const String profile = '/users/profile';

  // Documents
  static const String documents = '/documents';

  // Chat
  static String announcements(String tripId) => '/trips/$tripId/chat/announcements';
  static String groupMessages(String tripId) => '/trips/$tripId/chat/messages';
  static String chatUnreadCount(String tripId) => '/trips/$tripId/chat/unread-count';
  static String chatMarkRead(String tripId) => '/trips/$tripId/chat/mark-read';

  // Notifications
  static const String notifications = '/notifications';
  static const String unreadCount = '/notifications/unread-count';
  static const String markAllRead = '/notifications/read-all';
  static String markRead(String id) => '/notifications/$id/read';

  // Polls
  static String tripPolls(String tripId) => '/trips/$tripId/polls';
  static String tripPollDetail(String tripId, String pollId) => '/trips/$tripId/polls/$pollId';
  static String tripPollVote(String tripId, String pollId) => '/trips/$tripId/polls/$pollId/vote';
  static String tripPollVoters(String tripId, String pollId) => '/trips/$tripId/polls/$pollId/voters';
}


