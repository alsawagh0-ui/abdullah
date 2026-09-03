import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app/app.dart';
import 'app/bootstrap.dart';
import 'core/notif_prompt.dart';
import 'core/providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ar');
  await initializeDateFormatting('en');
  await NotifPromptStore.instance.load();
  final api = await buildApi();
  runApp(ProviderScope(overrides: [apiProvider.overrideWithValue(api)], child: const AlMunjezApp()));
}
