import 'supabase_config.dart';

/// The single persisted source of truth for the authenticated user's coins.
class WalletService {
  Future<int> loadBalance() async {
    final user = supabase.auth.currentUser;
    if (user == null) return 0;
    print('CURRENT_AUTH_USER_ID=${user.id}');
    print('WALLET_QUERY_USER_ID=${user.id}');
    var row = await supabase
        .from('wallets')
        .select('coins')
        .eq('user_id', user.id)
        .maybeSingle();
    if (row == null) {
      await supabase.from('wallets').insert({'user_id': user.id});
      row = await supabase
          .from('wallets')
          .select('coins')
          .eq('user_id', user.id)
          .single();
    }
    final coins = (row['coins'] as num).toInt();
    print('WALLET_RESULT user_id=${user.id} coins=$coins');
    return coins;
  }
}
