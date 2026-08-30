import 'package:flutter/material.dart';

import '../../models/ledger_entry.dart';
import '../../models/occasion.dart';
import '../store_scope.dart';

/// المحرك الرابع — دفتر المعاملة بالمثل.
///
/// خاص وصامت: لا مشاركة ولا تصدير ولا صياغة اتهامية. يعرض ما عليك أنت
/// فقط، ولا يُظهر «من قصّر معك».
class LedgerScreen extends StatelessWidget {
  const LedgerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final theme = Theme.of(context);
    final outstanding = store.ledger.outstanding();
    final entries = store.ledger.entries.toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    return Scaffold(
      appBar: AppBar(title: const Text('دفترك الخاص')),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                const Icon(Icons.lock_outline, size: 18),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'هذا الدفتر لك وحدك: لا يُشارك ولا يُصدَّر، '
                    'ووظيفته التذكير لا المحاسبة.',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
          if (outstanding.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Text('لم يُرَدّ بعد', style: theme.textTheme.titleSmall),
            ),
            ...outstanding.map((balance) {
              final person = store.person(balance.personId);
              return ListTile(
                leading: const Icon(Icons.favorite_border),
                title: Text(person?.displayName ?? 'غير معروف'),
                subtitle: Text(balance.reminderText),
              );
            }),
          ],
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text('السجل', style: theme.textTheme.titleSmall),
          ),
          if (entries.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text('الدفتر فاضي. يمتلي مع أول واجب تسجّله.'),
            ),
          ...entries.map((entry) {
            final person = store.person(entry.personId);
            final incoming = entry.direction == LedgerDirection.theyDidForMe;
            return ListTile(
              leading: Icon(
                incoming ? Icons.call_received : Icons.call_made,
              ),
              title: Text(person?.displayName ?? 'غير معروف'),
              subtitle: Text(
                '${entry.occasionType.label} · ${entry.action.label} · '
                '${entry.date.year}/${entry.date.month}/${entry.date.day}',
              ),
              trailing: Text(incoming ? 'لهم عندك' : 'أدّيته'),
            );
          }),
        ],
      ),
    );
  }
}
