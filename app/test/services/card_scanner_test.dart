import 'package:flutter_test/flutter_test.dart';
import 'package:wajb/engines/capture_engine.dart';
import 'package:wajb/models/occasion.dart';
import 'package:wajb/services/card_scanner.dart';

/// ناتج استخلاص ضوئي واقعي: أسطر فارغة، مسافات زائدة، وضوضاء من حواف
/// الصورة بمحرف واحد.
const String rawOcrOutput = '''
|

إنا لله وإنا إليه راجعون

انتقل   إلى رحمة الله تعالى:  سالم عبدالله المطيري

العزاء للرجال في ديوان المطيري - الرميثية قطعة 5   بعد صلاة العصر
مقر النساء:  منزل الفقيد - الرميثية قطعة 3

.
للتواصل: 99887766

''';

void main() {
  group('تنظيف ناتج الاستخلاص الضوئي', () {
    test('يحذف الأسطر الفارغة والمسافات الزائدة', () {
      final cleaned = OcrTextCleaner.clean(rawOcrOutput);
      expect(cleaned.contains('\n\n'), isFalse);
      expect(cleaned.contains('   '), isFalse);
    });

    test('يحذف أسطر الضوضاء ذات المحرف الواحد', () {
      final cleaned = OcrTextCleaner.clean(rawOcrOutput);
      for (final line in cleaned.split('\n')) {
        expect(line.length, greaterThan(1));
      }
    });

    test('يحافظ على كل الأسطر ذات المعنى', () {
      final cleaned = OcrTextCleaner.clean(rawOcrOutput);
      expect(cleaned, contains('سالم عبدالله المطيري'));
      expect(cleaned, contains('ديوان المطيري'));
      expect(cleaned, contains('منزل الفقيد'));
      expect(cleaned, contains('99887766'));
    });

    test('النص الفارغ لا يسبب انهياراً', () {
      expect(OcrTextCleaner.clean(''), '');
      expect(OcrTextCleaner.clean('   \n\n  '), '');
    });
  });

  group('التكامل: من الصورة إلى مسودة مناسبة', () {
    test('ناتج ضوئي واقعي يُحلَّل إلى حقول صحيحة', () {
      final cleaned = OcrTextCleaner.clean(rawOcrOutput);
      final result = const CaptureEngine().parse(cleaned);

      expect(result.type?.value, OccasionType.condolence);
      expect(result.subjectName?.value, contains('سالم'));
      expect(result.menVenue?.value.title, contains('ديوان المطيري'));
      expect(result.menVenue?.value.area, 'الرميثية');
      expect(result.womenVenue?.value.title, contains('منزل الفقيد'));
      expect(result.menVenue?.value.prayerAnchor, PrayerAnchor.asr);
      expect(result.contactPhone?.value, '99887766');
    });

    test('النص غير المنظَّف يبقى قابلاً للتحليل (تنظيف دفاعي فقط)', () {
      final result = const CaptureEngine().parse(rawOcrOutput);
      expect(result.type?.value, OccasionType.condolence);
    });
  });

  group('بوابات الاستخلاص', () {
    test('المحرك غير المتاح لا يعيد نصاً', () async {
      const recognizer = UnavailableCardRecognizer();
      expect(recognizer.isAvailable, isFalse);
      expect(await recognizer.recognize('/any/path.jpg'), isNull);
    });

    test('المحرك الصوري يسجّل ما طُلب منه', () async {
      final recognizer = FakeCardRecognizer('نص البطاقة');
      final text = await recognizer.recognize('/tmp/card.jpg');
      expect(text, 'نص البطاقة');
      expect(recognizer.requests.single, '/tmp/card.jpg');
    });

    test('منتقي الصور الصوري يسجّل المصدر المطلوب', () async {
      final picker = FakeCardImagePicker('/tmp/card.jpg');
      await picker.pickImage(CardImageSource.camera);
      await picker.pickImage(CardImageSource.gallery);
      expect(picker.requests, [
        CardImageSource.camera,
        CardImageSource.gallery,
      ]);
    });
  });
}
