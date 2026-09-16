import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConstants {
  static const String appName = 'TripSync';
  static const String appVersion = '1.0.0';

  static final String? apiProtocol = dotenv.env['API_PROTOCOL'];

  static final String? pcIp = dotenv.env['PC_IP'];

  static final String? emulatorIp = dotenv.env['EMULATOR_IP'];

  static final String? localhostIp = dotenv.env['LOCALHOST_IP'];

  static final int? port = int.tryParse(dotenv.env['PORT'] ?? '5000');

  static String getInviteLink(String inviteToken) {
    final host = pcIp ?? 'localhost';
    final portNum = port ?? 5000;
    final protocol = apiProtocol ?? 'http';
    // If host is an IPv4 address, append .nip.io so messaging apps (WhatsApp, Telegram, etc.)
    // recognize the full URL including http:// and :port as a clickable hyperlink.
    final domain = RegExp(r'^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$').hasMatch(host)
        ? '$host.nip.io'
        : host;
    return '$protocol://$domain:$portNum/join/$inviteToken';
  }
}
