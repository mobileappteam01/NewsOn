import 'package:flutter/widgets.dart';

/// Selectable calendar for the V2 Home date filter: today and the previous
/// six days in Asia/Kolkata, independent of the device timezone.
///
/// Days are returned as date-only local [DateTime]s whose year/month/day are
/// the Asia/Kolkata calendar date (what the Material date picker expects).
abstract final class V2HomeDateWindow {
  /// Asia/Kolkata is a fixed offset with no daylight saving.
  static const Duration istOffset = Duration(hours: 5, minutes: 30);

  /// Today plus the previous six calendar days.
  static const int days = 7;

  static const Set<String> _pickerLanguages = {
    'en',
    'ta',
    'hi',
    'ml',
    'te',
    'kn',
    'es',
    'fr',
  };

  static final RegExp _isoDay = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$');

  static DateTime today({DateTime? now}) {
    final ist = (now ?? DateTime.now()).toUtc().add(istOffset);
    return DateTime(ist.year, ist.month, ist.day);
  }

  static DateTime firstDay({DateTime? now}) {
    final t = today(now: now);
    return DateTime(t.year, t.month, t.day - (days - 1));
  }

  static bool isSelectable(DateTime day, {DateTime? now}) {
    final d = DateTime(day.year, day.month, day.day);
    return !d.isBefore(firstDay(now: now)) && !d.isAfter(today(now: now));
  }

  /// `YYYY-MM-DD` from calendar components (never via UTC conversion).
  static String format(DateTime day) =>
      '${day.year.toString().padLeft(4, '0')}-'
      '${day.month.toString().padLeft(2, '0')}-'
      '${day.day.toString().padLeft(2, '0')}';

  /// Parses a real `YYYY-MM-DD` calendar date, else null.
  static DateTime? parse(String? raw) {
    final match = _isoDay.firstMatch(raw?.trim() ?? '');
    if (match == null) return null;
    final y = int.parse(match.group(1)!);
    final m = int.parse(match.group(2)!);
    final d = int.parse(match.group(3)!);
    final day = DateTime(y, m, d);
    if (day.year != y || day.month != m || day.day != d) return null;
    return day;
  }

  /// Picker start day: the saved date when still selectable, else today.
  static DateTime initialPickerDay(String? saved, {DateTime? now}) {
    final day = parse(saved);
    if (day != null && isSelectable(day, now: now)) return day;
    return today(now: now);
  }

  /// Material locale for the picker in the app's UI language. The app-level
  /// locale is forced to English for languages without ARB files (ml/te/kn).
  static Locale pickerLocale(String? uiLanguageCode, Locale fallback) {
    final code = uiLanguageCode?.trim().toLowerCase();
    if (code != null && _pickerLanguages.contains(code)) return Locale(code);
    return fallback;
  }
}
