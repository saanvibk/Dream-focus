import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'services/supabase_config.dart';

class LoginPage extends StatefulWidget {
  final VoidCallback? onCreateAccount;
  const LoginPage({super.key, this.onCreateAccount});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() { _email.dispose(); _password.dispose(); super.dispose(); }

  Future<void> _login() async {
    setState(() { _busy = true; _error = null; });
    try {
      final response = await supabase.auth.signInWithPassword(
        email: _email.text.trim(), password: _password.text,
      );
      if (response.session == null && mounted) {
        setState(() => _error = 'Please confirm your email before signing in.');
      } else if (mounted) { Navigator.of(context).pop(); }
    } on AuthException catch (e) {
      if (mounted) setState(() => _error = _friendly(e.message));
    } catch (_) { if (mounted) setState(() => _error = 'Network error. Please try again.'); }
    if (mounted) setState(() => _busy = false);
  }

  String _friendly(String message) {
    final lower = message.toLowerCase();
    if (lower.contains('invalid login')) return 'The email or password is incorrect.';
    if (lower.contains('email')) return 'Enter a valid email address.';
    return 'We could not sign you in. Please try again.';
  }

  @override
  Widget build(BuildContext context) => _AuthScaffold(
    title: 'Welcome back, dreamer.', subtitle: 'Sign in to continue your journey.',
    fields: [
      TextField(controller: _email, keyboardType: TextInputType.emailAddress,
        decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.email_outlined))),
      TextField(controller: _password, obscureText: true,
        decoration: const InputDecoration(labelText: 'Password', prefixIcon: Icon(Icons.lock_outline))),
    ], error: _error, busy: _busy, button: 'Log In', onSubmit: _login,
    footer: TextButton(onPressed: widget.onCreateAccount, child: const Text('Create an account')),
  );
}

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});
  @override State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final _name = TextEditingController(); final _email = TextEditingController(); final _password = TextEditingController();
  bool _busy = false; String? _error;
  @override void dispose() { _name.dispose(); _email.dispose(); _password.dispose(); super.dispose(); }
  Future<void> _signup() async {
    setState(() { _busy = true; _error = null; });
    try {
      final response = await supabase.auth.signUp(email: _email.text.trim(), password: _password.text,
        data: {'display_name': _name.text.trim()});
      if (!mounted) return;
      if (response.session == null) {
        await showDialog<void>(context: context, builder: (_) => AlertDialog(
          title: const Text('Check your email'), content: const Text('Confirm your email address, then log in to DreamFocus.'),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],));
        if (mounted) Navigator.pop(context);
      } else { Navigator.pop(context); }
    } on AuthException catch (e) { if (mounted) setState(() => _error = e.message.toLowerCase().contains('email') ? 'Enter a valid email address.' : 'We could not create that account. Please try again.'); }
    catch (_) { if (mounted) setState(() => _error = 'Network error. Please try again.'); }
    if (mounted) setState(() => _busy = false);
  }
  @override Widget build(BuildContext context) => _AuthScaffold(
    title: 'Create your account.', subtitle: 'Save sessions and build your dream life.',
    fields: [TextField(controller: _name, decoration: const InputDecoration(labelText: 'Display Name', prefixIcon: Icon(Icons.person_outline))),
      TextField(controller: _email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.email_outlined))),
      TextField(controller: _password, obscureText: true, decoration: const InputDecoration(labelText: 'Password', prefixIcon: Icon(Icons.lock_outline)))],
    error: _error, busy: _busy, button: 'Create Account', onSubmit: _signup,
    footer: TextButton(onPressed: () => Navigator.pop(context), child: const Text('Already have an account? Log In')),
  );
}

class _AuthScaffold extends StatelessWidget {
  final String title, subtitle, button; final List<Widget> fields; final String? error; final bool busy; final VoidCallback onSubmit; final Widget footer;
  const _AuthScaffold({required this.title, required this.subtitle, required this.fields, required this.error, required this.busy, required this.button, required this.onSubmit, required this.footer});
  @override
  Widget build(BuildContext context) => Scaffold(
    resizeToAvoidBottomInset: true,
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.bolt_rounded, color: Color(0xFF7C5CFC), size: 52),
              const SizedBox(height: 18),
              Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF718096))),
              const SizedBox(height: 28),
              ...fields.map((f) => Padding(padding: const EdgeInsets.only(bottom: 14), child: f)),
              if (error != null) Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(error!, style: const TextStyle(color: Colors.red))),
              FilledButton(onPressed: busy ? null : onSubmit, child: Text(busy ? 'Please wait…' : button)),
              footer,
            ],
          ),
        ),
        ),
      ),
    ),
  );
}
