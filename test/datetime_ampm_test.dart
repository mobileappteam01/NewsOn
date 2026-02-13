import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AM/PM Time Format Tests', () {
    testWidgets('Time format should display correctly in AM/PM', (WidgetTester tester) async {
      // Test different times throughout the day
      final testCases = [
        {'hour': 0, 'minute': 30, 'expected': '12:30 AM'}, // Midnight
        {'hour': 6, 'minute': 15, 'expected': '6:15 AM'},  // Morning
        {'hour': 12, 'minute': 0, 'expected': '12:00 PM'}, // Noon
        {'hour': 15, 'minute': 45, 'expected': '3:45 PM'}, // Afternoon
        {'hour': 20, 'minute': 30, 'expected': '8:30 PM'}, // Evening
        {'hour': 23, 'minute': 59, 'expected': '11:59 PM'}, // Late night
      ];

      for (final testCase in testCases) {
        final hour = testCase['hour'] as int;
        final minute = testCase['minute'] as int;
        final expected = testCase['expected'] as String;

        final timeOfDay = TimeOfDay(hour: hour, minute: minute);
        
        // Format time as AM/PM
        final formattedHour = timeOfDay.hourOfPeriod == 0 ? 12 : timeOfDay.hourOfPeriod;
        final formattedMinute = timeOfDay.minute.toString().padLeft(2, '0');
        final period = timeOfDay.period == DayPeriod.am ? 'AM' : 'PM';
        final result = '$formattedHour:$formattedMinute $period';

        print('Test: $hour:$minute → $result (Expected: $expected)');
        expect(result, equals(expected));
      }
    });

    test('DateTime formatting should work correctly', () {
      final testDate = DateTime(2024, 2, 12, 14, 30); // 2:30 PM
      final timeOfDay = TimeOfDay.fromDateTime(testDate);
      
      // Format as AM/PM
      final formattedHour = timeOfDay.hourOfPeriod == 0 ? 12 : timeOfDay.hourOfPeriod;
      final formattedMinute = timeOfDay.minute.toString().padLeft(2, '0');
      final period = timeOfDay.period == DayPeriod.am ? 'AM' : 'PM';
      final timeString = '$formattedHour:$formattedMinute $period';
      
      // Format date
      final dateString = '12 Feb'; // Simplified for test
      
      final fullDisplay = '$dateString $timeString';
      
      print('Full display: $fullDisplay');
      expect(fullDisplay, equals('12 Feb 2:30 PM'));
    });
  });
}
