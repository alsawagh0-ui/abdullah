import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/providers.dart';
import 'push_bindings.dart';
import 'router.dart';
import 'theme.dart';

class AlMunjezApp extends ConsumerWidget {
  const AlMunjezApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final user = ref.watch(currentUserProvider).value;
    final locale = Locale(user?.locale ?? 'ar');
    return MaterialApp.router(
      title: 'المنجز',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      locale: locale,
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      routerConfig: router,
      builder: (context, child) => PushBindings(child: child ?? const SizedBox.shrink()),
    );
  }
}
