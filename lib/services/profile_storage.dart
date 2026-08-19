import 'supabase_config.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileStorage {
  static const _defaultBio = 'Building my dream life one focused session at a time.';

  Future<void> _ensureProfile(User user) async {
    final row = await supabase.from('profiles').select('id').eq('id', user.id).maybeSingle();
    if (row == null) {
      await supabase.from('profiles').insert({
        'id': user.id,
        'display_name': (user.userMetadata?['display_name'] as String?) ?? 'Dreamer',
      });
    }
  }

  Future<String> loadName() async {
    final user = currentSupabaseUser;
    if (user == null) return 'Dreamer';
    await _ensureProfile(user);
    final row = await supabase.from('profiles').select('display_name').eq('id', user.id).maybeSingle();
    final name = row?['display_name'] as String?;
    return name == null || name.trim().isEmpty ? 'Dreamer' : name;
  }

  Future<String> loadBio() async {
    final user = currentSupabaseUser;
    if (user == null) return _defaultBio;
    await _ensureProfile(user);
    final row = await supabase.from('profiles').select('bio').eq('id', user.id).maybeSingle();
    return (row?['bio'] as String?) ?? _defaultBio;
  }

  Future<void> save({required String name, required String bio}) async {
    final user = currentSupabaseUser;
    if (user == null) return;
    await supabase.from('profiles').update({
      'display_name': name.trim().isEmpty ? 'Dreamer' : name.trim(),
      'bio': bio.trim().isEmpty ? _defaultBio : bio.trim(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', user.id);
  }
}
