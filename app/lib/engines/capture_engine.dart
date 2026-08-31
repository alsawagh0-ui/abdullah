import '../models/hijri_date.dart';
import '../models/occasion.dart';
import 'arabic_text.dart';

/// حقل مستخلَص مع درجة ثقة، حتى تتمكن الواجهة من إبراز ما يحتاج مراجعة
/// بشرية بدل تمريره بصمت.
class CapturedField<T> {
  const CapturedField(this.value, {this.confidence = 1.0, this.rawText});

  final T value;
  final double confidence;
  final String? rawText;
}

/// ناتج المحرك الأول — الالتقاط الذكي.
///
/// المحرك لا يحفظ شيئاً بنفسه؛ يعيد مسودة يراجعها المستخدم ويصادق عليها.
/// حلقة التصحيح البشرية هذه إلزامية في التصميم لأن دقة قراءة اللهجة
/// والصياغات التقليدية لا تبلغ 100%.
class CaptureResult {
  CaptureResult({
    required this.type,
    required this.subjectName,
    required this.menVenue,
    required this.womenVenue,
    required this.contactPhone,
    required this.hijriDate,
    required this.gregorianDate,
    required this.durationDays,
    required this.warnings,
    required this.rawText,
  });

  final CapturedField<OccasionType>? type;
  final CapturedField<String>? subjectName;
  final CapturedField<Venue>? menVenue;
  final CapturedField<Venue>? womenVenue;
  final CapturedField<String>? contactPhone;
  final CapturedField<HijriDate>? hijriDate;
  final CapturedField<DateTime>? gregorianDate;
  final CapturedField<int>? durationDays;
  final List<String> warnings;
  final String rawText;

  /// الحقول التي لم يُعثر عليها ويجب أن تسأل عنها الواجهة صراحةً.
  List<String> get missingFields {
    return <String>[
      if (type == null) 'نوع المناسبة',
      if (subjectName == null) 'الاسم',
      if (menVenue == null) 'مقر الرجال',
      if (womenVenue == null) 'مقر النساء',
      if (gregorianDate == null && hijriDate == null) 'التاريخ',
    ];
  }

  /// نسبة اكتمال الاستخلاص (0..1) — مؤشر الجودة المعروض للمستخدم.
  double get confidence {
    const weights = <String, double>{
      'type': 0.25,
      'name': 0.25,
      'men': 0.15,
      'women': 0.15,
      'date': 0.15,
      'phone': 0.05,
    };
    var total = 0.0;
    total += (type?.confidence ?? 0) * weights['type']!;
    total += (subjectName?.confidence ?? 0) * weights['name']!;
    total += (menVenue?.confidence ?? 0) * weights['men']!;
    total += (womenVenue?.confidence ?? 0) * weights['women']!;
    total += ((gregorianDate ?? hijriDate) != null ? 1.0 : 0.0) *
        weights['date']!;
    total += (contactPhone?.confidence ?? 0) * weights['phone']!;
    return double.parse(total.toStringAsFixed(4));
  }

  /// أقل من هذا الحد تُعرض المسودة في وضع «راجع قبل الحفظ» الموسّع.
  bool get needsReview => confidence < 0.75 || missingFields.isNotEmpty;
}

/// المحرك الأول: يحوّل نص إعلان مناسبة (من صورة بعد استخلاص النص، أو من
/// رسالة واتساب، أو من إملاء صوتي) إلى بيانات منظّمة.
///
/// مصمَّم للصياغات الكويتية التقليدية: «انتقل إلى رحمة الله تعالى»،
/// «العزاء للرجال في ديوان...»، «مقر النساء...»، «بعد صلاة العصر».
class CaptureEngine {
  const CaptureEngine();

  static const Map<OccasionType, List<String>> _typeKeywords = {
    OccasionType.condolence: [
      'انتقل إلى رحمة الله',
      'انتقلت إلى رحمة الله',
      'إنا لله وإنا إليه راجعون',
      'المرحوم',
      'المرحومة',
      'المغفور له',
      'الفقيد',
      'الفقيدة',
      'وفاة',
      'نعي',
      'العزاء',
      'مقبرة',
      'الصلاة عليه',
      'الصلاة عليها',
      'البقاء لله',
    ],
    OccasionType.wedding: [
      'زفاف',
      'عرس',
      'زواج',
      'عقد قران',
      'ملكة',
      'ملجة',
      'حفل الزواج',
      'دعوة زواج',
    ],
    OccasionType.newborn: [
      'مولود',
      'المولودة',
      'بشارة',
      'بشرى',
      'رزق بمولود',
      'رزقنا الله',
      'قدوم',
    ],
    OccasionType.illness: [
      'عملية',
      'المستشفى',
      'شفاه الله',
      'شفاها الله',
      'يرقد',
      'وعكة',
      'زيارة مريض',
    ],
    OccasionType.graduation: ['تخرج', 'التخرج', 'تخرجه', 'تخرجها'],
    OccasionType.promotion: ['ترقية', 'ترقيته', 'تعيينه', 'منصب'],
    OccasionType.travel: ['سلامة الوصول', 'عودة', 'مسافر', 'سلامات'],
    OccasionType.eid: ['معايدة', 'عيد الفطر', 'عيد الأضحى', 'تهنئة العيد'],
    OccasionType.diwaniya: ['ديوانية', 'عزيمة', 'غبقة', 'استقبال'],
  };

  /// ترتيب الأولوية عند تطابق أكثر من نوع: الأثقل اجتماعياً أولاً.
  static const List<OccasionType> _typePriority = [
    OccasionType.condolence,
    OccasionType.wedding,
    OccasionType.newborn,
    OccasionType.illness,
    OccasionType.graduation,
    OccasionType.promotion,
    OccasionType.eid,
    OccasionType.travel,
    OccasionType.diwaniya,
  ];

  /// مناطق كويتية شائعة تُستخدم لتعبئة حقل المنطقة في المقر.
  static const List<String> kuwaitAreas = [
    'السالمية', 'حولي', 'الجابرية', 'بيان', 'مشرف', 'سلوى', 'الرميثية',
    'الشعب', 'القادسية', 'كيفان', 'الشامية', 'الروضة', 'العديلية',
    'الخالدية', 'الفيحاء', 'النزهة', 'الدسمة', 'الشويخ', 'السرة',
    'قرطبة', 'اليرموك', 'الزهراء', 'العارضية', 'الفروانية', 'الرقة',
    'الفنطاس', 'المهبولة', 'أبو حليفة', 'المنقف', 'الفحيحيل',
    'صباح السالم', 'المسيلة', 'أبو فطيرة', 'الفنيطيس', 'جابر العلي',
    'الأحمدي', 'الجهراء', 'سعد العبدالله', 'صباح الأحمد',
    'مبارك الكبير', 'القرين', 'العدان', 'صباح الناصر', 'الرابية',
    'الأندلس', 'إشبيلية', 'ضاحية عبدالله المبارك', 'غرناطة', 'الصليبخات',
    'الدعية', 'دسمان', 'الشرق', 'المرقاب', 'بنيد القار', 'كيفان',
  ];

  static const List<String> _menMarkers = [
    'الرجال',
    'للرجال',
    'رجال',
    'الشباب',
  ];

  static const List<String> _womenMarkers = [
    'النساء',
    'للنساء',
    'نساء',
    'الحريم',
  ];

  static final RegExp _phoneRe =
      RegExp(r'(?:\+?965[\s\-]?)?([2569]\d{7})\b');
  static final RegExp _gregorianRe =
      RegExp(r'\b(\d{1,2})[/\-\.](\d{1,2})[/\-\.](\d{4})\b');
  // ملاحظة: التطبيع يحذف التطويل، فتصير «هـ» حرف «ه» مفرداً.
  static final RegExp _hijriNumericRe =
      RegExp(r'(\d{4})[/\-](\d{1,2})[/\-](\d{1,2})\s*(?:هـ|ه|هجري)');
  static final RegExp _hijriWordyRe =
      RegExp(r'\b(\d{1,2})\s+([؀-ۿ]+(?:\s+[؀-ۿ]+)?)\s+(\d{4})\s*(?:هـ|ه|هجري)?');
  static final RegExp _durationRe =
      RegExp(r'(?:لمدة|مدة)\s+(يوم|يومين|ثلاثة|ثلاث|أربعة|خمسة|\d+)');

  CaptureResult parse(String input, {DateTime? referenceDate}) {
    final now = referenceDate ?? DateTime.now();
    final text = ArabicText.clean(input);
    final lines = text
        .split(RegExp(r'[\n\r]+'))
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    final warnings = <String>[];

    final type = _detectType(text);
    if (type == null) {
      warnings.add('لم يُتعرّف على نوع المناسبة — يرجى تحديده يدوياً.');
    }

    final name = _extractName(text, type?.value);
    if (name == null) {
      warnings.add('لم يُستخلص الاسم بوضوح — راجع الحقل قبل الحفظ.');
    }

    final defaultAnchor = _detectPrayerAnchor(text);
    final menVenue = _extractVenue(lines, _menMarkers, defaultAnchor);
    final womenVenue = _extractVenue(lines, _womenMarkers, defaultAnchor);

    if (menVenue == null || womenVenue == null) {
      warnings.add(
        'مقر الرجال ومقر النساء حقلان إلزاميان؛ أكمل الناقص منهما يدوياً.',
      );
    }

    final phone = _extractPhone(text);
    final hijri = _extractHijri(text);
    final gregorian = _extractGregorian(text, now);
    final duration = _extractDuration(text, type?.value);

    if (gregorian == null && hijri != null) {
      warnings.add('التاريخ الهجري تقريبي حسابياً؛ تأكد من اليوم الميلادي.');
    }

    return CaptureResult(
      type: type,
      subjectName: name,
      menVenue: menVenue,
      womenVenue: womenVenue,
      contactPhone: phone,
      hijriDate: hijri,
      gregorianDate: gregorian,
      durationDays: duration,
      warnings: warnings,
      rawText: text,
    );
  }

  CapturedField<OccasionType>? _detectType(String text) {
    final matches = <OccasionType, int>{};
    for (final entry in _typeKeywords.entries) {
      var hits = 0;
      for (final keyword in entry.value) {
        if (ArabicText.containsAny(text, [keyword])) hits++;
      }
      if (hits > 0) matches[entry.key] = hits;
    }
    if (matches.isEmpty) return null;
    for (final candidate in _typePriority) {
      if (matches.containsKey(candidate)) {
        final hits = matches[candidate]!;
        final confidence = (0.55 + 0.15 * hits).clamp(0.0, 1.0);
        return CapturedField<OccasionType>(candidate, confidence: confidence);
      }
    }
    return null;
  }

  CapturedField<String>? _extractName(String text, OccasionType? type) {
    final patterns = <RegExp>[
      RegExp(r'انتقل(?:ت)?\s+إلى\s+رحمة\s+الله(?:\s+تعالى)?\s*[:،-]?\s*(.+)'),
      RegExp(r'(?:المرحوم|المرحومة|المغفور\s+له|المغفور\s+لها)\s*[:،-]?\s*(.+)'),
      RegExp(r'(?:الفقيد|الفقيدة)\s*[:،-]?\s*(.+)'),
      RegExp(r'(?:زفاف|عرس|زواج|عقد\s+قران)\s*[:،-]?\s*(.+)'),
      RegExp(r'(?:تخرج|ترقية)\s*[:،-]?\s*(.+)'),
      RegExp(r'(?:مولود|بشارة|بشرى)\s*[:،-]?\s*(.+)'),
    ];
    for (final pattern in patterns) {
      final match = pattern.firstMatch(text);
      if (match == null) continue;
      var candidate = match.group(1) ?? '';
      candidate = candidate.split(RegExp(r'[\n،؛,.]')).first;
      candidate = candidate
          .replaceAll(RegExp(r'\b(رحمه|رحمها)\s+الله.*'), '')
          .replaceAll(RegExp(r'(تغمده|تغمدها)\s+الله.*'), '')
          .replaceAll(RegExp(r'(?:وسيشيع|والصلاة|وصلاة|والدفن).*'), '');
      candidate = ArabicText.stripHonorifics(candidate);
      final words = candidate.split(' ').where((w) => w.length > 1).toList();
      if (words.isEmpty) continue;
      final name = words.take(5).join(' ');
      if (name.length < 3) continue;
      final confidence = words.length >= 2 ? 0.9 : 0.6;
      return CapturedField<String>(name,
          confidence: confidence, rawText: match.group(0));
    }
    return null;
  }

  PrayerAnchor? _detectPrayerAnchor(String text) {
    final match =
        RegExp(r'بعد\s+صلاة\s+([؀-ۿ]+)').firstMatch(text);
    if (match == null) return null;
    return PrayerAnchor.tryParse(match.group(1)!);
  }

  CapturedField<Venue>? _extractVenue(
    List<String> lines,
    List<String> markers,
    PrayerAnchor? fallbackAnchor,
  ) {
    for (final line in lines) {
      if (!ArabicText.containsAny(line, markers)) continue;

      // القطع يكون عند كلمة الجنس نفسها لا عند أول شرطة، وإلا ضاع اسم
      // المقر في مثل: «العزاء للرجال في ديوان المطيري - الرميثية».
      var body = line;
      var cutAt = -1;
      var cutLength = 0;
      for (final marker in markers) {
        final idx = body.indexOf(marker);
        if (idx >= 0 && (cutAt < 0 || idx < cutAt)) {
          cutAt = idx;
          cutLength = marker.length;
        }
      }
      if (cutAt >= 0) body = body.substring(cutAt + cutLength);

      final anchor = PrayerAnchor.tryParse(line) ?? fallbackAnchor;
      body = body
          .replaceAll(RegExp(r'بعد\s+صلاة\s+[؀-ۿ]+'), '')
          .replaceFirst(RegExp(r'^[\s:：،\-–—]+'), '')
          .replaceFirst(RegExp(r'^(?:في|ب|بـ)\s+'), '')
          .replaceAll(RegExp(r'[،؛\-–—\s]+$'), '')
          .trim();

      String? area;
      for (final candidate in kuwaitAreas) {
        if (ArabicText.containsAny(body, [candidate])) {
          area = candidate;
          break;
        }
      }

      if (body.isEmpty) {
        if (area == null && anchor == null) continue;
        body = area ?? 'المقر غير محدد';
      }

      final confidence = area != null ? 0.9 : 0.7;
      return CapturedField<Venue>(
        Venue(title: body, area: area, prayerAnchor: anchor),
        confidence: confidence,
        rawText: line,
      );
    }
    return null;
  }

  CapturedField<String>? _extractPhone(String text) {
    final match = _phoneRe.firstMatch(text);
    if (match == null) return null;
    return CapturedField<String>(match.group(1)!, confidence: 0.95);
  }

  CapturedField<HijriDate>? _extractHijri(String text) {
    final numeric = _hijriNumericRe.firstMatch(text);
    if (numeric != null) {
      final y = int.parse(numeric.group(1)!);
      final m = int.parse(numeric.group(2)!);
      final d = int.parse(numeric.group(3)!);
      if (m >= 1 && m <= 12 && d >= 1 && d <= 30) {
        return CapturedField<HijriDate>(HijriDate(y, m, d), confidence: 0.9);
      }
    }
    for (final match in _hijriWordyRe.allMatches(text)) {
      final monthWord = ArabicText.fold(match.group(2)!);
      final monthIndex = HijriDate.monthNames
          .indexWhere((name) => ArabicText.fold(name) == monthWord);
      if (monthIndex < 0) continue;
      final d = int.parse(match.group(1)!);
      final y = int.parse(match.group(3)!);
      if (d < 1 || d > 30 || y < 1300 || y > 1600) continue;
      return CapturedField<HijriDate>(
        HijriDate(y, monthIndex + 1, d),
        confidence: 0.95,
      );
    }
    return null;
  }

  CapturedField<DateTime>? _extractGregorian(String text, DateTime now) {
    final match = _gregorianRe.firstMatch(text);
    if (match != null) {
      final d = int.parse(match.group(1)!);
      final m = int.parse(match.group(2)!);
      final y = int.parse(match.group(3)!);
      if (m >= 1 && m <= 12 && d >= 1 && d <= 31) {
        return CapturedField<DateTime>(DateTime(y, m, d), confidence: 0.95);
      }
    }
    if (ArabicText.containsAny(text, ['اليوم'])) {
      return CapturedField<DateTime>(
        DateTime(now.year, now.month, now.day),
        confidence: 0.7,
      );
    }
    if (ArabicText.containsAny(text, ['غداً', 'غدا', 'بكرة'])) {
      final tomorrow = now.add(const Duration(days: 1));
      return CapturedField<DateTime>(
        DateTime(tomorrow.year, tomorrow.month, tomorrow.day),
        confidence: 0.7,
      );
    }
    return null;
  }

  CapturedField<int>? _extractDuration(String text, OccasionType? type) {
    final match = _durationRe.firstMatch(text);
    if (match != null) {
      final token = match.group(1)!;
      final value = switch (token) {
        'يوم' => 1,
        'يومين' => 2,
        'ثلاثة' || 'ثلاث' => 3,
        'أربعة' => 4,
        'خمسة' => 5,
        _ => int.tryParse(token) ?? 0,
      };
      if (value > 0) return CapturedField<int>(value, confidence: 0.9);
    }
    if (type == OccasionType.condolence) {
      // العرف: العزاء ثلاثة أيام ما لم يُنص على خلاف ذلك.
      return const CapturedField<int>(3, confidence: 0.6);
    }
    return null;
  }
}
