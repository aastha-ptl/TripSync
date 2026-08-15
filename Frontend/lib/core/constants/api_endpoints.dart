import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

class ApiEndpoints {
  static String get baseUrl {
    if (kIsWeb) {
      return 'http://localhost:5000/api';
    } else if (Platform.isAndroid) {
      // 10.0.2.2 is the special alias to your host loopback interface in the Android Emulator
      return 'http://10.0.2.2:5000/api';
    } else {
      // For iOS Simulator or physical devices. 
      // NOTE: For physical devices, you will need to change this to your machine's local IP address (e.g., http://192.168.1.15:5000/api)
      return 'http://localhost:5000/api';
    }
  }

  // Auth
  static const String login = '/auth/login';
  static const String register = '/auth/register';
  static const String verifyOtp = '/auth/verify-otp';
  static const String resendOtp = '/auth/resend-otp';
}
