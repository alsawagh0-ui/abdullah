import 'package:flutter/material.dart';

import '../models/subject.dart';
import '../services/api_service.dart';
import 'login_screen.dart';

class DashboardScreen extends StatefulWidget {
  final String studentName;

  const DashboardScreen({super.key, required this.studentName});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _apiService = ApiService();
  late Future<List<Subject>> _subjectsFuture;

  @override
  void initState() {
    super.initState();
    _subjectsFuture = _apiService.fetchMySubjects();
  }

  Future<void> _refresh() async {
    setState(() {
      _subjectsFuture = _apiService.fetchMySubjects();
    });
    await _subjectsFuture;
  }

  Future<void> _logout() async {
    await _apiService.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Text('مرحباً، ${widget.studentName}'),
          actions: [
            IconButton(
              icon: const Icon(Icons.logout),
              tooltip: 'تسجيل الخروج',
              onPressed: _logout,
            ),
          ],
        ),
        body: RefreshIndicator(
          onRefresh: _refresh,
          child: FutureBuilder<List<Subject>>(
            future: _subjectsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return _ErrorView(message: snapshot.error.toString(), onRetry: _refresh);
              }

              final subjects = snapshot.data ?? [];
              if (subjects.isEmpty) {
                return const Center(child: Text('لا توجد مواد مقررة عليك حالياً'));
              }

              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: subjects.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final subject = subjects[index];
                  return _SubjectCard(subject: subject);
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

class _SubjectCard extends StatelessWidget {
  final Subject subject;

  const _SubjectCard({required this.subject});

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: const CircleAvatar(
          radius: 24,
          child: Icon(Icons.menu_book_rounded),
        ),
        title: Text(subject.name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('الصف: ${subject.gradeLevel}'),
        trailing: const Icon(Icons.arrow_back_ios_new, size: 16),
        onTap: () {
          // TODO: الانتقال لقائمة دروس المادة، ثم شاشة المولّد الذكي للشرح
          // (قسم 2.4 في الوثيقة): مشغّل شرائح + صوت متزامن.
        },
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 48),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          FilledButton(onPressed: onRetry, child: const Text('إعادة المحاولة')),
        ],
      ),
    );
  }
}
