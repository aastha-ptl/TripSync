import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

class ApiEndpoints {
  static String get baseUrl {
    // 192.168.31.6 is the local IP address of the machine running the backend.
    // This allows both physical Android/iOS devices and Emulators on the same WiFi to connect.
    if (kIsWeb) {
      return 'http://localhost:5000/api';
    }
    return 'http://192.168.31.6:5000/api';
  }

  // Auth
  static const String login = '/auth/login';
  static const String register = '/auth/register';
  static const String verifyOtp = '/auth/verify-otp';
  static const String resendOtp = '/auth/resend-otp';
}
