import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math' as math;

import 'models/focus_session.dart';
import 'services/focus_statistics.dart';
import 'services/focus_storage.dart';
import 'progress_page.dart';
import 'profile_page.dart';
import 'auth_pages.dart';
import 'services/supabase_config.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const ink = Color(0xFF172A3A);
const muted = Color(0xFF718096);
const surface = Color(0xFFF7F9FC);
const lavender = Color(0xFFEDE9FE);
const violet = Color(0xFF7C5CFC);
const mint = Color(0xFFDDF7ED);

int coinsFor(Duration focusedTime) => focusedTime.inSeconds ~/ 60 * 3;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(url: supabaseUrl, publishableKey: supabasePublishableKey);
  runApp(const DreamFocusApp());
}

class DreamFocusApp extends StatefulWidget {
  const DreamFocusApp({super.key});

  @override
  State<DreamFocusApp> createState() => _DreamFocusAppState();
}

class _DreamFocusAppState extends State<DreamFocusApp> {
  ThemeMode _themeMode = ThemeMode.light;
  StreamSubscription<AuthState>? _authSubscription;

  @override
  void initState() {
    super.initState();
    try { _authSubscription = supabase.auth.onAuthStateChange.listen((_) => setState(() {})); } catch (_) {}
  }

  @override
  void dispose() { _authSubscription?.cancel(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DreamFocus',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: surface,
        colorScheme: ColorScheme.fromSeed(seedColor: violet),
        fontFamily: 'Arial',
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: violet,
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF11131A),
        cardColor: const Color(0xFF1B1E28),
        fontFamily: 'Arial',
      ),
      themeMode: _themeMode,
      home: DashboardPage(
        user: currentSupabaseUser,
        onLogout: () => supabase.auth.signOut(),
        isDark: _themeMode == ThemeMode.dark,
        onThemeChanged: (value) => setState(() {
          _themeMode = value ? ThemeMode.dark : ThemeMode.light;
        }),
      ),
    );
  }
}

class DashboardPage extends StatefulWidget {
  final User? user;
  final Future<void> Function() onLogout;
  final bool isDark;
  final ValueChanged<bool> onThemeChanged;
  const DashboardPage({
    super.key,
    required this.isDark,
    required this.onThemeChanged,
    required this.user,
    required this.onLogout,
  });

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final _storage = FocusStorage();
  List<FocusSession> _sessions = [];
  int _balance = 0;
  bool _showProgress = false;
  bool _showProfile = false;
  String? _pendingDestination;

  @override
  void didUpdateWidget(covariant DashboardPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.user == null && widget.user != null && _pendingDestination != null) {
      final destination = _pendingDestination!;
      _pendingDestination = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (destination == 'Focus') {
          Navigator.of(context).push(MaterialPageRoute(builder: (_) => FocusPage(onCompleted: _loadData)));
        } else {
          setState(() { _showProfile = destination == 'Profile'; _showProgress = destination == 'Progress'; });
        }
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final sessions = await _storage.loadSessions();
    final balance = await _storage.loadBalance();
    if (mounted) {
      setState(() {
        _sessions = sessions;
        _balance = balance;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Row(
          children: [
            _Sidebar(
              isDark: widget.isDark,
              onThemeChanged: widget.onThemeChanged,
              progressSelected: _showProgress,
              profileSelected: _showProfile,
              onDashboard: () => setState(() {
                _showProgress = false;
                _showProfile = false;
              }),
              onProgress: () {
                if (widget.user == null) { _showAuthPrompt('Progress'); return; }
                setState(() {
                _showProgress = true;
                _showProfile = false;
                });
              },
              onProfile: () {
                if (widget.user == null) { _showAuthPrompt('Profile'); return; }
                setState(() {
                _showProgress = false;
                _showProfile = true;
                });
              },
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: constraints.maxWidth > 900 ? 48 : 24,
                    vertical: 32,
                  ),
                  child: _showProfile
                      ? ProfilePage(
                          sessions: _sessions,
                          balance: _balance,
                          onViewAllSessions: () => setState(() {
                            _showProfile = false;
                            _showProgress = false;
                          }),
                        )
                      : _showProgress
                      ? ProgressPage(sessions: _sessions)
                      : _MainContent(
                          sessions: _sessions,
                          balance: _balance,
                          onFocusComplete: _loadData,
                          isDark: widget.isDark,
                          user: widget.user,
                          onLogin: _openLogin,
                          onSignup: _openSignup,
                          onLogout: widget.onLogout,
                          onProfile: () => setState(() { _showProfile = true; _showProgress = false; }),
                          onSettings: _showSettings,
                          onAuthRequired: () => _showAuthPrompt('Focus'),
                          onThemeChanged: widget.onThemeChanged,
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAuthPrompt(String destination) {
    _pendingDestination = destination;
    showDialog<void>(context: context, builder: (context) => AlertDialog(
      title: Text('Sign in to open $destination'),
      content: const Text('Create an account to save your sessions, earn coins, and build your dream life.'),
      actions: [
        TextButton(onPressed: () { Navigator.pop(context); }, child: const Text('Continue Browsing')),
        TextButton(onPressed: () { Navigator.pop(context); _openSignup(); }, child: const Text('Sign Up')),
        FilledButton(onPressed: () { Navigator.pop(context); _openLogin(); }, child: const Text('Log In')),
      ],
    ));
  }

  void _openLogin() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => LoginPage(onCreateAccount: () {
        Navigator.of(context).pop();
        _openSignup();
      }),
    ));
  }

  void _openSignup() {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SignUpPage()));
  }

  void _showSettings() {
    showDialog<void>(context: context, builder: (_) => const AlertDialog(
      title: Text('Settings'),
      content: Text('Personal settings will be available here.'),
    ));
  }
}

class _Sidebar extends StatelessWidget {
  final bool isDark;
  final ValueChanged<bool> onThemeChanged;
  final bool progressSelected;
  final bool profileSelected;
  final VoidCallback onDashboard;
  final VoidCallback onProgress;
  final VoidCallback onProfile;
  const _Sidebar({
    required this.isDark,
    required this.onThemeChanged,
    required this.progressSelected,
    required this.profileSelected,
    required this.onDashboard,
    required this.onProgress,
    required this.onProfile,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      color: Theme.of(context).cardColor,
      padding: const EdgeInsets.fromLTRB(16, 30, 12, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: violet,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.bolt_rounded, color: Colors.white),
              ),
              const SizedBox(width: 10),
              const Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'DreamFocus',
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      color: ink,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Icon(
                isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                color: muted,
                size: 19,
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text('Dark mode', style: TextStyle(color: muted)),
              ),
              Switch(
                value: isDark,
                onChanged: onThemeChanged,
                activeThumbColor: violet,
              ),
            ],
          ),
          const SizedBox(height: 28),
          _NavItem(
            Icons.grid_view_rounded,
            'Dashboard',
            selected: !progressSelected && !profileSelected,
            onTap: onDashboard,
          ),
          _NavItem(
            Icons.bar_chart_rounded,
            'Progress',
            selected: progressSelected,
            onTap: onProgress,
          ),
          const _NavItem(Icons.auto_awesome_rounded, 'Dream Life'),
          const _NavItem(Icons.emoji_events_outlined, 'Achievements'),
          const Spacer(),
          const _NavItem(Icons.settings_outlined, 'Settings'),
          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 18),
          InkWell(
            onTap: onProfile,
            borderRadius: BorderRadius.circular(12),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 19,
                  backgroundColor: lavender,
                  child: const Text(
                    'DF',
                    style: TextStyle(
                      color: violet,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Your profile',
                    style: TextStyle(fontWeight: FontWeight.w700, color: ink),
                  ),
                ),
                const Icon(Icons.more_horiz, color: muted),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback? onTap;
  const _NavItem(this.icon, this.label, {this.selected = false, this.onTap});

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    decoration: BoxDecoration(
      color: selected ? lavender : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Material(
      color: Colors.transparent,
      child: ListTile(
        dense: true,
        leading: Icon(icon, color: selected ? violet : muted, size: 21),
        title: Text(label, style: TextStyle(color: selected ? violet : muted, fontWeight: selected ? FontWeight.w700 : FontWeight.w500)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        onTap: onTap ?? () {},
      ),
    ),
  );
}

class _MainContent extends StatelessWidget {
  final List<FocusSession> sessions;
  final int balance;
  final Future<void> Function() onFocusComplete;
  final bool isDark;
  final ValueChanged<bool> onThemeChanged;
  final User? user;
  final VoidCallback onLogin;
  final VoidCallback onSignup;
  final Future<void> Function() onLogout;
  final VoidCallback onProfile;
  final VoidCallback onSettings;
  final VoidCallback onAuthRequired;

  const _MainContent({
    required this.sessions,
    required this.balance,
    required this.onFocusComplete,
    required this.isDark,
    required this.onThemeChanged,
    required this.user,
    required this.onLogin,
    required this.onSignup,
    required this.onLogout,
    required this.onProfile,
    required this.onSettings,
    required this.onAuthRequired,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          runSpacing: 16,
          children: [
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Good morning, dreamer.',
                  style: TextStyle(color: muted, fontSize: 15),
                ),
                SizedBox(height: 6),
                Text(
                  'Ready to make progress?',
                  style: TextStyle(
                    color: ink,
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
                  child: const Row(children: [Icon(Icons.notifications_none_rounded, color: muted), SizedBox(width: 8), Icon(Icons.nightlight_outlined, color: muted)]),
                ),
                const SizedBox(width: 10),
                if (user == null) ...[
                  OutlinedButton(onPressed: onLogin, child: const Text('Log In')),
                  const SizedBox(width: 8),
                  FilledButton(onPressed: onSignup, child: const Text('Sign Up')),
                ] else PopupMenuButton<String>(
                  onSelected: (value) { if (value == 'logout') onLogout(); if (value == 'profile') onProfile(); if (value == 'settings') onSettings(); },
                  itemBuilder: (_) => const [PopupMenuItem(value: 'profile', child: Text('Profile')), PopupMenuItem(value: 'settings', child: Text('Settings')), PopupMenuItem(value: 'logout', child: Text('Log Out'))],
                  child: Row(children: [CircleAvatar(radius: 16, backgroundColor: violet, child: Text(((user!.userMetadata?['display_name'] as String? ?? 'D').isEmpty ? 'D' : (user!.userMetadata?['display_name'] as String? ?? 'D')[0]).toUpperCase(), style: const TextStyle(color: Colors.white))), const SizedBox(width: 8), Text(user!.userMetadata?['display_name'] as String? ?? 'Dreamer', style: const TextStyle(fontWeight: FontWeight.w700))]),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 30),
        _CoinCard(balance: balance, authenticated: user != null),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF7257F5), Color(0xFF9B7BFF)],
            ),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Focus time is your\nsuperpower.',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        height: 1.15,
                      ),
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Turn focused moments into the life you imagine.',
                      style: TextStyle(color: Color(0xFFE8E2FF), fontSize: 14),
                    ),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 18),
                child: Icon(
                  Icons.track_changes_rounded,
                  color: Color(0xFFDCD4FF),
                  size: 64,
                ),
              ),
              ElevatedButton.icon(
                onPressed: user == null ? onAuthRequired : () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                          builder: (_) => FocusPage(onCompleted: onFocusComplete),
                    ),
                  );
                  await onFocusComplete();
                },
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('Start Focusing'),
                style: ElevatedButton.styleFrom(
                  foregroundColor: violet,
                  backgroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 22,
                    vertical: 17,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  textStyle: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),
        const Text(
          'Your overview',
          style: TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w800,
            color: ink,
          ),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            _StatCard(
              Icons.schedule_rounded,
              'Today',
              '${FocusStatistics.today(sessions).inMinutes} min',
              'Focused today',
              Color(0xFFE2F0FF),
            ),
            _StatCard(
              Icons.local_fire_department_rounded,
              'Streak',
              '0 days',
              'Keep it going',
              Color(0xFFFFE8D8),
            ),
            _StatCard(
              Icons.stars_rounded,
              'This week',
              '${FocusStatistics.thisWeek(sessions).inMinutes} min',
              'Weekly focus',
              mint,
            ),
          ],
        ),
        const SizedBox(height: 28),
        Container(
          width: double.infinity,
          height: 340,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Build your dream life',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: ink,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Your dream world will grow with every focused session.',
                      style: TextStyle(color: muted),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Your dream world is waiting',
                      style: TextStyle(fontWeight: FontWeight.w700, color: ink),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Focus, earn coins, and unlock the life you\'ve always dreamed of.',
                      style: TextStyle(color: muted, fontSize: 12),
                    ),
                    const Spacer(),
                    OutlinedButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                      label: const Text('Explore Dream Life'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: violet,
                        side: const BorderSide(color: Color(0xFFDCD5FF)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(11),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 30),
              Container(
                width: 140,
                decoration: BoxDecoration(
                  color: const Color(0xFFF2F0FF),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: violet,
                      child: Icon(
                        Icons.home_rounded,
                        color: Colors.white,
                        size: 34,
                      ),
                    ),
                    SizedBox(height: 12),
                    Icon(
                      Icons.park_rounded,
                      color: Color(0xFFAC9AFF),
                      size: 35,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),
        _HistoryCard(sessions: sessions),
      ],
    );
  }
}

class _CoinCard extends StatelessWidget {
  final int balance;
  final bool authenticated;
  const _CoinCard({required this.balance, required this.authenticated});

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: const [
        BoxShadow(
          color: Color(0x08000000),
          blurRadius: 18,
          offset: Offset(0, 5),
        ),
      ],
    ),
    child: Row(
      children: [
        Icon(Icons.monetization_on_rounded, color: Color(0xFFF3B93F), size: 27),
        SizedBox(width: 10),
        Text(
          authenticated ? '$balance coins' : 'Sign in to track your coins',
          style: TextStyle(
            color: ink,
            fontWeight: FontWeight.w800,
            fontSize: 16,
          ),
        ),
      ],
    ),
  );
}

class FocusPage extends StatefulWidget {
  final Future<void> Function()? onCompleted;
  const FocusPage({super.key, this.onCompleted});

  @override
  State<FocusPage> createState() => _FocusPageState();
}

class _HistoryCard extends StatelessWidget {
  final List<FocusSession> sessions;
  const _HistoryCard({required this.sessions});

  String _dayLabel(DateTime date) {
    final now = DateTime.now();
    if (date.year == now.year &&
        date.month == now.month &&
        date.day == now.day) {
      return 'Today';
    }
    final yesterday = now.subtract(const Duration(days: 1));
    if (date.year == yesterday.year &&
        date.month == yesterday.month &&
        date.day == yesterday.day) {
      return 'Yesterday';
    }
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Session history',
          style: TextStyle(
            color: ink,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 16),
        if (sessions.isEmpty)
          const Text(
            'Completed sessions will appear here.',
            style: TextStyle(color: muted),
          )
        else
          ...sessions
              .take(8)
              .map(
                (session) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.check_circle_outline_rounded,
                        color: violet,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _dayLabel(session.date),
                          style: const TextStyle(
                            color: muted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Text(
                        formatDuration(
                          Duration(seconds: session.focusedSeconds),
                        ),
                        style: const TextStyle(
                          color: ink,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 18),
                      Text(
                        '+${session.coinsEarned} 🪙',
                        style: const TextStyle(
                          color: violet,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      ],
    ),
  );
}

class _FocusPageState extends State<FocusPage> {
  final _storage = FocusStorage();
  Timer? _ticker;
  late final DateTime _startTime;
  DateTime? _resumedAt;
  Duration _focusedTime = Duration.zero;
  bool _paused = false;
  bool _complete = false;
  int _balanceAfter = 0;

  @override
  void initState() {
    super.initState();
    _startTime = DateTime.now();
    _resumedAt = DateTime.now();
    _ticker = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (mounted && !_paused && !_complete) setState(() {});
    });
  }

  Duration get _liveFocusedTime {
    if (_paused || _complete || _resumedAt == null) return _focusedTime;
    return _focusedTime + DateTime.now().difference(_resumedAt!);
  }

  void _pause() {
    if (_paused || _complete || _resumedAt == null) return;
    setState(() {
      _focusedTime = _liveFocusedTime;
      _resumedAt = null;
      _paused = true;
    });
  }

  void _resume() {
    if (!_paused || _complete) return;
    setState(() {
      _resumedAt = DateTime.now();
      _paused = false;
    });
  }

  Future<void> _stop() async {
    if (_complete) return;
    final endTime = DateTime.now();
    final finalDuration = _liveFocusedTime;
    final earned = coinsFor(finalDuration);
    final previousBalance = await _storage.loadBalance();
    final session = FocusSession(
      id: '${_startTime.microsecondsSinceEpoch}',
      date: _startTime,
      startTime: _startTime,
      endTime: endTime,
      focusedSeconds: finalDuration.inSeconds,
      coinsEarned: earned,
      completed: finalDuration.inSeconds > 0,
    );
    if (finalDuration.inSeconds > 0) {
      await _storage.saveSession(session, previousBalance + earned);
      await widget.onCompleted?.call();
    }
    setState(() {
      _focusedTime = finalDuration;
      _resumedAt = null;
      _complete = true;
      _balanceAfter = previousBalance + earned;
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final focusedTime = _liveFocusedTime;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: _complete
                  ? _CompletionView(
                      focusedTime: focusedTime,
                      totalBalance: _balanceAfter,
                      onDashboard: () => Navigator.of(context).pop(),
                      onAnother: () => Navigator.of(context).pushReplacement(
                        MaterialPageRoute(builder: (_) => const FocusPage()),
                      ),
                    )
                  : _ActiveFocusView(
                      focusedTime: focusedTime,
                      paused: _paused,
                      onPause: _pause,
                      onResume: _resume,
                      onStop: _stop,
                      onBack: () => Navigator.of(context).pop(),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ActiveFocusView extends StatelessWidget {
  final Duration focusedTime;
  final bool paused;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onStop;
  final VoidCallback onBack;

  const _ActiveFocusView({
    required this.focusedTime,
    required this.paused,
    required this.onPause,
    required this.onResume,
    required this.onStop,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Align(
        alignment: Alignment.centerLeft,
        child: IconButton(
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back_rounded, color: muted),
        ),
      ),
      const SizedBox(height: 20),
      const Text(
        'FOCUS SESSION',
        style: TextStyle(
          color: violet,
          fontWeight: FontWeight.w800,
          letterSpacing: 2,
        ),
      ),
      const SizedBox(height: 28),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 58, horizontal: 24),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF7257F5), Color(0xFF9B7BFF)],
          ),
          borderRadius: BorderRadius.circular(30),
          boxShadow: const [
            BoxShadow(
              color: Color(0x247C5CFC),
              blurRadius: 30,
              offset: Offset(0, 14),
            ),
          ],
        ),
        child: Column(
          children: [
            _FlipClock(duration: focusedTime),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  paused ? Icons.pause_circle_filled : Icons.circle,
                  color: const Color(0xFFE8E2FF),
                  size: 13,
                ),
                const SizedBox(width: 8),
                Text(
                  paused ? 'Paused' : 'Focusing',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      const SizedBox(height: 22),
      Text(
        '+${coinsFor(focusedTime)} coins',
        style: const TextStyle(
          color: ink,
          fontSize: 20,
          fontWeight: FontWeight.w800,
        ),
      ),
      const SizedBox(height: 28),
      Wrap(
        spacing: 14,
        runSpacing: 14,
        alignment: WrapAlignment.center,
        children: [
          ElevatedButton.icon(
            onPressed: paused ? onResume : onPause,
            icon: Icon(paused ? Icons.play_arrow_rounded : Icons.pause_rounded),
            label: Text(paused ? 'Resume' : 'Pause'),
            style: ElevatedButton.styleFrom(
              backgroundColor: violet,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
          OutlinedButton(
            onPressed: onStop,
            style: OutlinedButton.styleFrom(
              foregroundColor: ink,
              padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: const Text('Stop Session'),
          ),
        ],
      ),
    ],
  );
}

class _FlipClock extends StatelessWidget {
  final Duration duration;
  const _FlipClock({required this.duration});

  @override
  Widget build(BuildContext context) {
    final values = [
      duration.inHours.toString().padLeft(2, '0'),
      (duration.inMinutes % 60).toString().padLeft(2, '0'),
      (duration.inSeconds % 60).toString().padLeft(2, '0'),
    ];
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < values.length; i++) ...[
          _FlipUnit(
            value: values[i],
            label: ['HOURS', 'MINUTES', 'SECONDS'][i],
          ),
          if (i < 2)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              child: Text(
                ':',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 44,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
        ],
      ],
    );
  }
}

class _FlipUnit extends StatelessWidget {
  final String value;
  final String label;
  const _FlipUnit({required this.value, required this.label});

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < 2; i++) ...[
            _FlipDigit(value: value[i]),
            if (i == 0) const SizedBox(width: 5),
          ],
        ],
      ),
      const SizedBox(height: 7),
      Text(
        label,
        style: const TextStyle(
          color: Color(0xFFE8E2FF),
          fontSize: 9,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      ),
    ],
  );
}

class _FlipDigit extends StatefulWidget {
  final String value;
  const _FlipDigit({required this.value});

  @override
  State<_FlipDigit> createState() => _FlipDigitState();
}

class _FlipDigitState extends State<_FlipDigit>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late String _oldValue;

  @override
  void initState() {
    super.initState();
    _oldValue = widget.value;
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
  }

  @override
  void didUpdateWidget(covariant _FlipDigit oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _oldValue = oldWidget.value;
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _face(String value, {required bool top}) => Container(
    width: 62,
    height: 72,
    alignment: top ? Alignment.topCenter : Alignment.bottomCenter,
    clipBehavior: Clip.hardEdge,
    decoration: BoxDecoration(
      color: top ? const Color(0xFF6550D6) : const Color(0xFF5540C8),
      borderRadius: top
          ? const BorderRadius.vertical(top: Radius.circular(10))
          : const BorderRadius.vertical(bottom: Radius.circular(10)),
    ),
    child: SizedBox(
      height: 72,
      child: Center(
        child: Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 54,
            height: 1,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    builder: (context, child) {
      final progress = _controller.value;
      final oldTop = _face(_oldValue, top: true);
      final newFace = Stack(
        children: [
          _face(widget.value, top: true),
          _face(widget.value, top: false),
          Positioned(
            top: 35,
            left: 0,
            right: 0,
            child: Container(height: 2, color: const Color(0x55000000)),
          ),
        ],
      );
      return Container(
        width: 62,
        height: 72,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          boxShadow: const [
            BoxShadow(
              color: Color(0x55000000),
              blurRadius: 8,
              offset: Offset(0, 5),
            ),
          ],
        ),
        child: Stack(
          children: [
            newFace,
            if (progress < 1)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Transform(
                  alignment: Alignment.bottomCenter,
                  transform: Matrix4.identity()
                    ..setEntry(3, 2, 0.0015)
                    ..rotateX(
                      -math.pi / 2 * Curves.easeInOut.transform(progress),
                    ),
                  child: oldTop,
                ),
              ),
          ],
        ),
      );
    },
  );
}

class _CompletionView extends StatelessWidget {
  final Duration focusedTime;
  final int totalBalance;
  final VoidCallback onDashboard;
  final VoidCallback onAnother;

  const _CompletionView({
    required this.focusedTime,
    required this.totalBalance,
    required this.onDashboard,
    required this.onAnother,
  });

  @override
  Widget build(BuildContext context) => Column(
    children: [
      const Icon(Icons.celebration_rounded, color: violet, size: 52),
      const SizedBox(height: 18),
      const Text(
        'SESSION COMPLETE 🎉',
        style: TextStyle(color: ink, fontSize: 24, fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 10),
      const Text(
        'You made time for the life you want.',
        style: TextStyle(color: muted),
      ),
      const SizedBox(height: 32),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Column(
          children: [
            const Text('Focused time', style: TextStyle(color: muted)),
            const SizedBox(height: 8),
            Text(
              formatDuration(focusedTime),
              style: const TextStyle(
                color: ink,
                fontSize: 42,
                fontWeight: FontWeight.w800,
              ),
            ),
            const Divider(height: 34),
            const Text('Coins earned', style: TextStyle(color: muted)),
            const SizedBox(height: 8),
            Text(
              '${coinsFor(focusedTime)} 🪙',
              style: const TextStyle(
                color: ink,
                fontSize: 28,
                fontWeight: FontWeight.w800,
              ),
            ),
            const Divider(height: 34),
            const Text('Total balance', style: TextStyle(color: muted)),
            const SizedBox(height: 8),
            Text(
              '$totalBalance 🪙',
              style: const TextStyle(
                color: ink,
                fontSize: 24,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 28),
      Wrap(
        spacing: 14,
        runSpacing: 14,
        alignment: WrapAlignment.center,
        children: [
          OutlinedButton(
            onPressed: onDashboard,
            style: OutlinedButton.styleFrom(
              foregroundColor: ink,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: const Text('Back to Dashboard'),
          ),
          ElevatedButton(
            onPressed: onAnother,
            style: ElevatedButton.styleFrom(
              backgroundColor: violet,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: const Text('Start Another Session'),
          ),
        ],
      ),
    ],
  );
}

String formatDuration(Duration duration) {
  final hours = duration.inHours.toString().padLeft(2, '0');
  final minutes = (duration.inMinutes % 60).toString().padLeft(2, '0');
  final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
  return '$hours:$minutes:$seconds';
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final String subtitle;
  final Color iconBg;
  const _StatCard(
    this.icon,
    this.title,
    this.value,
    this.subtitle,
    this.iconBg,
  );
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 190,
    child: Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: ink, size: 19),
          ),
          const SizedBox(height: 15),
          Text(title, style: const TextStyle(color: muted, fontSize: 13)),
          const SizedBox(height: 3),
          Text(
            value,
            style: const TextStyle(
              color: ink,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(subtitle, style: const TextStyle(color: muted, fontSize: 12)),
        ],
      ),
    ),
  );
}
