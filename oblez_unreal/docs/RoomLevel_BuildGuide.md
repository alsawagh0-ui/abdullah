# دليل بناء RoomLevel بالمحرر

هذا دليل تنفّذه إنت بـ Unreal Editor عندك (ما فيه شي هنا اتبنى أو
اتفحص فعلياً — راجع تحذير `README.md` الرئيسي). يفترض إنك فتحت
`Oblez.uproject` والكود بنى بنجاح.

الهدف: مستوى `RoomLevel` يطابق `RoomScreen` بنسخة Flutter — هيدر
وقت اليوم، بطاقة إحصائيات + شريط طاقة، أزرار (Aim Trainer/المتجر/إنهاء
اليوم)، نظام اتصالات مدير عشوائية، وحوار القرار اليومي.

---

## 0) تصحيح مهم قبل ما تبدأ

عدّلت `OblezPlayerProgress.h` بالكوميت الأخير: الحدث `OnChanged` كان
`DECLARE_MULTICAST_DELEGATE` عادي (C++ فقط، ما ينعرض بالبلوبرنت
إطلاقاً). صار الحين `DECLARE_DYNAMIC_MULTICAST_DELEGATE` +
`UPROPERTY(BlueprintAssignable)` عشان تقدر تعمل "Bind Event to
OnChanged" من أي Widget Blueprint. لو عندك نسخة أقدم مسحوبة، اسحب
آخر تحديث قبل لا تبدأ.

---

## 1) المستوى نفسه

1. Content Browser → مجلد جديد `Content/Maps`.
2. File → New Level → **Empty Level** → احفظه باسم `RoomLevel` جوا
   `Content/Maps`.
3. أضف: `Directional Light`، `Sky Atmosphere` أو `Sky Light` بسيط،
   أرضية (Cube مُكبّر أو `BSP Box`)، و`Player Start`. التفاصيل
   البصرية (غرفة القيمر، الكرسي، الشاشات) حرة لك — المطلوب هنا بنية
   وظيفية تشتغل، مو تصميم فني.
4. World Settings (Window → World Settings) → **GameMode Override** =
   `OblezGameModeBase` (أو تأكد `DefaultEngine.ini` يضبطه افتراضياً —
   موجود مسبقاً بالمشروع).
5. تأكد `Config/DefaultEngine.ini` يشير لـ
   `/Game/Maps/RoomLevel.RoomLevel` كـ Default Map — موجود مسبقاً،
   بس أول ما يفتح المشروع بدون هالمستوى كان يطلع تحذير؛ الحين حله.

---

## 2) Widget Blueprint: WBP_RoomHUD

Content Browser → مجلد `Content/UI` → **User Interface → Widget
Blueprint** → سمّه `WBP_RoomHUD`.

### تصميم العناصر (Designer tab)

يقابل جسم `RoomScreen.build()`:

| عنصر Flutter | Widget بـ UMG | ملاحظات |
|---|---|---|
| أيقونة الوقت الدائرية | `Image` داخل `SizeBox` (56×56) | اللون/الصورة تتغيّر بالـ Graph حسب `sky.accent`/`sky.icon` |
| "اليوم X" / "الفترة — الساعة HH:00" | `TextBlock` × 2 | داخل `VerticalBox` جنب الأيقونة |
| بطاقة الإحصائيات | `Border` (خلفية شفافة + حدود) يحتوي `WrapBox` | جوا الـ WrapBox: 5 × `TextBlock` (فلوس، إنذارات، شبكة، رانك، مرحلة) — أو صمم `WBP_StatChip` منفصل وكرره |
| شريط الطاقة | `ProgressBar` | `Percent` = `Energy / 100.0` |
| الأزرار الثلاثة | 3× `Button` بداخلها `TextBlock` | "العب Aim Trainer"، "المتجر"، "إنهاء اليوم" |

سمّ كل عنصر بوضوح بالـ Details panel (مثلاً `Txt_Day`, `Txt_HourPeriod`,
`Txt_Money`, `Txt_Warnings`, `Txt_Network`, `Txt_Rank`, `Txt_Tier`,
`Bar_Energy`, `Btn_AimTrainer`, `Btn_Shop`, `Btn_EndDay`, `Img_TimeIcon`)
— بتحتاجها بالـ Graph بعد شوي.

### منطق الـ Graph

**Event Construct:**
1. `Get Game Instance` → `Get Subsystem` (Class = `Oblez Player
   Progress`) → احفظ الناتج بمتغير Object Reference اسمه
   `PlayerProgress` (Cast مو لازم، النوع مضبوط من الـ Class بالنود).
2. من `PlayerProgress` → `Bind Event to On Changed` → اربطه بحدث
   مخصص جديد اسمه `RefreshUI` (Custom Event، بدون مدخلات).
3. نادِ `RefreshUI` مرة وحدة يدوياً بنهاية `Event Construct` (عشان
   القيم الابتدائية تنعرض قبل أول تغيير).

**دالة/حدث `RefreshUI`:**
- من `PlayerProgress` اسحب القيم (كلها `UPROPERTY(BlueprintReadOnly)`
  فتقدر تسحبها مباشرة كـ Get Node):
  - `Txt_Day` → `Set Text` = `Format Text("اليوم {0}", Day)`
  - `Txt_Money` → `Format Text("{0}$", Money)`
  - `Txt_Warnings` → `Format Text("{0}/3", MissedManagerCalls)`
  - `Txt_Network` → `Format Text("شبكة {0}", NetworkLevel)`
  - `Txt_Rank` → `Format Text("{0}", RankPoints)`
  - `Txt_Tier` → نادِ `OblezProgressionLogic::LabelFor(Tier)`
    (Blueprint Pure Function) → `Set Text`
  - `Bar_Energy` → `Percent` = `Energy / 100.0` (قسمة float)
  - `Txt_HourPeriod` و`Img_TimeIcon` → استخدم **Select** node على
    `Hour` (أو سلسلة `Branch`/`Switch on Int` مقسّمة لأربع نطاقات
    5-12 / 12-17 / 17-21 / غيره) لاختيار النص واللون بالضبط متل
    `_timeOfDayInfo(hour)` بنسخة Flutter — أربع حالات: الصبح
    (أزرق فاتح)، الظهر (كهرماني)، المغرب (برتقالي)، الليل (نيلي).

**أزرار (`On Clicked` لكل واحد):**
- `Btn_AimTrainer` → `Create Widget` من `WBP_AimTrainer` → `Add to
  Viewport` (**مو** `Open Level`! — انتقال مستوى يهدم `Level
  Blueprint` الحالي، يعني مؤقت الساعة وجدولة اتصالات المدير بالفقرتين
  3 و4 توقف. الغرض من نسخة Flutter إن هالمؤقتات تستمر بالخلفية وأنت
  تلعب Aim Trainer، فلازم يضل نفس المستوى — راجع
  `docs/AimTrainer_BuildGuide.md`).
- `Btn_Shop` → `Add to Viewport` لـ `WBP_Shop` (راجع
  `docs/Shop_BuildGuide.md`).
- `Btn_EndDay` → `Create Widget` من `WBP_DailyChoiceDialog` (قسم 4
  تحت) → `Add to Viewport`.

بنهاية هالخطوة: أضف `WBP_RoomHUD` للفيوبورت — إما من `Level
Blueprint` بحدث `Event BeginPlay` (`Create Widget` → `Add to
Viewport`)، أو من `OblezGameModeBase` بدالة `BeginPlay` (أنظف تقنياً
لو تبي تتفادى منطق بالـ Level Blueprint، بس هذا اختياري بهالمرحلة).

---

## 3) مؤقت الساعة (Hour Tick)

بالـ **Level Blueprint** لـ `RoomLevel` (Open Level Blueprint):

1. `Event BeginPlay` → `Set Timer by Function Name` (أو `Set Timer
   by Event`): الدالة `TickHour` على `PlayerProgress`، **Time =
   12.0**، **Looping = true**.
   - عشان توصل لـ `PlayerProgress`: نفس نود `Get Game Instance →
     Get Subsystem` من الفقرة 2.
2. هذا يقابل `Timer.periodic(_hourTickInterval, ...)` بـ
   `RoomScreen` بنسخة Flutter — كل 12 ثانية واقعية = ساعة لعبة وحدة.

---

## 4) نظام اتصالات المدير العشوائية

### WBP_ManagerCallDialog

Widget Blueprint جديد، يقابل `ManagerCallDialog`:
- `TextBlock` للرسالة (`Txt_Message`)
- `TextBlock` للعد التنازلي (`Txt_Countdown`)
- `Button` "حاضر!" (`Btn_Answer`)

**متغيرات:** `RemainingSeconds` (Integer، افتراضي 5).

**Graph:**
1. `Event Construct`: `Set Timer by Event` باسم `CountdownTimer`،
   Time = 1.0، Looping = true → يربط بحدث مخصص `Tick1Second`.
2. `Tick1Second`:
   - لو `RemainingSeconds <= 1` → `Clear Timer` (CountdownTimer) →
     نادِ Dispatcher/Event مخصص `OnTimeout` (Event Dispatcher تضيفه
     بالـ Widget) → `Remove from Parent`.
   - غير كذا: `RemainingSeconds -= 1` → حدّث `Txt_Countdown`.
3. `Btn_Answer → On Clicked`: `Clear Timer` (CountdownTimer) → نادِ
   Event Dispatcher `OnAnswered` → `Remove from Parent`.
4. أضف **Event Dispatcher** باسمين `OnAnswered` و`OnTimeout` (بدون
   معاملات) — هذي تقابل `onAnswered`/`onTimeout` callbacks بنسخة
   Flutter.

### الجدولة (بالـ Level Blueprint أو GameMode)

1. دالة/حدث مخصص `ScheduleNextManagerCall`:
   - `Random Integer in Range(15, 40)` → `Set Timer by Event` (غير
     Looping، مرة وحدة) → يربط بحدث `TriggerIncomingCall`.
2. `TriggerIncomingCall`:
   - نادِ `OblezComedyLines::GetManagerCalls` → `RandomLine` → احصل
     رسالة عشوائية.
   - `Create Widget` من `WBP_ManagerCallDialog` → مرّر الرسالة →
     `Add to Viewport`.
   - Bind Event لـ `OnAnswered` → نادِ `ScheduleNextManagerCall` من
     جديد (بدون عقوبة).
   - Bind Event لـ `OnTimeout` →
     - `PlayerProgress → IgnoreManagerCall` (القيمة الافتراضية 50
       كافية، تطابق Flutter).
     - Branch على `PlayerProgress → IsFired`:
       - **صح**: نادِ `OblezComedyLines::GetFiredReasons` →
         `RandomLine` → افتح `GameOverLevel` (أو Widget) مع تمرير
         السبب + النوع "Fired" (قسم 6).
       - **خطأ**: نادِ `ScheduleNextManagerCall` من جديد.
3. نادِ `ScheduleNextManagerCall` مرة وحدة من `Event BeginPlay`
   بالمستوى (جنب Timer الساعة بالفقرة 3).

---

## 5) WBP_DailyChoiceDialog

يقابل `DailyChoiceDialog`: 3 أزرار بنصوص/وصف واضح:
- "رانك إضافي" — "طاقة -15، نقاط رانك +25"
- "عمل إضافي" — "فلوس +80، طاقة -20"
- "نوم بدري" — "يخفف إنذار واحد من سجلك"

كل زر بـ `On Clicked`:
- نادِ `PlayerProgress → ApplyDailyChoice` مع القيمة المطابقة من
  `EOblezDailyChoice` (`ExtraRank` / `ExtraWork` / `SleepEarly`).
- `Remove from Parent`.

بما إن `PlayerProgress → Sleep()` (المستدعاة داخل `ApplyDailyChoice`)
تطلق `OnChanged`، و`WBP_RoomHUD` مربوطة عليه أصلاً، الهيدر والإحصائيات
تتحدث تلقائياً بدون أي كود إضافي.

---

## 6) شاشة الفشل (فصل/طرد) — أساسيات فقط

لسا برّا نطاق هالدليل بالتفصيل (تحتاج تصميمها متل `GameOverScreen`
بـ Flutter: أيقونة/لون حسب النوع، بطاقة السبب، ملخص إحصائيات، زر "من
جديد" ينادي `PlayerProgress → ResetGame` ويرجع لـ `RoomLevel`). الأهم
الحين: أنشئ `WBP_GameOver` بمتغيرين Input (`Reason: Text`,
`Kind: Enum` جديد بسيط `Fired`/`KickedFromTeam` تضيفه بالبلوبرنت أو
بالكود لاحقاً)، واستدعيه من نقطتين:
- `TriggerIncomingCall → OnTimeout` عند `IsFired` (فقرة 4).
- أي مكان تستدعي منه `RecordAimTrainerResult` وتلقى الناتج
  `IsKickedFromTeam` (لما تبني مستوى/ويدجت Aim Trainer لاحقاً).

---

## ترتيب مقترح لتنفيذ هالدليل

1. تصحيح الكود (تم بالفعل، اسحب آخر كوميت). ✅
2. القسم 1 (المستوى الفاضي يفتح بدون تحذيرات).
3. القسم 2 (WBP_RoomHUD يعرض قيم البداية الصحيحة).
4. القسم 3 (تأكد الساعة تتحرك والطاقة تنزل).
5. القسم 4 (اتصال مدير كامل، جرّب تجاهله 3 مرات لين تتأكد الفصل يشتغل).
6. القسم 5 (زر إنهاء اليوم يفتح الحوار ويطبّق الأثر).
7. القسم 6 (شاشة فشل بسيطة تسدّ الحلقة).

كل قسم مستقل تقريباً — تقدر تختبر بالـ **Play In Editor** بعد كل
قسم بدل ما تبني كل شي مرة وحدة.
