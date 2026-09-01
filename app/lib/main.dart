import 'package:flutter/material.dart';

import 'app.dart';
import 'data/storage.dart';
import 'data/wajb_store.dart';
import 'services/platform_services.dart';
import 'services/wajb_services.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // خدمات المنصة الحقيقية. الشاشات لا تعرف عنها شيئاً: كلها خلف واجهات
  // مجرّدة تُستبدل بنسخ صورية في الاختبارات.
  final notifications = LocalNotifications();
  final services = WajbServices(
    externalActions: const PlatformExternalActions(),
    notifications: notifications,
    recognizer: const TesseractCardRecognizer(),
    imagePicker: PlatformCardImagePicker(),
    voiceInput: PlatformVoiceInputRecognizer(),
  );

  final store = WajbStore(
    storage: PreferencesStorage(),
    notifications: notifications,
  );

  await notifications.initialize();
  await store.load(seedIfEmpty: false);
  await store.syncReminders();

  runApp(WajbApp(store: store, services: services));
}
