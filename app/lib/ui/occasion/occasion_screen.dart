import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../engines/action_layer.dart';
import '../../engines/prayer_times.dart';
import '../../models/hijri_date.dart';
import '../../models/ledger_entry.dart';
import '../../models/obligation.dart';
import '../../models/occasion.dart';
import '../../models/person.dart';
import '../../services/external_actions.dart';
import '../../services/wajb_services.dart';
import '../../theme/app_theme.dart';
import '../store_scope.dart';
import '../widgets/tier_chip.dart';
import 'message_sheet.dart';

/// شاشة المناسبة بأنماطها الثلاثة:
/// نمط العزاء (هادئ بلا ألوان ولا حركة ولا محتوى تجاري)،
/// نمط الفرح (أكثر حيوية مع الهدايا والورود)،
/// ونمط الديوانية.
class OccasionScreen extends StatelessWidget {
  const OccasionScreen({super.key, required this.occasionId});

  final String occasionId;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final occasion = store.occasion(occasionId);
    if (occasion == null) {
      return const Scaffold(body: Center(child: Text('المناسبة غير موجودة')));
    }
    final person = store.person(occasion.personId)!;
    final obligation = store.obligationEngine.evaluate(
      occasion: occasion,
      person: person,
      now: store.now,
      userArea: store.profile.area,
    );
    final solemn = occasion.type.isSolemn;

    final body = _OccasionBody(obligation: obligation);

    // نمط العزاء يبدّل نظام الألوان كاملاً إلى واجهة وقورة.
    if (!solemn) return body;
    return Theme(
      data: WajbTheme.light(
        elderMode: store.profile.elderMode,
        solemnMode: true,
      ),
      child: body,
    );
  }
}

class _OccasionBody extends StatelessWidget {
  const _OccasionBody({required this.obligation});

  final Obligation obligation;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final theme = Theme.of(context);
    final occasion = obligation.occasion;
    final person = obligation.person;
    final solemn = occasion.type.isSolemn;
    final viewerGender = store.profile.gender;
    final dayIndex = occasion.dayIndexAt(store.now);
    final delegation = store.delegationFor(occasion.id);

    return Scaffold(
      appBar: AppBar(title: Text(occasion.type.label)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  person.displayName,
                  style: theme.textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              TierChip(tier: obligation.tier),
            ],
          ),
          if (person.kinship != null)
            Text(
              person.kinship!,
              style: theme.textTheme.bodyLarge
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          const SizedBox(height: 16),
          _DatesRow(occasion: occasion, dayIndex: dayIndex),
          const SizedBox(height: 16),

          // المقران منفصلان دائماً، ومقر المستخدم يظهر أولاً تلقائياً
          // دون سؤال محرج.
          Text('المقر', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          ..._venueCards(context, occasion, viewerGender),

          if (occasion.contactPhone != null) ...[
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.phone_outlined),
              title: Text(occasion.contactPhone!),
              subtitle: const Text('رقم التواصل من الإعلان'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.call_outlined),
                    tooltip: 'اتصال',
                    onPressed: () => ServicesScope.of(context)
                        .externalActions
                        .call(occasion.contactPhone!),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy_outlined),
                    tooltip: 'نسخ',
                    onPressed: () => _copy(context, occasion.contactPhone!),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 16),
          _WhyCard(obligation: obligation),

          if (delegation != null) ...[
            const SizedBox(height: 12),
            Card(
              margin: EdgeInsets.zero,
              child: ListTile(
                leading: const Icon(Icons.handshake_outlined),
                title: Text('أنبت ${delegation.delegateName}'),
                subtitle: Text(delegation.status.label),
              ),
            ),
          ],

          const SizedBox(height: 24),
          Text('التنفيذ', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: occasion.done
                ? null
                : () => _confirmAttendance(context, occasion, person),
            icon: const Icon(Icons.how_to_reg_outlined),
            label: Text(occasion.done ? 'تم الأداء' : 'أنا حاضر'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => showMessageSheet(
              context,
              occasion: occasion,
              person: person,
            ),
            icon: const Icon(Icons.edit_note_outlined),
            label: const Text('رسالة مناسبة'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => _delegate(context, occasion),
            icon: const Icon(Icons.handshake_outlined),
            label: const Text('وكّل أحد عني'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => _services(context, occasion),
            icon: const Icon(Icons.local_mall_outlined),
            label: const Text('طلب خدمة'),
          ),

          // اقتراح النقوط خاص وسري ولا يظهر إطلاقاً في مناسبات العزاء.
          if (!solemn) ...[
            const SizedBox(height: 8),
            _MoneyHint(person: person, type: occasion.type),
          ],

          if (solemn) ...[
            const SizedBox(height: 24),
            Text(
              'واجهة العزاء خالية من أي محتوى تجاري أو ترويجي.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }

  List<Widget> _venueCards(
    BuildContext context,
    Occasion occasion,
    Gender viewerGender,
  ) {
    final mine = viewerGender == Gender.male
        ? ('مقر الرجال', occasion.menVenue)
        : ('مقر النساء', occasion.womenVenue);
    final other = viewerGender == Gender.male
        ? ('مقر النساء', occasion.womenVenue)
        : ('مقر الرجال', occasion.menVenue);

    final services = ServicesScope.of(context);
    return [
      _VenueCard(
        label: mine.$1,
        venue: mine.$2,
        highlighted: true,
        onNavigate: mine.$2 == null
            ? null
            : () => services.externalActions.openMap(mine.$2!),
      ),
      const SizedBox(height: 8),
      _VenueCard(
        label: other.$1,
        venue: other.$2,
        highlighted: false,
        onNavigate: other.$2 == null
            ? null
            : () => services.externalActions.openMap(other.$2!),
      ),
    ];
  }

  /// «أنا حاضر»: يقيّد الحضور في الدفتر، ويعرض إضافة الموعد إلى التقويم
  /// كخطوة اختيارية بموافقة صريحة — لا يكتب في تقويم المستخدم من تلقائه.
  Future<void> _confirmAttendance(
    BuildContext context,
    Occasion occasion,
    Person person,
  ) async {
    final store = StoreScope.read(context);
    final services = ServicesScope.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    store.markDone(occasion, LedgerAction.attended);

    final addToCalendar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('سُجّل الحضور'),
        content: const Text('تبي نضيف الموعد لتقويمك؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('لا، شكراً'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('أضِف للتقويم'),
          ),
        ],
      ),
    );

    if (addToCalendar ?? false) {
      final draft = const CalendarEventBuilder().build(
        occasion: occasion,
        person: person,
        viewerGender: store.profile.gender,
        prayerTimes: PrayerTimes.forDate(occasion.startsAt),
      );
      await services.externalActions.addToCalendar(draft);
    }

    navigator.pop();
    messenger.showSnackBar(
      const SnackBar(content: Text('سُجّل الحضور في دفترك الخاص')),
    );
  }

  Future<void> _delegate(BuildContext context, Occasion occasion) async {
    final store = StoreScope.read(context);
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('وكّل أحد عني'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'اسم من ينوب عنك',
            hintText: 'مثال: أخوي سعود',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('تأكيد'),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    store.addDelegation(Delegation(
      id: 'd${DateTime.now().microsecondsSinceEpoch}',
      occasionId: occasion.id,
      delegateName: name,
      status: DelegationStatus.pending,
    ));
  }

  Future<void> _services(BuildContext context, Occasion occasion) async {
    final store = StoreScope.read(context);
    final services = store.vendors.servicesFor(occasion);
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(
              title: const Text('سوق الخدمات'),
              subtitle: Text(
                occasion.type.isSolemn
                    ? 'خدمات تليق بالمقام فقط، تظهر بطلبك أنت لا كإعلان.'
                    : 'موردون معتمدون داخل المنصة.',
              ),
            ),
            const Divider(height: 1),
            ...services.map(
              (vendor) => ListTile(
                leading: const Icon(Icons.storefront_outlined),
                title: Text(vendor.name),
                subtitle: Text('${vendor.category.label} — ${vendor.area}'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static void _copy(BuildContext context, String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('نُسخ')));
  }
}

class _VenueCard extends StatelessWidget {
  const _VenueCard({
    required this.label,
    required this.venue,
    required this.highlighted,
    this.onNavigate,
  });

  final String label;
  final Venue? venue;
  final bool highlighted;
  final VoidCallback? onNavigate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      color: highlighted ? theme.colorScheme.secondaryContainer : null,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  highlighted ? Icons.my_location : Icons.place_outlined,
                  size: 18,
                ),
                const SizedBox(width: 6),
                Text(label, style: theme.textTheme.titleSmall),
                if (highlighted) ...[
                  const SizedBox(width: 8),
                  Text(
                    'وجهتك',
                    style: theme.textTheme.labelSmall,
                  ),
                ],
              ],
            ),
            const SizedBox(height: 6),
            Text(venue?.title ?? 'غير محدد في الإعلان'),
            if (venue?.area != null) Text(venue!.area!),
            if (venue?.address != null)
              Text(
                venue!.address!,
                style: theme.textTheme.bodySmall,
              ),
            const SizedBox(height: 4),
            Text(
              venue?.timingLabel ?? 'التوقيت غير محدد',
              style: theme.textTheme.bodySmall,
            ),
            if (onNavigate != null) ...[
              const SizedBox(height: 6),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton.icon(
                  onPressed: onNavigate,
                  icon: const Icon(Icons.directions_outlined, size: 18),
                  label: const Text('الملاحة'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DatesRow extends StatelessWidget {
  const _DatesRow({required this.occasion, required this.dayIndex});

  final Occasion occasion;
  final int? dayIndex;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hijri = occasion.hijriDate;
    final g = occasion.startsAt;
    return Wrap(
      spacing: 12,
      runSpacing: 6,
      children: [
        _Pill(text: hijri.format()),
        _Pill(text: '${g.day}/${g.month}/${g.year} م'),
        if (dayIndex != null && occasion.effectiveDurationDays > 1)
          _Pill(
            text: 'اليوم $dayIndex من ${occasion.effectiveDurationDays}',
            emphasized: true,
          ),
      ].map((w) => DefaultTextStyle.merge(
            style: theme.textTheme.bodySmall!,
            child: w,
          )).toList(),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.text, this.emphasized = false});

  final String text;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: emphasized
            ? scheme.tertiaryContainer
            : scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(text),
    );
  }
}

/// شفافية درجة الوجوب: يشرح للمستخدم لماذا رُتّب هذا الواجب هنا.
class _WhyCard extends StatelessWidget {
  const _WhyCard({required this.obligation});

  final Obligation obligation;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ليش ${obligation.tier.label}؟',
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            if (obligation.reasons.isEmpty)
              const Text('حسب قرب العلاقة ونوع المناسبة.')
            else
              ...obligation.reasons.map(
                (reason) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('• '),
                      Expanded(child: Text(reason)),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// اقتراح النقوط — خاص وسري، خلف نقرة، وبلا أي إظهار عام.
class _MoneyHint extends StatefulWidget {
  const _MoneyHint({required this.person, required this.type});

  final Person person;
  final OccasionType type;

  @override
  State<_MoneyHint> createState() => _MoneyHintState();
}

class _MoneyHintState extends State<_MoneyHint> {
  bool _revealed = false;

  @override
  Widget build(BuildContext context) {
    final range = const MoneySuggestion()
        .suggest(type: widget.type, tier: widget.person.tier);
    if (range == null) return const SizedBox.shrink();

    if (!_revealed) {
      return OutlinedButton.icon(
        onPressed: () => setState(() => _revealed = true),
        icon: const Icon(Icons.visibility_off_outlined),
        label: const Text('اقتراح النقوط (خاص)'),
      );
    }

    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        leading: const Icon(Icons.savings_outlined),
        title: Text(range.label),
        subtitle: Text(range.note),
      ),
    );
  }
}

/// امتداد صغير لعرض وقت المناسبة المرتبط بالصلاة بوقت فعلي تقريبي.
extension OccasionTiming on Occasion {
  DateTime? resolvedStart(PrayerTimes times) {
    final anchor = (menVenue ?? womenVenue)?.prayerAnchor;
    if (anchor == null) return (menVenue ?? womenVenue)?.startTime;
    return times.resolveAnchor(anchor);
  }

  HijriDate get hijri => HijriDate.fromGregorian(startsAt);
}
