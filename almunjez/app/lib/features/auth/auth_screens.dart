import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/config.dart';
import '../../app/theme.dart';
import '../../core/providers.dart';
import '../../l10n/strings.dart';
import '../../shared/widgets.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});
  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  final _ctrl = PageController();
  int _page = 0;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final slides = [
      (Icons.task_alt_rounded, s.welcome1Title, s.welcome1Body),
      (Icons.front_hand_rounded, s.welcome2Title, s.welcome2Body),
      (Icons.groups_rounded, s.welcome3Title, s.welcome3Body),
    ];
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(alignment: AlignmentDirectional.centerEnd, child: TextButton(onPressed: () => context.go('/sign-in'), child: Text(s.skip))),
            Expanded(
              child: PageView.builder(
                controller: _ctrl,
                itemCount: slides.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (_, i) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 120, height: 120,
                        decoration: BoxDecoration(color: AppTheme.accent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(36)),
                        child: Icon(slides[i].$1, size: 60, color: AppTheme.accent),
                      ),
                      const SizedBox(height: 32),
                      Text(slides[i].$2, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800), textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      Text(slides[i].$3, style: const TextStyle(fontSize: 16, color: AppTheme.muted, height: 1.6), textAlign: TextAlign.center),
                    ],
                  ),
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(slides.length, (i) => AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.all(4),
                    width: i == _page ? 22 : 8, height: 8,
                    decoration: BoxDecoration(color: i == _page ? AppTheme.accent : AppTheme.muted.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(4)),
                  )),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: FilledButton(onPressed: () => context.go('/sign-in'), child: Text(s.signIn)),
            ),
          ],
        ),
      ),
    );
  }
}

class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});
  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _phone = TextEditingController();
  final _code = TextEditingController();
  bool _codeSent = false;
  bool _busy = false;

  Future<void> _run(Future<void> Function() f) async {
    setState(() => _busy = true);
    await guard(context, f);
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final api = ref.watch(apiProvider);
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 16),
            Text(s.appName, style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w800, color: AppTheme.accent)),
            Text(s.tagline, style: const TextStyle(fontSize: 18, color: AppTheme.muted)),
            const SizedBox(height: 40),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: Colors.black, foregroundColor: Colors.white),
              onPressed: _busy ? null : () => _run(api.signInWithApple),
              icon: const Icon(Icons.apple, size: 26),
              label: Text(s.signInWithApple),
            ),
            const SizedBox(height: 24),
            Text(s.signInWithPhone, style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            if (!_codeSent) ...[
              TextField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                textDirection: TextDirection.ltr,
                decoration: InputDecoration(hintText: '+965 5xxx xxxx', labelText: s.phoneNumber),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: _busy || _phone.text.trim().length < 8
                    ? null
                    : () => _run(() async {
                          await api.sendPhoneOtp(_phone.text.trim());
                          setState(() => _codeSent = true);
                        }),
                child: Text(s.sendCode),
              ),
            ] else ...[
              Text('${s.codeSentTo} ${_phone.text.trim()}', style: const TextStyle(color: AppTheme.muted)),
              const SizedBox(height: 8),
              TextField(
                controller: _code,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                maxLength: 6,
                style: const TextStyle(fontSize: 28, letterSpacing: 8),
                decoration: InputDecoration(labelText: s.verificationCode, counterText: ''),
                onChanged: (v) {
                  if (v.length == 6 && !_busy) _run(() => api.verifyPhoneOtp(_phone.text.trim(), v));
                },
              ),
              const SizedBox(height: 12),
              OutlinedButton(onPressed: _busy ? null : () => _run(() => api.verifyPhoneOtp(_phone.text.trim(), _code.text.trim())), child: Text(s.verify)),
              TextButton(onPressed: () => setState(() => _codeSent = false), child: Text(s.cancel)),
            ],
            if (!AppConfig.useSupabase) ...[
              const SizedBox(height: 32),
              const Divider(),
              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: _busy ? null : () => _run(api.signInDemo),
                icon: const Icon(Icons.play_circle_outline),
                label: Text(s.signInDemo),
              ),
              Text(s.offlineMode, style: const TextStyle(fontSize: 12, color: AppTheme.muted), textAlign: TextAlign.center),
            ],
          ],
        ),
      ),
    );
  }
}

class ProfileSetupScreen extends ConsumerStatefulWidget {
  const ProfileSetupScreen({super.key});
  @override
  ConsumerState<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends ConsumerState<ProfileSetupScreen> {
  final _name = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final api = ref.watch(apiProvider);
    return Scaffold(
      appBar: AppBar(title: Text(s.completeProfile)),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(child: Avatar(name: _name.text, size: 88)),
            const SizedBox(height: 24),
            TextField(
              controller: _name,
              autofocus: true,
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(labelText: s.yourName),
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _submit(api),
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: _name.text.trim().isEmpty ? null : () => _submit(api), child: Text(s.continueLabel)),
            const Spacer(),
            TextButton(onPressed: () => guard(context, api.signOut), child: Text(s.signOut)),
          ],
        ),
      ),
    );
  }

  void _submit(api) => guard(context, () => api.completeProfile(displayName: _name.text.trim()));
}
