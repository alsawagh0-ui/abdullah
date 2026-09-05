<div dir="rtl">

# 15 — قائمة الإطلاق: ما تفعله أنت بحسابك، وما يفعله المستودع تلقائياً

كل ما في الشيفرة جاهز. الخطوات التالية تحتاج **حسابك** لأنها تربط التطبيق بهويتك عند Apple وبمشروعك عند Supabase. رتّبتها بحيث تنسخ قيمة من مكان وتلصقها في مكان آخر فقط.

## ٠. الحالة الآن — وما يعمل بلا أي إعداد

التطبيق منشور على **https://alsawagh0-ui.github.io/abdullah/almunjez/** ومربوط بمشروع Supabase `occukboecvnzjnatubre` (المخطط مُشغَّل).

**طريقة الدخول التي تعمل الآن بدون لمس لوحة Supabase: البريد + كلمة المرور.**

1. افتح الرابط → «تخطٍّ» → اضغط «ليس لديك حساب؟ أنشئ واحداً».
2. أدخل بريدك وكلمة مرور (٨ أحرف فأكثر) → «إنشاء حساب».
3. يصلك بريد «Confirm your signup». اضغط رابطه. **ستظهر صفحة فارغة أو `localhost` — هذا طبيعي**؛ التأكيد يتم في خادم Supabase قبل التحويل.
4. عد إلى التطبيق → «تسجيل الدخول» بالبريد وكلمة المرور نفسها → تُكمل ملفك وتدخل.

كل الطرق الأخرى في صفحة الدخول تحتاج إعداداً من الجدول التالي. رتّبتها من الأسرع إلى الأبطأ:

| الطريقة | ماذا ينقصها | أين | الخطوة |
|---|---|---|---|
| رابط البريد يفتح التطبيق بدل صفحة فارغة | Site URL و Redirect URLs | Authentication → **URL Configuration** | Site URL = `https://alsawagh0-ui.github.io/abdullah/almunjez/` ، وأضف في Redirect URLs: `https://alsawagh0-ui.github.io/abdullah/almunjez/**` |
| رمز من ٦ أرقام في البريد (بدل الرابط) | القالب لا يحوي الرمز | Authentication → **Email Templates** → Magic Link | أضف سطراً فيه `{{ .Token }}` (مثلاً: `رمز الدخول: {{ .Token }}`). إن كان التعديل مقفلاً فتجاهل هذه الطريقة — كلمة المرور تكفي |
| Google | OAuth Client (مجاني) | console.cloud.google.com → APIs & Services → Credentials → OAuth client ID (Web) ثم Supabase → Authentication → Providers → **Google** | Authorized redirect URI في Google = `https://occukboecvnzjnatubre.supabase.co/auth/v1/callback` ، ثم انسخ Client ID/Secret إلى Supabase |
| Apple | حساب مطور + Services ID | الجدول «أ» أدناه | |
| الجوال (SMS) | مزوّد SMS مدفوع | Authentication → Providers → **Phone** | Twilio أو MessageBird |

ملاحظة: أي تغيير في Supabase لا يحتاج نشراً جديداً للتطبيق؛ يعمل فور الحفظ.

## أ. Apple Developer (مرة واحدة)

| # | أين | ماذا | تنتج |
|---|---|---|---|
| 1 | developer.apple.com → Certificates, IDs & Profiles → **Identifiers** → App IDs | أنشئ App ID بالمعرّف `kw.almunjez.almunjez`، وفعّل: **Push Notifications** و**Sign in with Apple** | App ID |
| 2 | Identifiers → **Services IDs** | أنشئ Services ID (مثل `kw.almunjez.web`)، فعّل Sign in with Apple، Primary App ID = App ID أعلاه، Return URL = `https://<project-ref>.supabase.co/auth/v1/callback` | Services ID (تحتاجه Supabase) |
| 3 | **Keys** → + | مفتاح باسم «AlMunjez APNs»، فعّل **Apple Push Notifications service (APNs)** | ملف `AuthKey_XXXXXXXXXX.p8` + **Key ID** — يُنزَّل مرة واحدة فقط |
| 4 | **Keys** → + | مفتاح ثانٍ، فعّل **Sign in with Apple**، اختر Primary App ID | ملف `.p8` + Key ID |
| 5 | Membership | انسخ **Team ID** | Team ID |
| 6 | appstoreconnect.apple.com → Apps → + | تطبيق جديد: الاسم «المنجز»، اللغة الأساسية العربية، Bundle ID من الخطوة 1، SKU `almunjez` | صفحة التطبيق في App Store Connect |
| 7 | App Store Connect → Users and Access → **Integrations → App Store Connect API** → + | مفتاح بدور **App Manager** | `AuthKey_*.p8` + Key ID + **Issuer ID** (لخط TestFlight التلقائي) |

## ب. Supabase (مرة واحدة)

| # | أين | ماذا |
|---|---|---|
| 1 | supabase.com → New project | أقرب منطقة للخليج؛ احفظ كلمة مرور قاعدة البيانات |
| 2 | SQL Editor | الصق محتوى `backend/schema/001_initial.sql` وشغّله ✅ (مُنفَّذ)، ثم `003_storage.sql` (حاوية الملفات الخاصة لصور الإثبات — دقيقة واحدة)، ثم `002_push_cron.sql` بعد نشر الدالة (الخطوة 6) |
| 3 | Authentication → Providers → **Apple** | فعّل، Client IDs = `kw.almunjez.almunjez,kw.almunjez.web`، وSecret Key يُولَّد من مفتاح الخطوة أ‑4 (الدليل في صفحة الإعداد نفسها) |
| 4 | Authentication → Providers → **Phone** | فعّل، اختر مزوّد SMS (Twilio أو MessageBird) وضع مفاتيحه |
| 5 | Project Settings → API | انسخ **Project URL** و**anon/publishable key** |
| 6 | الطرفية | `supabase functions deploy push-sender --no-verify-jwt` من مجلد `backend/`، ثم الأسرار: `supabase secrets set APNS_TEAM_ID=… APNS_KEY_ID=… APNS_PRIVATE_KEY="$(cat AuthKey_XXXX.p8)" APNS_ENV=sandbox` |
| 7 | SQL Editor | `alter database postgres set app.settings.supabase_url = 'https://<ref>.supabase.co';` ثم شغّل `002_push_cron.sql` |

## ج. تشغيل التطبيق على جهازك (Mac + Xcode)

```bash
cd almunjez/app
flutter pub get
open ios/Runner.xcworkspace   # Signing & Capabilities: اختر فريقك — الحقوق (Push, Sign in with Apple) مضبوطة مسبقاً
flutter run --dart-define=SUPABASE_URL=https://<ref>.supabase.co --dart-define=SUPABASE_ANON_KEY=<anon>
```

أول تشغيل: سجّل الدخول بـ Apple، اقبل الإشعارات، ثم من جهاز ثانٍ (أو حساب هاتف) اطلب الانضمام وراقب وصول الإشعار.

## د. TestFlight تلقائياً من GitHub (اختياري)

أضف في المستودع → Settings → Secrets and variables → Actions:

| السر | من أين |
|---|---|
| `APPLE_TEAM_ID` | أ‑5 |
| `ASC_KEY_ID`، `ASC_ISSUER_ID`، `ASC_KEY_P8` | أ‑7 (محتوى ملف p8 كاملاً) |
| `IOS_DIST_P12_BASE64`، `IOS_DIST_P12_PASSWORD` | شهادة Apple Distribution مصدَّرة من Keychain بصيغة p12 ثم `base64 -i cert.p12` |
| `IOS_PROVISION_BASE64` | ملف App Store provisioning profile للمعرّف `kw.almunjez.almunjez` بعد `base64 -i profile.mobileprovision` |

ثم Actions → **AlMunjez** → Run workflow. بدون هذه الأسرار يعمل الخط حتى بناء iOS غير الموقّع فقط (يتحقق أن المشروع يُترجَم).

## هـ. قبل النشر في App Store

- `aps-environment` في `ios/Runner/Runner.entitlements` يتحول إلى `production` تلقائياً عند التصدير للمتجر؛ غيّر `APNS_ENV=production` في أسرار Supabase عندها.
- سياسة الخصوصية وشاشة حذف الحساب موجودتان (الشاشة G2)، وسياسة الإشعارات موثقة في `docs/08-notifications.md`.
- أضف رابط سياسة الخصوصية وصور الشاشات من `app/screenshots/` في App Store Connect.

</div>
