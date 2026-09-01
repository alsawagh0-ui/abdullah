/// الإدخال الصوتي باللهجة المحلية لشاشة الالتقاط الذكي.
///
/// بديل للّصق أو التصوير حين يكون كتابة النص أو تصوير البطاقة غير
/// عملي — أهم فئة مستفيدة هي كبار السن (انظر §5.6 في README). النص
/// المُملى صوتياً يمرّ بنفس حلقة المراجعة البشرية قبل الحفظ.
abstract class VoiceInputRecognizer {
  /// هل التعرّف الصوتي متاح على هذه المنصة؟ يُتحقق منه مرة قبل أول
  /// استخدام، فقد يرفض النظام الصلاحية أو يفتقد المنصة المحرك أصلاً.
  Future<bool> get isAvailable;

  /// يبدأ الاستماع بلهجة `localeId` (افتراضياً عربي)، وينادي `onResult`
  /// بكل نص جزئي أو نهائي يصل. يتوقف تلقائياً بعد صمت المستخدم.
  Future<void> listen({
    required void Function(String text, {required bool isFinal}) onResult,
    String localeId = 'ar',
  });

  /// يوقف الاستماع فوراً قبل انتهائه التلقائي.
  Future<void> stop();

  /// هل الجلسة الحالية ما زالت مستمعة؟ يُستخدم بعد `listen()` للتحقق
  /// من نجاح بدء الجلسة فعلياً، لأن اكتمال المستقبل لا يعني أن
  /// الاستماع لا يزال جارياً — قد يرفضه النظام فوراً (صلاحية مرفوضة
  /// مثلاً) دون أن يصل أي خطأ صريح.
  bool get isListeningNow;
}

/// محرك غير متاح — يُستخدم في الاختبارات وعلى المنصات غير المدعومة.
class UnavailableVoiceInputRecognizer implements VoiceInputRecognizer {
  const UnavailableVoiceInputRecognizer();

  @override
  Future<bool> get isAvailable async => false;

  @override
  Future<void> listen({
    required void Function(String text, {required bool isFinal}) onResult,
    String localeId = 'ar',
  }) async {}

  @override
  Future<void> stop() async {}

  @override
  bool get isListeningNow => false;
}

/// محرك صوري يعيد نتائج مُعدّة سلفاً — للاختبارات.
class FakeVoiceInputRecognizer implements VoiceInputRecognizer {
  FakeVoiceInputRecognizer({
    this.available = true,
    this.results = const <String>[],
  });

  final bool available;

  /// كل عنصر يُبلَّغ كنتيجة جزئية، ما عدا الأخير الذي يُبلَّغ نهائياً.
  final List<String> results;

  bool listening = false;
  int stopCalls = 0;

  @override
  Future<bool> get isAvailable async => available;

  @override
  Future<void> listen({
    required void Function(String text, {required bool isFinal}) onResult,
    String localeId = 'ar',
  }) async {
    listening = true;
    for (var i = 0; i < results.length; i++) {
      final isFinal = i == results.length - 1;
      onResult(results[i], isFinal: isFinal);
      if (isFinal) listening = false;
    }
  }

  @override
  Future<void> stop() async {
    listening = false;
    stopCalls++;
  }

  @override
  bool get isListeningNow => listening;
}
