import '../models/focus_session.dart';

class FocusActivity {
  static DateTime day(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  static Map<DateTime, Duration> daily(List<FocusSession> sessions) {
    final result = <DateTime, Duration>{};
    for (final session in sessions.where((session) => session.completed)) {
      final date = day(session.date.toLocal());
      result[date] =
          (result[date] ?? Duration.zero) +
          Duration(seconds: session.focusedSeconds);
    }
    return result;
  }

  static int level(Duration duration) {
    final minutes = duration.inMinutes;
    if (minutes == 0) return 0;
    if (minutes < 30) return 1;
    if (minutes < 60) return 2;
    if (minutes < 120) return 3;
    return 4;
  }

  static Duration total(Map<DateTime, Duration> values) =>
      values.values.fold(Duration.zero, (total, value) => total + value);

  static DateTime? bestDay(Map<DateTime, Duration> values) {
    if (values.isEmpty) return null;
    return values.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  }
}
