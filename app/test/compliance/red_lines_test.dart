import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:wajb/models/occasion.dart';
import 'package:wajb/models/person.dart';
import 'package:wajb/models/settings.dart';

/// اختبارات امتثال للخطوط الحمراء التصميمية في وثيقة المشروع.
/// هذه ليست اختبارات وظيفية بل حراسة على القيود التي لا يجوز كسرها لاحقاً.
void main() {
  final sources = Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList();

  String codeOf(File file) {
    // تجاهل أسطر التعليقات: القيود مذكورة فيها نصاً بحكم التوثيق.
    return file
        .readAsLinesSync()
        .where((line) => !line.trimLeft().startsWith('//'))
        .join('\n');
  }

  group('لا تصنيف قبلي أو طائفي أو مناطقي', () {
    test('لا يوجد أي حقل من هذا النوع في الشيفرة', () {
      const banned = [
        'tribe',
        'tribal',
        'sect',
        'sectarian',
        'ethnicity',
        'قبيلة',
        'قبلي',
        'طائفة',
        'طائفي',
        'مذهب',
      ];
      for (final file in sources) {
        final code = codeOf(file);
        for (final word in banned) {
          expect(
            code.contains(word),
            isFalse,
            reason: 'ظهر مصطلح ممنوع «$word» في ${file.path}',
          );
        }
      }
    });

    test('نموذج الشخص لا يحمل إلا حقولاً وظيفية', () {
      final json = Person(
        id: 'p1',
        displayName: 'اسم',
        circle: SocialCircle.family,
        closeness: 50,
      ).toJson();
      expect(
        json.keys.toSet(),
        {
          'id',
          'displayName',
          'circle',
          'closeness',
          'gender',
          'kinship',
          'phone',
          'areaHint',
          'lastInteraction',
        },
      );
    });
  });

  group('لا نشر عام ولا ترتيب للأشخاص', () {
    test('لا توجد في الشيفرة مفاهيم الشبكات الاجتماعية العامة', () {
      const banned = [
        'follower',
        'followers',
        'publicFeed',
        'leaderboard',
        'likeCount',
        'المتابعون',
        'قائمة الأوائل',
      ];
      for (final file in sources) {
        final code = codeOf(file);
        for (final word in banned) {
          expect(
            code.contains(word),
            isFalse,
            reason: 'ظهر مفهوم ممنوع «$word» في ${file.path}',
          );
        }
      }
    });

    test('لا حقل تقييم أو ترتيب داخل نموذج الشخص', () {
      final json = Person(
        id: 'p1',
        displayName: 'اسم',
        circle: SocialCircle.family,
        closeness: 50,
      ).toJson();
      for (final key in ['rank', 'score', 'rating', 'points']) {
        expect(json.containsKey(key), isFalse);
      }
    });
  });

  group('الخصوصية الافتراضية هي الأشد تحفّظاً', () {
    test('كل مفاتيح المشاركة مغلقة افتراضياً', () {
      const privacy = PrivacySettings();
      expect(privacy.shareLedger, isFalse);
      expect(privacy.allowFamilyCoordination, isFalse);
      expect(privacy.allowContactImport, isFalse);
      expect(privacy.allowAnonymousDiagnostics, isFalse);
      expect(privacy.autoSendMessages, isFalse);
    });

    test('ملف المستخدم الافتراضي يحترم مواقيت الصلاة ولم يُنشر بعد', () {
      const profile = UserProfile(displayName: 'اسم', gender: Gender.male);
      expect(profile.respectPrayerTimes, isTrue);
      expect(profile.onboarded, isFalse);
      expect(profile.privacy.shareLedger, isFalse);
    });

    test('استرجاع إعدادات ناقصة من JSON يعود للأشد تحفّظاً', () {
      final restored = PrivacySettings.fromJson(const {});
      expect(restored.shareLedger, isFalse);
      expect(restored.allowContactImport, isFalse);
    });
  });

  group('منع الإرسال الآلي على مستوى النموذج', () {
    test('لا يمكن إنشاء إعدادات تسمح بالإرسال الآلي', () {
      expect(
        () => PrivacySettings(autoSendMessages: true),
        throwsA(isA<AssertionError>()),
      );
    });

    test('copyWith لا يفتح باباً خلفياً للإرسال الآلي', () {
      const privacy = PrivacySettings();
      final copy = privacy.copyWith(shareLedger: true);
      expect(copy.autoSendMessages, isFalse);
    });
  });

  group('الفصل بين المقرين حقل بيانات أساسي', () {
    test('نموذج المناسبة يحمل المقرين منفصلين في التسلسل', () {
      final json = Occasion(
        id: 'o1',
        personId: 'p1',
        type: OccasionType.condolence,
        title: 'عزاء',
        startsAt: DateTime(2026, 5, 10),
        menVenue: const Venue(title: 'ديوان'),
        womenVenue: const Venue(title: 'منزل'),
      ).toJson();
      expect(json.containsKey('menVenue'), isTrue);
      expect(json.containsKey('womenVenue'), isTrue);
      expect(json['menVenue'], isNot(json['womenVenue']));
    });

    test('الواجهة تختار المقر الصحيح بحسب المستخدم', () {
      final occasion = Occasion(
        id: 'o1',
        personId: 'p1',
        type: OccasionType.condolence,
        title: 'عزاء',
        startsAt: DateTime(2026, 5, 10),
        menVenue: const Venue(title: 'ديوان الرجال'),
        womenVenue: const Venue(title: 'مقر النساء'),
      );
      expect(occasion.venueFor(Gender.male)?.title, 'ديوان الرجال');
      expect(occasion.venueFor(Gender.female)?.title, 'مقر النساء');
    });

    test('عند غياب أحد المقرين يُعرض المتاح بدل الفراغ', () {
      final occasion = Occasion(
        id: 'o1',
        personId: 'p1',
        type: OccasionType.condolence,
        title: 'عزاء',
        startsAt: DateTime(2026, 5, 10),
        menVenue: const Venue(title: 'ديوان الرجال'),
      );
      expect(occasion.venueFor(Gender.female)?.title, 'ديوان الرجال');
    });
  });

  group('أيام العزاء ثلاثة بحسب العرف', () {
    test('المدة الافتراضية للعزاء ثلاثة أيام', () {
      expect(OccasionType.condolence.defaultDurationDays, 3);
    });

    test('اليوم الثالث ما زال ضمن نافذة الواجب والرابع خارجها', () {
      final start = DateTime(2026, 5, 10, 16);
      final occasion = Occasion(
        id: 'o1',
        personId: 'p1',
        type: OccasionType.condolence,
        title: 'عزاء',
        startsAt: start,
      );
      expect(occasion.isActiveAt(DateTime(2026, 5, 12, 20)), isTrue);
      expect(occasion.dayIndexAt(DateTime(2026, 5, 12, 20)), 3);
      expect(occasion.isActiveAt(DateTime(2026, 5, 14, 9)), isFalse);
    });
  });
}
