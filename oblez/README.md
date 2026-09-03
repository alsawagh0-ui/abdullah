# أوبلز (Oblez)

مشروع Flutter مستقل (منفصل عن `app/` و`website/` بالمستودع) — محاكاة ساخرة
لحياة قيمر عربي عادي بين الدوام المكتبي وشغف القيمنق.

## حالة المشروع: MVP قيد البناء

الخطوات الثلاث الأولى المنجزة (بانتظار المراجعة قبل التوسع):

1. **هيكلة المشروع** — `lib/models`, `lib/screens`, `lib/widgets`, `lib/logic`, `lib/data`
2. **PlayerState** (`lib/models/player_state.dart`) — حالة اللاعب المركزية
   (طاقة، وقت، راتب، شبكة، إنذارات) عبر `ChangeNotifier` + `provider`.
3. **RoomScreen** (`lib/screens/room_screen.dart`) — الشاشة الرئيسية، بدون
   تفاصيل بصرية معقدة: عرض حالة اللاعب + أزرار تنقّل (Aim Trainer, المتجر,
   نوم) + محاكاة اتصال المدير.

`AimTrainerScreen`, `ShopScreen`, `GameOverScreen` حالياً Placeholder فاضي
لغرض التنقل فقط، وبتُبنى بمرحلة لاحقة.

## التشغيل

```
cd oblez
flutter pub get
flutter run
```
