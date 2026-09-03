import 'package:almunjez/app/app.dart';
import 'package:almunjez/core/api/local/local_api.dart';
import 'package:almunjez/core/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

/// Boots the real app on the local engine and walks the critical path:
/// sign in → home → open task → «سأتولى المهمة» → «تم الإنجاز».
void main() {
  setUpAll(() async {
    await initializeDateFormatting('ar');
    await initializeDateFormatting('en');
  });

  Future<LocalApi> pumpApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1170, 2532); // iPhone 14 Pro
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final api = LocalApi(MemoryStore());
    await tester.pumpWidget(ProviderScope(overrides: [apiProvider.overrideWithValue(api)], child: const AlMunjezApp()));
    await tester.pumpAndSettle();
    return api;
  }

  testWidgets('welcome → demo sign-in → home shows greeting and groups', (tester) async {
    await pumpApp(tester);
    expect(find.text('تسجيل الدخول'), findsWidgets);
    await tester.tap(find.text('تخطٍّ'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('تجربة سريعة بحساب تجريبي'));
    await tester.pumpAndSettle();
    expect(find.textContaining('عبدالله'), findsWidgets);
    expect(find.text('البيت'), findsWidgets);
    // pending join request from the seed is surfaced on home
    expect(find.textContaining('نورة'), findsWidgets);
    await tester.scrollUntilVisible(find.text('شركة الأفق'), 200, scrollable: find.byType(Scrollable).first);
    expect(find.text('شركة الأفق'), findsWidgets);
  });

  testWidgets('claim an open task from its detail screen, then complete it', (tester) async {
    final api = await pumpApp(tester);
    await tester.tap(find.text('تخطٍّ'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('تجربة سريعة بحساب تجريبي'));
    await tester.pumpAndSettle();

    // open the family group from the groups tab
    await tester.tap(find.text('المجموعات'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'البيت'));
    await tester.pumpAndSettle();
    expect(find.text('شراء الخبز'), findsOneWidget);
    await tester.tap(find.text('شراء الخبز'));
    await tester.pumpAndSettle();

    // state header: new — available, and the big claim button
    expect(find.textContaining('متاحة'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'سأتولى المهمة'));
    await tester.pumpAndSettle();
    expect(find.text('قيد التنفيذ'), findsWidgets);
    expect(find.widgetWithText(FilledButton, 'تم الإنجاز'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'تم الإنجاز'));
    await tester.pumpAndSettle();
    expect(find.text('مكتملة'), findsWidgets);

    final task = (await api.search('شراء الخبز')).tasks.single;
    expect(task.completedBy, DemoSeed.abdullah);
    expect((await api.taskActivity(task.id)).map((e) => e.action), containsAllInOrder(['task.claimed', 'task.completed']));
  });

  testWidgets('approve a submitted completion from the group', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('تخطٍّ'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('تجربة سريعة بحساب تجريبي'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('المجموعات'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'البيت'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('ترتيب المخزن'), 200, scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('ترتيب المخزن'));
    await tester.pumpAndSettle();
    expect(find.text('بانتظار الاعتماد'), findsWidgets);
    await tester.tap(find.widgetWithText(FilledButton, 'اعتماد'));
    await tester.pumpAndSettle();
    expect(find.text('مكتملة'), findsWidgets);
  });

  testWidgets('join requests screen accepts a pending request', (tester) async {
    final api = await pumpApp(tester);
    await tester.tap(find.text('تخطٍّ'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('تجربة سريعة بحساب تجريبي'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('نورة').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('قبول'));
    await tester.pumpAndSettle();
    expect(find.text('لا طلبات معلقة'), findsOneWidget);
    final home = (await api.myGroups()).firstWhere((g) => g.group.name == 'البيت');
    expect((await api.members(home.group.id)).map((m) => m.user.displayName), contains('نورة'));
  });

  testWidgets('notification settings (G3): toggling a category off persists through the API', (tester) async {
    final api = await pumpApp(tester);
    await tester.tap(find.text('تخطٍّ'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('تجربة سريعة بحساب تجريبي'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('homeProfileAvatar'))); // home → profile
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.settings_outlined)); // profile → settings
    await tester.pumpAndSettle();
    await tester.tap(find.text('إعدادات الإشعارات'));
    await tester.pumpAndSettle();

    expect(find.text('التعليقات'), findsOneWidget);
    expect((await api.notificationPreferences())['task.comment'], isNull, reason: 'both on by default, no row needed');

    await tester.tap(find.widgetWithText(SwitchListTile, 'التعليقات'));
    await tester.pumpAndSettle();

    expect((await api.notificationPreferences())['task.comment']!.push, isFalse);
    final sw = tester.widget<SwitchListTile>(find.widgetWithText(SwitchListTile, 'التعليقات'));
    expect(sw.value, isFalse);
  });
}
