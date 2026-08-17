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

  static Duration thisMonth(List<FocusSession> sessions, [DateTime? now]) {
    final current = now ?? DateTime.now();
    final start = DateTime(current.year, current.month);
    return _sum(sessions.where((s) => !s.date.isBefore(start)));
  }

  static int activeDays(List<FocusSession> sessions) => sessions
      .map((s) => DateTime(s.date.year, s.date.month, s.date.day))
      .toSet()
      .length;

  static int totalCoins(List<FocusSession> sessions) =>
      sessions.fold(0, (sum, session) => sum + session.coinsEarned);

  static Duration? longest(List<FocusSession> sessions) =>
      _extreme(sessions, true);
  static Duration? shortest(List<FocusSession> sessions) =>
      _extreme(sessions, false);

  static Duration? _extreme(List<FocusSession> sessions, bool longest) {
    if (sessions.isEmpty) return null;
    return sessions
        .map((s) => Duration(seconds: s.focusedSeconds))
        .reduce((a, b) => longest ? (a > b ? a : b) : (a < b ? a : b));
  }

  static Duration average(List<FocusSession> sessions) => sessions.isEmpty
      ? Duration.zero
      : Duration(seconds: total(sessions).inSeconds ~/ sessions.length);

  static Duration _sum(Iterable<FocusSession> sessions) => Duration(
    seconds: sessions.fold(0, (sum, session) => sum + session.focusedSeconds),
  );

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
