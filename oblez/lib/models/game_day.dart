/// القرار اليومي اللي يختاره اللاعب بنهاية كل يوم.
enum DailyChoice {
  extraRank, // طاقة -، تقدم/نقاط +
  extraWork, // فلوس +، طاقة -
  sleepEarly, // لا تغيير، يحمي من إنذار الفصل
}

/// سجل مختصر ليوم واحد داخل اللعبة، يُستخدم لاحقاً لعرض ملخص/إحصائيات.
class GameDay {
  final int dayNumber;
  final DailyChoice? choice;
  final int missedManagerCalls;

  const GameDay({
    required this.dayNumber,
    this.choice,
    this.missedManagerCalls = 0,
  });

  GameDay copyWith({DailyChoice? choice, int? missedManagerCalls}) {
    return GameDay(
      dayNumber: dayNumber,
      choice: choice ?? this.choice,
      missedManagerCalls: missedManagerCalls ?? this.missedManagerCalls,
    );
  }
}
