import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConstants {
  static const String appName = 'TripSync';
  static const String appVersion = '1.0.0';

  static final String? apiProtocol = dotenv.env['API_PROTOCOL'];

  static final String? pcIp = dotenv.env['PC_IP'];

  static final String? emulatorIp = dotenv.env['EMULATOR_IP'];

  static final String? localhostIp = dotenv.env['LOCALHOST_IP'];

  static final int? port = int.tryParse(dotenv.env['PORT'] ?? '5000');
}
