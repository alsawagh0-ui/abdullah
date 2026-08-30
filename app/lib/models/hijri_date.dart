/// تحويل بين التقويمين الهجري والميلادي بالخوارزمية الجدولية (Tabular /
/// الخوارزمية الكويتية).
///
/// ملاحظة دقة: هذه الخوارزمية حسابية بحتة وقد تختلف عن تقويم أم القرى أو
/// الرؤية الشرعية بيوم واحد. لهذا السبب تعرض الواجهة التاريخين الهجري
/// والميلادي جنباً إلى جنب، ويبقى التاريخ الميلادي هو المرجع في الحسابات
/// الزمنية للتنبيهات.
class HijriDate {
  const HijriDate(this.year, this.month, this.day)
      : assert(month >= 1 && month <= 12, 'الشهر الهجري بين 1 و 12'),
        assert(day >= 1 && day <= 30, 'اليوم الهجري بين 1 و 30');

  final int year;
  final int month;
  final int day;

  static const List<String> monthNames = <String>[
    'محرم',
    'صفر',
    'ربيع الأول',
    'ربيع الآخر',
    'جمادى الأولى',
    'جمادى الآخرة',
    'رجب',
    'شعبان',
    'رمضان',
    'شوال',
    'ذو القعدة',
    'ذو الحجة',
  ];

  String get monthName => monthNames[month - 1];

  /// عدد الأيام الجولياني (JDN) ليوم ميلادي.
  static int gregorianToJdn(int year, int month, int day) {
    final a = (14 - month) ~/ 12;
    final y = year + 4800 - a;
    final m = month + 12 * a - 3;
    return day +
        (153 * m + 2) ~/ 5 +
        365 * y +
        y ~/ 4 -
        y ~/ 100 +
        y ~/ 400 -
        32045;
  }

  static DateTime jdnToGregorian(int jdn) {
    final a = jdn + 32044;
    final b = (4 * a + 3) ~/ 146097;
    final c = a - (146097 * b) ~/ 4;
    final d = (4 * c + 3) ~/ 1461;
    final e = c - (1461 * d) ~/ 4;
    final m = (5 * e + 2) ~/ 153;
    final day = e - (153 * m + 2) ~/ 5 + 1;
    final month = m + 3 - 12 * (m ~/ 10);
    final year = 100 * b + d - 4800 + (m ~/ 10);
    return DateTime(year, month, day);
  }

  int get jdn =>
      day +
      ((29.5 * (month - 1)).ceil()) +
      (year - 1) * 354 +
      ((3 + 11 * year) ~/ 30) +
      1948439;

  static HijriDate fromGregorian(DateTime date) {
    var l = gregorianToJdn(date.year, date.month, date.day) - 1948440 + 10632;
    final n = (l - 1) ~/ 10631;
    l = l - 10631 * n + 354;
    final j = ((10985 - l) ~/ 5316) * ((50 * l) ~/ 17719) +
        (l ~/ 5670) * ((43 * l) ~/ 15238);
    l = l -
        ((30 - j) ~/ 15) * ((17719 * j) ~/ 50) -
        (j ~/ 16) * ((15238 * j) ~/ 43) +
        29;
    final month = (24 * l) ~/ 709;
    final day = l - (709 * month) ~/ 24;
    final year = 30 * n + j - 30;
    return HijriDate(year, month, day);
  }

  DateTime toGregorian() => jdnToGregorian(jdn);

  /// هل هذا التاريخ في رمضان؟ يستخدم لتفعيل النمط الموسمي (الغبقة وتعديل
  /// أوقات الزيارات).
  bool get isRamadan => month == 9;

  /// أيام عيد الفطر الثلاثة وأيام عيد الأضحى.
  bool get isEid =>
      (month == 10 && day <= 3) || (month == 12 && day >= 10 && day <= 13);

  String format() => '$day $monthName $yearهـ';

  @override
  String toString() => '$year-${month.toString().padLeft(2, '0')}-'
      '${day.toString().padLeft(2, '0')}';

  @override
  bool operator ==(Object other) =>
      other is HijriDate &&
      other.year == year &&
      other.month == month &&
      other.day == day;

  @override
  int get hashCode => Object.hash(year, month, day);
}
