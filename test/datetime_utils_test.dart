import 'package:flutter_test/flutter_test.dart';
import 'package:home_manager/core/utils/datetime_utils.dart';

void main() {
  group('DateTimeUtils', () {
    group('truncateToMillis', () {
      test('should truncate microseconds to milliseconds', () {
        final withMicroseconds = DateTime.utc(2026, 4, 12, 10, 30, 45, 123, 456);
        final truncated = DateTimeUtils.truncateToMillis(withMicroseconds);

        expect(truncated.millisecond, equals(123));
        expect(truncated.microsecond, equals(0));
      });

      test('should preserve milliseconds', () {
        final withMillis = DateTime.utc(2026, 4, 12, 10, 30, 45, 123);
        final truncated = DateTimeUtils.truncateToMillis(withMillis);

        expect(truncated.millisecond, equals(123));
        expect(truncated.microsecond, equals(0));
      });
    });

    group('nowUtc', () {
      test('should return UTC time with millisecond precision', () {
        final now = DateTimeUtils.nowUtc();

        expect(now.isUtc, isTrue);
        expect(now.microsecond, equals(0));
      });
    });

    group('parseIso8601', () {
      test('should parse ISO8601 string and truncate to milliseconds', () {
        const isoString = '2026-04-12T10:30:45.123456Z';
        final parsed = DateTimeUtils.parseIso8601(isoString);

        expect(parsed.year, equals(2026));
        expect(parsed.month, equals(4));
        expect(parsed.day, equals(12));
        expect(parsed.hour, equals(10));
        expect(parsed.minute, equals(30));
        expect(parsed.second, equals(45));
        expect(parsed.millisecond, equals(123));
        expect(parsed.microsecond, equals(0));
        expect(parsed.isUtc, isTrue);
      });

      test('should parse ISO8601 string without microseconds', () {
        const isoString = '2026-04-12T10:30:45.123Z';
        final parsed = DateTimeUtils.parseIso8601(isoString);

        expect(parsed.millisecond, equals(123));
        expect(parsed.microsecond, equals(0));
      });
    });

    group('toIso8601', () {
      test('should convert DateTime to ISO8601 string', () {
        final dt = DateTime.utc(2026, 4, 12, 10, 30, 45, 123);
        final isoString = DateTimeUtils.toIso8601(dt);

        expect(isoString, contains('2026-04-12'));
        expect(isoString, contains('10:30:45'));
      });
    });

    group('compareTime', () {
      test('should return 0 for equal times', () {
        final a = DateTime.utc(2026, 4, 12, 10, 30, 45, 123);
        final b = DateTime.utc(2026, 4, 12, 10, 30, 45, 123);

        expect(DateTimeUtils.compareTime(a, b), equals(0));
      });

      test('should return negative when a is before b', () {
        final a = DateTime.utc(2026, 4, 12, 10, 30, 45, 100);
        final b = DateTime.utc(2026, 4, 12, 10, 30, 45, 200);

        expect(DateTimeUtils.compareTime(a, b), lessThan(0));
      });

      test('should return positive when a is after b', () {
        final a = DateTime.utc(2026, 4, 12, 10, 30, 45, 200);
        final b = DateTime.utc(2026, 4, 12, 10, 30, 45, 100);

        expect(DateTimeUtils.compareTime(a, b), greaterThan(0));
      });

      test('should ignore microseconds', () {
        final a = DateTime.utc(2026, 4, 12, 10, 30, 45, 123, 456);
        final b = DateTime.utc(2026, 4, 12, 10, 30, 45, 123, 789);

        expect(DateTimeUtils.compareTime(a, b), equals(0));
      });
    });

    group('isEqual', () {
      test('should return true for equal times', () {
        final a = DateTime.utc(2026, 4, 12, 10, 30, 45, 123);
        final b = DateTime.utc(2026, 4, 12, 10, 30, 45, 123);

        expect(DateTimeUtils.isEqual(a, b), isTrue);
      });

      test('should return false for different times', () {
        final a = DateTime.utc(2026, 4, 12, 10, 30, 45, 100);
        final b = DateTime.utc(2026, 4, 12, 10, 30, 45, 200);

        expect(DateTimeUtils.isEqual(a, b), isFalse);
      });

      test('should ignore microseconds', () {
        final a = DateTime.utc(2026, 4, 12, 10, 30, 45, 123, 456);
        final b = DateTime.utc(2026, 4, 12, 10, 30, 45, 123, 789);

        expect(DateTimeUtils.isEqual(a, b), isTrue);
      });
    });

    group('isAfter', () {
      test('should return true when a is after b', () {
        final a = DateTime.utc(2026, 4, 12, 10, 30, 45, 200);
        final b = DateTime.utc(2026, 4, 12, 10, 30, 45, 100);

        expect(DateTimeUtils.isAfter(a, b), isTrue);
      });

      test('should return false when a is before b', () {
        final a = DateTime.utc(2026, 4, 12, 10, 30, 45, 100);
        final b = DateTime.utc(2026, 4, 12, 10, 30, 45, 200);

        expect(DateTimeUtils.isAfter(a, b), isFalse);
      });
    });

    group('isBefore', () {
      test('should return true when a is before b', () {
        final a = DateTime.utc(2026, 4, 12, 10, 30, 45, 100);
        final b = DateTime.utc(2026, 4, 12, 10, 30, 45, 200);

        expect(DateTimeUtils.isBefore(a, b), isTrue);
      });

      test('should return false when a is after b', () {
        final a = DateTime.utc(2026, 4, 12, 10, 30, 45, 200);
        final b = DateTime.utc(2026, 4, 12, 10, 30, 45, 100);

        expect(DateTimeUtils.isBefore(a, b), isFalse);
      });
    });

    group('isToday', () {
      test('should return true for today', () {
        final now = DateTime.now();
        final today = DateTime.utc(now.year, now.month, now.day);

        expect(DateTimeUtils.isToday(today), isTrue);
      });

      test('should return false for yesterday', () {
        final yesterday = DateTime.now().subtract(const Duration(days: 1));
        final yesterdayUtc = DateTime.utc(
            yesterday.year, yesterday.month, yesterday.day);

        expect(DateTimeUtils.isToday(yesterdayUtc), isFalse);
      });
    });

    group('isTomorrow', () {
      test('should return true for tomorrow', () {
        final tomorrow = DateTime.now().add(const Duration(days: 1));
        final tomorrowUtc =
            DateTime.utc(tomorrow.year, tomorrow.month, tomorrow.day);

        expect(DateTimeUtils.isTomorrow(tomorrowUtc), isTrue);
      });

      test('should return false for today', () {
        final now = DateTime.now();
        final today = DateTime.utc(now.year, now.month, now.day);

        expect(DateTimeUtils.isTomorrow(today), isFalse);
      });
    });

    group('isOverdue', () {
      test('should return true for past time', () {
        final past = DateTime.now().subtract(const Duration(hours: 1));

        expect(DateTimeUtils.isOverdue(past), isTrue);
      });

      test('should return false for future time', () {
        final future = DateTime.now().add(const Duration(hours: 1));

        expect(DateTimeUtils.isOverdue(future), isFalse);
      });
    });

    group('formatDate', () {
      test('should format date correctly', () {
        final dt = DateTime.utc(2026, 4, 12, 10, 30, 45);
        final formatted = DateTimeUtils.formatDate(dt);

        expect(formatted, contains('2026'));
        expect(formatted, contains('04'));
        expect(formatted, contains('12'));
      });
    });

    group('formatRelative', () {
      test('should return "刚刚" for less than 1 minute', () {
        final now = DateTime.now();
        final justNow = now.subtract(const Duration(seconds: 30));

        expect(DateTimeUtils.formatRelative(justNow, now: now), equals('刚刚'));
      });

      test('should return minutes ago for less than 1 hour', () {
        final now = DateTime.now();
        final minutesAgo = now.subtract(const Duration(minutes: 30));

        expect(
            DateTimeUtils.formatRelative(minutesAgo, now: now), equals('30分钟前'));
      });

      test('should return hours ago for less than 1 day', () {
        final now = DateTime.now();
        final hoursAgo = now.subtract(const Duration(hours: 5));

        expect(
            DateTimeUtils.formatRelative(hoursAgo, now: now), equals('5小时前'));
      });

      test('should return days ago for less than 7 days', () {
        final now = DateTime.now();
        final daysAgo = now.subtract(const Duration(days: 3));

        expect(
            DateTimeUtils.formatRelative(daysAgo, now: now), equals('3天前'));
      });
    });
  });
}
