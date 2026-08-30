/// مصدر صورة بطاقة الإعلان.
enum CardImageSource { camera, gallery }

/// التقاط صورة البطاقة من الكاميرا أو المعرض.
abstract class CardImagePicker {
  Future<String?> pickImage(CardImageSource source);
}

/// استخلاص النص العربي من صورة البطاقة.
///
/// ملاحظة مهمة عن الواقع التقني: محرك ML Kit من جوجل — الخيار الافتراضي
/// في فلاتر — **لا يدعم النص العربي** (يدعم اللاتيني والصيني والياباني
/// والكوري والديفاناغاري فقط). لذلك يعتمد التطبيق على Tesseract مع
/// بيانات اللغة العربية محلياً على الجهاز، حفاظاً على مبدأ الستر: صورة
/// بطاقة العزاء لا تغادر الجهاز إلى أي خدمة سحابية.
abstract class CardTextRecognizer {
  /// هل المحرك متاح على هذه المنصة؟
  bool get isAvailable;

  /// يعيد النص المستخلَص، أو null إذا تعذّر.
  Future<String?> recognize(String imagePath);
}

/// محرك غير متاح — يُستخدم في الاختبارات وعلى الويب وسطح المكتب.
class UnavailableCardRecognizer implements CardTextRecognizer {
  const UnavailableCardRecognizer();

  @override
  bool get isAvailable => false;

  @override
  Future<String?> recognize(String imagePath) async => null;
}

/// محرك صوري يعيد نصاً محدداً — للاختبارات.
class FakeCardRecognizer implements CardTextRecognizer {
  FakeCardRecognizer(this.text, {this.available = true});

  final String? text;
  final bool available;
  final List<String> requests = <String>[];

  @override
  bool get isAvailable => available;

  @override
  Future<String?> recognize(String imagePath) async {
    requests.add(imagePath);
    return text;
  }
}

class FakeCardImagePicker implements CardImagePicker {
  FakeCardImagePicker(this.path);

  final String? path;
  final List<CardImageSource> requests = <CardImageSource>[];

  @override
  Future<String?> pickImage(CardImageSource source) async {
    requests.add(source);
    return path;
  }
}

/// تنظيف ناتج الاستخلاص الضوئي قبل تمريره لمحرك الالتقاط.
///
/// المحركات الضوئية تُدخل أسطراً فارغة ومسافات زائدة ومحارف مقطوعة؛
/// هذا التنظيف يرفع دقة التحليل اللاحق.
class OcrTextCleaner {
  const OcrTextCleaner._();

  static String clean(String raw) {
    final lines = raw
        .split(RegExp(r'[\r\n]+'))
        .map((line) => line.replaceAll(RegExp(r'[ \t]+'), ' ').trim())
        // أسطر من محرف واحد غالباً ضوضاء من حواف الصورة.
        .where((line) => line.length > 1)
        .toList();
    return lines.join('\n');
  }
}
