/// يمثّل بيانات الطالب المسجّل دخوله حالياً.
class StudentModel {
  final String civilId;
  final String fullName;
  final String gradeLevel;

  const StudentModel({
    required this.civilId,
    required this.fullName,
    required this.gradeLevel,
  });

  /// بيانات وهمية مؤقتة تُستخدم بعد نجاح تسجيل الدخول
  /// إلى حين ربط التطبيق بالـ Backend الفعلي (Phase 2).
  factory StudentModel.mock(String civilId) {
    return StudentModel(
      civilId: civilId,
      fullName: 'عبدالله الصواغ',
      gradeLevel: 'الصف العاشر',
    );
  }
}
