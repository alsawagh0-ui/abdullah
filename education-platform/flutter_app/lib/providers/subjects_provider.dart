import 'package:flutter/material.dart';

import '../models/subject_model.dart';

/// يدير قائمة المواد المقررة على الطالب المعروضة في لوحة التحكم.
///
/// يعتمد حالياً على بيانات وهمية (Mock Data) لتصميم وتجربة الواجهة قبل
/// اكتمال تكامل الـ Backend؛ دالة `loadSubjects` هي نقطة الاستبدال
/// الوحيدة عند ربط GET /subjects/me الحقيقية في مرحلة لاحقة.
class SubjectsProvider extends ChangeNotifier {
  List<SubjectModel> _subjects = [];
  bool _isLoading = false;

  List<SubjectModel> get subjects => _subjects;
  bool get isLoading => _isLoading;

  /// يجلب المواد المقررة على الطالب فور دخوله للوحة التحكم.
  Future<void> loadSubjects() async {
    _isLoading = true;
    notifyListeners();

    // محاكاة زمن استجابة الشبكة.
    await Future.delayed(const Duration(milliseconds: 600));

    // TODO(Phase 2): استبدال هذا بنداء ApiService.fetchMySubjects فعلي.
    _subjects = _mockSubjects;

    _isLoading = false;
    notifyListeners();
  }

  static final List<SubjectModel> _mockSubjects = [
    const SubjectModel(
      id: 'sub_math',
      name: 'الرياضيات',
      teacherName: 'أ. سارة العتيبي',
      lessonsCount: 24,
      progress: 0.65,
      icon: Icons.calculate_rounded,
      color: Color(0xFF4F46E5),
    ),
    const SubjectModel(
      id: 'sub_arabic',
      name: 'اللغة العربية',
      teacherName: 'أ. محمد العنزي',
      lessonsCount: 18,
      progress: 0.40,
      icon: Icons.menu_book_rounded,
      color: Color(0xFF059669),
    ),
    const SubjectModel(
      id: 'sub_science',
      name: 'العلوم',
      teacherName: 'أ. فاطمة الرشيدي',
      lessonsCount: 20,
      progress: 0.80,
      icon: Icons.science_rounded,
      color: Color(0xFFD97706),
    ),
    const SubjectModel(
      id: 'sub_english',
      name: 'اللغة الإنجليزية',
      teacherName: 'Ms. Layla Hassan',
      lessonsCount: 16,
      progress: 0.25,
      icon: Icons.translate_rounded,
      color: Color(0xFF2563EB),
    ),
    const SubjectModel(
      id: 'sub_islamic',
      name: 'التربية الإسلامية',
      teacherName: 'أ. خالد المطيري',
      lessonsCount: 14,
      progress: 0.55,
      icon: Icons.mosque_rounded,
      color: Color(0xFF0D9488),
    ),
  ];
}
