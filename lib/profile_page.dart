import 'package:flutter/material.dart';

import 'models/focus_session.dart';
import 'progress_page.dart';
import 'services/focus_activity.dart';
import 'services/focus_statistics.dart';
import 'services/profile_storage.dart';
import 'models/stage7.dart';
import 'services/stage7_storage.dart';
import 'models/shop_item.dart';
import 'services/shop_storage.dart';

const _profileViolet = Color(0xFF7C5CFC);
const _profileInk = Color(0xFF172A3A);
const _profileMuted = Color(0xFF718096);

class ProfilePage extends StatefulWidget {
  final List<FocusSession> sessions;
  final int balance;
  final VoidCallback onViewAllSessions;
  const ProfilePage({
    super.key,
    required this.sessions,
    required this.balance,
    required this.onViewAllSessions,
  });

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _storage = ProfileStorage();
  String _name = 'Dreamer';
  String _bio = 'Building my dream life one focused session at a time.';
  int _achievementCount = 0;
  int _ownedItemCount = 0;

  @override
  void initState() {
    super.initState();
    _loadProfile();
    Stage7Storage().loadUnlocked().then((value) { if (mounted) setState(() => _achievementCount = value.length); });
    ShopStorage().loadPurchases().then((value) { if (mounted) setState(() => _ownedItemCount = value.map((p) => p.itemId).toSet().length); });
  }

  Future<void> _loadProfile() async {
    final name = await _storage.loadName();
    final bio = await _storage.loadBio();
    if (mounted)
      setState(() {
        _name = name;
        _bio = bio;
      });
  }

  String _duration(Duration value) {
    if (value.inHours > 0) return '${value.inHours}h ${value.inMinutes % 60}m';
    if (value.inMinutes > 0) return '${value.inMinutes}m';
    return '${value.inSeconds}s';
  }

  Future<void> _editProfile() async {
    final name = TextEditingController(text: _name);
    final bio = TextEditingController(text: _bio);
    final result = await showDialog<(String, String)>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit profile'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              decoration: const InputDecoration(labelText: 'Display name'),
            ),
            TextField(
              controller: bio,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Short bio'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, (name.text, bio.text)),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    name.dispose();
    bio.dispose();
    if (result != null) {
      await _storage.save(name: result.$1, bio: result.$2);
      if (mounted)
        setState(() {
          _name = result.$1.trim().isEmpty ? 'Dreamer' : result.$1.trim();
          _bio = result.$2.trim().isEmpty
              ? 'Building my dream life one focused session at a time.'
              : result.$2.trim();
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final sessions = widget.sessions;
    final today = DateTime.now();
    final end = DateTime(today.year, today.month, today.day);
    final start = end.subtract(const Duration(days: 364));
    final daily = FocusActivity.daily(
      sessions.where((s) {
        final date = FocusActivity.day(s.date.toLocal());
        return !date.isBefore(start) && !date.isAfter(end);
      }).toList(),
    );
    final bestDay = FocusActivity.bestDay(daily);
    final total = FocusStatistics.total(sessions);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Profile',
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w800,
                color: _profileInk,
              ),
            ),
            OutlinedButton.icon(
              onPressed: _editProfile,
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Edit profile'),
            ),
          ],
        ),
        const SizedBox(height: 22),
          _Card(
          child: Wrap(
            spacing: 24,
            runSpacing: 18,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              CircleAvatar(
                radius: 42,
                backgroundColor: const Color(0xFFEDE9FE),
                child: Text(
                  _initials(_name),
                  style: const TextStyle(
                    color: _profileViolet,
                    fontSize: 23,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              SizedBox(
                width: 290,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _name,
                      style: const TextStyle(
                        fontSize: 25,
                        fontWeight: FontWeight.w800,
                        color: _profileInk,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(_bio, style: const TextStyle(color: _profileMuted)),
                  ],
                ),
              ),
              _MiniStat('🪙', '${widget.balance}', 'coins'),
              _MiniStat('⏱️', _duration(total), 'focused'),
              _MiniStat('🔥', '0', 'day streak (placeholder)'),
              _MiniStat('🏆', '0', 'longest streak (placeholder)'),
            ],
          ),
        ),
        _Card(child: Row(children: [const Icon(Icons.local_fire_department, color: _profileViolet), const SizedBox(width: 10), Text('${Stage7Calculations.currentStreak(sessions)} day streak · Longest ${Stage7Calculations.longestStreak(sessions)} days', style: const TextStyle(fontWeight: FontWeight.w700))])),
          _Card(child: Row(children: [const Icon(Icons.emoji_events, color: _profileViolet), const SizedBox(width: 10), Text('$_achievementCount / ${achievements.length} achievements', style: const TextStyle(fontWeight: FontWeight.w700))])),
        _Card(child: Row(children: [const Icon(Icons.auto_awesome, color: _profileViolet), const SizedBox(width: 10), Text('Dream Life Progress', style: const TextStyle(fontWeight: FontWeight.w700)), const Spacer(), Text('$_ownedItemCount / ${shopCatalog.length} items unlocked', style: const TextStyle(color: _profileMuted))])),
        const SizedBox(height: 26),
        const Text(
          'Productivity overview',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: _profileInk,
          ),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 14,
          runSpacing: 14,
          children: [
            _MetricCard('Total focus time', _duration(total)),
            _MetricCard('Today', _duration(FocusStatistics.today(sessions))),
            _MetricCard(
              'This week',
              _duration(FocusStatistics.thisWeek(sessions)),
            ),
            _MetricCard(
              'This month',
              _duration(FocusStatistics.thisMonth(sessions)),
            ),
            _MetricCard(
              'Active days',
              '${FocusStatistics.activeDays(sessions)}',
            ),
          ],
        ),
        const SizedBox(height: 26),
        _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Focus activity',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: _profileInk,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${_duration(FocusActivity.total(daily))} focused in the last 12 months',
                style: const TextStyle(color: _profileMuted),
              ),
              const SizedBox(height: 16),
              ActivityGraph(daily: daily, duration: _duration),
              const SizedBox(height: 14),
              Wrap(
                spacing: 28,
                runSpacing: 10,
                children: [
                  Text(
                    'Active days: ${daily.values.where((v) => v > Duration.zero).length}',
                    style: const TextStyle(color: _profileMuted),
                  ),
                  Text(
                    'Best focus day: ${bestDay == null ? 'No sessions yet' : '${bestDay.month}/${bestDay.day} · ${_duration(daily[bestDay]!)}'}',
                    style: const TextStyle(color: _profileMuted),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 26),
        _section(
          'Recent sessions',
          sessions.isEmpty
              ? const [
                  Text(
                    'Your productivity story starts here.',
                    style: TextStyle(color: _profileMuted),
                  ),
                ]
              : sessions
                    .take(5)
                    .map((s) => _SessionRow(session: s, duration: _duration))
                    .toList(),
          action: sessions.isEmpty ? null : widget.onViewAllSessions,
        ),
        const SizedBox(height: 26),
        _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Focus statistics',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: _profileInk,
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 34,
                runSpacing: 18,
                children: [
                  _Stat('Total sessions', '${sessions.length}'),
                  _Stat(
                    'Average session',
                    _duration(FocusStatistics.average(sessions)),
                  ),
                  _Stat(
                    'Longest session',
                    _duration(
                      FocusStatistics.longest(sessions) ?? Duration.zero,
                    ),
                  ),
                  _Stat(
                    'Shortest session',
                    _duration(
                      FocusStatistics.shortest(sessions) ?? Duration.zero,
                    ),
                  ),
                  _Stat('Total focused time', _duration(total)),
                  _Stat(
                    'Total coins earned',
                    '${FocusStatistics.totalCoins(sessions)}',
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _initials(String value) => value.trim().toLowerCase() == 'dreamer'
      ? 'DF'
      : value.trim().isEmpty
      ? 'DF'
      : value
            .trim()
            .split(RegExp(r'\s+'))
            .take(2)
            .map((p) => p[0])
            .join()
            .toUpperCase();
}

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(
      color: Theme.of(context).cardColor,
      borderRadius: BorderRadius.circular(20),
      boxShadow: const [
        BoxShadow(
          color: Color(0x08000000),
          blurRadius: 16,
          offset: Offset(0, 5),
        ),
      ],
    ),
    child: child,
  );
}

class _MiniStat extends StatelessWidget {
  final String icon, value, label;
  const _MiniStat(this.icon, this.value, this.label);
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        '$icon $value',
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w800,
          color: _profileInk,
        ),
      ),
      Text(label, style: const TextStyle(fontSize: 12, color: _profileMuted)),
    ],
  );
}

class _MetricCard extends StatelessWidget {
  final String title, value;
  const _MetricCard(this.title, this.value);
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 155,
    child: _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 12, color: _profileMuted),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: _profileInk,
            ),
          ),
        ],
      ),
    ),
  );
}

class _Stat extends StatelessWidget {
  final String title, value;
  const _Stat(this.title, this.value);
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 145,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(color: _profileMuted, fontSize: 12)),
        const SizedBox(height: 5),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            color: _profileInk,
          ),
        ),
      ],
    ),
  );
}

class _SessionRow extends StatelessWidget {
  final FocusSession session;
  final String Function(Duration) duration;
  const _SessionRow({required this.session, required this.duration});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      children: [
        const Icon(
          Icons.check_circle_outline_rounded,
          color: _profileViolet,
          size: 20,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            _label(session.date),
            style: const TextStyle(
              color: _profileMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Text(
          duration(Duration(seconds: session.focusedSeconds)),
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            color: _profileInk,
          ),
        ),
        const SizedBox(width: 18),
        Text(
          '+${session.coinsEarned} 🪙',
          style: const TextStyle(
            color: _profileViolet,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    ),
  );
}

String _label(DateTime date) {
  final now = DateTime.now();
  if (date.year == now.year && date.month == now.month && date.day == now.day)
    return 'Today';
  final yesterday = now.subtract(const Duration(days: 1));
  if (date.year == yesterday.year &&
      date.month == yesterday.month &&
      date.day == yesterday.day)
    return 'Yesterday';
  return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
}

Widget _section(String title, List<Widget> children, {VoidCallback? action}) =>
    _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: _profileInk,
                ),
              ),
              if (action != null)
                TextButton(
                  onPressed: action,
                  child: const Text('View all sessions'),
                ),
            ],
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
