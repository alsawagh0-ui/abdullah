import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../providers/subjects_provider.dart';
import '../../widgets/subject_card.dart';
import '../login/login_screen.dart';

/// لوحة تحكم الطالب: ترحيب باسم الطالب، ثم عرض مواده المقررة كبطاقات.
///
/// تُحمَّل قائمة المواد تلقائياً فور الدخول عبر `initState`، بما يطابق
/// متطلب "تظهر تلقائياً فور تسجيل الدخول" في وثيقة التصميم.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    // يُجدوَل بعد أول إطار لتفادي استدعاء notifyListeners أثناء البناء.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SubjectsProvider>().loadSubjects();
    });
  }

  Future<void> _handleLogout() async {
    context.read<AuthProvider>().logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final student = context.watch<AuthProvider>().currentStudent;
    final subjectsProvider = context.watch<SubjectsProvider>();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('موادي الدراسية'),
          actions: [
            IconButton(
              icon: const Icon(Icons.logout_rounded),
              tooltip: 'تسجيل الخروج',
              onPressed: _handleLogout,
            ),
          ],
        ),
        body: RefreshIndicator(
          onRefresh: () => context.read<SubjectsProvider>().loadSubjects(),
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                sliver: SliverToBoxAdapter(
                  child: _WelcomeBanner(studentName: student?.fullName ?? 'الطالب'),
                ),
              ),
              if (subjectsProvider.isLoading)
                const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (subjectsProvider.subjects.isEmpty)
                const SliverFillRemaining(
                  child: Center(child: Text('لا توجد مواد مقررة عليك حالياً')),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                  sliver: SliverList.separated(
                    itemCount: subjectsProvider.subjects.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final subject = subjectsProvider.subjects[index];
                      return SubjectCard(
                        subject: subject,
                        onTap: () {
                          // TODO(Phase 2): الانتقال لشاشة دروس المادة،
                          // ثم شاشة المولّد الذكي للشرح (شرائح + صوت).
                        },
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// شريط ترحيبي أعلى لوحة التحكم يعرض اسم الطالب وملخصاً سريعاً.
class _WelcomeBanner extends StatelessWidget {
  final String studentName;

  const _WelcomeBanner({required this.studentName});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 26,
            backgroundColor: Colors.white24,
            child: Icon(Icons.person_rounded, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'مرحباً، $studentName 👋',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'استمر في التعلّم لتحقيق أفضل النتائج',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
