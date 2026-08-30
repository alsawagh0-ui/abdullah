import 'occasion.dart';

/// اتجاه القيد في دفتر المعاملة بالمثل.
enum LedgerDirection {
  /// واجب أدّاه الآخر تجاه المستخدم (رصيد له في ذمّتي).
  theyDidForMe,

  /// واجب أدّاه المستخدم تجاه الآخر.
  iDidForThem,
}

/// كيفية أداء الواجب.
enum LedgerAction { attended, message, gift, delegate, call }

extension LedgerActionLabel on LedgerAction {
  String get label => switch (this) {
        LedgerAction.attended => 'حضور',
        LedgerAction.message => 'رسالة',
        LedgerAction.gift => 'هدية',
        LedgerAction.delegate => 'إنابة',
        LedgerAction.call => 'اتصال',
      };

  /// ثقل الأداء داخل حساب الرصيد؛ الحضور شخصياً أثقل من الرسالة.
  double get weight => switch (this) {
        LedgerAction.attended => 1.0,
        LedgerAction.delegate => 0.7,
        LedgerAction.gift => 0.6,
        LedgerAction.call => 0.5,
        LedgerAction.message => 0.4,
      };
}

/// قيد في دفتر المعاملة بالمثل.
///
/// قاعدة تصميم صارمة: الدفتر خاص وصامت. لا يُصدَّر، ولا يُشارك، ولا يُعرض
/// بصيغة اتهامية تُظهر تقصير الآخرين. وظيفته التذكير لا المحاسبة، ولهذا
/// لا يحمل هذا النموذج أي حقل تقييم أو ترتيب للأشخاص.
class LedgerEntry {
  LedgerEntry({
    required this.id,
    required this.personId,
    required this.direction,
    required this.action,
    required this.occasionType,
    required this.date,
    this.occasionId,
    this.note,
  });

  final String id;
  final String personId;
  final LedgerDirection direction;
  final LedgerAction action;
  final OccasionType occasionType;
  final DateTime date;
  final String? occasionId;
  final String? note;

  Map<String, dynamic> toJson() => {
        'id': id,
        'personId': personId,
        'direction': direction.name,
        'action': action.name,
        'occasionType': occasionType.name,
        'date': date.toIso8601String(),
        'occasionId': occasionId,
        'note': note,
      };

  static LedgerEntry fromJson(Map<String, dynamic> json) => LedgerEntry(
        id: json['id'] as String,
        personId: json['personId'] as String,
        direction: LedgerDirection.values.byName(json['direction'] as String),
        action: LedgerAction.values.byName(json['action'] as String),
        occasionType:
            OccasionType.values.byName(json['occasionType'] as String),
        date: DateTime.parse(json['date'] as String),
        occasionId: json['occasionId'] as String?,
        note: json['note'] as String?,
      );
}
