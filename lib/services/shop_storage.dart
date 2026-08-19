import '../models/shop_item.dart';
import 'supabase_config.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'wallet_service.dart';

class ShopPurchase {
  final String itemId;
  final int price;
  final DateTime purchasedAt;
  final double x, y, rotation, scale;
  final bool isPlaced;
  const ShopPurchase({
    required this.itemId,
    required this.price,
    required this.purchasedAt,
    this.x = .5,
    this.y = .5,
    this.rotation = 0,
    this.scale = 1,
    this.isPlaced = true,
  });
}

class ShopStorage {
  Future<List<ShopItem>> loadCatalog() async {
    final rows = await supabase
        .from('shop_items')
        .select('id, name, category, description, price, repeatable')
        .order('created_at');
    final loaded = rows.map((row) {
      final matches = shopCatalog.where((item) => item.id == row['id']);
      final visual = matches.isEmpty ? null : matches.first;
      return ShopItem(
        id: row['id'] as String,
        name: row['name'] as String,
        category: row['category'] as String,
        price: (row['price'] as num).toInt(),
        description:
            (row['description'] as String?) ?? visual?.description ?? '',
        icon: visual?.icon ?? '✨',
        repeatable: row['repeatable'] as bool? ?? false,
      );
    }).toList();
    shopCatalog = loaded;
    return loaded;
  }

  Future<List<ShopPurchase>> loadPurchases() async {
    final user = currentSupabaseUser;
    if (user == null) return [];
    final ownedRows = await supabase
        .from('user_items')
        .select('item_id, price_paid, purchased_at')
        .eq('user_id', user.id)
        .order('purchased_at', ascending: false);
    // Shop ownership is user_items only. Dream World placement is loaded separately.
    return ownedRows
        .map(
          (row) => ShopPurchase(
            itemId: row['item_id'] as String,
            price: row['price_paid'] as int,
            purchasedAt: DateTime.parse(
              row['purchased_at'] as String,
            ).toLocal(),
            isPlaced: true,
          ),
        )
        .toList();
  }

  Future<int> loadBalance() => WalletService().loadBalance();

  Future<List<ShopPurchase>> loadDreamWorldPurchases() async {
    final user = currentSupabaseUser;
    if (user == null) return [];
    final owned = await loadPurchases();
    print('DREAM_WORLD_QUERY_USER_ID=${user.id}');
    List<dynamic> rows;
    try {
      rows = await supabase.from('dream_world_items').select(
        'item_id, position_x, position_y, rotation, scale, is_placed',
      ).eq('user_id', user.id);
      print('DREAM_WORLD_ITEM_COUNT=${rows.length}');
    } on PostgrestException catch (e) {
      // Keep owned items visible if an older deployment has not exposed the
      // placement table yet. New positions will still report save errors.
      print('DREAM_WORLD_QUERY_FAILED user=${user.id} code=${e.code} message=${e.message}');
      return owned;
    }
    final world = {for (final row in rows) row['item_id'] as String: row};
    return owned.map((p) {
      final row = world[p.itemId];
      return ShopPurchase(itemId: p.itemId, price: p.price, purchasedAt: p.purchasedAt,
        x: (row?['position_x'] as num?)?.toDouble() ?? .5,
        y: (row?['position_y'] as num?)?.toDouble() ?? .5,
        rotation: (row?['rotation'] as num?)?.toDouble() ?? 0,
        scale: (row?['scale'] as num?)?.toDouble() ?? 1,
        isPlaced: row?['is_placed'] as bool? ?? true);
    }).toList();
  }

  Future<int> purchase(String itemId) async {
    final user = currentSupabaseUser;
    if (user == null)
      throw StateError('Authentication required to purchase an item.');
    try {
      final result = await supabase.rpc(
        'purchase_shop_item',
        params: {'p_item_id': itemId},
      );
      final balance = ((result as Map)['new_balance'] as num).toInt();
      print(
        '[shop] purchase succeeded user=${user.id} item=$itemId persisted_balance=$balance',
      );
      return balance;
    } on PostgrestException catch (e) {
      print(
        '[shop] purchase failed user=${user.id} item=$itemId operation=purchase_shop_item message=${e.message} code=${e.code}',
      );
      rethrow;
    }
  }

  Future<void> savePlacement(ShopPurchase purchase) async {
    final user = currentSupabaseUser;
    if (user == null) throw StateError('Authentication required.');
    await supabase
        .from('dream_world_items')
        .upsert({
          'user_id': user.id,
          'item_id': purchase.itemId,
          'position_x': purchase.x.clamp(.08, .92),
          'position_y': purchase.y.clamp(.08, .92),
          'rotation': purchase.rotation,
          'scale': purchase.scale.clamp(.7, 1.8),
          'is_placed': purchase.isPlaced,
        })
        .eq('user_id', user.id)
        .eq('item_id', purchase.itemId);
  }

  Future<void> removeFromWorld(String itemId) async {
    final user = currentSupabaseUser;
    if (user == null) throw StateError('Authentication required.');
    await supabase.from('dream_world_items').delete()
        .eq('user_id', user.id).eq('item_id', itemId);
  }
}
