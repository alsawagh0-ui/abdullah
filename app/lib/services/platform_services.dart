import 'dart:io' show Platform;

import 'package:add_2_calendar/add_2_calendar.dart' as cal;
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_tesseract_ocr/flutter_tesseract_ocr.dart';
import 'package:image_picker/image_picker.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import 'package:url_launcher/url_launcher.dart';

import '../models/occasion.dart';
import 'card_scanner.dart';
import 'external_actions.dart';
import 'notification_planner.dart';
import 'voice_input.dart';

/// تنبيه للمراجع: كل ما في هذا الملف طبقة رقيقة فوق إضافات المنصة، ولا
/// يمكن تشغيلها إلا على جهاز فعلي (iOS أو Android). المنطق القابل
/// للاختبار كله خارجها في `external_actions.dart` و
/// `notification_planner.dart` و `card_scanner.dart`.

/// فتح الخرائط والاتصال وإضافة الحدث للتقويم عبر تطبيقات النظام.
class PlatformExternalActions implements ExternalActions {
  const PlatformExternalActions();

  @override
  bool get isIOS => !kIsWeb && Platform.isIOS;

  @override
  Future<bool> openMap(Venue venue) async {
    final uri = ExternalLinks.mapsFor(venue, isIOS: isIOS);
    if (uri == null) return false;
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Future<bool> call(String phone) async {
    final uri = ExternalLinks.telFor(phone);
    if (uri == null) return false;
    return launchUrl(uri);
  }

  @override
  Future<bool> addToCalendar(CalendarEventDraft draft) async {
    return cal.Add2Calendar.addEvent2Cal(
      cal.Event(
        title: draft.title,
        description: draft.description,
        location: draft.location,
        startDate: draft.start,
        endDate: draft.end,
        allDay: draft.allDay,
      ),
    );
  }
}

/// جدولة التنبيهات محلياً على الجهاز.
///
/// لا يُرسل شيء إلى خادم: كل تنبيه مجدول محلياً، تماماً كبقية بيانات
/// التطبيق.
class LocalNotifications implements WajbNotifications {
  LocalNotifications({this.timeZoneName = 'Asia/Kuwait'});

  final String timeZoneName;
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _ready = false;

  static const AndroidNotificationDetails _androidDetails =
      AndroidNotificationDetails(
    'wajb_duties',
    'واجباتي',
    channelDescription: 'تذكير بالواجبات الاجتماعية القادمة',
    importance: Importance.defaultImportance,
    priority: Priority.defaultPriority,
  );

  static const NotificationDetails _details = NotificationDetails(
    android: _androidDetails,
    iOS: DarwinNotificationDetails(),
  );

  @override
  Future<void> initialize() async {
    if (_ready) return;
    tz_data.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation(timeZoneName));

    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );
    _ready = true;
  }

  @override
  Future<bool> requestPermission() async {
    await initialize();
    if (kIsWeb) return false;

    if (Platform.isIOS) {
      final granted = await _plugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, badge: true, sound: true);
      return granted ?? false;
    }

    final granted = await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    return granted ?? false;
  }

  @override
  Future<void> sync(List<ReminderPlan> plans) async {
    await initialize();
    await _plugin.cancelAll();
    for (final plan in plans) {
      await _plugin.zonedSchedule(
        id: plan.id,
        title: plan.title,
        body: plan.body,
        scheduledDate: tz.TZDateTime.from(plan.at, tz.local),
        notificationDetails: _details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: plan.occasionId,
      );
    }
  }

  @override
  Future<void> cancelAll() async {
    await initialize();
    await _plugin.cancelAll();
  }
}

/// التقاط صورة البطاقة من الكاميرا أو المعرض.
class PlatformCardImagePicker implements CardImagePicker {
  PlatformCardImagePicker();

  final ImagePicker _picker = ImagePicker();

  @override
  Future<String?> pickImage(CardImageSource source) async {
    final file = await _picker.pickImage(
      source: source == CardImageSource.camera
          ? ImageSource.camera
          : ImageSource.gallery,
      // دقة كافية للاستخلاص دون إرهاق الذاكرة على الأجهزة الأقدم.
      maxWidth: 2000,
      imageQuality: 90,
    );
    return file?.path;
  }
}

/// استخلاص النص العربي على الجهاز عبر Tesseract.
///
/// اختير على ML Kit لأن الأخير لا يدعم العربية أصلاً، وعلى الخدمات
/// السحابية لأن صورة بطاقة العزاء يجب ألا تغادر الجهاز.
class TesseractCardRecognizer implements CardTextRecognizer {
  const TesseractCardRecognizer();

  @override
  bool get isAvailable => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  @override
  Future<String?> recognize(String imagePath) async {
    if (!isAvailable) return null;
    try {
      final raw = await FlutterTesseractOcr.extractText(
        imagePath,
        language: 'ara',
        args: <String, String>{
          // 1 = تجزئة تلقائية للصفحة مع كشف اتجاه النص.
          'psm': '1',
          'preserve_interword_spaces': '1',
        },
      );
      final cleaned = OcrTextCleaner.clean(raw);
      return cleaned.isEmpty ? null : cleaned;
    } on Exception {
      return null;
    }
  }
}

/// الإدخال الصوتي عبر محرك التعرّف الكلامي المدمج في النظام (iOS/Android).
///
/// **ملاحظة ستر مهمة، خلافاً لقراءة الصور:** هذا يستخدم محرك النظام
/// الافتراضي (`SFSpeechRecognizer` على iOS، `SpeechRecognizer` على
/// أندرويد)، وهو غالباً **يرسل الصوت لخادم آبل أو جوجل** لمعالجته إلا
/// إذا كان الجهاز يدعم التعرّف على الجهاز فعلياً. هذا خلاف مبدأ الستر
/// المطبَّق حرفياً على قراءة صور بطاقات النعي عبر Tesseract محلياً (انظر
/// `TesseractCardRecognizer`). **قرار مؤجل:** إن اعتُبر هذا غير مقبول
/// لمحتوى حسّاس كالعزاء، الحل تفعيل `onDevice: true` مع تعطيل الميزة
/// كلياً على الأجهزة التي لا تدعمه — لم يُفعَّل هنا لأنه سيعطّل الميزة
/// على غالبية الأجهزة الحالية.
class PlatformVoiceInputRecognizer implements VoiceInputRecognizer {
  PlatformVoiceInputRecognizer() : _speech = stt.SpeechToText();

  final stt.SpeechToText _speech;
  bool? _initialized;

  @override
  Future<bool> get isAvailable async {
    if (kIsWeb) return false;
    return _initialized ??= await _speech.initialize();
  }

  @override
  Future<void> listen({
    required void Function(String text, {required bool isFinal}) onResult,
    String localeId = 'ar',
  }) async {
    if (!await isAvailable) return;
    await _speech.listen(
      onResult: (result) => onResult(
        result.recognizedWords,
        isFinal: result.finalResult,
      ),
      listenOptions: stt.SpeechListenOptions(localeId: localeId),
    );
  }

  @override
  Future<void> stop() => _speech.stop();

  @override
  bool get isListeningNow => _speech.isListening;
}
