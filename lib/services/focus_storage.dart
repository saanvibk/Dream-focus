import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/focus_session.dart';

class FocusStorage {
  static const _sessionsKey = 'dreamfocus.sessions.v1';
  static const _balanceKey = 'dreamfocus.coin_balance.v1';

  Future<List<FocusSession>> loadSessions() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_sessionsKey);
    if (raw == null) return [];
    try {
      final values = jsonDecode(raw);
      if (values is! List) return [];
      return values
          .whereType<Map>()
          .map(
            (value) => FocusSession.fromJson(Map<String, dynamic>.from(value)),
          )
          .whereType<FocusSession>()
          .where((session) => session.completed)
          .toList()
        ..sort((a, b) => b.endTime.compareTo(a.endTime));
    } catch (_) {
      return [];
    }
  }

  Future<int> loadBalance() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getInt(_balanceKey) ?? 0;
  }

  Future<void> saveSession(FocusSession session, int newBalance) async {
    final preferences = await SharedPreferences.getInstance();
    final sessions = await loadSessions();
    sessions.insert(0, session);
    await preferences.setString(
      _sessionsKey,
      jsonEncode(sessions.map((item) => item.toJson()).toList()),
    );
    await preferences.setInt(_balanceKey, newBalance);
  }
}
