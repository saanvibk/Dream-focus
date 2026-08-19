import 'package:flutter/material.dart';
import 'models/shop_item.dart';
import 'services/shop_storage.dart';

class ShopPage extends StatefulWidget {
  final int balance;
  final ValueChanged<int> onBalanceChanged;
  const ShopPage({
    super.key,
    required this.balance,
    required this.onBalanceChanged,
  });
  @override
  State<ShopPage> createState() => _ShopPageState();
}

class _ShopPageState extends State<ShopPage> {
  final storage = ShopStorage();
  List<ShopPurchase> purchases = [];
  List<ShopItem> catalog = [];
  String category = 'All';
  bool ownershipLoading = true;
  String? ownershipError;
  String? message;
  @override
  void initState() {
    super.initState();
    _loadShop();
  }

  Future<void> _loadShop() async {
    try {
      final balance = await storage.loadBalance();
      print('SHOP_COINS=$balance');
      if (mounted) widget.onBalanceChanged(balance);
    } catch (_) {}
    try {
      final value = await storage.loadCatalog();
      if (mounted) setState(() => catalog = value);
    } catch (_) {
      if (mounted) setState(() => catalog = shopCatalog);
    }
    await _loadPurchases();
  }

  Future<void> _loadPurchases() async {
    if (mounted)
      setState(() {
        ownershipLoading = true;
        ownershipError = null;
      });
    try {
      final value = await storage.loadPurchases();
      if (mounted)
        setState(() {
          purchases = value;
          ownershipLoading = false;
        });
    } catch (error) {
      if (mounted)
        setState(() {
          ownershipLoading = false;
          ownershipError = 'Could not load owned items: $error';
        });
    }
  }

  ShopItem? item(String id) {
    for (final value in catalog) {
      if (value.id == id) return value;
    }
    return null;
  }

  Future<void> buy(ShopItem item) async {
    if (purchases.any((p) => p.itemId == item.id)) {
      setState(() => message = 'Already owned');
      return;
    }
    if (widget.balance < item.price) {
      setState(
        () => message = 'Not enough coins\nFocus more to unlock this item.',
      );
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Purchase ${item.name}?'),
        content: Text('This will cost ${item.price} coins.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Buy'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      final newBalance = await storage.purchase(item.id);
      final latest = await storage.loadPurchases();
      if (mounted) {
        setState(() {
          purchases = latest;
          message = null;
        });
        widget.onBalanceChanged(newBalance);
      }
    } catch (error) {
      if (mounted)
        setState(
          () => message = error.toString().contains('Not enough coins')
              ? 'Not enough coins\nFocus more to unlock this item.'
              : error.toString().contains('already owned')
              ? 'Already owned'
              : 'Purchase could not be completed. Please try again.',
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final categories = [
      'All',
      ...{for (final i in shopCatalog) i.category},
    ];
    final visible = shopCatalog
        .where((i) => category == 'All' || i.category == category)
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Dream Life Shop',
          style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        const Text("Turn your focused time into the life you're building."),
        const SizedBox(height: 22),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                const Text('🪙', style: TextStyle(fontSize: 28)),
                const SizedBox(width: 10),
                Text(
                  '${widget.balance} coins',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (message != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              message!,
              style: const TextStyle(
                color: Colors.deepOrange,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        if (ownershipError != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    ownershipError!,
                    style: const TextStyle(color: Colors.deepOrange),
                  ),
                ),
                TextButton(
                  onPressed: _loadPurchases,
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        const SizedBox(height: 18),
        Wrap(
          spacing: 8,
          children: [
            for (final c in categories)
              ChoiceChip(
                label: Text(c),
                selected: category == c,
                onSelected: (_) => setState(() => category = c),
              ),
          ],
        ),
        const SizedBox(height: 20),
        if (visible.isEmpty)
          const Text('No shop items available.')
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 260,
              mainAxisExtent: 300,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            itemCount: visible.length,
            itemBuilder: (_, index) {
              final i = visible[index],
                  owned = purchases.any((p) => p.itemId == i.id);
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(i.icon, style: const TextStyle(fontSize: 38)),
                      const SizedBox(height: 8),
                      Text(
                        i.name,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        i.category,
                        style: const TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        i.description,
                        style: const TextStyle(color: Colors.grey),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const Spacer(),
                      Text(
                        '🪙 ${i.price}',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: owned
                            ? OutlinedButton.icon(
                                onPressed: null,
                                icon: const Icon(Icons.check),
                                label: const Text('Owned'),
                              )
                            : FilledButton(
                                onPressed: widget.balance < i.price
                                    ? null
                                    : () => buy(i),
                                child: const Text('Purchase'),
                              ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        const SizedBox(height: 30),
        const Text(
          'My Purchases',
          style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 10),
        if (purchases.isEmpty && !ownershipLoading)
          const Text(
            'My dream life is waiting. Keep focusing to unlock your first item.',
            style: TextStyle(color: Colors.grey),
          )
        else ...[
          for (final p in purchases)
            if (item(p.itemId) != null)
              ListTile(
                leading: Text(
                  item(p.itemId)!.icon,
                  style: const TextStyle(fontSize: 24),
                ),
                title: Text(item(p.itemId)!.name),
                subtitle: Text(
                  '🪙 ${p.price} · Purchased ${p.purchasedAt.month}/${p.purchasedAt.day}/${p.purchasedAt.year}',
                ),
              ),
        ],
      ],
    );
  }
}
