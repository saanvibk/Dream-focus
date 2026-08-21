import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'models/shop_item.dart';
import 'services/shop_storage.dart';

const _violet = Color(0xFF7357E8);

// Only assets that exist in assets/world are mapped here. Unmapped catalog
// items remain available for purchase but are not represented by emoji sprites.
const _worldAssetByShopId = <String, String>{
  'cozy_cabin': 'assets/world/homes/cozy_cabin.png',
  'bicycle': 'assets/world/vehicles/bicycle.png',
  'cat': 'assets/world/pets/cat.png',
  'dog': 'assets/world/pets/dog.png',
};

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
          style: TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w900,
            letterSpacing: .2,
          ),
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
            return SizedBox(
              height: constraints.maxWidth < 600 ? 360 : 520,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: ColoredBox(
                  color: const Color(0xFF8CC9D1),
                  child: InteractiveViewer(
                    minScale: .65,
                    maxScale: 2.4,
                    scaleEnabled: true,
                    panEnabled: _selected == null,
                    boundaryMargin: const EdgeInsets.all(180),
                    child: SizedBox(
                      width: 960,
                      height: 540,
                      child: Stack(
                        children: [
                          const Positioned.fill(
                            child: CustomPaint(painter: _LandPainter()),
                          ),
                          Stack(
                            children: [
                              for (final p in placed)
                                if (_worldAssetByShopId.containsKey(p.itemId) &&
                                    _item(p.itemId) != null)
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
                                    onControl: (kind) =>
                                        _control(p.itemId, kind),
                                  ),
                            ],
                          ),
                        ],
                      ),
                    ),
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
      _storage
          .removeFromWorld(id)
          .then((_) {
            if (mounted) {
              setState(() {
                final i = _items.indexWhere((item) => item.itemId == id);
                if (i >= 0) _items[i] = _copy(_items[i], isPlaced: false);
                _selected = null;
              });
            }
          })
          .catchError((_) {
            if (mounted)
              setState(
                () => _error = 'Item could not be removed from the world.',
              );
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
    const t = 32.0;
    c.drawRect(Offset.zero & s, p..color = const Color(0xFF78A958));
    // Base tile texture: crisp checker variation, never a smooth fill.
    for (var x = 0; x < s.width / t; x++) {
      for (var y = 0; y < s.height / t; y++) {
        p.color = ((x + y).toInt() % 3 == 0)
            ? const Color(0xFF80B45C)
            : const Color(0xFF75A453);
        c.drawRect(Rect.fromLTWH(x * t, y * t, t, t), p);
        if ((x * 7 + y * 11).toInt() % 5 == 0) {
          p.color = const Color(0x32708F4D);
          c.drawRect(Rect.fromLTWH(x * t + 7, y * t + 20, 5, 3), p);
        }
      }
    }
    // Water inlet with pixel ripples.
    p.color = const Color(0xFF4A9FB2);
    c.drawRect(Rect.fromLTWH(s.width * .72, 0, s.width * .28, s.height), p);
    p.color = const Color(0xFF6BC1C0);
    for (var y = 16.0; y < s.height; y += 42) {
      c.drawRect(Rect.fromLTWH(s.width * .76, y, 34, 4), p);
      c.drawRect(Rect.fromLTWH(s.width * .88, y + 16, 22, 4), p);
    }
    // Stone-edged shoreline.
    p.color = const Color(0xFFB7A878);
    for (var y = 0.0; y < s.height; y += 32)
      c.drawRect(Rect.fromLTWH(s.width * .69, y, 18, 18), p);
    // Winding dirt path with darker pixel border.
    p.color = const Color(0xFF8A6546);
    c.drawRect(Rect.fromLTWH(0, s.height * .67, s.width * .70, 58), p);
    c.drawRect(
      Rect.fromLTWH(s.width * .38, s.height * .18, 58, s.height * .58),
      p,
    );
    p.color = const Color(0xFFD2A96D);
    c.drawRect(Rect.fromLTWH(0, s.height * .67 + 7, s.width * .70, 42), p);
    c.drawRect(
      Rect.fromLTWH(s.width * .38 + 7, s.height * .18, 42, s.height * .58),
      p,
    );
    // Flowers and bushes as small pixel clusters.
    for (final o in [
      Offset(125, 110),
      Offset(235, 390),
      Offset(520, 425),
      Offset(635, 150),
      Offset(300, 120),
    ]) {
      p.color = const Color(0xFF3E7745);
      c.drawRect(Rect.fromLTWH(o.dx, o.dy + 8, 5, 15), p);
      p.color = const Color(0xFFF4D36B);
      c.drawRect(Rect.fromLTWH(o.dx - 4, o.dy + 2, 12, 7), p);
      p.color = const Color(0xFFE88983);
      c.drawRect(Rect.fromLTWH(o.dx + 1, o.dy - 3, 5, 16), p);
    }
    for (final o in [
      Offset(90, 250),
      Offset(250, 280),
      Offset(700, 390),
      Offset(560, 90),
    ]) {
      p.color = const Color(0xFF315F3D);
      c.drawRect(Rect.fromLTWH(o.dx, o.dy + 14, 30, 13), p);
      p.color = const Color(0xFF4D8B4D);
      c.drawRect(Rect.fromLTWH(o.dx - 8, o.dy + 5, 34, 18), p);
      p.color = const Color(0xFF74AA57);
      c.drawRect(Rect.fromLTWH(o.dx + 5, o.dy, 18, 14), p);
    }
    // Layered trees: shadow, trunk, dark canopy, highlight canopy.
    for (final o in [
      Offset(95, 85),
      Offset(205, 445),
      Offset(580, 450),
      Offset(850, 100),
      Offset(760, 350),
    ]) {
      p.color = const Color(0x443E4B35);
      c.drawRect(Rect.fromLTWH(o.dx - 20, o.dy + 35, 64, 14), p);
      p.color = const Color(0xFF6E4B35);
      c.drawRect(Rect.fromLTWH(o.dx + 8, o.dy + 18, 14, 36), p);
      p.color = const Color(0xFF2F6542);
      c.drawRect(Rect.fromLTWH(o.dx - 12, o.dy + 4, 54, 42), p);
      p.color = const Color(0xFF43834A);
      c.drawRect(Rect.fromLTWH(o.dx - 2, o.dy - 8, 40, 28), p);
      p.color = const Color(0xFF70A956);
      c.drawRect(Rect.fromLTWH(o.dx + 8, o.dy - 12, 18, 12), p);
    }
    // A small free starter plot landmark, drawn as pixel-art terrain only.
    p.color = const Color(0x443E4B35);
    c.drawRect(Rect.fromLTWH(430, 250, 180, 18), p);
    p.color = const Color(0xFFB88A58);
    c.drawRect(Rect.fromLTWH(420, 238, 180, 12), p);
  }

  @override
  bool shouldRepaint(covariant _LandPainter old) => false;
}

class _DraggableObject extends StatelessWidget {
  static const worldWidth = 960.0;
  static const worldHeight = 540.0;
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
    left: purchase.x * worldWidth - 32,
    top: purchase.y * worldHeight - 35,
    child: GestureDetector(
      onTap: onSelect,
      onPanUpdate: (d) {
        onSelect();
        onMove(d.delta.dx / worldWidth, d.delta.dy / worldHeight);
      },
      onPanEnd: (_) => onEnd(),
      child: Transform.rotate(
        angle: purchase.rotation,
        child: _worldAssetByShopId[item.id] != null
            ? Image.asset(
                _worldAssetByShopId[item.id]!,
                width: 210 * purchase.scale,
                height: 155 * purchase.scale,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.none,
              )
            : CustomPaint(
                size: Size(156 * purchase.scale, 140 * purchase.scale),
                painter: _SmallApartmentPainter(selected: selected),
              ),
      ),
    ),
  );
}

/// Original pixel sprite for the first production world object. The canvas is
/// transparent; every mark is a crisp pixel block in the shared world palette.
class _SmallApartmentPainter extends CustomPainter {
  final bool selected;
  const _SmallApartmentPainter({required this.selected});
  @override
  void paint(Canvas c, Size s) {
    final k = s.width / 156;
    final p = Paint()..isAntiAlias = false;
    if (selected) {
      p.color = const Color(0xFFFAE58A);
      c.drawRect(Rect.fromLTWH(12 * k, 6 * k, 132 * k, 126 * k), p);
    }
    p.color = const Color(0x553C352B);
    c.drawRect(Rect.fromLTWH(18 * k, 116 * k, 116 * k, 13 * k), p);
    // Side wall and front wall, with a stepped 3/4 silhouette.
    p.color = const Color(0xFFB96F4C);
    c.drawRect(Rect.fromLTWH(32 * k, 42 * k, 82 * k, 72 * k), p);
    p.color = const Color(0xFFD79A62);
    c.drawRect(Rect.fromLTWH(20 * k, 52 * k, 82 * k, 62 * k), p);
    // Roof planes.
    p.color = const Color(0xFF713F3D);
    final roof = Path()
      ..moveTo(14 * k, 53 * k)
      ..lineTo(57 * k, 18 * k)
      ..lineTo(126 * k, 38 * k)
      ..lineTo(97 * k, 62 * k)
      ..close();
    c.drawPath(roof, p);
    p.color = const Color(0xFF96504A);
    c.drawPath(
      Path()
        ..moveTo(57 * k, 18 * k)
        ..lineTo(137 * k, 45 * k)
        ..lineTo(126 * k, 61 * k)
        ..lineTo(97 * k, 62 * k)
        ..close(),
      p,
    );
    // Door, windows, and bright trim.
    p.color = const Color(0xFF4B3A43);
    c.drawRect(Rect.fromLTWH(52 * k, 78 * k, 22 * k, 36 * k), p);
    p.color = const Color(0xFFF1C979);
    c.drawRect(Rect.fromLTWH(57 * k, 83 * k, 12 * k, 25 * k), p);
    for (final x in [27.0, 80.0]) {
      p.color = const Color(0xFFF0D98F);
      c.drawRect(Rect.fromLTWH(x * k, 67 * k, 25 * k, 22 * k), p);
      p.color = const Color(0xFF6CB4BD);
      c.drawRect(Rect.fromLTWH((x + 4) * k, 71 * k, 17 * k, 14 * k), p);
      p.color = const Color(0xFFDBB66A);
      c.drawRect(Rect.fromLTWH((x + 12) * k, 71 * k, 3 * k, 14 * k), p);
    }
    // Tiny chimney and roof highlight pixels.
    p.color = const Color(0xFF6A4540);
    c.drawRect(Rect.fromLTWH(91 * k, 27 * k, 12 * k, 22 * k), p);
    p.color = const Color(0xFFE2A36A);
    c.drawRect(Rect.fromLTWH(23 * k, 56 * k, 6 * k, 4 * k), p);
  }

  @override
  bool shouldRepaint(covariant _SmallApartmentPainter old) =>
      old.selected != selected;
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
          const Icon(Icons.home_work_outlined, color: _violet),
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
                      avatar: _worldAssetByShopId[p.itemId] != null
                          ? Image.asset(
                              _worldAssetByShopId[p.itemId]!,
                              width: 32,
                              height: 32,
                              fit: BoxFit.contain,
                              filterQuality: FilterQuality.none,
                            )
                          : Text(
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
