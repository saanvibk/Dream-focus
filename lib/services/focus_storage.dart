import '../models/focus_session.dart';
import 'supabase_config.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'wallet_service.dart';

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
    return WalletService().loadBalance();
  }

  Future<int> saveSession(FocusSession session) async {
    final user = currentSupabaseUser;
    if (user == null) throw StateError('Authentication required to save a focus session.');
    final expected = session.focusedSeconds ~/ 60 * 3;
    try {
      final result = await supabase.rpc('complete_focus_session', params: {
        'p_start_time': session.startTime.toUtc().toIso8601String(),
        'p_end_time': session.endTime.toUtc().toIso8601String(),
        'p_duration_seconds': session.focusedSeconds,
      });
      final payload = result is Map ? result : const <String, dynamic>{};
      // The migration returns the balance. During a rolling deployment the
      // older RPC may still return the inserted session; read the wallet back
      // rather than retrying and potentially rewarding the session twice.
      final balance = payload['new_balance'] is num
          ? (payload['new_balance'] as num).toInt()
          : await loadBalance();
      print('[wallet] completed user=${user.id} reward=$expected persisted_balance=$balance');
      return balance;
    } on PostgrestException catch (e) {
      print('[wallet] completion failed user=${user.id} reward=$expected operation=complete_focus_session message=${e.message} code=${e.code}');
      rethrow;
    } catch (e) {
      print('[wallet] completion failed user=${user.id} reward=$expected operation=complete_focus_session error=$e');
      rethrow;
    }
  }
}
