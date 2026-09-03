import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/api/local/local_api.dart';
import '../../core/notif_prompt.dart';
import '../../core/providers.dart';
import '../../core/push.dart';
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
  final _phoneCode = TextEditingController();
  bool _phoneCodeSent = false;

  final _email = TextEditingController();
  final _emailCode = TextEditingController();
  bool _emailCodeSent = false;

  bool _busy = false;

  Future<void> _run(Future<void> Function() f) async {
    setState(() => _busy = true);
    await guard(context, f);
    if (mounted) setState(() => _busy = false);
  }

  /// Kuwait-first MVP (doc 19): if the user just typed the local number, add
  /// the country code Supabase's E.164-only phone auth requires.
  String _normalizePhone(String raw) {
    final digits = raw.trim();
    if (digits.startsWith('+')) return digits;
    return '+965$digits';
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
            const SizedBox(height: 12),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(foregroundColor: Colors.black87, side: const BorderSide(color: Color(0xFFDADCE0))),
              onPressed: _busy ? null : () => _run(api.signInWithGoogle),
              icon: const _GoogleG(),
              label: Text(s.signInWithGoogle),
            ),
            const SizedBox(height: 24),
            Text(s.signInWithEmail, style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            if (!_emailCodeSent) ...[
              TextField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                textDirection: TextDirection.ltr,
                decoration: InputDecoration(hintText: 'name@example.com', labelText: s.email),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: _busy || !_email.text.contains('@')
                    ? null
                    : () => _run(() async {
                          await api.sendEmailOtp(_email.text.trim());
                          setState(() => _emailCodeSent = true);
                        }),
                child: Text(s.sendCode),
              ),
            ] else ...[
              Text('${s.codeSentTo} ${_email.text.trim()}', style: const TextStyle(color: AppTheme.muted)),
              const SizedBox(height: 8),
              TextField(
                controller: _emailCode,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                maxLength: 6,
                style: const TextStyle(fontSize: 28, letterSpacing: 8),
                decoration: InputDecoration(labelText: s.verificationCode, counterText: ''),
                onChanged: (v) {
                  if (v.length == 6 && !_busy) _run(() => api.verifyEmailOtp(_email.text.trim(), v));
                },
              ),
              const SizedBox(height: 12),
              OutlinedButton(onPressed: _busy ? null : () => _run(() => api.verifyEmailOtp(_email.text.trim(), _emailCode.text.trim())), child: Text(s.verify)),
              TextButton(onPressed: () => setState(() => _emailCodeSent = false), child: Text(s.cancel)),
            ],
            const SizedBox(height: 24),
            Text(s.signInWithPhone, style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            if (!_phoneCodeSent) ...[
              TextField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                textDirection: TextDirection.ltr,
                decoration: InputDecoration(hintText: '+965 5xxx xxxx', labelText: s.phoneNumber),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: _busy || _phone.text.trim().length < 8
                    ? null
                    : () => _run(() async {
                          await api.sendPhoneOtp(_normalizePhone(_phone.text));
                          setState(() => _phoneCodeSent = true);
                        }),
                child: Text(s.sendCode),
              ),
            ] else ...[
              Text('${s.codeSentTo} ${_normalizePhone(_phone.text)}', style: const TextStyle(color: AppTheme.muted)),
              const SizedBox(height: 8),
              TextField(
                controller: _phoneCode,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                maxLength: 6,
                style: const TextStyle(fontSize: 28, letterSpacing: 8),
                decoration: InputDecoration(labelText: s.verificationCode, counterText: ''),
                onChanged: (v) {
                  if (v.length == 6 && !_busy) _run(() => api.verifyPhoneOtp(_normalizePhone(_phone.text), v));
                },
              ),
              const SizedBox(height: 12),
              OutlinedButton(onPressed: _busy ? null : () => _run(() => api.verifyPhoneOtp(_normalizePhone(_phone.text), _phoneCode.text.trim())), child: Text(s.verify)),
              TextButton(onPressed: () => setState(() => _phoneCodeSent = false), child: Text(s.cancel)),
            ],
            if (api is LocalApi) ...[
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

/// A5 — explain, then ask (doc 02 §1, brief §7). Shown once, only where push
/// is meaningful (native iOS); the router redirect gates it (doc app/router.dart).
class NotificationsPermissionScreen extends StatelessWidget {
  const NotificationsPermissionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(color: AppTheme.accent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(36)),
                child: const Icon(Icons.notifications_active_rounded, size: 60, color: AppTheme.accent),
              ),
              const SizedBox(height: 32),
              Text(s.notificationsPermissionTitle, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800), textAlign: TextAlign.center),
              const SizedBox(height: 12),
              Text(s.notificationsPermissionBody, style: const TextStyle(fontSize: 16, color: AppTheme.muted, height: 1.6), textAlign: TextAlign.center),
              const Spacer(),
              FilledButton(onPressed: () => _finish(context, request: true), child: Text(s.enable)),
              const SizedBox(height: 8),
              TextButton(onPressed: () => _finish(context, request: false), child: Text(s.later)),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _finish(BuildContext context, {required bool request}) async {
    if (request) await PushService.instance.requestPermission();
    await NotifPromptStore.instance.markSeen();
    if (context.mounted) context.go('/home');
  }
}

/// Minimal "G" mark in Google's brand colours — avoids shipping a logo asset.
class _GoogleG extends StatelessWidget {
  const _GoogleG();

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 20,
        height: 20,
        child: CustomPaint(painter: _GoogleGPainter()),
      );
}

class _GoogleGPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final r = size.width / 2;
    final center = Offset(r, r);
    final stroke = size.width * 0.22;
    final rect = Rect.fromCircle(center: center, radius: r - stroke / 2);
    void arc(double startDeg, double sweepDeg, Color color) {
      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.butt;
      canvas.drawArc(rect, startDeg * 3.14159265 / 180, sweepDeg * 3.14159265 / 180, false, paint);
    }

    arc(-90, 90, const Color(0xFF4285F4));
    arc(0, 90, const Color(0xFF34A853));
    arc(90, 90, const Color(0xFFFBBC05));
    arc(180, 90, const Color(0xFFEA4335));
    final barPaint = Paint()..color = const Color(0xFF4285F4);
    canvas.drawRect(Rect.fromLTWH(center.dx, center.dy - stroke / 2, r - stroke / 2, stroke), barPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
