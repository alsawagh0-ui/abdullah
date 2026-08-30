import 'package:flutter/material.dart';

import 'app.dart';
import 'data/storage.dart';
import 'data/wajb_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = WajbStore(storage: PreferencesStorage());
  await store.load(seedIfEmpty: false);
  runApp(WajbApp(store: store));
}
