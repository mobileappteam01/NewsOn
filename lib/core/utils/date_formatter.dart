import 'package:intl/intl.dart';

/// Utility class for date formatting
class DateFormatter {
  /// Format date to readable string (e.g., "Jan 15, 2024")
  static String formatDate(DateTime date) {
    return DateFormat('MMM dd, yyyy').format(date);
  }

  /// Format date with time (e.g., "Jan 15, 2024 at 3:30 PM")
  static String formatDateTime(DateTime date) {
    return DateFormat('MMM dd, yyyy \'at\' h:mm a').format(date);
  }

  /// Get relative time (e.g., "2 hours ago")
  static String getRelativeTime(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 365) {
      final years = (difference.inDays / 365).floor();
      return '$years year${years > 1 ? 's' : ''} ago';
    } else if (difference.inDays > 30) {
      final months = (difference.inDays / 30).floor();
      return '$months month${months > 1 ? 's' : ''} ago';
    } else if (difference.inDays > 7) {
      final weeks = (difference.inDays / 7).floor();
      return '$weeks week${weeks > 1 ? 's' : ''} ago';
    } else if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''} ago';
    } else {
      return 'Just now';
    }
  }

  /// Parse date string from API
  /// Handles formats like:
  /// - "2025-11-24 00:00:00" (space-separated)
  /// - "2025-11-24T00:00:00" (ISO format)
  /// - "2025-11-24T00:00:00Z" (ISO with timezone)
  static DateTime? parseApiDate(String? dateString) {
    if (dateString == null || dateString.isEmpty) return null;
    
    try {
      // Try direct parsing first (for ISO formats)
      return DateTime.parse(dateString);
    } catch (e) {
      // If that fails, try to handle space-separated format "2025-11-24 00:00:00"
      try {
        // Replace space with 'T' to convert to ISO format
        final isoFormat = dateString.replaceFirst(' ', 'T');
        return DateTime.parse(isoFormat);
      } catch (e2) {
        // If that also fails, try parsing just the date part
        try {
          final dateOnly = dateString.split(' ').first;
          return DateTime.parse(dateOnly);
        } catch (e3) {
          return null;
        }
      }
    }
  }
}
