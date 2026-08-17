import 'package:supabase_flutter/supabase_flutter.dart';

const supabaseUrl = 'https://fdskfkvkvnbfptedsnjr.supabase.co';
const supabasePublishableKey =
    'sb_publishable_vwIl_8WaVXaueI1Y-L2r_w_fZr4f1Od';

SupabaseClient get supabase => Supabase.instance.client;

User? get currentSupabaseUser {
  try { return supabase.auth.currentUser; } catch (_) { return null; }
}
