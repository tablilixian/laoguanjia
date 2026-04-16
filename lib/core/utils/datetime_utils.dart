import 'package:intl/intl.dart';

class DateTimeUtils {
  static const String _utcFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'";

  static DateTime nowUtc() {
    final now = DateTime.now().toUtc();
    return truncateToMillis(now);
  }

  static DateTime truncateToMillis(DateTime dt) {
    final millis = dt.millisecondsSinceEpoch;
    return DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true);
  }

  static DateTime parseIso8601(String isoString) {
    final dt = DateTime.parse(isoString);
    return truncateToMillis(dt);
  }

  static DateTime parseFromLocal(DateTime localTime) {
    final millis = localTime.millisecondsSinceEpoch;
    return DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true);
  }

  static DateTime fromDrift(DateTime driftTime) {
    final millis = driftTime.millisecondsSinceEpoch;
    return DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true);
  }

  static String toIso8601(DateTime dt) {
    final utc = truncateToMillis(dt);
    return utc.toIso8601String();
  }

  static DateTime toLocalTime(DateTime utcTime) {
    return truncateToMillis(utcTime).toLocal();
  }

  static String formatRelative(DateTime utcTime, {DateTime? now}) {
    final local = toLocalTime(utcTime);
    final reference = (now ?? DateTime.now()).toLocal();
    final diff = reference.difference(local);

    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inMinutes < 60) return '${diff.inMinutes}分钟前';
    if (diff.inHours < 24) return '${diff.inHours}小时前';
    if (diff.inDays < 7) return '${diff.inDays}天前';

    return formatDate(utcTime);
  }

  static String formatDate(DateTime utcTime) {
    final local = toLocalTime(utcTime);
    return DateFormat('yyyy-MM-dd HH:mm').format(local);
  }

  static String formatDateOnly(DateTime utcTime) {
    final local = toLocalTime(utcTime);
    return DateFormat('yyyy-MM-dd').format(local);
  }

  static String formatTimeOnly(DateTime utcTime) {
    final local = toLocalTime(utcTime);
    return DateFormat('HH:mm').format(local);
  }

  static bool isToday(DateTime utcTime) {
    final local = toLocalTime(utcTime);
    final now = DateTime.now();
    return local.year == now.year &&
        local.month == now.month &&
        local.day == now.day;
  }

  static bool isTomorrow(DateTime utcTime) {
    final local = toLocalTime(utcTime);
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    return local.year == tomorrow.year &&
        local.month == tomorrow.month &&
        local.day == tomorrow.day;
  }

  static bool isOverdue(DateTime utcTime) {
    return DateTime.now().toUtc().isAfter(truncateToMillis(utcTime));
  }

  static int compareTime(DateTime a, DateTime b) {
    final aMillis = truncateToMillis(a).millisecondsSinceEpoch;
    final bMillis = truncateToMillis(b).millisecondsSinceEpoch;
    return aMillis.compareTo(bMillis);
  }

  static bool isEqual(DateTime a, DateTime b) {
    return compareTime(a, b) == 0;
  }

  static bool isAfter(DateTime a, DateTime b) {
    return compareTime(a, b) > 0;
  }

  static bool isBefore(DateTime a, DateTime b) {
    return compareTime(a, b) < 0;
  }
}
