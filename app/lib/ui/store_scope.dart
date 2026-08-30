import 'package:flutter/widgets.dart';

import '../data/wajb_store.dart';

/// وصول الشاشات إلى الحالة دون الاعتماد على حزمة خارجية.
class StoreScope extends InheritedNotifier<WajbStore> {
  const StoreScope({
    super.key,
    required WajbStore store,
    required super.child,
  }) : super(notifier: store);

  static WajbStore of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<StoreScope>();
    assert(scope != null, 'StoreScope غير موجود في شجرة الواجهة');
    return scope!.notifier!;
  }

  /// قراءة بلا اشتراك في التحديثات — للاستخدام داخل معالجات الأحداث.
  static WajbStore read(BuildContext context) {
    final scope =
        context.getElementForInheritedWidgetOfExactType<StoreScope>()!.widget
            as StoreScope;
    return scope.notifier!;
  }
}
