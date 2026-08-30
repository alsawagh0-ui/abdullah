import 'package:flutter/material.dart';

import '../../models/occasion.dart';
import '../../models/person.dart';
import '../../models/settings.dart';
import '../store_scope.dart';

/// الإعدادات — ومعها إعدادات الخصوصية.
///
/// كل مفاتيح المشاركة مغلقة افتراضياً (مبدأ الستر)، والانفتاح خيار واعٍ.
/// لا يوجد مفتاح للإرسال الآلي أصلاً: الأمر ممنوع تصميمياً لا معطّلاً.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final profile = store.profile;
    final privacy = profile.privacy;
    final theme = Theme.of(context);
    final times = store.todayPrayerTimes;

    String hhmm(DateTime t) =>
        '${t.hour.toString().padLeft(2, '0')}:'
        '${t.minute.toString().padLeft(2, '0')}';

    return Scaffold(
      appBar: AppBar(title: const Text('الإعدادات')),
      body: ListView(
        children: [
          const _SectionTitle('حسابك'),
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: Text(profile.displayName),
            subtitle: Text('${profile.role.label} · ${profile.area}'),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.wc_outlined),
            title: const Text('أعرض مقر النساء'),
            subtitle: const Text(
              'يحدد أي مقر يظهر لك تلقائياً في كل مناسبة.',
            ),
            value: profile.gender == Gender.female,
            onChanged: (value) => store.updateProfile(
              profile.copyWith(
                gender: value ? Gender.female : Gender.male,
              ),
            ),
          ),

          const _SectionTitle('إتاحة الوصول'),
          SwitchListTile(
            secondary: const Icon(Icons.text_fields),
            title: const Text('نمط كبار السن'),
            subtitle: const Text('خط أكبر، تباين أعلى، أزرار أوسع.'),
            value: profile.elderMode,
            onChanged: store.setElderMode,
          ),

          const _SectionTitle('التنبيهات'),
          SwitchListTile(
            secondary: const Icon(Icons.mosque_outlined),
            title: const Text('احترام مواقيت الصلاة'),
            subtitle: const Text('لا تُرسل التنبيهات أثناء الصلاة.'),
            value: profile.respectPrayerTimes,
            onChanged: (value) => store.updateProfile(
              profile.copyWith(respectPrayerTimes: value),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Text(
              'مواقيت اليوم (الكويت): '
              '${PrayerAnchor.values.map((a) => '${a.label} ${hhmm(times[a])}').join(' · ')}',
              style: theme.textTheme.bodySmall,
            ),
          ),

          const _SectionTitle('الخصوصية'),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              'الإعدادات الافتراضية هي الأشد تحفّظاً. لا يوجد في «واجِب» '
              'نشر عام ولا إعجابات ولا متابعون ولا قوائم أوائل.',
              style: theme.textTheme.bodySmall,
            ),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.family_restroom_outlined),
            title: const Text('تنسيق الواجبات مع الأسرة'),
            subtitle: const Text('مشاركة تنسيق الحضور مع أفراد أسرتك فقط.'),
            value: privacy.allowFamilyCoordination,
            onChanged: (value) => store.setPrivacy(
              privacy.copyWith(allowFamilyCoordination: value),
            ),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.contacts_outlined),
            title: const Text('استيراد جهات الاتصال'),
            value: privacy.allowContactImport,
            onChanged: (value) =>
                store.setPrivacy(privacy.copyWith(allowContactImport: value)),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.insights_outlined),
            title: const Text('إحصاءات مجهولة الهوية'),
            subtitle: const Text('لا تشمل أسماء ولا علاقات ولا دفترك.'),
            value: privacy.allowAnonymousDiagnostics,
            onChanged: (value) => store.setPrivacy(
              privacy.copyWith(allowAnonymousDiagnostics: value),
            ),
          ),
          const ListTile(
            leading: Icon(Icons.block_outlined),
            title: Text('الإرسال الآلي للرسائل'),
            subtitle: Text(
              'ممنوع تصميمياً. موافقتك على نص كل رسالة شرط في كل مرة.',
            ),
            enabled: false,
          ),

          const _SectionTitle('عن التطبيق'),
          const ListTile(
            leading: Icon(Icons.shield_outlined),
            title: Text('بياناتك محلية على جهازك'),
            subtitle: Text(
              'خريطة العلاقات والدفتر لا يغادران الجهاز في هذه النسخة.',
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Text(
        text,
        style: Theme.of(context)
            .textTheme
            .titleSmall
            ?.copyWith(color: Theme.of(context).colorScheme.primary),
      ),
    );
  }
}
