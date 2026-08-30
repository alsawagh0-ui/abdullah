import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wajb/theme/app_theme.dart';
import 'package:yaml/yaml.dart';

/// اختبارات الخط المدمج: التطبيق عربي أولاً، فلا يُترك شكل النص لخط
/// النظام الذي يختلف بين iOS وإصدارات Android.
void main() {
  group('الخط المدمج', () {
    test('ملفات الخط موجودة فعلياً مع نص الرخصة', () {
      for (final name in [
        'Cairo-Regular',
        'Cairo-SemiBold',
        'Cairo-Bold',
      ]) {
        final file = File('assets/fonts/$name.ttf');
        expect(file.existsSync(), isTrue, reason: 'ملف $name مفقود');
        expect(file.lengthSync(), greaterThan(10000));
      }
      final license = File('assets/fonts/OFL.txt');
      expect(license.existsSync(), isTrue);
      expect(license.readAsStringSync(), contains('SIL Open Font License'));
    });

    test('ملفات الخط صالحة (توقيع TrueType)', () {
      for (final name in [
        'Cairo-Regular',
        'Cairo-SemiBold',
        'Cairo-Bold',
      ]) {
        final bytes = File('assets/fonts/$name.ttf').readAsBytesSync();
        expect(
          bytes.sublist(0, 4),
          <int>[0x00, 0x01, 0x00, 0x00],
          reason: '$name ليس ملف TrueType صالحاً',
        );
      }
    });

    test('الخط مسجَّل في pubspec بأوزانه الثلاثة', () {
      final pubspec = loadYaml(File('pubspec.yaml').readAsStringSync());
      final fonts = pubspec['flutter']['fonts'] as YamlList;
      final cairo = fonts.firstWhere((f) => f['family'] == 'Cairo');
      final weights = (cairo['fonts'] as YamlList)
          .map((f) => f['weight'] as int)
          .toList();
      expect(weights, containsAll(<int>[400, 600, 700]));
    });

    test('كل الأنماط تستخدم الخط المدمج', () {
      for (final theme in [
        WajbTheme.light(),
        WajbTheme.dark(),
        WajbTheme.light(elderMode: true),
        WajbTheme.light(solemnMode: true),
        WajbTheme.dark(elderMode: true, solemnMode: true),
      ]) {
        expect(theme.textTheme.bodyMedium?.fontFamily, WajbTheme.fontFamily);
        expect(theme.textTheme.titleLarge?.fontFamily, WajbTheme.fontFamily);
      }
    });

    test('أنساق الأزرار ترث الخط المدمج ولا تُسقط العائلة', () {
      for (final theme in [
        WajbTheme.light(),
        WajbTheme.light(elderMode: true),
        WajbTheme.dark(solemnMode: true),
      ]) {
        final filled =
            theme.filledButtonTheme.style?.textStyle?.resolve(<WidgetState>{});
        final outlined = theme.outlinedButtonTheme.style?.textStyle
            ?.resolve(<WidgetState>{});
        expect(filled?.fontFamily, WajbTheme.fontFamily);
        expect(outlined?.fontFamily, WajbTheme.fontFamily);
      }
    });

    testWidgets('نص الزر يُرسم بحجم غير صفري', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: WajbTheme.light(),
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              body: Center(
                child: FilledButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.how_to_reg_outlined),
                  label: const Text('أنا حاضر'),
                ),
              ),
            ),
          ),
        ),
      );
      final size = tester.getSize(find.text('أنا حاضر'));
      expect(size.width, greaterThan(20));
      expect(size.height, greaterThan(10));
    });

    testWidgets('النص المعروض يرث الخط المدمج', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: WajbTheme.light(),
          home: const Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(body: Text('عظّم الله أجرك')),
          ),
        ),
      );
      final text = tester.widget<Text>(find.text('عظّم الله أجرك'));
      final style = DefaultTextStyle.of(
        tester.element(find.text('عظّم الله أجرك')),
      ).style;
      expect(text.style?.fontFamily ?? style.fontFamily, WajbTheme.fontFamily);
    });
  });
}
