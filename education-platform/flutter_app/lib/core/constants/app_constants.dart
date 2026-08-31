/// ثوابت عامة يُعاد استخدامها في أكثر من مكان بالتطبيق.
class AppConstants {
  AppConstants._();

  /// طول الرقم المدني الكويتي (Civil ID) الثابت رسمياً.
  static const int civilIdLength = 12;

  /// عنوان الـ API الخلفي — يُستبدل بالعنوان الفعلي عند ربط الـ Backend الحقيقي.
  static const String apiBaseUrl = 'https://api.education-platform.example.com';
}
