import 'dart:math' as math;

import '../models/occasion.dart';

/// إحداثيات مدينة الكويت وتوقيتها.
class GeoLocation {
  const GeoLocation({
    required this.latitude,
    required this.longitude,
    required this.timeZoneHours,
  });

  final double latitude;
  final double longitude;
  final double timeZoneHours;

  static const GeoLocation kuwaitCity = GeoLocation(
    latitude: 29.3759,
    longitude: 47.9774,
    timeZoneHours: 3,
  );
}

/// حساب مواقيت الصلاة (طريقة أم القرى: الفجر 18.5°، العشاء بعد المغرب
/// بـ 90 دقيقة، والعصر على المذهب الشافعي).
///
/// تُستخدم لغرضين: ترجمة «بعد صلاة العصر» في الإعلانات إلى وقت فعلي،
/// وكتم التنبيهات أثناء الصلاة.
class PrayerTimes {
  PrayerTimes._(this.date, this._times);

  final DateTime date;
  final Map<PrayerAnchor, DateTime> _times;

  static const double _fajrAngle = 18.5;
  static const int _ishaOffsetMinutes = 90;
  static const double _sunriseAltitude = -0.833;
  static const int _asrShadowFactor = 1;

  DateTime operator [](PrayerAnchor anchor) => _times[anchor]!;

  Map<PrayerAnchor, DateTime> get all => Map.unmodifiable(_times);

  DateTime get sunrise => _sunrise;
  late final DateTime _sunrise;

  static PrayerTimes forDate(
    DateTime date, {
    GeoLocation location = GeoLocation.kuwaitCity,
  }) {
    final day = DateTime(date.year, date.month, date.day);
    final jd = _julianDay(day) - location.longitude / (15 * 24);

    final decl = _sunDeclination(jd);
    final eqTime = _equationOfTime(jd);

    final dhuhrHours =
        12 + location.timeZoneHours - location.longitude / 15 - eqTime / 60;

    double? hourAngle(double altitude) {
      final latRad = _rad(location.latitude);
      final declRad = _rad(decl);
      final cosH = (math.sin(_rad(altitude)) -
              math.sin(latRad) * math.sin(declRad)) /
          (math.cos(latRad) * math.cos(declRad));
      if (cosH.abs() > 1) return null; // خطوط عرض قطبية — غير وارد للكويت
      return _deg(math.acos(cosH)) / 15;
    }

    final sunriseOffset = hourAngle(_sunriseAltitude);
    final fajrOffset = hourAngle(-_fajrAngle);

    // زاوية العصر: ظل الشيء مثله (شافعي).
    final latRad = _rad(location.latitude);
    final declRad = _rad(decl);
    final asrAltitude = _deg(
      math.atan(1 /
          (_asrShadowFactor + math.tan((latRad - declRad).abs()))),
    );
    final asrOffset = hourAngle(asrAltitude);

    DateTime at(double hours) {
      final clamped = hours % 24;
      final totalMinutes = (clamped * 60).round();
      return day.add(Duration(minutes: totalMinutes));
    }

    final dhuhr = at(dhuhrHours + 65 / 3600); // دقيقة احتياط بعد الزوال
    final maghrib = at(dhuhrHours + (sunriseOffset ?? 6));
    final times = <PrayerAnchor, DateTime>{
      PrayerAnchor.fajr: at(dhuhrHours - (fajrOffset ?? 7)),
      PrayerAnchor.dhuhr: dhuhr,
      PrayerAnchor.asr: at(dhuhrHours + (asrOffset ?? 3.5)),
      PrayerAnchor.maghrib: maghrib,
      PrayerAnchor.isha:
          maghrib.add(const Duration(minutes: _ishaOffsetMinutes)),
    };

    final result = PrayerTimes._(day, times);
    result._sunrise = at(dhuhrHours - (sunriseOffset ?? 6));
    return result;
  }

  /// الوقت الفعلي لمناسبة معلنة بصيغة «بعد صلاة X»، مع فاصل عرفي قصير
  /// يسمح بأداء الصلاة قبل بدء الاستقبال.
  DateTime resolveAnchor(
    PrayerAnchor anchor, {
    Duration gap = const Duration(minutes: 30),
  }) =>
      this[anchor].add(gap);

  /// هل هذه اللحظة داخل نافذة صلاة يجب كتم التنبيهات فيها؟
  bool isQuietAt(DateTime moment,
      {Duration window = const Duration(minutes: 25)}) {
    for (final time in _times.values) {
      if (!moment.isBefore(time) && moment.isBefore(time.add(window))) {
        return true;
      }
    }
    return false;
  }

  /// أقرب وقت مناسب لإرسال تنبيه بعد لحظة معيّنة، مع احترام مواقيت الصلاة.
  DateTime nextAllowedNotification(
    DateTime moment, {
    Duration window = const Duration(minutes: 25),
  }) {
    var candidate = moment;
    for (var i = 0; i < _times.length + 1; i++) {
      if (!isQuietAt(candidate, window: window)) return candidate;
      for (final time in _times.values) {
        if (!candidate.isBefore(time) &&
            candidate.isBefore(time.add(window))) {
          candidate = time.add(window);
        }
      }
    }
    return candidate;
  }

  static double _julianDay(DateTime date) {
    var year = date.year;
    var month = date.month;
    final day = date.day;
    if (month <= 2) {
      year -= 1;
      month += 12;
    }
    final a = (year / 100).floor();
    final b = 2 - a + (a / 4).floor();
    return (365.25 * (year + 4716)).floor() +
        (30.6001 * (month + 1)).floor() +
        day +
        b -
        1524.5;
  }

  static double _sunDeclination(double jd) {
    final d = jd - 2451545.0;
    final g = _fixAngle(357.529 + 0.98560028 * d);
    final q = _fixAngle(280.459 + 0.98564736 * d);
    final l = _fixAngle(
        q + 1.915 * math.sin(_rad(g)) + 0.020 * math.sin(_rad(2 * g)));
    final e = 23.439 - 0.00000036 * d;
    return _deg(math.asin(math.sin(_rad(e)) * math.sin(_rad(l))));
  }

  static double _equationOfTime(double jd) {
    final d = jd - 2451545.0;
    final g = _fixAngle(357.529 + 0.98560028 * d);
    final q = _fixAngle(280.459 + 0.98564736 * d);
    final l = _fixAngle(
        q + 1.915 * math.sin(_rad(g)) + 0.020 * math.sin(_rad(2 * g)));
    final e = 23.439 - 0.00000036 * d;
    final ra = _deg(math.atan2(
          math.cos(_rad(e)) * math.sin(_rad(l)),
          math.cos(_rad(l)),
        )) /
        15;
    final raFixed = ra < 0 ? ra + 24 : ra;
    var eq = q / 15 - raFixed;
    // تعديل الالتفاف: معادلة الزمن لا تتجاوز ±20 دقيقة تقريباً.
    while (eq > 12) {
      eq -= 24;
    }
    while (eq < -12) {
      eq += 24;
    }
    return eq;
  }

  static double _fixAngle(double angle) {
    final a = angle % 360;
    return a < 0 ? a + 360 : a;
  }

  static double _rad(double degrees) => degrees * math.pi / 180;

  static double _deg(double radians) => radians * 180 / math.pi;
}
