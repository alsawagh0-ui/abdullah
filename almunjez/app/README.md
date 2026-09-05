<div dir="rtl">

# تطبيق «المنجز» — Flutter (iPhone أولاً)

تنفيذ الشاشات الـ 24 لمرحلة MVP المحددة في [`../docs/02-screen-map.md`](../docs/02-screen-map.md)،
فوق نفس عقد الـ API الذي يقدّمه مخطط قاعدة البيانات في [`../backend/schema/001_initial.sql`](../backend/schema/001_initial.sql).

</div>

## Screenshots

Captured from the real app (web build of the same code, iPhone viewport, local mode with the demo
seed) — see `screenshots/`: welcome, sign-in, home, groups, group dashboard, open task, claimed
task, task with comments, today, notifications, new task, company dashboard, collaborative task.

## Run

```bash
flutter pub get
flutter run                                   # defaults to the real Supabase project (lib/app/config.dart)
flutter run --dart-define=SUPABASE_URL=       # local mode instead: data stays on the device, demo account available
flutter test                                  # 23 tests: engine rules + full-app widget flows (always run on LocalApi)
flutter analyze
flutter build ipa --release                   # macOS + Xcode; bundle id kw.almunjez.almunjez
```

Point at a *different* Supabase project (staging, a fork) with both flags:

```bash
flutter run --dart-define=SUPABASE_URL=https://xxx.supabase.co --dart-define=SUPABASE_ANON_KEY=eyJ...
```

## Two backends, one contract

| | `LocalApi` | `SupabaseApi` |
|---|---|---|
| Where | `lib/core/api/local/` | `lib/core/api/supabase/` |
| What | Dart port of the SQL rules: permission resolution, task state machine, activity log, notification fan-out, Arabic search normalisation | RPC calls + RLS-filtered reads + Realtime |
| When | `--dart-define=SUPABASE_URL=` (empty), or any code that constructs `LocalApi` directly — the widget and engine tests always do this, regardless of build flags | default (`lib/app/config.dart` ships this project's real URL and anon key) |
| Data | JSON in `shared_preferences` on the device | Postgres |

The demo-sign-in button and the "local mode" banner are driven by the *actual injected instance*
(`api is LocalApi`), not the build flag, so they show correctly however the app was launched.

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

## Signing in on the live build

Email + password is the only method that works on a fresh Supabase project
with nothing configured; it is therefore the first option on the sign-in
screen. Supabase's default "confirm email" setting sends a confirmation link
whose redirect lands on a blank/localhost page until Site URL and Redirect
URLs are set (doc 15 §0) — the confirmation itself still succeeds, so the
user comes back and signs in with the password. The emailed-code, Google,
Apple and phone paths stay in place behind their respective dashboard steps.

## Backend status

`lib/app/config.dart` ships this project's real Supabase URL and anon key as the default —
`flutter run` targets it with no flags. The schema (`backend/schema/001_initial.sql`) has been
applied to it directly through the Supabase SQL Editor.

**Not verified from this environment:** the sandbox this app was built in has no network route to
`*.supabase.co` (an organisation egress policy, confirmed via the proxy's own diagnostic — a
403 on every CONNECT attempt, not a bug to work around). So while the code compiles clean against
the real project (`flutter build web`, `flutter analyze`, all 23 tests — none of which touch the
network, since tests always inject `LocalApi` directly), nobody has actually run this app against
a live network connection yet. First real run, on a machine with normal internet access:

```bash
flutter run -d chrome        # or -d <ios-device-id> from a Mac
```

then walk sign-in → create a group → claim a task, and confirm it shows up in the Supabase Table
Editor. If Sign in with Apple errors, add the Apple Services ID under Supabase → Authentication →
Providers → Apple (needs an Apple Developer account, separate from this).

## Not wired yet (needs accounts or a Mac)

* **Push delivery.** The backend outbox, the in-app inbox, `backend/functions/push-sender`, the
  iOS `AppDelegate.swift` APNs registration, and the Dart `PushService`/A5 consent screen are all
  written and wired end to end — the only missing piece is an Apple Developer account to get a
  real APNs key and turn the Push Notifications capability on for the app ID.
* **Proof photos/files.** Storage upload UI is Phase 2 (doc 11); proof-by-note works now.
* **Signed iOS build.** Needs macOS/Xcode; the `ios/` project is generated with bundle id
  `kw.almunjez.almunjez`, Arabic display name, camera permission text, portrait only.

## App icon and launch screen

A brand mark (single checkmark on the accent gradient `#1F5F8B`, doc 14) replaces Flutter's
default icon everywhere: iOS `AppIcon.appiconset` (all sizes, alpha stripped per App Store
requirement), web favicon/PWA icons, and manifest name/description in Arabic. Source art is
`assets/icon/` (generated once with Pillow — see `flutter_launcher_icons.yaml`). The iOS launch
screen background was changed from Flutter's default white to the app's own off-white
(`#F7F7F5`) so there is no flash before the first frame. Regenerate after changing the source
art with:

```bash
dart run flutter_launcher_icons
```

