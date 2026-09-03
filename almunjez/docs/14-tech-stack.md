# 14 — Recommended Technology Stack

## 1. Summary

| Layer | Choice | Alternative considered | Why this one |
|---|---|---|---|
| iPhone app | **Flutter 3.x (stable)**, Dart 3 | SwiftUI | see §2 |
| State | Riverpod 2 (no code-gen; plain providers in `core/providers.dart`) | Bloc | less ceremony for a screen-per-feature app; every provider refreshes from the API change stream |
| Navigation | go_router | Navigator 2 by hand | deep links and push routes declaratively |
| Local cache | MVP: the on-device rules engine persists JSON via `shared_preferences` (local mode); Phase 2: drift (SQLite) read cache + write queue for Supabase mode | Hive / Isar | typed SQL, migrations, good for offline read cache and later write queue |
| Backend platform | **Supabase** (Postgres 15+, Auth, PostgREST, Realtime, Storage, Edge Functions, pg_cron) | Firebase; custom NestJS + Postgres | see §3 |
| Push | APNs via **Firebase Cloud Messaging** (`firebase_messaging`) with the APNs key uploaded to FCM | direct APNs from the Edge Function | FCM handles token lifecycle, works unchanged if Android is added; the outbox design does not care which sender is used |
| Background jobs | pg_cron + Edge Functions (Deno/TypeScript) | separate worker service | zero extra infra in MVP |
| Files | Supabase Storage (S3-backed), signed URLs | Cloudflare R2 | integrated policies |
| Auth providers | Sign in with Apple, phone OTP (Twilio via Supabase) | — | doc 05 |
| Fonts | IBM Plex Sans Arabic (UI) — or Cairo, already licensed and bundled in this repo | Noto Naskh Arabic | Plex Arabic has a calm, professional tone matching the visual direction; Cairo is the fallback if the team wants one font across both products |
| Analytics / crash | Sentry (crash), PostHog (product events, self-hostable) | Firebase Analytics | privacy control, no task content sent |
| CI | GitHub Actions (analyze, test, pgTAP), **Xcode Cloud or Codemagic** for signed iOS builds → TestFlight | Fastlane on a Mac runner | the repo already runs Flutter on Actions; iOS signing needs macOS |
| Backend tests | pgTAP + a Dart integration suite against a staging project | — | authorization is in SQL, so test it in SQL |
| Web (Phase 3 admin) | Flutter Web or Next.js against the same API | — | decided later |

## 2. Flutter vs SwiftUI for an "iPhone application"

The brief asks for an iPhone app. Native SwiftUI would be the default answer for a pure-iOS
product. Flutter is recommended here for these reasons, in order of weight:

1. **RTL and Arabic typography are already solved in this repository.** The Wajb app in `app/`
   ships bundled Arabic fonts, RTL layouts, Arabic digits and a compliance test suite for
   typography. That know-how transfers directly.
2. **Android is a build target, not a rewrite.** Families and companies in the Gulf are mixed
   iPhone/Android; the moment a group has one Android member the product's core promise («كل
   مهمة لها صاحب») breaks. Flutter keeps that door open at zero architectural cost.
3. **A single UI codebase against a thin API** suits the "thin client over a rule-enforcing
   database" architecture; there is little platform-specific logic to gain from Swift.
4. **CI already exists** for Flutter in this repo; only the iOS signing lane is new.

What Flutter costs, and how it is contained:

| Cost | Mitigation |
|---|---|
| Slightly less native feel in system sheets/pickers | use Cupertino widgets for pickers, share sheet, and haptics; `flutter_platform_widgets` where needed |
| Push, Sign in with Apple, Keychain need plugins | `firebase_messaging`, `sign_in_with_apple`, `flutter_secure_storage` — all mature |
| Widget extensions / Live Activities (later) | written natively in Swift as add-on targets; Flutter does not block this |
| App size | ~ 15 MB more than Swift; acceptable |

If the team decides on SwiftUI instead, **every document in this package still applies** — the
backend, schema, RLS and API are client-agnostic. Only doc 02's implementation notes change.

## 3. Supabase vs a custom backend

| Criterion | Supabase (recommended) | Custom (NestJS/Go + Postgres) |
|---|---|---|
| Authorization "never client-side only" | RLS is the enforcement layer; one place to audit | must be re-implemented in middleware and kept in sync with queries |
| Atomic claim | one SQL function | same SQL inside a service |
| Realtime updates for "others see Mohammed took it" | built-in | WebSocket server to build |
| Auth (Apple, phone OTP) | built-in | integrate a provider |
| Files with per-row authorization | built-in policies | signed-URL service to build |
| Scheduled jobs | pg_cron | worker + scheduler |
| Time to a working MVP | weeks | months |
| Lock-in | Postgres is portable; PostgREST/RLS conventions are open source; Edge Functions are plain Deno | none, at the cost above |
| Multi-region / very large orgs | fine to mid-size; beyond that add a service layer (doc 09 §6) | designed in from the start |

Decision: Supabase for MVP and Phase 2, with the explicit growth path in doc 09 §6. The SQL in
`backend/schema/001_initial.sql` runs on plain Postgres 15+ too (it only assumes an `auth.uid()`
function), so the exit is real, not theoretical.

## 4. Client project structure (feature-first)

```
almunjez_app/lib/
├── app/               # bootstrap, router, theme, l10n
├── core/              # api client, auth session, error mapping, realtime, cache
├── features/
│   ├── auth/          # A1–A5
│   ├── home/          # B1
│   ├── today/         # B2, E1
│   ├── groups/        # C1–C10
│   ├── tasks/         # D1–D5
│   ├── notifications/ # F1, G3
│   ├── search/        # F2
│   └── profile/       # G1, G2
└── shared/            # widgets: state header, task row, avatar, member chip, empty states
```

Each feature has `data/` (repository over PostgREST/RPC), `domain/` (models, pure logic such as
section grouping for Today), and `ui/`. Pure logic has unit tests; screens have widget tests with
a fake repository; the critical claim → complete flow has an integration test against staging.

## 5. Backend repository structure

```
almunjez/backend/
├── schema/            # numbered migrations; 001_initial.sql is here already
├── tests/             # pgTAP: rls_*.sql, claim_concurrency.sql, transitions.sql
├── functions/         # Edge Functions: push-sender, apple-revoke, (ai-planner)
└── seed/              # demo family + demo company for staging
```

## 6. Environments

| Env | Purpose | Data |
|---|---|---|
| local | `supabase start` (Docker) for schema and pgTAP | seed |
| staging | TestFlight builds, integration tests | seed + testers |
| production | App Store | real; PITR backups |

## 7. Versions to pin at project start

Flutter stable (3.2x at time of writing), Dart 3, Postgres 15 on Supabase, Deno as provided by
Edge Functions runtime, Xcode current. Pin exact versions in `pubspec.lock` and in the Supabase
project config; upgrade deliberately, not automatically.
