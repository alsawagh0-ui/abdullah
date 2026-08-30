import 'package:flutter/material.dart';

import '../../models/obligation.dart';
import '../../models/occasion.dart';
import '../../models/person.dart';
import 'tier_chip.dart';

/// بطاقة واجب واحدة في الشاشة الرئيسية:
/// الاسم، صلة القرابة، نوع المناسبة، المكان، الوقت المقترح، وزر تنفيذ واحد.
class DutyCard extends StatelessWidget {
  const DutyCard({
    super.key,
    required this.obligation,
    required this.viewerGender,
    required this.onOpen,
    this.onPrimaryAction,
  });

  final Obligation obligation;
  final Gender viewerGender;
  final VoidCallback onOpen;
  final VoidCallback? onPrimaryAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final occasion = obligation.occasion;
    final person = obligation.person;
    final venue = occasion.venueFor(viewerGender);
    final solemn = occasion.type.isSolemn;

    return Card(
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      person.displayName,
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  TierChip(tier: obligation.tier),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                [
                  if (person.kinship != null) person.kinship!,
                  occasion.type.label,
                ].join(' · '),
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 12),
              _InfoRow(
                icon: Icons.place_outlined,
                text: venue == null
                    ? 'المقر غير محدد بعد'
                    : '${venue.title}'
                        '${venue.area != null ? ' — ${venue.area}' : ''}',
                semanticLabel: viewerGender == Gender.male
                    ? 'مقر الرجال'
                    : 'مقر النساء',
              ),
              const SizedBox(height: 6),
              _InfoRow(
                icon: Icons.schedule_outlined,
                text: venue?.timingLabel ?? 'التوقيت غير محدد',
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: onPrimaryAction ?? onOpen,
                      icon: Icon(
                        solemn ? Icons.people_outline : Icons.check_circle_outline,
                      ),
                      label: Text(solemn ? 'أنا حاضر' : 'نفّذ الواجب'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.text,
    this.semanticLabel,
  });

  final IconData icon;
  final String text;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            semanticLabel == null ? text : '$semanticLabel: $text',
            style: theme.textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }
}
