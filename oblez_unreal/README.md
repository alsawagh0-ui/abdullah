# أوبلز (Oblez) — نسخة Unreal Engine

مشروع Unreal Engine 5 (C++) لنفس فكرة أوبلز — محاكاة ساخرة لحياة قيمر
عربي بين الدوام والقيمنق. **هذا مشروع منفصل تماماً عن نسخة Flutter
بمجلد `oblez/`** — الاثنان موجودان بالمستودع، ما فيه اعتماد بينهما.

## حدود هالبيئة (مهم تقرأه قبل لا تفتح المشروع)

Unreal Engine (المحرر + أدوات البناء) **مو مثبت بالبيئة اللي أشتغل
فيها** — ما قدرت أبني، أشغّل، أو أتحقق من أي شي هنا فعلياً. اللي
تحصله بهالمجلد سكافولد C++ فقط:

- **جاهز**: بنية المشروع (`.uproject`, `Source/`, ملفات Build/Target)،
  وطبقة المنطق/البيانات كاملة (حالة اللاعب، منطق الطاقة/البنق/Aim
  Trainer/التقدّم، كتالوج المتجر، بنك النصوص) — كل هذا C++ نصي عادي.
- **ناقص ولازم تسويه إنت بالـ Editor**: أي شي بصري — المستويات
  (Levels/.umap)، واجهات UMG، الـ Blueprints، الأصول (نماذج، أيقونات،
  أصوات)، وربط المدخلات (Input). هذي كلها ملفات ثنائية تُبنى بالمحرر
  الرسومي، ما تنكتب كنص.
- ما فيه ضمان إن الكود يبني بأول محاولة — اكتبته بعناية متوافق مع
  اصطلاحات UE 5.4، بس بدون تشغيل فعلي ممكن يطلع خطأ تجميع بسيط
  (include ناقص مثلاً) تصلحه بسرعة بأول build عندك.

## الخطوات عندك (بجهازك)

أدلة تفصيلية خطوة-بخطوة (اتبعها بهالترتيب، كل وحدة تعتمد على اللي قبلها):

1. [`docs/RoomLevel_BuildGuide.md`](docs/RoomLevel_BuildGuide.md) —
   المستوى، `WBP_RoomHUD`، مؤقت الساعة، نظام اتصالات المدير، وحوار
   القرار اليومي (يقابل `RoomScreen`).
2. [`docs/Shop_BuildGuide.md`](docs/Shop_BuildGuide.md) — متجر
   بأربع تبويبات (عتاد/شبكة/فلكس/الهدف النهائي) عبر `WidgetSwitcher`
   (يقابل `ShopScreen`).
3. [`docs/AimTrainer_BuildGuide.md`](docs/AimTrainer_BuildGuide.md) —
   لعبة الأهداف المصغرة كويدجت فوق الغرفة، لا كمستوى منفصل (عشان
   مؤقتات الغرفة تستمر بالخلفية) (يقابل `AimTrainerScreen`).

ملخص سريع:

1. افتح `Oblez.uproject` بـ Unreal Editor (يسألك يبني الكود — وافق).
2. أنشئ مستوى `Content/Maps/RoomLevel` وحطه Default Map (`Config/DefaultEngine.ini`
   يشير له مسبقاً).
3. اربط `UOblezPlayerProgress` (GameInstanceSubsystem) بواجهات UMG اللي
   تسويها — نادِ الدوال (`ChangeEnergy`, `BuyGearUpgrade`, ...) واستمع
   لـ `OnChanged` لتحديث العرض، تماماً متل `Provider`/`notifyListeners()`
   بنسخة Flutter.
4. صمم مستويات/واجهات: الغرفة، المتجر، Aim Trainer، شاشة الفصل/الطرد،
   شاشة الفوز (العقار) — كلها Blueprints/UMG تستخدم دوال `Source/Oblez/Logic/`
   و`Source/Oblez/Data/` الجاهزة.

## البنية

```
Oblez.uproject
Source/
  Oblez.Target.cs / OblezEditor.Target.cs
  Oblez/
    Oblez.Build.cs, Oblez.h/.cpp        → الموديول
    OblezGameModeBase.h/.cpp            → GameMode أساسي فاضي
    Player/
      OblezPlayerProgress.h/.cpp        → حالة اللاعب (يقابل PlayerState بـ Flutter)
    Logic/
      OblezEnergyLogic, OblezPingLogic,
      OblezAimTrainerLogic, OblezProgressionLogic
    Data/
      OblezTypes.h                      → Enums مشتركة
      ShopItem.h, OblezShopCatalog      → كتالوج المتجر
      OblezComedyLines                  → بنك النصوص الكوميدي
Config/
  DefaultEngine.ini, DefaultGame.ini
```

## المقابلات مع نسخة Flutter

| Flutter (`oblez/lib/...`) | Unreal (`Source/Oblez/...`) |
|---|---|
| `models/player_state.dart` (ChangeNotifier) | `Player/OblezPlayerProgress` (GameInstanceSubsystem) |
| `logic/energy_logic.dart` | `Logic/OblezEnergyLogic` |
| `logic/ping_logic.dart` | `Logic/OblezPingLogic` |
| `logic/aim_trainer_logic.dart` | `Logic/OblezAimTrainerLogic` |
| `logic/progression_logic.dart` | `Logic/OblezProgressionLogic` |
| `data/shop_catalog.dart` + `models/shop_item.dart` | `Data/OblezShopCatalog` + `Data/ShopItem.h` |
| `data/comedy_lines.dart` | `Data/OblezComedyLines` |
| `RoomScreen`, `ShopScreen`, `AimTrainerScreen`, `GameOverScreen`... | **ناقصة** — تُبنى كمستويات + UMG بالـ Editor |
