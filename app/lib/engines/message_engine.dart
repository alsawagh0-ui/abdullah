import '../models/occasion.dart';
import '../models/person.dart';

/// يُرمى عند أي محاولة إرسال رسالة لم يصادق عليها إنسان.
///
/// خط أحمر تصميمي: لا إرسال آلي لأي تعزية أو تهنئة، والموافقة البشرية
/// شرط في كل مرة — لا مرة واحدة ولا «تذكّر اختياري».
class AutoSendBlockedException implements Exception {
  const AutoSendBlockedException(this.message);
  final String message;

  @override
  String toString() => 'AutoSendBlockedException: $message';
}

enum MessageTone { formal, dialect }

extension MessageToneLabel on MessageTone {
  String get label =>
      this == MessageTone.formal ? 'فصحى' : 'لهجة كويتية';
}

/// مسودة رسالة. تبدأ دائماً غير معتمَدة، ولا تُرسل إلا بعد مصادقة صريحة
/// من المستخدم على النص النهائي.
class MessageDraft {
  const MessageDraft({
    required this.text,
    required this.occasionType,
    required this.tone,
    this.approved = false,
  });

  final String text;
  final OccasionType occasionType;
  final MessageTone tone;
  final bool approved;

  /// المصادقة البشرية: تأخذ النص كما يراه المستخدم لحظة الضغط، فإن عُدّل
  /// النص بعدها بطلت المصادقة ووجب اعتمادها من جديد.
  MessageDraft approve(String finalText) => MessageDraft(
        text: finalText,
        occasionType: occasionType,
        tone: tone,
        approved: true,
      );

  MessageDraft edit(String newText) => MessageDraft(
        text: newText,
        occasionType: occasionType,
        tone: tone,
      );
}

/// المحرك الخامس (طبقة التنفيذ) — بنك العبارات.
///
/// عبارات محلية أصيلة مراجَعة بشرياً، مميّزة بحسب المناسبة ودرجة القرب:
/// عبارة الزميل ليست عبارة ابن العم. ولا توجد ترجمة آلية تُفقد الرسالة
/// صدقها.
class MessageEngine {
  const MessageEngine();

  static const Map<OccasionType, Map<MessageTone, List<String>>> _bank = {
    OccasionType.condolence: {
      MessageTone.formal: [
        'عظّم الله أجركم، وأحسن عزاءكم، وغفر لفقيدكم ورحمه.',
        'إنا لله وإنا إليه راجعون. أحسن الله عزاءكم في {name}، '
            'وجعل مثواه الجنة.',
        'خالص العزاء والمواساة. غفر الله له ورحمه وأسكنه فسيح جناته، '
            'وألهمكم الصبر والسلوان.',
      ],
      MessageTone.dialect: [
        'عظّم الله أجرك، الله يرحمه ويغفر له ويسكنه فسيح جناته.',
        'الله يرحمه ويصبّركم، أحسن الله عزاكم وما تشوفون شر.',
        'البقاء لله، الله يرحم {name} ويجعل مثواه الجنة ويصبّر قلوبكم.',
      ],
    },
    OccasionType.wedding: {
      MessageTone.formal: [
        'بارك الله لكما، وبارك عليكما، وجمع بينكما في خير. ألف مبروك.',
        'ألف مبروك الزواج، أسأل الله أن يجعله زواجاً مباركاً '
            'وبيتاً عامراً بالخير.',
      ],
      MessageTone.dialect: [
        'ألف ألف مبروك، الله يبارك لكم ويتمم لكم على خير.',
        'مبروك يا {name}، عقبال ما نفرح فيكم دوم وبيت عامر إن شاء الله.',
      ],
    },
    OccasionType.newborn: {
      MessageTone.formal: [
        'بارك الله لكم في الموهوب لكم، وشكرتم الواهب، وبلغ أشدّه، '
            'ورُزقتم برّه.',
        'ألف مبروك المولود، جعله الله من الذرية الصالحة.',
      ],
      MessageTone.dialect: [
        'مبروك المولود، الله يخليه لكم ويربيه في عزكم.',
        'ألف مبروك يا {name}، الله يجعله من ذرية صالحة ويقر عيونكم فيه.',
      ],
    },
    OccasionType.illness: {
      MessageTone.formal: [
        'شفاه الله وعافاه، وجعل ما أصابه طهوراً وأجراً.',
        'أسأل الله لكم العافية والشفاء العاجل.',
      ],
      MessageTone.dialect: [
        'طهور إن شاء الله، الله يقومه بالسلامة ويشفيه.',
        'ما تشوف شر، الله يعافيك ويقومك بالسلامة يا {name}.',
      ],
    },
    OccasionType.graduation: {
      MessageTone.formal: [
        'ألف مبروك التخرج، وفقكم الله لما فيه الخير.',
      ],
      MessageTone.dialect: [
        'مبروك التخرج يا {name}، عقبال الوظيفة والدرجات العالية.',
      ],
    },
    OccasionType.promotion: {
      MessageTone.formal: [
        'ألف مبروك الترقية، أهلٌ لها وزيادة، ووفقكم الله.',
      ],
      MessageTone.dialect: [
        'مبروك الترقية يا {name}، تستاهل وعقبال المناصب الأعلى.',
      ],
    },
    OccasionType.travel: {
      MessageTone.formal: [
        'الحمد لله على السلامة، حمداً على سلامة الوصول.',
      ],
      MessageTone.dialect: [
        'الحمدلله على السلامة يا {name}، وحشتنا.',
      ],
    },
    OccasionType.eid: {
      MessageTone.formal: [
        'عيدكم مبارك، وكل عام وأنتم بخير، تقبّل الله منا ومنكم.',
      ],
      MessageTone.dialect: [
        'عساكم من عواده، عيدكم مبارك وكل عام وانتم بخير.',
      ],
    },
    OccasionType.diwaniya: {
      MessageTone.formal: [
        'شكراً على الدعوة الكريمة، حضورٌ إن شاء الله.',
      ],
      MessageTone.dialect: [
        'يا هلا والله، إن شاء الله حاضرين.',
      ],
    },
  };

  /// اختيار الصياغة بحسب نوع المناسبة ودرجة القرب:
  /// كلما قرُبت العلاقة صار النص أطول وأكثر خصوصية بذكر الاسم.
  MessageDraft draft({
    required OccasionType type,
    required Person person,
    MessageTone tone = MessageTone.dialect,
    int variant = 0,
  }) {
    final options = _bank[type]?[tone] ?? _bank[type]?[MessageTone.formal];
    if (options == null || options.isEmpty) {
      return MessageDraft(
        text: 'بالتوفيق والخير دائماً.',
        occasionType: type,
        tone: tone,
      );
    }

    final index = _variantFor(person.tier, options.length, variant);
    final text = options[index].replaceAll('{name}', person.displayName);
    return MessageDraft(text: text, occasionType: type, tone: tone);
  }

  List<MessageDraft> variantsFor({
    required OccasionType type,
    required Person person,
    MessageTone tone = MessageTone.dialect,
  }) {
    final options = _bank[type]?[tone] ?? const <String>[];
    return List<MessageDraft>.generate(
      options.length,
      (i) => draft(type: type, person: person, tone: tone, variant: i),
    );
  }

  static int _variantFor(ClosenessTier tier, int length, int requested) {
    if (requested > 0) return requested % length;
    // الدائرة الأقرب تحصل على الصيغة الأطول (الأخيرة عادةً) التي تذكر الاسم.
    return switch (tier) {
      ClosenessTier.inner => length - 1,
      ClosenessTier.close => length > 1 ? 1 : 0,
      _ => 0,
    };
  }
}

/// بوابة الإرسال الوحيدة في التطبيق.
class MessageDispatcher {
  const MessageDispatcher();

  /// لا يمر شيء من هنا بلا مصادقة بشرية. لا يوجد مسار بديل ولا علم
  /// (flag) يتجاوز هذا الشرط.
  String send(MessageDraft draft) {
    if (!draft.approved) {
      throw const AutoSendBlockedException(
        'لا تُرسل أي رسالة قبل مراجعة المستخدم واعتماده لنصها.',
      );
    }
    if (draft.text.trim().isEmpty) {
      throw const AutoSendBlockedException('لا يمكن إرسال رسالة فارغة.');
    }
    return draft.text.trim();
  }
}
