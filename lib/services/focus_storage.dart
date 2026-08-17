import '../models/focus_session.dart';
import 'supabase_config.dart';

class FocusStorage {
  Future<List<FocusSession>> loadSessions() async {
    final user = currentSupabaseUser;
    if (user == null) return [];
    final rows = await supabase.from('focus_sessions').select().eq('user_id', user.id).order('end_time', ascending: false);
    return rows.map<FocusSession>((row) => FocusSession(
      id: row['id'] as String,
      date: DateTime.parse(row['start_time'] as String).toLocal(),
      startTime: DateTime.parse(row['start_time'] as String).toLocal(),
      endTime: DateTime.parse(row['end_time'] as String).toLocal(),
      focusedSeconds: row['duration_seconds'] as int,
      coinsEarned: row['coins_earned'] as int,
      completed: true,
    )).toList();
  }

  Future<int> loadBalance() async {
    final user = currentSupabaseUser;
    if (user == null) return 0;
    final row = await supabase.from('wallets').select('coins').eq('user_id', user.id).maybeSingle();
    return (row?['coins'] as int?) ?? 0;
  }

  Future<void> saveSession(FocusSession session, int _) async {
    final user = currentSupabaseUser;
    if (user == null) return;
    await supabase.rpc('complete_focus_session', params: {
      'p_start_time': session.startTime.toUtc().toIso8601String(),
      'p_end_time': session.endTime.toUtc().toIso8601String(),
      'p_duration_seconds': session.focusedSeconds,
    });
  }
}
