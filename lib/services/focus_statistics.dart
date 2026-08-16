import '../models/focus_session.dart';

class FocusStatistics {
  static Duration today(List<FocusSession> sessions, [DateTime? now]) {
    final current = now ?? DateTime.now();
    return _sum(sessions.where((s) => _sameDay(s.date, current)));
  }

  static Duration thisWeek(List<FocusSession> sessions, [DateTime? now]) {
    final current = now ?? DateTime.now();
    // Monday is the consistent local week start.
    final monday = DateTime(
      current.year,
      current.month,
      current.day,
    ).subtract(Duration(days: current.weekday - DateTime.monday));
    return _sum(sessions.where((s) => !s.date.isBefore(monday)));
  }

  static Duration total(List<FocusSession> sessions) => _sum(sessions);

  static Duration _sum(Iterable<FocusSession> sessions) => Duration(
    seconds: sessions.fold(0, (sum, session) => sum + session.focusedSeconds),
  );

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
