import '../models/focus_session.dart';
import '../models/stage7.dart';
import 'supabase_config.dart';

class Stage7Storage {
  Future<UserGoals> loadGoals() async {
    final user = currentSupabaseUser;
    if (user == null) return const UserGoals();
    final row = await supabase.from('goals').select().eq('user_id', user.id).maybeSingle();
    if (row == null) return const UserGoals();
    return UserGoals(dailyTargetMinutes: row['daily_target_minutes'] as int, weeklyTargetMinutes: row['weekly_target_minutes'] as int);
  }

  Future<UserGoals> saveGoals(UserGoals goals) async {
    final user = currentSupabaseUser;
    if (user == null) return goals;
    await supabase.from('goals').upsert({'user_id': user.id, 'daily_target_minutes': goals.dailyTargetMinutes, 'weekly_target_minutes': goals.weeklyTargetMinutes}, onConflict: 'user_id');
    return goals;
  }

  Future<Map<String, DateTime>> loadUnlocked() async {
    final user = currentSupabaseUser;
    if (user == null) return {};
    final rows = await supabase.from('user_achievements').select('achievement_id, unlocked_at').eq('user_id', user.id);
    return {for (final row in rows) row['achievement_id'] as String: DateTime.parse(row['unlocked_at'] as String).toLocal()};
  }

  Future<void> unlock(Iterable<String> ids) async {
    final user = currentSupabaseUser;
    if (user == null || ids.isEmpty) return;
    await supabase.from('user_achievements').upsert(ids.map((id) => {'user_id': user.id, 'achievement_id': id}).toList(), onConflict: 'user_id,achievement_id', ignoreDuplicates: true);
  }

  Future<Map<String, DateTime>> evaluate(List<FocusSession> sessions) async {
    final unlocked = await loadUnlocked();
    final totalSeconds = sessions.fold(0, (sum, s) => sum + (s.completed ? s.focusedSeconds : 0));
    final totalCoins = sessions.fold(0, (sum, s) => sum + (s.completed ? s.coinsEarned : 0));
    final daily = <DateTime, int>{};
    for (final s in sessions.where((s) => s.completed)) { final d = DateTime(s.date.year, s.date.month, s.date.day); daily[d] = (daily[d] ?? 0) + s.focusedSeconds; }
    final eligible = <String>[];
    void add(String id, bool yes) { if (yes && !unlocked.containsKey(id)) eligible.add(id); }
    add('first_step', sessions.isNotEmpty); add('one_hour', totalSeconds >= 3600); add('five_hours', totalSeconds >= 18000); add('ten_hours', totalSeconds >= 36000); add('ten_sessions', sessions.length >= 10);
    add('seven_day_streak', Stage7Calculations.longestStreak(sessions) >= 7); add('thirty_day_streak', Stage7Calculations.longestStreak(sessions) >= 30); add('thousand_coins', totalCoins >= 1000); add('ten_thousand_coins', totalCoins >= 10000); add('focused_day', daily.values.any((seconds) => seconds >= 7200));
    await unlock(eligible);
    final now = DateTime.now();
    for (final id in eligible) unlocked[id] = now;
    return unlocked;
  }
}
