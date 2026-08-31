import 'package:flutter/material.dart';

import '../../models/person.dart';
import '../../models/settings.dart';
import '../store_scope.dart';

/// رحلة الانضمام — مصمّمة لتُنجَز في أقل من 90 ثانية:
/// رقم الهاتف، سؤالان عن الدور والدوائر، ثم تصنيف سريع لأقرب العلاقات.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.onDone});

  final VoidCallback onDone;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  int _step = 0;
  final TextEditingController _phone = TextEditingController();
  final TextEditingController _name = TextEditingController();
  SocialRole _role = SocialRole.employee;
  Gender _gender = Gender.male;
  final Set<SocialCircle> _circles = {
    SocialCircle.family,
    SocialCircle.work,
  };

  @override
  void dispose() {
    _phone.dispose();
    _name.dispose();
    super.dispose();
  }

  void _next() {
    if (_step < 2) {
      setState(() => _step++);
      return;
    }
    final store = StoreScope.read(context);
    store.seed();
    store.updateProfile(
      store.profile.copyWith(
        displayName: _name.text.trim().isEmpty
            ? 'مستخدم واجِب'
            : _name.text.trim(),
        phone: _phone.text.trim(),
        role: _role,
        gender: _gender,
        onboarded: true,
      ),
    );
    widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('واجِب')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LinearProgressIndicator(value: (_step + 1) / 3),
            const SizedBox(height: 20),
            Expanded(child: _buildStep(theme)),
            FilledButton(
              onPressed: _next,
              child: Text(_step == 2 ? 'يلا نبدأ' : 'التالي'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep(ThemeData theme) {
    switch (_step) {
      case 0:
        return ListView(
          children: [
            Text('ذاكرتك الاجتماعية', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(
              'نعرف عنك واجباتك قبل لا تنساها، وننفّذها معك بضغطة وحدة، '
              'ونحفظ سرّك.',
              style: theme.textTheme.bodyLarge,
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _name,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'اسمك',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'رقم الهاتف',
                helperText: 'يُستخدم للدخول فقط.',
              ),
            ),
          ],
        );
      case 1:
        return ListView(
          children: [
            Text('دورك الاجتماعي', style: theme.textTheme.titleLarge),
            const SizedBox(height: 12),
            RadioGroup<SocialRole>(
              groupValue: _role,
              onChanged: (value) => setState(() => _role = value!),
              child: Column(
                children: SocialRole.values
                    .map(
                      (role) => RadioListTile<SocialRole>(
                        value: role,
                        title: Text(role.label),
                      ),
                    )
                    .toList(),
              ),
            ),
            const Divider(height: 32),
            Text('أي مقر يخصك؟', style: theme.textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              'نعرض لك المقر الصحيح تلقائياً في كل مناسبة.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            SegmentedButton<Gender>(
              segments: Gender.values
                  .map((g) => ButtonSegment<Gender>(
                        value: g,
                        label: Text(g == Gender.male
                            ? 'مقر الرجال'
                            : 'مقر النساء'),
                      ))
                  .toList(),
              selected: {_gender},
              onSelectionChanged: (s) => setState(() => _gender = s.first),
            ),
          ],
        );
      default:
        return ListView(
          children: [
            Text('دوائرك', style: theme.textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              'اختر الدوائر اللي تهمك، وتقدر تعدّل درجة القرب لكل شخص لاحقاً.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            ...SocialCircle.values.map(
              (circle) => CheckboxListTile(
                value: _circles.contains(circle),
                onChanged: (value) => setState(() {
                  if (value ?? false) {
                    _circles.add(circle);
                  } else {
                    _circles.remove(circle);
                  }
                }),
                title: Text(circle.label),
              ),
            ),
            const SizedBox(height: 16),
            const Card(
              margin: EdgeInsets.zero,
              child: ListTile(
                leading: Icon(Icons.lock_outline),
                title: Text('خصوصيتك افتراضياً مقفلة'),
                subtitle: Text(
                  'ما في نشر عام ولا إعجابات ولا متابعون. '
                  'كل شيء يبقى عندك.',
                ),
              ),
            ),
          ],
        );
    }
  }
}
