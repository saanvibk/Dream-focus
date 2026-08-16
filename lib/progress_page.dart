import 'package:flutter/material.dart';

import 'models/focus_session.dart';
import 'services/focus_activity.dart';

const _purple = Color(0xFF7C5CFC);
const _muted = Color(0xFF718096);

class ProgressPage extends StatelessWidget {
  final List<FocusSession> sessions;
  const ProgressPage({super.key, required this.sessions});

  String _duration(Duration value) {
    if (value.inHours > 0) {
      return '${value.inHours}h ${(value.inMinutes % 60)}m';
    }
    return '${value.inMinutes}m';
  }

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final end = DateTime(today.year, today.month, today.day);
    final start = end.subtract(const Duration(days: 364));
    final daily = FocusActivity.daily(
      sessions.where((session) {
        final date = FocusActivity.day(session.date.toLocal());
        return !date.isBefore(start) && !date.isAfter(end);
      }).toList(),
    );
    final total = FocusActivity.total(daily);
    final best = FocusActivity.bestDay(daily);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(48, 32, 48, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Progress',
            style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          const Text(
            'See how your focused time builds over time.',
            style: TextStyle(color: _muted),
          ),
          const SizedBox(height: 26),
          _Summary(
            total: total,
            activeDays: daily.values.where((v) => v.inSeconds > 0).length,
            best: best,
            daily: daily,
            duration: _duration,
          ),
          const SizedBox(height: 18),
          _ActivityCard(daily: daily, duration: _duration),
          const SizedBox(height: 18),
          _RecentWeek(daily: daily, duration: _duration),
        ],
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  final Duration total;
  final int activeDays;
  final DateTime? best;
  final Map<DateTime, Duration> daily;
  final String Function(Duration) duration;
  const _Summary({
    required this.total,
    required this.activeDays,
    required this.best,
    required this.daily,
    required this.duration,
  });
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(
      color: Theme.of(context).cardColor,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Wrap(
      spacing: 42,
      runSpacing: 18,
      children: [
        _Metric(
          'Focus activity',
          '${duration(total)} focused in the last 12 months',
        ),
        _Metric('Active days', '$activeDays days'),
        _Metric(
          'Best day',
          best == null
              ? 'No sessions yet'
              : '${_date(best!)} · ${duration(daily[best!]!)}',
        ),
      ],
    ),
  );
  static String _date(DateTime value) =>
      '${_months[value.month - 1]} ${value.day}';
}

class _Metric extends StatelessWidget {
  final String title, value;
  const _Metric(this.title, this.value);
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title, style: const TextStyle(color: _muted, fontSize: 12)),
      const SizedBox(height: 6),
      Text(
        value,
        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
      ),
    ],
  );
}

class _ActivityCard extends StatelessWidget {
  final Map<DateTime, Duration> daily;
  final String Function(Duration) duration;
  const _ActivityCard({required this.daily, required this.duration});
  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final end = DateTime(today.year, today.month, today.day);
    final start = end.subtract(const Duration(days: 364));
    final first = start.subtract(Duration(days: (start.weekday - 1)));
    final weeks = ((end.difference(first).inDays + 1) / 7).ceil();
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Focus activity',
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(width: 28),
                Column(
                  children: [
                    for (final label in ['Mon', '', 'Wed', '', 'Fri', '', ''])
                      SizedBox(
                        height: 16,
                        child: Text(
                          label,
                          style: const TextStyle(fontSize: 10, color: _muted),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var week = 0; week < weeks; week++)
                      Column(
                        children: [
                          for (var weekday = 0; weekday < 7; weekday++)
                            _ActivityCell(
                              date: first.add(
                                Duration(days: week * 7 + weekday),
                              ),
                              daily: daily,
                              duration: duration,
                            ),
                        ],
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          const Row(
            children: [
              Text('Less', style: TextStyle(color: _muted, fontSize: 11)),
              SizedBox(width: 6),
              _Legend(level: 0),
              _Legend(level: 1),
              _Legend(level: 2),
              _Legend(level: 3),
              _Legend(level: 4),
              SizedBox(width: 6),
              Text('More', style: TextStyle(color: _muted, fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActivityCell extends StatelessWidget {
  final DateTime date;
  final Map<DateTime, Duration> daily;
  final String Function(Duration) duration;
  const _ActivityCell({
    required this.date,
    required this.daily,
    required this.duration,
  });
  @override
  Widget build(BuildContext context) {
    final value =
        daily[DateTime(date.year, date.month, date.day)] ?? Duration.zero;
    final level = FocusActivity.level(value);
    final label = value == Duration.zero
        ? 'No focus time'
        : '${duration(value)} focused';
    return Tooltip(
      message: '${_months[date.month - 1]} ${date.day}, ${date.year}\n$label',
      child: Container(
        width: 13,
        height: 13,
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: _levelColor(level),
          borderRadius: BorderRadius.circular(3),
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  final int level;
  const _Legend({required this.level});
  @override
  Widget build(BuildContext context) => Container(
    width: 13,
    height: 13,
    margin: const EdgeInsets.only(left: 3),
    decoration: BoxDecoration(
      color: _levelColor(level),
      borderRadius: BorderRadius.circular(3),
    ),
  );
}

Color _levelColor(int level) => [
  const Color(0xFFF0EDFF),
  const Color(0xFFDCD4FF),
  const Color(0xFFB9A9FF),
  const Color(0xFF947BFF),
  _purple,
][level];

class _RecentWeek extends StatelessWidget {
  final Map<DateTime, Duration> daily;
  final String Function(Duration) duration;
  const _RecentWeek({required this.daily, required this.duration});
  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final monday = DateTime(
      today.year,
      today.month,
      today.day,
    ).subtract(Duration(days: today.weekday - 1));
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'This week',
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 20,
            runSpacing: 14,
            children: [
              for (var i = 0; i < 7; i++)
                _DayStat(
                  date: monday.add(Duration(days: i)),
                  daily: daily,
                  duration: duration,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DayStat extends StatelessWidget {
  final DateTime date;
  final Map<DateTime, Duration> daily;
  final String Function(Duration) duration;
  const _DayStat({
    required this.date,
    required this.daily,
    required this.duration,
  });
  @override
  Widget build(BuildContext context) {
    final value = daily[date] ?? Duration.zero;
    return Column(
      children: [
        Text(
          _weekdays[date.weekday - 1],
          style: const TextStyle(color: _muted, fontSize: 12),
        ),
        const SizedBox(height: 5),
        Text(
          duration(value),
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ],
    );
  }
}

const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];
const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
