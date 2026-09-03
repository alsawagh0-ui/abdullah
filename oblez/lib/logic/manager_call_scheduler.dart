import 'dart:async';
import 'dart:math';

typedef ManagerCallCallback = void Function();

/// يجدول اتصالات المدير العشوائية بفواصل زمنية غير منتظمة، وحدة واحدة
/// نشطة بأي وقت (يستدعيها الطرف اللي يستخدمه بعد ما يحل الاتصال الحالي).
class ManagerCallScheduler {
  final Random _random;
  final int minSeconds;
  final int maxSeconds;
  Timer? _timer;

  ManagerCallScheduler({
    Random? random,
    this.minSeconds = 15,
    this.maxSeconds = 40,
  }) : _random = random ?? Random();

  /// يحسب فترة الانتظار العشوائية التالية بالثواني (يُفصل عن Timer لتسهيل الاختبار).
  int nextDelaySeconds() =>
      minSeconds + _random.nextInt(maxSeconds - minSeconds + 1);

  void scheduleNext(ManagerCallCallback onIncomingCall) {
    _timer?.cancel();
    _timer = Timer(Duration(seconds: nextDelaySeconds()), onIncomingCall);
  }

  void cancel() {
    _timer?.cancel();
    _timer = null;
  }
}
