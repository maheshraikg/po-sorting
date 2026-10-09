import 'package:flutter_test/flutter_test.dart';
import 'package:sorting_sahayak/core/reminder.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

void main() {
  test('reminder: next time today if still ahead, else tomorrow', () {
    tzdata.initializeTimeZones();
    final ist = tz.getLocation('Asia/Kolkata');
    final morning = tz.TZDateTime(ist, 2026, 10, 9, 8, 30);
    expect(PracticeReminder.nextAt(19 * 60, morning), tz.TZDateTime(ist, 2026, 10, 9, 19));
    final night = tz.TZDateTime(ist, 2026, 10, 9, 21);
    expect(PracticeReminder.nextAt(19 * 60, night), tz.TZDateTime(ist, 2026, 10, 10, 19));
  });
}
