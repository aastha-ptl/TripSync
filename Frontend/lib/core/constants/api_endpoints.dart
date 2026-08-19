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

  // Auth
  static const String login = '/auth/login';
  static const String register = '/auth/register';
  static const String verifyOtp = '/auth/verify-otp';
  static const String resendOtp = '/auth/resend-otp';
  static const String forgotPassword = '/auth/forgot-password';
  static const String verifyForgotPasswordOtp = '/auth/verify-forgot-password-otp';
  static const String resetPassword = '/auth/reset-password';
    // Trips
  static const String trips = '/trips';
  static const String joinTrip = '/trips/join';
  static String getInviteInfo(String token) => '/trips/invite/$token';

  // Users
  static const String profile = '/users/profile';
}
