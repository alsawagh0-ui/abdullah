import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wajb/app.dart';
import 'package:wajb/data/storage.dart';
import 'package:wajb/data/wajb_store.dart';
import 'package:wajb/models/person.dart';
import 'package:wajb/ui/home/home_screen.dart';
import 'package:wajb/ui/occasion/occasion_screen.dart';
import 'package:wajb/ui/store_scope.dart';
import 'package:wajb/ui/widgets/duty_card.dart';

final DateTime fixedNow = DateTime(2026, 5, 10, 14);

Future<WajbStore> seededStore() async {
  final store = WajbStore(storage: MemoryStorage(), clock: () => fixedNow);
  await store.load();
  return store;
}

Future<void> pumpApp(
  WidgetTester tester,
  WajbStore store, {
  Size surface = const Size(420, 1400),
}) async {
  await tester.binding.setSurfaceSize(surface);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(WajbApp(store: store));
  await tester.pumpAndSettle();
}

Future<void> pumpScreen(
  WidgetTester tester,
  WajbStore store,
  Widget screen, {
  Size surface = const Size(420, 1400),
}) async {
  await tester.binding.setSurfaceSize(surface);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    StoreScope(
      store: store,
      child: MaterialApp(
        home: Directionality(textDirection: TextDirection.rtl, child: screen),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('الشاشة الرئيسية تعرض ثلاث بطاقات كحد أقصى', (tester) async {
    final store = await seededStore();
    await pumpApp(tester, store);

    expect(find.text('واجبات اليوم'), findsOneWidget);
    expect(find.byType(DutyCard), findsNWidgets(DutiesScreen.maxCards));
  });

  testWidgets('الشريط العلوي يلخّص واجبات الأسبوع', (tester) async {
    final store = await seededStore();
    await pumpApp(tester, store);

    final summary = store.weekSummary();
    expect(
      find.textContaining('هذا الأسبوع: ${summary.total}'),
      findsOneWidget,
    );
  });

  testWidgets('اتجاه الواجهة من اليمين إلى اليسار', (tester) async {
    final store = await seededStore();
    await pumpApp(tester, store);

    final direction = Directionality.of(
      tester.element(find.byType(DutyCard).first),
    );
    expect(direction, TextDirection.rtl);
  });

  testWidgets('التنقل بين الأقسام الأربعة يعمل', (tester) async {
    final store = await seededStore();
    await pumpApp(tester, store);

    await tester.tap(find.text('العلاقات'));
    await tester.pumpAndSettle();
    expect(find.text('خريطة العلاقات'), findsOneWidget);

    await tester.tap(find.text('الدفتر'));
    await tester.pumpAndSettle();
    expect(find.text('دفترك الخاص'), findsOneWidget);

    await tester.tap(find.text('الإعدادات'));
    await tester.pumpAndSettle();
    expect(find.text('الإعدادات'), findsWidgets);
  });

  testWidgets('نمط كبار السن يكبّر النص فعلياً', (tester) async {
    final store = await seededStore();
    await pumpApp(tester, store);

    double renderedSize() {
      final context = tester.element(find.byType(DutyCard).first);
      final style = Theme.of(context).textTheme.titleMedium!;
      return MediaQuery.textScalerOf(context).scale(style.fontSize!);
    }

    final before = renderedSize();
    store.setElderMode(true);
    await tester.pumpAndSettle();
    expect(renderedSize(), greaterThan(before));
    expect(tester.takeException(), isNull);
  });

  group('شاشة المناسبة', () {
    testWidgets('نمط العزاء يعرض المقرين ويحدد وجهة المستخدم', (tester) async {
      final store = await seededStore();
      await pumpScreen(tester, store, const OccasionScreen(occasionId: 'o1'));

      expect(find.text('مقر الرجال'), findsOneWidget);
      expect(find.text('مقر النساء'), findsOneWidget);
      expect(find.text('وجهتك'), findsOneWidget);
    });

    testWidgets('تغيير جنس المستخدم يبدّل الوجهة المعروضة', (tester) async {
      final store = await seededStore();
      store.updateProfile(
        store.profile.copyWith(gender: Gender.female),
      );
      await pumpScreen(tester, store, const OccasionScreen(occasionId: 'o1'));

      final womenCard = find.ancestor(
        of: find.text('مقر النساء'),
        matching: find.byType(Card),
      );
      expect(
        find.descendant(of: womenCard, matching: find.text('وجهتك')),
        findsOneWidget,
      );
    });

    testWidgets('واجهة العزاء بلا اقتراح نقوط وبلا محتوى تجاري',
        (tester) async {
      final store = await seededStore();
      await pumpScreen(tester, store, const OccasionScreen(occasionId: 'o1'));

      expect(find.textContaining('اقتراح النقوط'), findsNothing);
      expect(
        find.textContaining('واجهة العزاء خالية من أي محتوى تجاري'),
        findsOneWidget,
      );
    });

    testWidgets('مناسبة الفرح تعرض اقتراح النقوط خلف نقرة واحدة',
        (tester) async {
      final store = await seededStore();
      await pumpScreen(tester, store, const OccasionScreen(occasionId: 'o2'));
      await tester.scrollUntilVisible(
        find.textContaining('اقتراح النقوط'),
        200,
      );

      expect(find.textContaining('اقتراح النقوط'), findsOneWidget);
      expect(find.textContaining('د.ك'), findsNothing);

      await tester.tap(find.textContaining('اقتراح النقوط'));
      await tester.pumpAndSettle();
      expect(find.textContaining('د.ك'), findsOneWidget);
    });

    testWidgets('شاشة المناسبة تشرح سبب درجة الوجوب', (tester) async {
      final store = await seededStore();
      await pumpScreen(tester, store, const OccasionScreen(occasionId: 'o1'));
      expect(find.textContaining('ليش'), findsOneWidget);
    });

    testWidgets('«أنا حاضر» يسجّل الواجب في الدفتر', (tester) async {
      final store = await seededStore();
      final before = store.ledger.entries.length;
      await pumpScreen(tester, store, const OccasionScreen(occasionId: 'o1'));

      await tester.tap(find.text('أنا حاضر'));
      await tester.pumpAndSettle();

      expect(store.ledger.entries.length, before + 1);
      expect(store.occasion('o1')!.done, isTrue);
    });
  });

  group('صياغة الرسالة', () {
    testWidgets('زر الإرسال معطّل حتى يعتمد المستخدم النص', (tester) async {
      final store = await seededStore();
      await pumpScreen(tester, store, const OccasionScreen(occasionId: 'o1'));

      await tester.tap(find.text('رسالة مناسبة'));
      await tester.pumpAndSettle();

      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'نسخ النص لإرساله بنفسك'),
      );
      expect(button.onPressed, isNull);

      await tester.tap(find.text('راجعت النص وأعتمده'));
      await tester.pumpAndSettle();

      final enabled = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'نسخ النص لإرساله بنفسك'),
      );
      expect(enabled.onPressed, isNotNull);
    });

    testWidgets('تعديل النص بعد الاعتماد يعيد تعطيل الإرسال', (tester) async {
      final store = await seededStore();
      await pumpScreen(tester, store, const OccasionScreen(occasionId: 'o1'));

      await tester.tap(find.text('رسالة مناسبة'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('راجعت النص وأعتمده'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'نص عدّلته بنفسي');
      await tester.pumpAndSettle();

      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'نسخ النص لإرساله بنفسك'),
      );
      expect(button.onPressed, isNull);
    });
  });

  group('الإعدادات', () {
    testWidgets('لا يوجد مفتاح لتفعيل الإرسال الآلي', (tester) async {
      final store = await seededStore();
      await pumpApp(tester, store);
      await tester.tap(find.text('الإعدادات'));
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('الإرسال الآلي للرسائل'),
        200,
      );
      final tile = tester.widget<ListTile>(
        find.widgetWithText(ListTile, 'الإرسال الآلي للرسائل'),
      );
      expect(tile.enabled, isFalse);
    });

    testWidgets('مفاتيح الخصوصية تبدأ مغلقة', (tester) async {
      final store = await seededStore();
      await pumpApp(tester, store);
      await tester.tap(find.text('الإعدادات'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('استيراد جهات الاتصال'),
        200,
      );

      final switchTile = tester.widget<SwitchListTile>(
        find.widgetWithText(SwitchListTile, 'استيراد جهات الاتصال'),
      );
      expect(switchTile.value, isFalse);
    });
  });

  group('رحلة الانضمام', () {
    testWidgets('المستخدم الجديد يبدأ من شاشة الانضمام', (tester) async {
      final store = WajbStore(storage: MemoryStorage(), clock: () => fixedNow);
      await store.load(seedIfEmpty: false);
      await pumpApp(tester, store);

      expect(find.text('ذاكرتك الاجتماعية'), findsOneWidget);
    });

    testWidgets('ثلاث خطوات توصل إلى الشاشة الرئيسية', (tester) async {
      final store = WajbStore(storage: MemoryStorage(), clock: () => fixedNow);
      await store.load(seedIfEmpty: false);
      await pumpApp(tester, store);

      await tester.enterText(find.byType(TextField).first, 'أبو محمد');
      await tester.tap(find.text('التالي'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('التالي'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('يلا نبدأ'));
      await tester.pumpAndSettle();

      expect(find.text('واجبات اليوم'), findsOneWidget);
      expect(store.profile.displayName, 'أبو محمد');
      expect(store.profile.onboarded, isTrue);
    });
  });

  group('الالتقاط الذكي عبر الواجهة', () {
    testWidgets('لصق إعلان يضيف مناسبة بعد مراجعة المستخدم', (tester) async {
      final store = await seededStore();
      await pumpApp(tester, store);
      final before = store.occasions.length;

      await tester.tap(find.byIcon(Icons.document_scanner_outlined));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byType(TextField),
        'انتقل إلى رحمة الله تعالى: ناصر السالم\n'
        'العزاء للرجال في ديوان السالم - كيفان بعد صلاة المغرب\n'
        'مقر النساء: منزل الفقيد - كيفان',
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('استخلاص'));
      await tester.pumpAndSettle();

      expect(find.text('نتيجة الاستخلاص'), findsOneWidget);
      // يظهر مرتين: في نص الإعلان الملصوق وفي حقل المقر المستخلَص.
      expect(find.textContaining('ديوان السالم'), findsNWidgets(2));

      // ensureVisible لا scrollUntilVisible: الشاشة فيها أكثر من عنصر
      // قابل للتمرير (حقل النص نفسه قابل للتمرير).
      await tester.ensureVisible(find.textContaining('احفظ'));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('احفظ'));
      await tester.pumpAndSettle();

      expect(store.occasions.length, before + 1);
    });
  });
}
