import 'package:flutter/material.dart';

import '../../models/hijri_date.dart';
import '../ledger/ledger_screen.dart';
import '../occasion/capture_screen.dart';
import '../occasion/occasion_screen.dart';
import '../relations/relations_screen.dart';
import '../settings/settings_screen.dart';
import '../store_scope.dart';
import '../widgets/duty_card.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    const pages = <Widget>[
      DutiesScreen(),
      RelationsScreen(),
      LedgerScreen(),
      SettingsScreen(),
    ];

    return Scaffold(
      body: pages[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.today_outlined),
            selectedIcon: Icon(Icons.today),
            label: 'واجباتي',
          ),
          NavigationDestination(
            icon: Icon(Icons.diversity_3_outlined),
            selectedIcon: Icon(Icons.diversity_3),
            label: 'العلاقات',
          ),
          NavigationDestination(
            icon: Icon(Icons.menu_book_outlined),
            selectedIcon: Icon(Icons.menu_book),
            label: 'الدفتر',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'الإعدادات',
          ),
        ],
      ),
    );
  }
}

/// الشاشة الرئيسية — «واجبات اليوم».
///
/// مبدأ التصميم: ثلاث ثوانٍ للمعرفة، ونقرة واحدة للتنفيذ.
/// لهذا لا تتجاوز الشاشة ثلاث بطاقات، ولكل بطاقة زر تنفيذ واحد.
class DutiesScreen extends StatelessWidget {
  const DutiesScreen({super.key});

  static const int maxCards = 3;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final duties = store.todaysDuties(limit: maxCards);
    final summary = store.weekSummary();
    final hijri = HijriDate.fromGregorian(store.now);

    return Scaffold(
      appBar: AppBar(
        title: const Text('واجبات اليوم'),
        actions: [
          IconButton(
            tooltip: 'التقاط ذكي',
            icon: const Icon(Icons.document_scanner_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const CaptureScreen()),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          _WeekStrip(
            total: summary.total,
            confirmed: summary.confirmed,
            hijri: hijri,
          ),
          if (duties.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Column(
                children: [
                  Icon(Icons.check_circle_outline, size: 48),
                  SizedBox(height: 12),
                  Text(
                    'ما عليك واجب اليوم.\nنذكّرك أول ما يجي شيء.',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          else
            ...duties.map(
              (obligation) => DutyCard(
                obligation: obligation,
                viewerGender: store.profile.gender,
                onOpen: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        OccasionScreen(occasionId: obligation.occasion.id),
                  ),
                ),
              ),
            ),
          if (store.rankedObligations().length > maxCards)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const AllDutiesScreen(),
                  ),
                ),
                child: Text(
                  'عرض بقية الواجبات '
                  '(${store.rankedObligations().length - maxCards})',
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _WeekStrip extends StatelessWidget {
  const _WeekStrip({
    required this.total,
    required this.confirmed,
    required this.hijri,
  });

  final int total;
  final int confirmed;
  final HijriDate hijri;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'هذا الأسبوع: $total واجبات — $confirmed مؤكد',
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: 2),
          Text(
            hijri.format(),
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

/// قائمة كل الواجبات النشطة — خارج قاعدة الثلاث بطاقات، بطلب صريح.
class AllDutiesScreen extends StatelessWidget {
  const AllDutiesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final duties = store.rankedObligations();
    return Scaffold(
      appBar: AppBar(title: const Text('كل الواجبات')),
      body: ListView.builder(
        itemCount: duties.length,
        itemBuilder: (context, index) {
          final obligation = duties[index];
          return DutyCard(
            obligation: obligation,
            viewerGender: store.profile.gender,
            onOpen: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) =>
                    OccasionScreen(occasionId: obligation.occasion.id),
              ),
            ),
          );
        },
      ),
    );
  }
}
