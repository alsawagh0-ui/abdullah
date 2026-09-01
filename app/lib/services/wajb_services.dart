import 'package:flutter/widgets.dart';

import 'card_scanner.dart';
import 'external_actions.dart';
import 'notification_planner.dart';
import 'voice_input.dart';

/// حزمة خدمات المنصة التي تعتمد عليها الشاشات.
///
/// تُمرَّر من الجذر كي تُستبدل بنسخ صورية في الاختبارات: لا شاشة في هذا
/// التطبيق تستدعي إضافة منصة مباشرة.
class WajbServices {
  const WajbServices({
    required this.externalActions,
    required this.notifications,
    required this.recognizer,
    required this.imagePicker,
    required this.voiceInput,
  });

  final ExternalActions externalActions;
  final WajbNotifications notifications;
  final CardTextRecognizer recognizer;
  final CardImagePicker imagePicker;
  final VoiceInputRecognizer voiceInput;

  /// خدمات صورية: لا تلمس المنصة، وتُستخدم في الاختبارات وعلى المنصات
  /// غير المدعومة.
  factory WajbServices.fake() => WajbServices(
        externalActions: RecordingExternalActions(),
        notifications: RecordingNotifications(),
        recognizer: const UnavailableCardRecognizer(),
        imagePicker: FakeCardImagePicker(null),
        voiceInput: const UnavailableVoiceInputRecognizer(),
      );
}

class ServicesScope extends InheritedWidget {
  const ServicesScope({
    super.key,
    required this.services,
    required super.child,
  });

  final WajbServices services;

  static WajbServices of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<ServicesScope>();
    assert(scope != null, 'ServicesScope غير موجود في شجرة الواجهة');
    return scope!.services;
  }

  @override
  bool updateShouldNotify(ServicesScope oldWidget) =>
      services != oldWidget.services;
}
