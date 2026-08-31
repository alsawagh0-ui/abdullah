import 'package:flutter/foundation.dart';

import '../models/student_model.dart';

/// يدير حالة تسجيل الدخول والطالب الحالي في كل التطبيق.
///
/// أي واجهة تحتاج معرفة هوية الطالب أو حالة الدخول (Dashboard، الإعدادات،
/// شاشة الدرس...) تستمع لهذا الـ Provider بدل تمرير البيانات يدوياً بين
/// الشاشات، وهو ما يسهّل لاحقاً استبدال منطق "الدخول الوهمي" بربط حقيقي
/// مع الـ Backend دون تعديل الشاشات نفسها.
class AuthProvider extends ChangeNotifier {
  StudentModel? _currentStudent;
  bool _isLoading = false;
  String? _errorMessage;

  StudentModel? get currentStudent => _currentStudent;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isLoggedIn => _currentStudent != null;

  /// يسجّل دخول الطالب بالرقم المدني.
  ///
  /// في هذه المرحلة (Phase 1) يُستخدم تأخير بسيط وبيانات وهمية بدل
  /// استدعاء API فعلي؛ التوقيع (signature) نفسه يبقى صالحاً عند ربط
  /// نقطة النهاية الحقيقية POST /auth/login لاحقاً.
  Future<bool> loginWithCivilId(String civilId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // محاكاة زمن استجابة الشبكة.
      await Future.delayed(const Duration(milliseconds: 800));

      // TODO(Phase 2): استبدال هذا بنداء ApiService.login فعلي.
      _currentStudent = StudentModel.mock(civilId);
      return true;
    } catch (e) {
      _errorMessage = 'تعذّر تسجيل الدخول، حاول مرة أخرى';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// يسجّل خروج الطالب ويمسح حالته من الذاكرة.
  void logout() {
    _currentStudent = null;
    notifyListeners();
  }
}
