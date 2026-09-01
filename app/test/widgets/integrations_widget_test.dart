import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wajb/app.dart';
import 'package:wajb/data/storage.dart';
import 'package:wajb/data/wajb_store.dart';
import 'package:wajb/models/person.dart';
import 'package:wajb/services/card_scanner.dart';
import 'package:wajb/services/external_actions.dart';
import 'package:wajb/services/notification_planner.dart';
import 'package:wajb/services/voice_input.dart';
import 'package:wajb/services/wajb_services.dart';
import 'package:wajb/ui/occasion/capture_screen.dart';
import 'package:wajb/ui/occasion/occasion_screen.dart';
import 'package:wajb/ui/store_scope.dart';

final DateTime fixedNow = DateTime(2026, 5, 10, 14);

const String cardText = '''
انتقل إلى رحمة الله تعالى: ناصر السالم
العزاء للرجال في ديوان السالم - كيفان بعد صلاة المغرب
مقر النساء: منزل الفقيد - كيفان
''';

class TestBundle {
  TestBundle(this.store, this.services, this.actions, this.notifications,
      this.recognizer, this.picker, this.voice);

  final WajbStore store;
  final WajbServices services;
  final RecordingExternalActions actions;
  final RecordingNotifications notifications;
  final FakeCardRecognizer recognizer;
  final FakeCardImagePicker picker;
  final FakeVoiceInputRecognizer voice;
}

Future<TestBundle> buildBundle({
  bool isIOS = false,
  String? recognizedText = cardText,
  String? imagePath = '/tmp/card.jpg',
  bool recognizerAvailable = true,
  bool voiceAvailable = true,
  List<String> voiceResults = const <String>[],
}) async {
  final actions = RecordingExternalActions(isIOS: isIOS);
  final notifications = RecordingNotifications();
  final recognizer =
      FakeCardRecognizer(recognizedText, available: recognizerAvailable);
  final picker = FakeCardImagePicker(imagePath);
  final voice = FakeVoiceInputRecognizer(
    available: voiceAvailable,
    results: voiceResults,
  );
  final store = WajbStore(
    storage: MemoryStorage(),
    clock: () => fixedNow,
    notifications: notifications,
  );
  await store.load();
  return TestBundle(
    store,
    WajbServices(
      externalActions: actions,
      notifications: notifications,
      recognizer: recognizer,
      imagePicker: picker,
      voiceInput: voice,
    ),
    actions,
    notifications,
    recognizer,
    picker,
    voice,
  );
}

Future<void> pump(
  WidgetTester tester,
  TestBundle bundle,
  Widget screen,
) async {
  await tester.binding.setSurfaceSize(const Size(420, 1600));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ServicesScope(
      services: bundle.services,
      child: StoreScope(
        store: bundle.store,
        child: MaterialApp(
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: screen,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('التقاط البطاقة من صورة', () {
    testWidgets('أزرار التصوير تظهر حين يتوفر المحرك', (tester) async {
      final bundle = await buildBundle();
      await pump(tester, bundle, const CaptureScreen());
      expect(find.text('صوّر البطاقة'), findsOneWidget);
      expect(find.text('من المعرض'), findsOneWidget);
    });

    testWidgets('يُخفى الخيار ويُشرح السبب حين لا يتوفر المحرك',
        (tester) async {
      final bundle = await buildBundle(recognizerAvailable: false);
      await pump(tester, bundle, const CaptureScreen());
      expect(find.text('صوّر البطاقة'), findsNothing);
      expect(
        find.textContaining('قراءة الصور غير متاحة'),
        findsOneWidget,
      );
    });

    testWidgets('تصوير البطاقة يملأ النص ويعرض الحقول المستخلَصة',
        (tester) async {
      final bundle = await buildBundle();
      await pump(tester, bundle, const CaptureScreen());

      await tester.tap(find.text('صوّر البطاقة'));
      await tester.pumpAndSettle();

      expect(bundle.picker.requests.single, CardImageSource.camera);
      expect(bundle.recognizer.requests.single, '/tmp/card.jpg');
      expect(find.text('نتيجة الاستخلاص'), findsOneWidget);
      expect(find.textContaining('ديوان السالم'), findsWidgets);
      expect(find.textContaining('ناصر السالم'), findsWidgets);
    });

    testWidgets('النص المستخلَص يبقى قابلاً للتحرير قبل الحفظ',
        (tester) async {
      final bundle = await buildBundle();
      await pump(tester, bundle, const CaptureScreen());
      await tester.tap(find.text('من المعرض'));
      await tester.pumpAndSettle();

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller!.text, contains('ناصر السالم'));
      expect(field.enabled, isNot(false));
    });

    testWidgets('فشل القراءة يُبلَّغ به ولا يحفظ شيئاً', (tester) async {
      final bundle = await buildBundle(recognizedText: null);
      final before = bundle.store.occasions.length;
      await pump(tester, bundle, const CaptureScreen());

      await tester.tap(find.text('صوّر البطاقة'));
      await tester.pumpAndSettle();

      expect(find.textContaining('ما قدرنا نقرأ البطاقة'), findsOneWidget);
      expect(find.text('نتيجة الاستخلاص'), findsNothing);
      expect(bundle.store.occasions.length, before);
    });

    testWidgets('إلغاء اختيار الصورة لا يغيّر شيئاً', (tester) async {
      final bundle = await buildBundle(imagePath: null);
      await pump(tester, bundle, const CaptureScreen());

      await tester.tap(find.text('صوّر البطاقة'));
      await tester.pumpAndSettle();

      expect(bundle.recognizer.requests, isEmpty);
      expect(find.text('نتيجة الاستخلاص'), findsNothing);
    });
  });

  group('الإدخال الصوتي', () {
    testWidgets('زر الميكروفون يُخفى حين لا يتوفر المحرك', (tester) async {
      final bundle = await buildBundle(voiceAvailable: false);
      await pump(tester, bundle, const CaptureScreen());
      expect(find.byIcon(Icons.mic_none_outlined), findsNothing);
      expect(find.byIcon(Icons.mic_off_outlined), findsOneWidget);
    });

    testWidgets('الإملاء يضيف النص النهائي إلى حقل التحرير', (tester) async {
      final bundle = await buildBundle(
        voiceResults: const ['العزاء', 'العزاء للرجال في ديوان السالم'],
      );
      await pump(tester, bundle, const CaptureScreen());

      await tester.tap(find.byIcon(Icons.mic_none_outlined));
      await tester.pumpAndSettle();

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller!.text, 'العزاء للرجال في ديوان السالم');
      expect(bundle.voice.listening, isFalse);
    });

    testWidgets('الإملاء يُلحَق بالنص الموجود لا يستبدله', (tester) async {
      final bundle = await buildBundle(voiceResults: const ['بعد المغرب']);
      await pump(tester, bundle, const CaptureScreen());

      await tester.enterText(find.byType(TextField), 'العزاء للرجال');
      await tester.tap(find.byIcon(Icons.mic_none_outlined));
      await tester.pumpAndSettle();

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller!.text, 'العزاء للرجال بعد المغرب');
    });

    testWidgets('الضغط أثناء الاستماع يوقفه', (tester) async {
      final bundle = await buildBundle(voiceAvailable: true);
      await pump(tester, bundle, const CaptureScreen());

      await tester.tap(find.byIcon(Icons.mic_none_outlined));
      await tester.pump();
      expect(find.text('يستمع الآن...'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.mic));
      await tester.pumpAndSettle();

      expect(bundle.voice.stopCalls, 1);
      expect(find.text('يستمع الآن...'), findsNothing);
    });
  });

  group('الملاحة والاتصال', () {
    testWidgets('زر الملاحة يفتح مقر المستخدم هو', (tester) async {
      final bundle = await buildBundle();
      await pump(tester, bundle, const OccasionScreen(occasionId: 'o1'));

      await tester.tap(find.text('الملاحة').first);
      await tester.pumpAndSettle();

      expect(bundle.actions.mapRequests.single.title, 'ديوان المطيري');
    });

    testWidgets('كل مقر له زر ملاحة مستقل', (tester) async {
      final bundle = await buildBundle();
      await pump(tester, bundle, const OccasionScreen(occasionId: 'o1'));
      expect(find.text('الملاحة'), findsNWidgets(2));

      await tester.tap(find.text('الملاحة').last);
      await tester.pumpAndSettle();
      expect(bundle.actions.mapRequests.single.title, 'منزل الفقيد');
    });

    testWidgets('زر الاتصال يستخدم رقم الإعلان', (tester) async {
      final bundle = await buildBundle();
      await pump(tester, bundle, const OccasionScreen(occasionId: 'o1'));

      await tester.tap(find.byIcon(Icons.call_outlined));
      await tester.pumpAndSettle();

      expect(bundle.actions.callRequests.single, '99887766');
    });
  });

  group('إضافة الموعد للتقويم', () {
    testWidgets('لا يُكتب في التقويم إلا بموافقة صريحة', (tester) async {
      final bundle = await buildBundle();
      await pump(tester, bundle, const OccasionScreen(occasionId: 'o1'));

      await tester.tap(find.text('أنا حاضر'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('لا، شكراً'));
      await tester.pumpAndSettle();

      expect(bundle.actions.calendarRequests, isEmpty);
      expect(bundle.store.occasion('o1')!.done, isTrue);
    });

    testWidgets('الموافقة تضيف حدثاً يحمل المقر والتوقيت الصحيحين',
        (tester) async {
      final bundle = await buildBundle();
      await pump(tester, bundle, const OccasionScreen(occasionId: 'o1'));

      await tester.tap(find.text('أنا حاضر'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('أضِف للتقويم'));
      await tester.pumpAndSettle();

      final draft = bundle.actions.calendarRequests.single;
      expect(draft.title, contains('عزاء'));
      expect(draft.title, contains('عبدالله المطيري'));
      expect(draft.location, contains('ديوان المطيري'));
      expect(draft.description, contains('مقر الرجال'));
      expect(draft.allDay, isFalse);
    });

    testWidgets('المرأة تحصل على حدث بمقر النساء', (tester) async {
      final bundle = await buildBundle();
      bundle.store.updateProfile(
        bundle.store.profile.copyWith(gender: Gender.female),
      );
      await pump(tester, bundle, const OccasionScreen(occasionId: 'o1'));

      await tester.tap(find.text('أنا حاضر'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('أضِف للتقويم'));
      await tester.pumpAndSettle();

      final draft = bundle.actions.calendarRequests.single;
      expect(draft.location, contains('منزل الفقيد'));
      expect(draft.description, contains('مقر النساء'));
    });
  });

  group('جدولة التنبيهات عبر المخزن', () {
    testWidgets('أول تغيير في الحالة يزامن الخطة مع المنصة', (tester) async {
      final bundle = await buildBundle();
      await pump(tester, bundle, const OccasionScreen(occasionId: 'o1'));

      await tester.tap(find.text('أنا حاضر'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('لا، شكراً'));
      await tester.pumpAndSettle();

      expect(bundle.notifications.cancelCount, greaterThan(0));
      // الواجب الذي أُدّي لا يبقى في الخطة.
      expect(
        bundle.notifications.scheduled.any((p) => p.occasionId == 'o1'),
        isFalse,
      );
    });

    testWidgets('الخطة تُبنى من الواجبات الفعلية', (tester) async {
      final bundle = await buildBundle();
      await bundle.store.syncReminders();
      final plans = bundle.notifications.scheduled;
      expect(plans, isNotEmpty);
      for (final plan in plans) {
        expect(plan.at.isAfter(fixedNow), isTrue);
        expect(plan.title.trim(), isNotEmpty);
        expect(plan.body.trim(), isNotEmpty);
      }
    });
  });

  group('التطبيق الكامل', () {
    testWidgets('يعمل بخدمات صورية بلا جهاز حقيقي', (tester) async {
      final bundle = await buildBundle();
      await tester.binding.setSurfaceSize(const Size(420, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        WajbApp(store: bundle.store, services: bundle.services),
      );
      await tester.pumpAndSettle();
      expect(find.text('واجبات اليوم'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
