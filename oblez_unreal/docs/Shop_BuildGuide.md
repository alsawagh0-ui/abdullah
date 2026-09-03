# دليل بناء المتجر (WBP_Shop)

يفترض إنك خلّصت `docs/RoomLevel_BuildGuide.md` — بالذات `PlayerProgress`
كمتغير بـ `WBP_RoomHUD` وربطه بـ `Get Subsystem`. يقابل هالدليل
`ShopScreen` بنسخة Flutter (4 تبويبات: عتاد/شبكة/فلكس/الهدف النهائي).

**تصحيح لازم قبل ما تبدأ:** أضفت دالة `GetPropertyPrice()`
(`BlueprintPure`, static) بـ `OblezPlayerProgress` — القيمة القديمة
`PropertyPrice` كانت `static constexpr` بالكود C++ بس، ما تنقرأ من
بلوبرنت إطلاقاً (نفس مشكلة `OnChanged` بالدليل السابق). اسحب آخر
كوميت قبل لا تبدأ.

---

## 1) WBP_ShopItemRow (ويدجت فرعي قابل لإعادة الاستخدام)

Widget Blueprint جديد باسم `WBP_ShopItemRow` — صف واحد بأي تبويب
(عتاد/شبكة/فلكس).

### التصميم
`Border` (بطاقة) يحتوي `HorizontalBox`:
- دائرة أيقونة صغيرة (`Image` داخل `SizeBox` 48×48 — الأيقونة الفعلية
  تختارها إنت حسب العنصر، ما فيها حقل بالكتالوج C++، راجع ملاحظة
  `ShopItem.h`).
- `VerticalBox`: `Txt_Name` (عريض) + `Txt_Description` (صغير) +
  `Txt_Status` (شارة الحالة، بلون يتغيّر).
- `Button` باسم `Btn_Buy` بداخله `Txt_BuyLabel`.

### متغيرات (My Blueprint → Variables)
- `Item` (Type: `Oblez Shop Item`, Struct) — Private، بيتخزن وقت
  `SetupItem`.

### Event Dispatcher (My Blueprint → Event Dispatchers → +)
- `OnBuyRequested` — بدون Inputs (كافي، لأن `WBP_Shop` نفسه يحتفظ
  بمرجع الـ Widget اللي استدعاه عبر الـ Binding، ويقدر يقرأ `Item`
  منه مباشرة كـ Get Variable).

### دالة `SetupItem`
أضف Function جديدة (مو Event) بمدخلات:
- `NewItem` (Oblez Shop Item)
- `StatusText` (Text)
- `StatusColor` (Linear Color)
- `bInteractable` (Boolean)
- `bOwned` (Boolean)

الجسم:
1. `Set Item = NewItem`.
2. `Txt_Name → Set Text = NewItem.Name` (Break Oblez Shop Item أو
   Get مباشر من بنية الـ Struct).
3. `Txt_Description → Set Text = NewItem.Description`.
4. `Txt_Status → Set Text = StatusText`، `Set Color and Opacity =
   StatusColor`.
5. `Branch` على `bOwned`:
   - **صح**: `Btn_Buy → Set Visibility = Collapsed` (يقابل أيقونة ✔
    بدل الزر بنسخة Flutter — لو تبي نفس الشكل بالضبط ضيف `Image`
    منفصلة "تشيك" وخلها `Visible` عكس الزر).
   - **خطأ**: `Btn_Buy → Set Visibility = Visible` → `Set Is Enabled
    = bInteractable`.

### `Btn_Buy → On Clicked`
→ `OnBuyRequested → Broadcast` (بدون معاملات، الأب يقرأ `Item` من
هالويدجت نفسه بعد الـ Bind).

---

## 2) WBP_Shop — الحاوية الرئيسية

### التصميم
- شريط علوي: `Txt_Title` ("المتجر — {Money}$") + 4 أزرار تبويب
  (`Btn_TabGear`, `Btn_TabNetwork`, `Btn_TabCosmetic`,
  `Btn_TabProperty`).
- `WidgetSwitcher` باسم `Switcher_Tabs` بأربع Slots:
  - **Slot 0 (عتاد)**: `ScrollBox` يحتوي `Txt_ProgressHeader` +
    `ProgressBar` (`Bar_GearProgress`) + `VerticalBox`
    (`Box_GearItems`) فاضي (يتعبى بالكود).
  - **Slot 1 (شبكة)**: نفس الشيء بأسماء `Bar_NetworkProgress`،
    `Box_NetworkItems`.
  - **Slot 2 (فلكس)**: `Txt_CosmeticHeader` ("مملوك X من Y") +
    `VerticalBox` (`Box_CosmeticItems`).
  - **Slot 3 (الهدف النهائي)**: تصميم ثابت — أيقونة بيت، عنوان،
    وصف، `Txt_TierLabel`، `Txt_MoneyProgress`، `ProgressBar`
    (`Bar_MoneyProgress`)، زر `Btn_BuyProperty`.
- زر إغلاق (`Btn_Close`) يقفل المتجر ويرجع للغرفة (`Remove from
  Parent`).

### متغيرات
- `PlayerProgress` (Object Reference, Oblez Player Progress).

### `Event Construct`
1. `Get Game Instance → Get Subsystem (Oblez Player Progress)` →
   `Set PlayerProgress`.
2. `Bind Event to On Changed` (من `PlayerProgress`) → حدث مخصص
   `RefreshShop`.
3. نادِ `RefreshShop` يدوياً مرة وحدة.
4. أزرار التبويبات الأربعة → كل وحدة `On Clicked` تنادي
   `Switcher_Tabs → Set Active Widget Index` بالرقم المطابق (0-3).

### حدث `RefreshShop`
1. `Txt_Title → Set Text = Format Text("المتجر — {0}$", PlayerProgress.Money)`.
2. نادِ 3 دوال فرعية جديدة (كلها Custom Functions بـ `WBP_Shop`):
   - `PopulateGear()`
   - `PopulateNetwork()`
   - `PopulateCosmetics()`
3. حدّث تبويب الهدف النهائي مباشرة هنا (تفاصيله بالفقرة 4 تحت).

### دالة `PopulateGear` (ونظيراتها لـ Network بنفس المنطق بالضبط)
1. `Box_GearItems → Clear Children`.
2. `Items = OblezShopCatalog::GetGearItems` (Pure function، تقدر
   تناديها مباشرة).
3. `MaxTier = Get(Items, Items.Length - 1).Tier` (آخر عنصر بالمصفوفة).
4. `Progress = PlayerProgress.GearLevel / (float)MaxTier` (احترس:
   قسمة Integer بالبلوبرنت تحتاج تحويل صريح لـ Float أول — استخدم
   `Integer / Integer (float)` أو حوّل الطرفين بـ `Int to Float`
   قبل القسمة، وإلا النتيجة تنقصّ لعدد صحيح).
5. `Txt_ProgressHeader → Set Text = Format Text("المستوى {0} من {1}",
   PlayerProgress.GearLevel, MaxTier)`.
6. `Bar_GearProgress → Set Percent = Clamp(Progress, 0.0, 1.0)`.
7. `For Each Loop` على `Items` (Loop Body، المتغير `Item`):
   - `bOwned = Item.Tier <= PlayerProgress.GearLevel`.
   - `bBuyable = Item.Tier == PlayerProgress.GearLevel + 1`.
   - `StatusText`:
     - `bOwned` → `"مملوك حالياً"`.
     - غير كذا و`bBuyable` → `Format Text("{0}$", Item.Price)`.
     - غير كذا → `"يحتاج الترقية السابقة"`.
   - `StatusColor`: أخضر لو `bOwned`، برتقالي (accent الفئة) لو
     `bBuyable`، رمادي غير كذا.
   - `Create Widget (WBP_ShopItemRow)` → `SetupItem(Item, StatusText,
     StatusColor, bBuyable, bOwned)`.
   - `Bind Event to OnBuyRequested` (من الويدجت المُنشأ) → Custom
     Event `HandleGearBuy` **لازم ياخذ الـ Row Widget نفسه كمدخل**
     (اربط بـ "Create Event" وحدد Self reference) عشان تقدر تقرأ
     `RowWidget.Item` بالـ Event:
     - `PlayerProgress → BuyGearUpgrade(RowWidget.Item.Tier,
       RowWidget.Item.Price)` → Branch:
       - **صح**: اعرض توست "تم الشراء! 🎉" (فقرة 3) — مو لازم تنادي
         `RefreshShop` يدوياً، لأن `BuyGearUpgrade` ينادي
         `OnChanged.Broadcast()` بذاته وأنت أصلاً Bound عليه، فبيعيد
         تنفيذ `RefreshShop` تلقائياً.
       - **خطأ**: اعرض توست "ما تكفي فلوسك، أو لازم تكمل الترقية
         اللي قبلها أول."
   - `Add Child to Box_GearItems`.
8. كرر بالضبط نفس الفقرة 7 بدالة `PopulateNetwork` مع
   `GetNetworkItems`/`BuyNetworkUpgrade`/`Bar_NetworkProgress`/إلخ.

### دالة `PopulateCosmetics`
نفس نمط `PopulateGear` بس:
- `Items = OblezShopCatalog::GetCosmeticItems`.
- `bOwned = PlayerProgress.OwnedCosmetics.Contains(Item.Id)`
  (`Id` بالكتالوج `FName`، والحقل بـ `PlayerProgress` أصلاً
  `TArray<FName>` — يطابقون مباشرة).
- ما فيه مفهوم "Buyable حسب مستوى" — الزر شغّال دايماً لو مو مملوك.
- الشراء: `PlayerProgress → BuyCosmetic(Item.Id, Item.Price)`.
- عدّاد أعلى التبويب: `Txt_CosmeticHeader → Format Text("مملوك {0} من
  {1}", OwnedCount, Items.Length)` — احسب `OwnedCount` بحلقة عد أو
  `Filter Array` على `Items` بشرط `OwnedCosmetics.Contains(Item.Id)`.

---

## 3) رسالة التوست (بديل SnackBar/ScaffoldMessenger)

أبسط حل بلوبرنت-فقط: أضف `Txt_Toast` (TextBlock مخفي افتراضياً)
بأسفل `WBP_Shop`، ودالة `ShowToast(Message: Text)`:
1. `Txt_Toast → Set Text = Message` → `Set Visibility = Visible`.
2. `Set Timer by Event` (غير Looping، Time = 2.0) → حدث مخصص يخلي
   `Txt_Toast → Set Visibility = Hidden`.

---

## 4) تبويب الهدف النهائي (Slot 3)

بنهاية `RefreshShop` (أو بدالة فرعية `RefreshPropertyTab`):
1. `Txt_TierLabel → Set Text = OblezProgressionLogic::LabelFor(PlayerProgress.Tier)`.
2. `Txt_MoneyProgress → Set Text = Format Text("{0}$ / {1}$",
   PlayerProgress.Money, UOblezPlayerProgress::GetPropertyPrice())`
   (دالة static، تناديها بدون حاجة لمرجع `PlayerProgress`).
3. `Bar_MoneyProgress → Set Percent = Clamp(PlayerProgress.Money /
   (float)UOblezPlayerProgress::GetPropertyPrice(), 0.0, 1.0)`.
4. `Btn_BuyProperty → Set Is Enabled = PlayerProgress.CanBuyProperty()`.

`Btn_BuyProperty → On Clicked`:
1. `PlayerProgress → BuyProperty` → Branch:
   - **خطأ**: `ShowToast("لازم توصل لمرحلة \"المحترف\" وتوفر السعر
     كامل.")`.
   - **صح**: افتح شاشة/ويدجت الفوز (`WBP_Ending` — تصميمها حر لك،
     تقابل `EndingScreen` بنسخة Flutter: رسالة تهنئة + زر يرجع
     للبداية عبر `PlayerProgress → ResetGame` ثم إخفاء كل الويدجتس
     والرجوع لـ `WBP_RoomHUD`).

---

## ترتيب التنفيذ المقترح

1. `WBP_ShopItemRow` لحاله، اختبره بويدجت تجريبي بسيط.
2. `WBP_Shop` تبويب العتاد فقط (`PopulateGear` + التبديل بينه وبين
   نفسه لتتأكد الـ WidgetSwitcher شغّال).
3. كرر بنفس النمط لـ Network ثم Cosmetics.
4. تبويب الهدف النهائي.
5. اربط `Btn_Shop` بـ `WBP_RoomHUD` (already بالدليل السابق) وجرّب
   دورة شراء كاملة من الغرفة.
