import 'package:flutter/material.dart';

import '../../models/person.dart';
import '../store_scope.dart';

/// المحرك الثاني — خريطة العلاقات.
///
/// دوائر وظيفية فقط (عائلة، أصهار، ديوانية، زمالة، جيرة، دراسة).
/// لا يوجد ولن يوجد تصنيف قبلي أو طائفي أو مناطقي، ولا ترتيب تفاضلي
/// ظاهر بين الأشخاص: الأسماء داخل كل دائرة مرتّبة أبجدياً.
class RelationsScreen extends StatelessWidget {
  const RelationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final byCircle = <SocialCircle, List<Person>>{};
    for (final person in store.people) {
      byCircle.putIfAbsent(person.circle, () => []).add(person);
    }
    for (final list in byCircle.values) {
      list.sort((a, b) => a.displayName.compareTo(b.displayName));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('خريطة العلاقات')),
      body: ListView(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text(
              'بياناتك وحدك. لا تُشارك ولا تُعرض لأي طرف آخر.',
            ),
          ),
          for (final circle in SocialCircle.values)
            if ((byCircle[circle] ?? const []).isNotEmpty)
              _CircleSection(circle: circle, people: byCircle[circle]!),
        ],
      ),
    );
  }
}

class _CircleSection extends StatelessWidget {
  const _CircleSection({required this.circle, required this.people});

  final SocialCircle circle;
  final List<Person> people;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Text(
            '${circle.label} (${people.length})',
            style: theme.textTheme.titleSmall,
          ),
        ),
        ...people.map((person) => _PersonTile(person: person)),
      ],
    );
  }
}

class _PersonTile extends StatelessWidget {
  const _PersonTile({required this.person});

  final Person person;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    return ListTile(
      title: Text(person.displayName),
      subtitle: Text(person.kinship ?? person.circle.label),
      trailing: Text(person.tier.label),
      onTap: () => showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        builder: (context) => _ClosenessSheet(
          person: person,
          onChanged: (value) => store.updateCloseness(person.id, value),
        ),
      ),
    );
  }
}

class _ClosenessSheet extends StatefulWidget {
  const _ClosenessSheet({required this.person, required this.onChanged});

  final Person person;
  final ValueChanged<int> onChanged;

  @override
  State<_ClosenessSheet> createState() => _ClosenessSheetState();
}

class _ClosenessSheetState extends State<_ClosenessSheet> {
  late double _value = widget.person.closeness.toDouble();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.person.displayName,
                style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              'درجة القرب تحدّد ترتيب الواجب وصياغة الرسالة. '
              'تعديلها خاص بك ولا يظهر لأحد.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            Slider(
              value: _value,
              min: 0,
              max: 100,
              divisions: 20,
              label: ClosenessTier.of(_value.round()).label,
              onChanged: (value) => setState(() => _value = value),
              onChangeEnd: (value) => widget.onChanged(value.round()),
            ),
            Center(child: Text(ClosenessTier.of(_value.round()).label)),
          ],
        ),
      ),
    );
  }
}
