# دليل بناء Aim Trainer (WBP_AimTrainer)

يقابل `AimTrainerScreen` بنسخة Flutter. **قرار تصميم مهم يختلف عن
الاقتراح الأول بدليل الغرفة**: هذا **ويدجت يُضاف فوق `WBP_RoomHUD`
(`Add to Viewport`)**، مو مستوى منفصل (`Open Level`) — لأن الانتقال
لمستوى جديد يهدم `Level Blueprint` لمستوى الغرفة، وبالتالي يوقف مؤقت
الساعة وجدولة اتصالات المدير (`docs/RoomLevel_BuildGuide.md`، فقرتين
3 و4). بنسخة Flutter الأصلية، `RoomScreen` تظل حية بالخلفية أثناء
اللعب بـ Aim Trainer، وهالتصميم يحافظ على نفس السلوك بالضبط.

---

## 1) التصميم (Designer)

Widget Blueprint جديد `WBP_AimTrainer`:

- شريط علوي (`HorizontalBox`): `Txt_Timer` ("Aim Trainer — {X}ث")،
  `Txt_Score` ("النقاط: {X}")، `Txt_Combo` ("كومبو: {X}").
- `Txt_Feedback` — سطر نص فاضي افتراضياً، يتلون أخضر/أحمر حسب الحدث.
- `Canvas Panel` باسم `Canvas_PlayArea` ياخذ باقي المساحة (`Fill` بالـ
  Vertical/Horizontal Box الأب)، يحتوي **عنصر وحيد**:
  - `Button` باسم `Btn_Target` (Canvas Slot، Anchors = 0,0 —
    الموضع/الحجم نضبطهم بالكود لا بالتصميم). حط جواه `Image` دائرية
    حمراء (استخدم Brush دائري أو `Image` بخلفية شفافة + `Border`
    نصف قطره كبير). خلي خلفية الزر نفسه Transparent عشان الدائرة
    الحمراء هي اللي تظهر.

---

## 2) متغيرات (My Blueprint → Variables)

| الاسم | النوع | ملاحظة |
|---|---|---|
| `PlayerProgress` | Object Reference (Oblez Player Progress) | |
| `Score` | Integer | افتراضي 0 |
| `Combo` | Integer | افتراضي 0 |
| `SecondsLeft` | Integer | افتراضي 30 |
| `TargetX`, `TargetY` | Float | نسبة 0-1، موضع الهدف الحالي |
| `JitterX`, `JitterY` | Float | افتراضي 0 |
| `bLowEnergy` | Boolean | يُحسب مرة وحدة بـ Construct |
| `SessionTimerHandle`, `JitterTimerHandle`, `TargetTimerHandle` | Timer Handle | |

---

## 3) `Event Construct`

1. `Get Game Instance → Get Subsystem (Oblez Player Progress)` →
   `Set PlayerProgress`.
2. `bLowEnergy = OblezEnergyLogic::IsLow(PlayerProgress.Energy)`.
3. `SessionTimerHandle = Set Timer by Event(Time=1.0, Looping=true)`
   → حدث مخصص `TickSession`.
4. `Branch` على `bLowEnergy`: لو صح، `JitterTimerHandle = Set Timer
   by Event(Time=0.12, Looping=true)` → حدث مخصص `TickJitter`.
5. نادِ `SpawnTarget` (فقرة 5).

## `Event Destruct`

نظّف كل شي (آمن حتى لو الـ Handle غير صالح):
`Clear Timer(SessionTimerHandle)`, `Clear Timer(JitterTimerHandle)`,
`Clear Timer(TargetTimerHandle)`.

---

## 4) `TickSession`

```
Branch (SecondsLeft <= 1)
├─ صح: Clear Timer(SessionTimerHandle) → نادِ EndSession (فقرة 8)
└─ خطأ: SecondsLeft -= 1 → Txt_Timer → Set Text
```

## `TickJitter`

```
Jitter = OblezAimTrainerLogic::JitterOffset()
Set JitterX = Jitter.X   (FVector2D.X)
Set JitterY = Jitter.Y
نادِ PositionTarget (فقرة 6)
```

---

## 5) `SpawnTarget`

```
Clear Timer(TargetTimerHandle)   ← آمن حتى لو أول مرة
Pos = OblezAimTrainerLogic::RandomPosition()
Set TargetX = Pos.X
Set TargetY = Pos.Y
Lifetime = OblezAimTrainerLogic::TargetLifetimeSeconds(Combo)
نادِ PositionTarget
Btn_Target → Set Visibility = Visible
TargetTimerHandle = Set Timer by Event(Lifetime, Looping=false) → OnTargetMissed
```

---

## 6) `PositionTarget`

يحوّل النسبة (0-1) + الـ Jitter لموضع/حجم فعلي بالبكسل — يطابق
منطق `_targetSizeFor` و`LayoutBuilder` بـ Flutter تماماً:

```
Size2D = Canvas_PlayArea → Get Cached Geometry → Get Local Size   (W, H)
TargetSize = Clamp( Min(W, H) * 0.09 , 44.0 , 110.0 )

Branch (bLowEnergy)
├─ صح: Dx = JitterX * W  |  Dy = JitterY * H
└─ خطأ: Dx = 0.0        |  Dy = 0.0

Left = Clamp( TargetX * W - TargetSize/2 + Dx , 0.0 , W - TargetSize )
Top  = Clamp( TargetY * H - TargetSize/2 + Dy , 0.0 , H - TargetSize )

Btn_Target (Canvas Panel Slot):
  Set Position  = (Left, Top)
  Set Size      = (TargetSize, TargetSize)
```

(النودز: `Get Local Size` من `Geometry`، و`Set Position in Viewport`
**لا تستخدمها** — المطلوب `Slot (Canvas Panel Slot) → Set Position`
و`Set Size`، تحصلها بـ "Get Slot as Canvas Slot" على `Btn_Target`.)

---

## 7) `OnTargetMissed` (انتهى وقت الهدف بدون ضغط)

```
Set Combo = 0
Line = OblezComedyLines::RandomLine( OblezComedyLines::GetRankDownTaunts() )
Txt_Feedback → Set Text = Line  |  Set Color and Opacity = أحمر
نادِ SpawnTarget
```

---

## 8) `Btn_Target → On Clicked` (يقابل `_onTargetTapped`)

```
Branch ( OblezPingLogic::RollLagSpike(PlayerProgress.NetworkLevel) )
├─ صح (تقطيع):
│    Line = RandomLine(GetLagSpikeLines())
│    Txt_Feedback → Set Text = Line | لون أحمر
│    (رجّع بدون أي شي ثاني — الهدف يضل مكانه، المؤقت يكمل عد)
│
└─ خطأ (إصابة مسجّلة):
     Clear Timer(TargetTimerHandle)
     HitScore = OblezAimTrainerLogic::ScoreForHit(Combo)   ← احسبها *قبل* ما تزيد الكومبو
     Set Score = Score + HitScore
     NewCombo = Combo + 1
     Set Combo = NewCombo
     Branch ( NewCombo % 5 == 0 )
     ├─ صح: Line = RandomLine(GetHypeComments()) → Txt_Feedback أخضر
     └─ خطأ: Txt_Feedback → Set Text = "" (فاضي)
     Txt_Score / Txt_Combo → تحديث النصوص
     نادِ SpawnTarget
```

**تنبيه ترتيب مهم**: لازم تحسب `HitScore` باستخدام قيمة `Combo`
**قبل** الزيادة (نفس `_score += _logic.scoreForHit(_combo); _combo =
newCombo;` بالكود الأصلي) — إذا حسبتها بعد الزيادة راح تعطي نقاط أعلى
من المفروض بكل إصابة.

---

## 9) `EndSession` (تنتهي الجولة)

```
Clear Timer(TargetTimerHandle)
Clear Timer(JitterTimerHandle)
Btn_Target → Set Visibility = Collapsed

Kicked (bool) , Reward (int, Output) = PlayerProgress → RecordAimTrainerResult(Score)

Branch (Kicked)
├─ صح:
│    Reason = RandomLine(GetKickedReasons())
│    Create Widget (WBP_GameOver) → Set Reason, Set Kind = KickedFromTeam
│    Add to Viewport (فوق كل شي)
│    Remove from Parent (لهذا الويدجت، WBP_AimTrainer)
│    (اختياري: Remove from Parent لـ WBP_RoomHUD كمان، عشان يطابق
│    "مسح المكدس بالكامل" بنسخة Flutter — القرار التصميمي لك)
│
└─ خطأ:
     Create Widget (WBP_AimTrainerResult — بسيط: نص "نقاطك: {Score}\n
     مكافأة: {Reward}$\nنقاط رانك: +{Score}" + زر "رجوع للغرفة")
     Add to Viewport
     زر "رجوع للغرفة" → On Clicked:
        Remove from Parent (نتيجة الجولة)
        Remove from Parent (WBP_AimTrainer نفسه)
        ← WBP_RoomHUD يظهر تلقائياً (كان تحته طول الوقت، ما توقف)
```

`RecordAimTrainerResult` بالكود C++ توقيعها
`bool RecordAimTrainerResult(int32 Score, int32& OutReward)` —
بالبلوبرنت يطلع لك Node بمخرجين: القيمة المرجعة (Kicked) ومخرج
`Out Reward` باسم `Reward` تلقائياً.

---

## ترتيب التنفيذ المقترح

1. التصميم (فقرة 1) + المتغيرات (فقرة 2) بدون منطق.
2. `Event Construct` + `SpawnTarget` + `PositionTarget` — شغّل
   وتأكد الهدف يطلع بمكان عشوائي وحجمه صحيح.
3. `Btn_Target → On Clicked` (فقرة 8) — جرّب تسجيل نقاط وكومبو.
4. `OnTargetMissed` (فقرة 7) — جرّب تتجاهل هدف لين ينتهي وقته.
5. `TickSession` + `EndSession` (فقرتين 4 و9) — أكمل جولة كاملة.
6. `TickJitter` (فقرة 4) — جرّب بطاقة منخفضة (عدّل `Energy` يدوياً
   بالـ Editor أو زر تجريبي لتنزيله) وتأكد الاهتزاز يظهر.
7. اربط `Btn_AimTrainer` بـ `WBP_RoomHUD` (موصوف بدليل الغرفة، فقرة
   الأزرار) وجرّب الدورة كاملة من الغرفة.
