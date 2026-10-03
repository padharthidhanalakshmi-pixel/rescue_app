import 'package:flutter/material.dart';

import '../models.dart';
import '../store.dart';
import '../widgets.dart';
import 'shared_tabs.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _pw = TextEditingController();
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _pw.dispose();
    super.dispose();
  }

  void _login() {
    FocusScope.of(context).unfocus();
    final err = store.login(_email.text, _pw.text);
    if (err != null) setState(() => _error = err);
  }

  void _demo(String email, String pw) {
    _email.text = email;
    _pw.text = pw;
    _login();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      body: SingleChildScrollView(
        child: Column(children: [
          GradientHeader(
            colors: const [brandTeal, brandTealLight],
            child: Padding(
              padding: const EdgeInsets.only(top: 24, bottom: 40),
              child: Column(children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(color: Colors.white.withAlpha(40), shape: BoxShape.circle),
                  child: const Icon(Icons.location_city_rounded, size: 52, color: Colors.white),
                ),
                const SizedBox(height: 14),
                const Text('CityPulse',
                    style: TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
                const SizedBox(height: 4),
                Text('Spot it. Report it. See it fixed.',
                    style: TextStyle(color: Colors.white.withAlpha(225), fontSize: 15)),
              ]),
            ),
          ),
          Transform.translate(
            offset: const Offset(0, -34),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Card(
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    const Text('Sign in', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Text('Citizens, officers and administrators use the same login.',
                        style: TextStyle(color: cs.onSurfaceVariant)),
                    const SizedBox(height: 18),
                    TextField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      decoration: fieldDeco(context, 'Email', Icons.alternate_email_rounded),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _pw,
                      obscureText: _obscure,
                      onSubmitted: (_) => _login(),
                      decoration: fieldDeco(
                        context,
                        'Password',
                        Icons.lock_outline_rounded,
                        suffix: IconButton(
                          icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                          onPressed: () => setState(() => _obscure = !_obscure),
                        ),
                      ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 10),
                      Text(_error!, style: TextStyle(color: cs.error, fontWeight: FontWeight.w600)),
                    ],
                    const SizedBox(height: 18),
                    FilledButton(
                      onPressed: _login,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text('Sign in', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    ),
                    const SizedBox(height: 6),
                    TextButton(
                      onPressed: () =>
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterScreen())),
                      child: const Text('New here? Create a citizen account'),
                    ),
                  ]),
                ),
              ),
            ),
          ),
          Transform.translate(
            offset: const Offset(0, -18),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  const Expanded(
                    child: Text('Try a demo account', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                  ),
                  TextButton(onPressed: () => showDemoAccounts(context), child: const Text('All accounts')),
                ]),
                const SizedBox(height: 4),
                Row(
                  children: withGap([
                    Expanded(
                      child: _DemoTile(
                        role: UserRole.citizen,
                        subtitle: 'citizen123',
                        onTap: () => _demo('citizen@citypulse.com', 'citizen123'),
                      ),
                    ),
                    Expanded(
                      child: _DemoTile(
                        role: UserRole.officer,
                        subtitle: 'officer123',
                        onTap: () => _demo('officer@citypulse.com', 'officer123'),
                      ),
                    ),
                    Expanded(
                      child: _DemoTile(
                        role: UserRole.admin,
                        subtitle: 'admin123',
                        onTap: () => _demo('admin@citypulse.com', 'admin123'),
                      ),
                    ),
                  ], gap: 10),
                ),
                const SizedBox(height: 16),
                Row(children: [
                  Icon(Icons.smartphone_rounded, size: 16, color: cs.onSurfaceVariant),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text('Works offline. Your reports and photos are saved on this phone.',
                        style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                  ),
                ]),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}

class _DemoTile extends StatelessWidget {
  final UserRole role;
  final String subtitle;
  final VoidCallback onTap;
  const _DemoTile({required this.role, required this.subtitle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: role.color.withAlpha(26),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          child: Column(children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: role.color,
              child: Icon(role.icon, color: Colors.white),
            ),
            const SizedBox(height: 8),
            Text(role.short, style: TextStyle(fontWeight: FontWeight.w800, color: role.color)),
            Text(subtitle, style: TextStyle(fontSize: 11, color: role.color.withAlpha(200))),
          ]),
        ),
      ),
    );
  }
}

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _pw = TextEditingController();
  String? _error;
  bool _obscure = true;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _pw.dispose();
    super.dispose();
  }

  void _register() {
    final err = store.register(name: _name.text, email: _email.text, phone: _phone.text, password: _pw.text);
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    Navigator.of(context).popUntil((r) => r.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Create account')),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        Text('Join CityPulse to report problems in your area and follow them until they are fixed.',
            style: TextStyle(color: cs.onSurfaceVariant, fontSize: 15)),
        const SizedBox(height: 20),
        TextField(controller: _name, textCapitalization: TextCapitalization.words, decoration: fieldDeco(context, 'Full name', Icons.badge_outlined)),
        const SizedBox(height: 12),
        TextField(controller: _email, keyboardType: TextInputType.emailAddress, decoration: fieldDeco(context, 'Email', Icons.alternate_email_rounded)),
        const SizedBox(height: 12),
        TextField(controller: _phone, keyboardType: TextInputType.phone, decoration: fieldDeco(context, 'Mobile number', Icons.phone_outlined)),
        const SizedBox(height: 12),
        TextField(
          controller: _pw,
          obscureText: _obscure,
          decoration: fieldDeco(
            context,
            'Password (min 6 characters)',
            Icons.lock_outline_rounded,
            suffix: IconButton(
              icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
              onPressed: () => setState(() => _obscure = !_obscure),
            ),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 10),
          Text(_error!, style: TextStyle(color: cs.error, fontWeight: FontWeight.w600)),
        ],
        const SizedBox(height: 22),
        FilledButton(
          onPressed: _register,
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          child: const Text('Create account', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        ),
      ]),
    );
  }
}
