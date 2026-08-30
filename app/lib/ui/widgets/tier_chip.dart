import 'package:flutter/material.dart';

import '../../models/obligation.dart';

/// شارة مستوى الوجوب. تصف الواجب لا الشخص — لا يوجد في التطبيق أي مقياس
/// ظاهر يقارن بين الأشخاص.
class TierChip extends StatelessWidget {
  const TierChip({super.key, required this.tier, this.compact = false});

  final ObligationTier tier;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (Color bg, Color fg) = switch (tier) {
      ObligationTier.confirmed => (scheme.errorContainer, scheme.onErrorContainer),
      ObligationTier.recommended => (
          scheme.tertiaryContainer,
          scheme.onTertiaryContainer
        ),
      ObligationTier.optional => (
          scheme.surfaceContainerHighest,
          scheme.onSurfaceVariant
        ),
    };

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 12,
        vertical: compact ? 3 : 6,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        tier.label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: fg,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}
