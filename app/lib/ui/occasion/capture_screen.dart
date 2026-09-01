import 'package:flutter/material.dart';

import '../../engines/capture_engine.dart';
import '../../models/occasion.dart';
import '../../models/person.dart';
import '../../services/card_scanner.dart';
import '../../services/voice_input.dart';
import '../../services/wajb_services.dart';
import '../store_scope.dart';

/// شاشة المحرك الأول — الالتقاط الذكي.
///
/// في هذا النموذج يُلصق نص الإعلان (كما يصل من واتساب، أو بعد استخلاص
/// النص من صورة البطاقة). المخرج مسودة يراجعها المستخدم قبل الحفظ —
/// حلقة التصحيح البشرية إلزامية لأن دقة القراءة ليست 100%.
class CaptureScreen extends StatefulWidget {
  const CaptureScreen({super.key});

  @override
  State<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends State<CaptureScreen> {
  final TextEditingController _input = TextEditingController();
  final CaptureEngine _engine = const CaptureEngine();
  CaptureResult? _result;
  bool _scanning = false;
  bool _listening = false;
  // نص الجملة الحالية وحدها، حتى يُستبدَل بنتيجتها النهائية بدل أن
  // يتكرر مع كل نتيجة جزئية يبثّها محرك التعرّف الصوتي.
  String _voiceSegment = '';
  // يُخزَّن هنا بدل قراءته في dispose، لأن البحث في الشجرة عبر
  // InheritedWidget غير مسموح بعد بدء إزالة العنصر (unmount).
  VoiceInputRecognizer? _voiceInput;
  bool _voiceAvailable = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final voiceInput = ServicesScope.of(context).voiceInput;
    if (!identical(voiceInput, _voiceInput)) {
      _voiceInput = voiceInput;
      voiceInput.isAvailable.then((available) {
        if (mounted) setState(() => _voiceAvailable = available);
      });
    }
  }

  @override
  void initState() {
    super.initState();
    // بدون هذا المستمع يبقى زر «استخلاص» معطّلاً بعد كتابة النص.
    _input.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    if (_listening) _voiceInput?.stop();
    _input.dispose();
    super.dispose();
  }

  void _parse() {
    setState(() => _result = _engine.parse(_input.text));
  }

  /// يبدّل بين بدء الإملاء الصوتي وإيقافه.
  ///
  /// النص المُملى يُلحَق بحقل التحرير ويبقى قابلاً للتعديل قبل
  /// الاستخلاص — لا يُحفظ شيء اعتماداً على قراءة آلية وحدها، تماماً
  /// كصورة البطاقة.
  Future<void> _toggleVoice() async {
    final voice = ServicesScope.of(context).voiceInput;
    if (_listening) {
      await voice.stop();
      if (mounted) setState(() => _listening = false);
      return;
    }

    final base = _input.text;
    final needsSpace = base.isNotEmpty && !base.endsWith('\n');
    setState(() {
      _listening = true;
      _voiceSegment = '';
    });

    await voice.listen(
      onResult: (text, {required isFinal}) {
        if (!mounted) return;
        setState(() {
          _voiceSegment = text;
          _input.text =
              '$base${needsSpace ? ' ' : ''}$_voiceSegment';
          _input.selection =
              TextSelection.collapsed(offset: _input.text.length);
          if (isFinal) _listening = false;
        });
      },
    );
    // إن رفض النظام بدء الاستماع (صلاحية أو خطأ) يبقى _listening=true
    // خطأً — نتحقق من حالة المحرك الفعلية بدل افتراض النجاح.
    if (mounted && !_voiceInput!.isListeningNow) {
      setState(() => _listening = false);
    }
  }

  /// يلتقط صورة البطاقة، يستخلص نصها، ثم يضعه في حقل التحرير.
  ///
  /// النص المستخلَص يُعرض للمستخدم دائماً قبل التحليل: لا يُحفظ شيء
  /// اعتماداً على قراءة آلية وحدها.
  Future<void> _scan(CardImageSource source) async {
    final services = ServicesScope.of(context);
    final messenger = ScaffoldMessenger.of(context);

    setState(() => _scanning = true);
    try {
      final path = await services.imagePicker.pickImage(source);
      if (path == null) return;

      final text = await services.recognizer.recognize(path);
      if (text == null || text.trim().isEmpty) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('ما قدرنا نقرأ البطاقة — جرّب صورة أوضح'),
          ),
        );
        return;
      }
      _input.text = text;
      _parse();
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final result = _result;

    return Scaffold(
      appBar: AppBar(title: const Text('التقاط ذكي')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'صوّر بطاقة الإعلان، أو الصق نصها، أو أملِه صوتياً باللهجة.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          if (ServicesScope.of(context).recognizer.isAvailable)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _scanning
                        ? null
                        : () => _scan(CardImageSource.camera),
                    icon: const Icon(Icons.photo_camera_outlined),
                    label: const Text('صوّر البطاقة'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _scanning
                        ? null
                        : () => _scan(CardImageSource.gallery),
                    icon: const Icon(Icons.image_outlined),
                    label: const Text('من المعرض'),
                  ),
                ),
              ],
            )
          else
            Text(
              'قراءة الصور غير متاحة على هذه المنصة — الصق النص يدوياً.',
              style: theme.textTheme.bodySmall,
            ),
          if (_scanning) ...[
            const SizedBox(height: 12),
            const LinearProgressIndicator(),
            const SizedBox(height: 4),
            const Text('جارٍ قراءة البطاقة...'),
          ],
          const SizedBox(height: 12),
          TextField(
            controller: _input,
            maxLines: 8,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: 'انتقل إلى رحمة الله تعالى ...\n'
                  'العزاء للرجال في ديوان ... بعد صلاة العصر\n'
                  'مقر النساء: ...',
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _input.text.trim().isEmpty ? null : _parse,
                  icon: const Icon(Icons.auto_awesome_outlined),
                  label: const Text('استخلاص'),
                ),
              ),
              const SizedBox(width: 8),
              if (_voiceAvailable)
                IconButton.filledTonal(
                  tooltip: _listening ? 'إيقاف الإملاء' : 'إدخال صوتي',
                  onPressed: _toggleVoice,
                  isSelected: _listening,
                  icon: Icon(
                    _listening ? Icons.mic : Icons.mic_none_outlined,
                  ),
                )
              else
                IconButton.filledTonal(
                  tooltip: 'الإدخال الصوتي غير متاح على هذه المنصة',
                  onPressed: null,
                  icon: const Icon(Icons.mic_off_outlined),
                ),
            ],
          ),
          if (_listening) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 8),
                Text('يستمع الآن...', style: theme.textTheme.bodySmall),
              ],
            ),
          ],
          if (result != null) ...[
            const SizedBox(height: 20),
            _ResultCard(result: result, onSave: () => _save(result)),
          ],
        ],
      ),
    );
  }

  void _save(CaptureResult result) {
    final store = StoreScope.read(context);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    final name = result.subjectName?.value ?? 'غير محدد';
    // شخص جديد يدخل خريطة العلاقات بأدنى درجة قرب حتى يصنّفه المستخدم.
    final person = store.people.firstWhere(
      (p) => p.displayName == name,
      orElse: () {
        final created = Person(
          id: 'p${DateTime.now().microsecondsSinceEpoch}',
          displayName: name,
          circle: SocialCircle.work,
          closeness: SocialCircle.work.suggestedCloseness,
        );
        store.upsertPerson(created);
        return created;
      },
    );

    final start = result.gregorianDate?.value ??
        result.hijriDate?.value.toGregorian() ??
        DateTime.now();

    store.addOccasion(Occasion(
      id: 'o${DateTime.now().microsecondsSinceEpoch}',
      personId: person.id,
      type: result.type?.value ?? OccasionType.diwaniya,
      title: '${result.type?.value.label ?? 'مناسبة'} $name',
      startsAt: start,
      menVenue: result.menVenue?.value,
      womenVenue: result.womenVenue?.value,
      contactPhone: result.contactPhone?.value,
      durationDays: result.durationDays?.value,
      source: OccasionSource.capture,
    ));

    navigator.pop();
    messenger.showSnackBar(
      const SnackBar(content: Text('أُضيفت المناسبة بعد مراجعتك')),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.result, required this.onSave});

  final CaptureResult result;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final percent = (result.confidence * 100).round();

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'نتيجة الاستخلاص',
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                Text('اكتمال $percent%'),
              ],
            ),
            const SizedBox(height: 12),
            _Field(label: 'النوع', value: result.type?.value.label),
            _Field(label: 'الاسم', value: result.subjectName?.value),
            _Field(label: 'مقر الرجال', value: _venue(result.menVenue?.value)),
            _Field(label: 'مقر النساء', value: _venue(result.womenVenue?.value)),
            _Field(
              label: 'التاريخ الهجري',
              value: result.hijriDate?.value.format(),
            ),
            _Field(
              label: 'التاريخ الميلادي',
              value: result.gregorianDate == null
                  ? null
                  : '${result.gregorianDate!.value.day}/'
                      '${result.gregorianDate!.value.month}/'
                      '${result.gregorianDate!.value.year}',
            ),
            _Field(label: 'رقم التواصل', value: result.contactPhone?.value),
            _Field(
              label: 'المدة',
              value: result.durationDays == null
                  ? null
                  : '${result.durationDays!.value} أيام',
            ),
            if (result.warnings.isNotEmpty) ...[
              const SizedBox(height: 12),
              ...result.warnings.map(
                (w) => Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline, size: 18),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(w, style: theme.textTheme.bodySmall),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: onSave,
              child: Text(
                result.needsReview ? 'راجعت البيانات — احفظ' : 'حفظ المناسبة',
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String? _venue(Venue? venue) {
    if (venue == null) return null;
    final parts = <String>[
      venue.title,
      if (venue.area != null) venue.area!,
      venue.timingLabel,
    ];
    return parts.join(' — ');
  }
}

class _Field extends StatelessWidget {
  const _Field({required this.label, required this.value});

  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final missing = value == null || value!.isEmpty;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
          Expanded(
            child: Text(
              missing ? 'لم يُستخلص — أكمله يدوياً' : value!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: missing ? theme.colorScheme.error : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
