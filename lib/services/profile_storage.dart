import 'supabase_config.dart';

class ProfileStorage {
  static const _defaultBio = 'Building my dream life one focused session at a time.';

  Future<String> loadName() async {
    final user = currentSupabaseUser;
    if (user == null) return 'Dreamer';
    final row = await supabase.from('profiles').select('display_name').eq('id', user.id).maybeSingle();
    final name = row?['display_name'] as String?;
    return name == null || name.trim().isEmpty ? 'Dreamer' : name;
  }

  Future<String> loadBio() async {
    final user = currentSupabaseUser;
    if (user == null) return _defaultBio;
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
