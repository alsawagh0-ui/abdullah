/// أدوات معالجة النص العربي المشتركة بين المحركات.
class ArabicText {
  const ArabicText._();

  static final RegExp _tashkeel = RegExp(r'[ً-ْٰـ]');
  static final RegExp _multiSpace = RegExp(r'[ \t ]+');

  /// تحويل الأرقام العربية الهندية والفارسية إلى أرقام لاتينية.
  static String normalizeDigits(String input) {
    final buffer = StringBuffer();
    for (final rune in input.runes) {
      if (rune >= 0x0660 && rune <= 0x0669) {
        buffer.writeCharCode(rune - 0x0660 + 0x30);
      } else if (rune >= 0x06F0 && rune <= 0x06F9) {
        buffer.writeCharCode(rune - 0x06F0 + 0x30);
      } else {
        buffer.writeCharCode(rune);
      }
    }
    return buffer.toString();
  }

  /// تنظيف خفيف يحافظ على شكل الكلمة: إزالة التشكيل والتطويل وتوحيد
  /// المسافات وتحويل الأرقام. يُستخدم للنص الذي سيُعرض للمستخدم.
  static String clean(String input) {
    return normalizeDigits(input)
        .replaceAll(_tashkeel, '')
        .replaceAll('‏', '')
        .replaceAll('‎', '')
        .replaceAll(_multiSpace, ' ')
        .trim();
  }

  /// تطبيع صارم للمطابقة فقط: توحيد الهمزات والألف المقصورة والتاء
  /// المربوطة. لا يُعرض ناتجه للمستخدم.
  static String fold(String input) {
    return clean(input)
        .replaceAll(RegExp('[أإآٱ]'), 'ا')
        .replaceAll('ى', 'ي')
        .replaceAll('ة', 'ه')
        .replaceAll('ؤ', 'و')
        .replaceAll('ئ', 'ي')
        .replaceAll('ء', '');
  }

  /// هل يحتوي النص على أي من الكلمات المفتاحية (بعد التطبيع)؟
  static bool containsAny(String haystack, List<String> needles) {
    final folded = fold(haystack);
    for (final needle in needles) {
      if (folded.contains(fold(needle))) return true;
    }
    return false;
  }

  /// إزالة الألقاب والدعوات الشائعة الملتصقة بالأسماء في إعلانات النعي.
  static const List<String> honorifics = <String>[
    'المرحوم',
    'المرحومة',
    'المغفور له',
    'المغفور لها',
    'الفقيد',
    'الفقيدة',
    'رحمه الله',
    'رحمها الله',
    'تغمده الله بواسع رحمته',
    'تغمدها الله بواسع رحمته',
    'طيب الله ثراه',
    'الشيخ',
    'السيد',
    'السيدة',
    'الأستاذ',
    'الدكتور',
    'المهندس',
    'الحاج',
    'الحاجة',
  ];

  static String stripHonorifics(String name) {
    var out = clean(name);
    for (final word in honorifics) {
      out = out.replaceAll(word, ' ');
    }
    return out.replaceAll(_multiSpace, ' ').trim();
  }
}
