import 'package:flutter_test/flutter_test.dart';
import 'package:wajb/engines/message_engine.dart';
import 'package:wajb/models/occasion.dart';
import 'package:wajb/models/person.dart';

Person person({int closeness = 90, String name = 'عبدالله'}) => Person(
      id: 'p1',
      displayName: name,
      circle: SocialCircle.family,
      closeness: closeness,
    );

void main() {
  const engine = MessageEngine();
  const dispatcher = MessageDispatcher();

  group('بنك العبارات', () {
    test('لكل نوع مناسبة صياغة بالفصحى وباللهجة', () {
      for (final type in OccasionType.values) {
        for (final tone in MessageTone.values) {
          final draft = engine.draft(type: type, person: person(), tone: tone);
          expect(draft.text.trim(), isNotEmpty, reason: 'فارغ عند $type');
        }
      }
    });

    test('عبارة العزاء لا تحمل أي تهنئة', () {
      final draft = engine.draft(
        type: OccasionType.condolence,
        person: person(),
      );
      for (final banned in ['مبروك', 'تهانينا', 'عقبال']) {
        expect(draft.text.contains(banned), isFalse);
      }
    });

    test('عبارة الفرح لا تحمل صيغة تعزية', () {
      final draft =
          engine.draft(type: OccasionType.wedding, person: person());
      for (final banned in ['عظم الله أجرك', 'البقاء لله', 'رحمه الله']) {
        expect(draft.text.contains(banned), isFalse);
      }
    });

    test('عبارة الزميل تختلف عن عبارة ابن العم', () {
      final close = engine.draft(
        type: OccasionType.condolence,
        person: person(closeness: 95),
      );
      final distant = engine.draft(
        type: OccasionType.condolence,
        person: person(closeness: 20),
      );
      expect(close.text, isNot(distant.text));
    });

    test('الاسم يحل محل المتغير ولا يبقى قالباً خاماً', () {
      final draft = engine.draft(
        type: OccasionType.condolence,
        person: person(name: 'فهد'),
      );
      expect(draft.text.contains('{name}'), isFalse);
      final variants = engine.variantsFor(
        type: OccasionType.condolence,
        person: person(name: 'فهد'),
      );
      expect(variants.any((v) => v.text.contains('فهد')), isTrue);
    });

    test('«صياغة أخرى» تدور بين البدائل بلا خروج عن الحدود', () {
      for (var i = 0; i < 20; i++) {
        final draft = engine.draft(
          type: OccasionType.wedding,
          person: person(),
          variant: i,
        );
        expect(draft.text, isNotEmpty);
      }
    });
  });

  group('منع الإرسال الآلي — خط أحمر', () {
    test('المسودة تبدأ غير معتمَدة', () {
      final draft =
          engine.draft(type: OccasionType.condolence, person: person());
      expect(draft.approved, isFalse);
    });

    test('الإرسال بلا مصادقة بشرية يُرفض', () {
      final draft =
          engine.draft(type: OccasionType.condolence, person: person());
      expect(
        () => dispatcher.send(draft),
        throwsA(isA<AutoSendBlockedException>()),
      );
    });

    test('الإرسال بعد المصادقة يمر بالنص المعتمد', () {
      final draft = engine
          .draft(type: OccasionType.condolence, person: person())
          .approve('عظم الله أجرك');
      expect(dispatcher.send(draft), 'عظم الله أجرك');
    });

    test('أي تعديل بعد المصادقة يُبطلها', () {
      final approved = engine
          .draft(type: OccasionType.condolence, person: person())
          .approve('نص معتمد');
      final edited = approved.edit('نص جديد');
      expect(edited.approved, isFalse);
      expect(
        () => dispatcher.send(edited),
        throwsA(isA<AutoSendBlockedException>()),
      );
    });

    test('الرسالة الفارغة لا تُرسل حتى لو اعتُمدت', () {
      final draft = engine
          .draft(type: OccasionType.condolence, person: person())
          .approve('   ');
      expect(
        () => dispatcher.send(draft),
        throwsA(isA<AutoSendBlockedException>()),
      );
    });
  });
}
