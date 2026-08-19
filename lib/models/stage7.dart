import 'focus_session.dart';

class UserGoals {
  final int dailyTargetMinutes;
  final int weeklyTargetMinutes;
  const UserGoals({this.dailyTargetMinutes = 60, this.weeklyTargetMinutes = 420});
}

class AchievementDefinition {
  final String id, title, description, icon, requirement;
  const AchievementDefinition(this.id, this.title, this.description, this.icon, this.requirement);
}

class AchievementState {
  final AchievementDefinition definition;
  final DateTime? unlockedAt;
  const AchievementState(this.definition, this.unlockedAt);
  bool get unlocked => unlockedAt != null;
}

const achievements = <AchievementDefinition>[
  AchievementDefinition('first_step', 'First Step', 'Complete your first focus session', 'footprints', '1 focus session'),
  AchievementDefinition('one_hour', 'One Hour', 'Reach 60 total focused minutes', 'schedule', '60 focused minutes'),
  AchievementDefinition('five_hours', 'Five Hours', 'Reach 5 total focused hours', 'hourglass_top', '5 focused hours'),
  AchievementDefinition('ten_hours', 'Ten Hours', 'Reach 10 total focused hours', 'timer', '10 focused hours'),
  AchievementDefinition('ten_sessions', 'Ten Sessions', 'Complete 10 focus sessions', 'repeat', '10 focus sessions'),
  AchievementDefinition('seven_day_streak', 'Seven Day Streak', 'Focus for 7 consecutive days', 'local_fire_department', '7-day streak'),
  AchievementDefinition('thirty_day_streak', 'Thirty Day Streak', 'Focus for 30 consecutive days', 'whatshot', '30-day streak'),
  AchievementDefinition('thousand_coins', 'Thousand Coins', 'Earn 1,000 total coins', 'monetization_on', '1,000 coins'),
  AchievementDefinition('ten_thousand_coins', 'Ten Thousand Coins', 'Earn 10,000 total coins', 'paid', '10,000 coins'),
  AchievementDefinition('focused_day', 'Focused Day', 'Complete 120 minutes in one day', 'today', '120 minutes in one day'),
];

class Stage7Calculations {
  static List<DateTime> activeDays(List<FocusSession> sessions) => sessions
      .where((s) => s.completed && s.focusedSeconds > 0)
      .map((s) => DateTime(s.date.toLocal().year, s.date.toLocal().month, s.date.toLocal().day))
      .toSet().toList()..sort();

  static int currentStreak(List<FocusSession> sessions, [DateTime? now]) {
    final days = activeDays(sessions).toSet();
    var day = _day(now ?? DateTime.now());
    if (!days.contains(day)) return 0;
    var count = 0;
    while (days.contains(day)) { count++; day = day.subtract(const Duration(days: 1)); }
    return count;
  }

  static int longestStreak(List<FocusSession> sessions) {
    var best = 0, run = 0;
    DateTime? previous;
    for (final day in activeDays(sessions)) {
      if (previous != null && day.difference(previous!).inDays == 1) { run++; } else { run = 1; }
      if (run > best) best = run;
      previous = day;
    }
    return best;
  }

  static DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);
}
