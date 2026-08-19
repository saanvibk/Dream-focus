import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'models/shop_item.dart';
import 'services/shop_storage.dart';

const _violet = Color(0xFF7357E8);

class DreamWorldPage extends StatefulWidget {
  final int balance;
  final VoidCallback onVisitShop;
  const DreamWorldPage({
    super.key,
    required this.balance,
    required this.onVisitShop,
  });
  @override
  State<DreamWorldPage> createState() => _DreamWorldPageState();
}

class _DreamWorldPageState extends State<DreamWorldPage> {
  final _storage = ShopStorage();
  List<ShopPurchase> _items = [];
  List<ShopItem> _catalog = [];
  String? _selected;
  bool _loading = true;
  String? _error;
  double _zoom = 1;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final catalog = await _storage.loadCatalog();
      final purchases = await _storage.loadDreamWorldPurchases();
      if (mounted)
        setState(() {
          _catalog = catalog;
          _items = purchases;
          _loading = false;
        });
    } catch (_) {
      if (mounted)
        setState(() {
          _loading = false;
          _error = 'Your dream world could not be loaded.';
        });
    }
  }

  ShopItem? _item(String id) => _catalog.where((i) => i.id == id).firstOrNull;
  ShopPurchase? _purchase(String id) =>
      _items.where((p) => p.itemId == id).firstOrNull;
  void _change(
    String id,
    ShopPurchase Function(ShopPurchase) edit, {
    bool save = true,
  }) {
    final i = _items.indexWhere((p) => p.itemId == id);
    if (i < 0) return;
    final next = edit(_items[i]);
    setState(() => _items[i] = next);
    if (save)
      _storage.savePlacement(next).catchError((_) {
        if (mounted) setState(() => _error = 'Layout could not be saved.');
      });
  }

  ShopPurchase _default(ShopPurchase p, int index) => ShopPurchase(
    itemId: p.itemId,
    price: p.price,
    purchasedAt: p.purchasedAt,
    x: .22 + (index % 4) * .18,
    y: .25 + (index ~/ 4) * .18,
    isPlaced: true,
    rotation: 0,
    scale: 1,
  );

  @override
  Widget build(BuildContext context) {
    if (_loading)
      return const Center(child: CircularProgressIndicator(color: _violet));
    if (_error != null && _catalog.isEmpty)
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!),
            TextButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
    final owned = _items.where((p) => _item(p.itemId) != null).toList();
    final placed = owned.where((p) => p.isPlaced).toList()
      ..sort((a, b) => a.y.compareTo(b.y));
    final unplaced = owned.where((p) => !p.isPlaced).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Dream Farm',
          style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900, letterSpacing: .2),
        ),
        const SizedBox(height: 6),
        const Text(
          'Grow a peaceful little world, one focused day at a time.',
          style: TextStyle(color: Colors.grey),
        ),
        const SizedBox(height: 18),
        Wrap(
          spacing: 12,
          runSpacing: 10,
          children: [
            _Stat('🪙', '${widget.balance}', 'coins'),
            _Stat('🏠', '${owned.length}', 'items unlocked'),
            _Stat(
              '✨',
              '${owned.length} / ${_catalog.length}',
              'world progress',
            ),
          ],
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            const Text(
              'Your homestead',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 19),
            ),
            const Spacer(),
            IconButton(
              onPressed: _zoom > .75 ? () => setState(() => _zoom -= .1) : null,
              icon: const Icon(Icons.remove),
            ),
            Text('${(_zoom * 100).round()}%'),
            IconButton(
              onPressed: _zoom < 1.4 ? () => setState(() => _zoom += .1) : null,
              icon: const Icon(Icons.add),
            ),
            TextButton(
              onPressed: () => setState(() => _zoom = 1),
              child: const Text('Reset View'),
            ),
          ],
        ),
        LayoutBuilder(
          builder: (context, constraints) {
            return AspectRatio(
              aspectRatio: constraints.maxWidth < 600 ? .92 : 1.75,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: ColoredBox(
                  color: const Color(0xFF8CC9D1),
                  child: Stack(
                    children: [
                      const Positioned.fill(
                        child: CustomPaint(painter: _LandPainter()),
                      ),
                      Transform.scale(
                        scale: _zoom,
                        child: Stack(
                          children: [
                            for (final p in placed)
                              if (_item(p.itemId) != null)
                                _DraggableObject(
                                  item: _item(p.itemId)!,
                                  purchase: p,
                                  selected: _selected == p.itemId,
                                  onSelect: () =>
                                      setState(() => _selected = p.itemId),
                                  onMove: (dx, dy) => _change(
                                    p.itemId,
                                    (old) => _copy(
                                      old,
                                      x: (old.x + dx).clamp(.08, .92),
                                      y: (old.y + dy).clamp(.08, .92),
                                    ),
                                    save: false,
                                  ),
                                  onEnd: () {
                                    final latest = _purchase(p.itemId);
                                    if (latest != null)
                                      _storage.savePlacement(latest);
                                  },
                                  onControl: (kind) => _control(p.itemId, kind),
                                ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
        if (owned.isEmpty) _Empty(onVisitShop: widget.onVisitShop),
        if (_selected != null &&
            _purchase(_selected!) != null &&
            _item(_selected!) != null)
          _Panel(
            item: _item(_selected!)!,
            purchase: _purchase(_selected!)!,
            onClose: () => setState(() => _selected = null),
            onControl: (kind) => _control(_selected!, kind),
          ),
        _OwnedPanel(
          items: unplaced,
          catalog: _catalog,
          onPlace: (p) =>
              _change(p.itemId, (old) => _default(old, _items.indexOf(old))),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton.icon(
              onPressed: _reset,
              icon: const Icon(Icons.refresh),
              label: const Text('Reset Layout'),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: widget.onVisitShop,
              icon: const Icon(Icons.shopping_bag_outlined),
              label: const Text('Visit Shop'),
            ),
          ],
        ),
      ],
    );
  }

  static ShopPurchase _copy(
    ShopPurchase p, {
    double? x,
    double? y,
    double? rotation,
    double? scale,
    bool? isPlaced,
  }) => ShopPurchase(
    itemId: p.itemId,
    price: p.price,
    purchasedAt: p.purchasedAt,
    x: x ?? p.x,
    y: y ?? p.y,
    rotation: rotation ?? p.rotation,
    scale: scale ?? p.scale,
    isPlaced: isPlaced ?? p.isPlaced,
  );
  void _control(String id, String kind) {
    final p = _purchase(id);
    if (p == null) return;
    if (kind == 'rotate')
      _change(id, (o) => _copy(o, rotation: o.rotation + math.pi / 8));
    if (kind == 'resize')
      _change(id, (o) => _copy(o, scale: (o.scale + .15).clamp(.7, 1.8)));
    if (kind == 'remove') {
      _storage.removeFromWorld(id).then((_) {
        if (mounted) {
          setState(() {
            final i = _items.indexWhere((item) => item.itemId == id);
            if (i >= 0) _items[i] = _copy(_items[i], isPlaced: false);
            _selected = null;
          });
        }
      }).catchError((_) {
        if (mounted) setState(() => _error = 'Item could not be removed from the world.');
      });
    }
  }

  Future<void> _reset() async {
    for (var i = 0; i < _items.length; i++) {
      final n = _default(_items[i], i);
      _change(_items[i].itemId, (_) => n);
    }
  }
}

class _Stat extends StatelessWidget {
  final String icon, value, label;
  const _Stat(this.icon, this.value, this.label);
  @override
  Widget build(BuildContext c) => Card(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(icon, style: const TextStyle(fontSize: 24)),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 17,
                ),
              ),
              Text(
                label,
                style: const TextStyle(color: Colors.grey, fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

class _LandPainter extends CustomPainter {
  const _LandPainter();
  @override
  void paint(Canvas c, Size s) {
    final p = Paint()..isAntiAlias = false;
    c.drawRect(Offset.zero & s, p..color = const Color(0xFF78B96D));

    // A simple tile grid gives the map its cozy 2D game feel.
    const tile = 28.0;
    p.color = const Color(0x1470473A);
    for (double x = 0; x < s.width; x += tile) {
      for (double y = 0; y < s.height; y += tile) {
        if (((x / tile).floor() + (y / tile).floor()) % 2 == 0) {
          c.drawRect(Rect.fromLTWH(x, y, tile, tile), p);
        }
      }
    }

    // River and wooden bridge.
    p.color = const Color(0xFF5BAEC2);
    c.drawPath(Path()..moveTo(s.width * .80, 0)..quadraticBezierTo(s.width * .65, s.height * .3, s.width * .82, s.height * .58)..quadraticBezierTo(s.width * .92, s.height * .78, s.width * .78, s.height)..lineTo(s.width, s.height)..lineTo(s.width, 0)..close(), p);
    p.color = const Color(0xFFB97948);
    c.drawRect(Rect.fromLTWH(s.width * .69, s.height * .48, s.width * .23, 32), p);
    p.color = const Color(0x664A2E25);
    for (var i = 0; i < 6; i++) c.drawRect(Rect.fromLTWH(s.width * .69 + i * s.width * .045, s.height * .48, 5, 32), p);

    // Dirt paths and crop patch.
    p.color = const Color(0xFFD9B477);
    c.drawRect(Rect.fromLTWH(s.width * .08, s.height * .68, s.width * .66, 32), p);
    c.drawRect(Rect.fromLTWH(s.width * .38, s.height * .14, 30, s.height * .7), p);
    p.color = const Color(0xFF9A633F);
    c.drawRect(Rect.fromLTWH(s.width * .13, s.height * .28, s.width * .22, s.height * .2), p);
    p.color = const Color(0xFF6B9D54);
    for (var i = 0; i < 4; i++) {
      c.drawRect(Rect.fromLTWH(s.width * .16 + i * 25, s.height * .32, 8, 8), p);
      c.drawRect(Rect.fromLTWH(s.width * .16 + i * 25, s.height * .40, 8, 8), p);
    }

    // House: shadow, walls, roof, door, and window.
    p.color = const Color(0x443C322E);
    c.drawRect(Rect.fromLTWH(s.width * .45 + 5, s.height * .21 + 7, s.width * .21, s.height * .2), p);
    p.color = const Color(0xFFE9C47A);
    c.drawRect(Rect.fromLTWH(s.width * .45, s.height * .21, s.width * .21, s.height * .2), p);
    p.color = const Color(0xFFB95745);
    c.drawPath(Path()..moveTo(s.width * .42, s.height * .22)..lineTo(s.width * .56, s.height * .08)..lineTo(s.width * .69, s.height * .22)..close(), p);
    p.color = const Color(0xFF79503A);
    c.drawRect(Rect.fromLTWH(s.width * .535, s.height * .31, 22, s.height * .1), p);
    p.color = const Color(0xFFA9D9D8);
    c.drawRect(Rect.fromLTWH(s.width * .47, s.height * .27, 23, 18), p);

    // Chunky trees.
    for (final o in [Offset(s.width * .13, s.height * .14), Offset(s.width * .27, s.height * .58), Offset(s.width * .62, s.height * .62), Offset(s.width * .12, s.height * .84)]) {
      p.color = const Color(0xFF76503A); c.drawRect(Rect.fromLTWH(o.dx - 5, o.dy + 13, 10, 22), p);
      p.color = const Color(0xFF39734C); c.drawCircle(o, 18, p); p.color = const Color(0xFF4F9757); c.drawCircle(o.translate(-7, -7), 12, p);
    }
  }

  @override
  bool shouldRepaint(covariant _LandPainter old) => false;
}

class _DraggableObject extends StatelessWidget {
  final ShopItem item;
  final ShopPurchase purchase;
  final bool selected;
  final VoidCallback onSelect;
  final void Function(double, double) onMove;
  final VoidCallback onEnd;
  final void Function(String) onControl;
  const _DraggableObject({
    required this.item,
    required this.purchase,
    required this.selected,
    required this.onSelect,
    required this.onMove,
    required this.onEnd,
    required this.onControl,
  });
  @override
  Widget build(BuildContext c) => Positioned(
    left: purchase.x * MediaQuery.sizeOf(c).width - 32,
    top: purchase.y * MediaQuery.sizeOf(c).height - 35,
    child: GestureDetector(
      onTap: onSelect,
      onPanUpdate: (d) {
        onSelect();
        onMove(
          d.delta.dx / MediaQuery.sizeOf(c).width,
          d.delta.dy / MediaQuery.sizeOf(c).height,
        );
      },
      onPanEnd: (_) => onEnd(),
      child: Transform.rotate(
        angle: purchase.rotation,
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .92),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected ? _violet : Colors.transparent,
              width: 3,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x44000000),
                blurRadius: 12,
                offset: Offset(0, 7),
              ),
            ],
          ),
          child: Text(
            item.icon,
            style: TextStyle(fontSize: 42 * purchase.scale),
          ),
        ),
      ),
    ),
  );
}

class _Panel extends StatelessWidget {
  final ShopItem item;
  final ShopPurchase purchase;
  final VoidCallback onClose;
  final void Function(String) onControl;
  const _Panel({
    required this.item,
    required this.purchase,
    required this.onClose,
    required this.onControl,
  });
  @override
  Widget build(BuildContext c) => Card(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Text(item.icon, style: const TextStyle(fontSize: 30)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              item.name,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          IconButton(
            onPressed: () => onControl('rotate'),
            icon: const Icon(Icons.rotate_right),
          ),
          IconButton(
            onPressed: () => onControl('resize'),
            icon: const Icon(Icons.zoom_in),
          ),
          IconButton(
            onPressed: () => onControl('remove'),
            icon: const Icon(Icons.visibility_off_outlined),
          ),
          IconButton(onPressed: onClose, icon: const Icon(Icons.close)),
        ],
      ),
    ),
  );
}

class _OwnedPanel extends StatelessWidget {
  final List<ShopPurchase> items;
  final List<ShopItem> catalog;
  final void Function(ShopPurchase) onPlace;
  const _OwnedPanel({
    required this.items,
    required this.catalog,
    required this.onPlace,
  });
  @override
  Widget build(BuildContext c) => Card(
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Owned Items',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 5),
          if (items.isEmpty)
            const Text(
              'All your dreams are placed.',
              style: TextStyle(color: Colors.grey),
            )
          else
            Wrap(
              spacing: 8,
              children: [
                for (final p in items)
                  if (catalog.where((i) => i.id == p.itemId).isNotEmpty)
                    ActionChip(
                      avatar: Text(
                        catalog.firstWhere((i) => i.id == p.itemId).icon,
                      ),
                      label: Text(
                        catalog.firstWhere((i) => i.id == p.itemId).name,
                      ),
                      onPressed: () => onPlace(p),
                    ),
              ],
            ),
        ],
      ),
    ),
  );
}

class _Empty extends StatelessWidget {
  final VoidCallback onVisitShop;
  const _Empty({required this.onVisitShop});
  @override
  Widget build(BuildContext c) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const Text(
            'Your Dream Land is waiting.',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          const Text('Focus, earn, and start building.'),
          FilledButton(onPressed: onVisitShop, child: const Text('Visit Shop')),
        ],
      ),
    ),
  );
}
