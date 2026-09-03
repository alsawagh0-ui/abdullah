<div dir="rtl">

# تطبيق «المنجز» — Flutter (iPhone أولاً)

تنفيذ الشاشات الـ 24 لمرحلة MVP المحددة في [`../docs/02-screen-map.md`](../docs/02-screen-map.md)،
فوق نفس عقد الـ API الذي يقدّمه مخطط قاعدة البيانات في [`../backend/schema/001_initial.sql`](../backend/schema/001_initial.sql).

</div>

## Run

```bash
flutter pub get
flutter run                                   # local mode: data stays on the device, demo account available
flutter run --dart-define=SUPABASE_URL=https://xxx.supabase.co \
            --dart-define=SUPABASE_ANON_KEY=eyJ...   # real backend (schema applied per ../backend/README.md)
flutter test                                  # 20 tests: engine rules + full-app widget flows
flutter analyze
flutter build ipa --release                   # macOS + Xcode; bundle id kw.almunjez.almunjez
```

## Two backends, one contract

| | `LocalApi` | `SupabaseApi` |
|---|---|---|
| Where | `lib/core/api/local/` | `lib/core/api/supabase/` |
| What | Dart port of the SQL rules: permission resolution, task state machine, activity log, notification fan-out, Arabic search normalisation | RPC calls + RLS-filtered reads + Realtime |
| When | no `SUPABASE_URL` at build time; all tests | production |
| Data | JSON in `shared_preferences` on the device | Postgres |

Screens only ever talk to `AlMunjezApi` (`lib/core/api/almunjez_api.dart`), so nothing in `features/`
knows which backend it is running on. The local engine is tested against the same scenarios as
`backend/tests/smoke.sql`, so both implementations enforce the same rules.

## Layout

```
lib/
├── app/          bootstrap (picks the backend), router (deep links), theme, config
├── core/
│   ├── models/   enums + models mirroring the schema
│   ├── api/      contract, local engine (+ demo seed), Supabase client
│   ├── providers.dart   Riverpod providers; everything refreshes on the API's change stream
│   └── format.dart      Eastern Arabic digits, dates, relative time
├── l10n/         strings — Arabic first, English complete
├── features/     auth · home · today · groups · tasks · notifications · search · profile
└── shared/       task tile, state pill, avatar, empty state, error/retry, dialogs
```

## Deep links

`almunjez://task/{id}`, `almunjez://group/{id}`, `almunjez://group/{id}/requests`,
`almunjez://join/{code}` (also the QR payload as `https://almunjez.app/join/{code}`),
`almunjez://notifications`. Routes are declared in `lib/app/router.dart`.

## Not wired yet (needs accounts or a Mac)

* **Push delivery.** The backend outbox and the in-app inbox are complete; the APNs sender
  (Edge Function + FCM/APNs key) and `firebase_messaging` registration need a Firebase/Apple
  developer account. `registerDevice(token)` is in the API contract ready for it.
* **Sign in with Apple.** Wired through Supabase OAuth; needs the Apple Services ID in the
  Supabase dashboard. Phone OTP needs the SMS provider configured there.
* **Proof photos/files.** Storage upload UI is Phase 2 (doc 11); proof-by-note works now.
* **Signed iOS build.** Needs macOS/Xcode; the `ios/` project is generated with bundle id
  `kw.almunjez.almunjez`, Arabic display name, camera permission text, portrait only.
