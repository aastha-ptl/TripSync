import 'package:intl/intl.dart';

class TripInfoHelper {
  static String formatTripHeader(
    Map<String, dynamic>? tripData, {
    String? defaultText,
    bool showMembers = false,
    bool showCities = false,
    bool showDuration = false,
  }) {
    if (tripData == null || tripData['startDate'] == null || tripData['endDate'] == null) {
      return defaultText ?? 'Unknown Dates';
    }
    
    try {
      final start = DateTime.parse(tripData['startDate']);
      final end = DateTime.parse(tripData['endDate']);
      
      String dateStr = '';
      if (start.year == end.year && start.month == end.month) {
        dateStr = '${DateFormat('MMM d').format(start)} – ${DateFormat('d, yyyy').format(end)}';
      } else if (start.year == end.year) {
        dateStr = '${DateFormat('MMM d').format(start)} – ${DateFormat('MMM d, yyyy').format(end)}';
      } else {
        dateStr = '${DateFormat('MMM d, yyyy').format(start)} – ${DateFormat('MMM d, yyyy').format(end)}';
      }
      
      if (showDuration) {
        final duration = end.difference(start).inDays + 1;
        dateStr = '$dateStr ($duration Days)';
      }
      
      List<String> parts = [dateStr];
      
      if (showMembers) {
        final membersCount = tripData['membersCount'] ?? tripData['participantsCount'] ?? 1;
        parts.add('$membersCount Member${membersCount > 1 ? 's' : ''}');
      }
      if (showCities) {
        final destCount = tripData['destinations'] != null ? (tripData['destinations'] as List).length : 1;
        parts.add('$destCount Cit${destCount > 1 ? 'ies' : 'y'}');
      }
      
      if (parts.length > 1) {
        return '${parts[0]} • ${parts.sublist(1).join(' • ')}';
      }
      return dateStr;
    } catch (e) {
      return defaultText ?? 'Unknown Dates';
    }
  }
}
