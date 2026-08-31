import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'data/wajb_store.dart';
import 'services/wajb_services.dart';
import 'theme/app_theme.dart';
import 'ui/home/home_screen.dart';
import 'ui/onboarding/onboarding_screen.dart';
import 'ui/store_scope.dart';

/// جذر التطبيق.
///
/// العربية أولاً: اللغة والاتجاه (RTL) مثبّتان في الجذر لا مضافين لاحقاً.
class WajbApp extends StatefulWidget {
  const WajbApp({super.key, required this.store, this.services});

  final WajbStore store;

  /// خدمات المنصة. تُترك فارغة في الاختبارات فتُستخدم نسخ صورية.
  final WajbServices? services;

  @override
  State<WajbApp> createState() => _WajbAppState();
}

class _WajbAppState extends State<WajbApp> {
  @override
  Widget build(BuildContext context) {
    return ServicesScope(
      services: widget.services ?? WajbServices.fake(),
      child: StoreScope(
        store: widget.store,
        child: AnimatedBuilder(
          animation: widget.store,
          builder: (context, _) {
            final elder = widget.store.profile.elderMode;
            return MaterialApp(
              title: 'واجِب',
              debugShowCheckedModeBanner: false,
              theme: WajbTheme.light(elderMode: elder),
              darkTheme: WajbTheme.dark(elderMode: elder),
              locale: const Locale('ar'),
              supportedLocales: const [Locale('ar'), Locale('en')],
              localizationsDelegates: const [
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              builder: (context, child) {
                final media = MediaQuery.of(context);
                return MediaQuery(
                  // نمط كبار السن: تكبير النص بالطريقة المعتمدة في فلاتر،
                  // مع احترام تكبير النظام إن كان أكبر أصلاً.
                  data: media.copyWith(
                    textScaler: elder
                        ? TextScaler.linear(media.textScaler.scale(1) * 1.25)
                        : media.textScaler,
                  ),
                  child: Directionality(
                    textDirection: TextDirection.rtl,
                    child: child ?? const SizedBox.shrink(),
                  ),
                );
              },
              home: widget.store.profile.onboarded
                  ? const HomeShell()
                  : OnboardingScreen(onDone: () => setState(() {})),
            );
          },
        ),
      ),
    );
  }
}
