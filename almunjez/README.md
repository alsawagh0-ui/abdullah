<div dir="rtl">

# المنجز — AlMunjez

**تطبيق iPhone للإنجاز التشاركي والمساءلة الواضحة** — للبيت، والعائلة، والشركة، والفريق، واللجنة، والفرد.

> **كل مهمة لها صاحب.**
> أنشئ ← تولَّ ← نفّذ ← أنجز ← قِس

### الفكرة في سطرين

المهام في المجموعات تُناقَش كثيراً ولا يتولاها أحد بوضوح. «المنجز» يحوّل كل مهمة مشتركة إلى
مسؤولية واضحة: لها صاحب، وحالة، وسجل، ومساهمة قابلة للقياس — بأقل عدد من النقرات.

### خيارات التموضع (Positioning)

| الخيار | العبارة | يناسب |
|---|---|---|
| 1 | **«كل مهمة لها صاحب»** | الرسالة الأساسية — واضحة للأسرة والشركة معاً |
| 2 | «من الكلام إلى الإنجاز» | التسويق للفرق والشركات |
| 3 | «مهام البيت والعمل… بوضوح» | متجر التطبيقات (وصف قصير) |

### هذه الحزمة

بحسب **البند 24** من موجز المنتج، **لا يبدأ التنفيذ قبل اكتمال المعمارية**. هذا المجلد يحوي الوثائق
الأربع عشرة المطلوبة ومخطط قاعدة البيانات الفعلي (SQL) الذي يُبنى عليه الخادم.

</div>

---

# AlMunjez — Architecture Package

This directory is the **pre-implementation architecture** required by section 24 of the product
brief. Nothing here is a screen mock-up; every document is a decision record that the MVP build
must follow. Documents are written in English for the engineering team and use the product's
Arabic terminology verbatim wherever it appears in the UI.

| # | Document | What it decides |
|---|---|---|
| 01 | [Product architecture](docs/01-product-architecture.md) | System layers, bounded contexts, scaling path from one family to an organisation |
| 02 | [Screen map](docs/02-screen-map.md) | Every screen, its purpose, entry points and primary action |
| 03 | [User flows](docs/03-user-flows.md) | Step-by-step flows with tap counts for the critical path |
| 04 | [Database schema](docs/04-database-schema.md) | Tables, columns, constraints, indexes; the runnable DDL is in [`backend/schema/001_initial.sql`](backend/schema/001_initial.sql) |
| 05 | [Authentication model](docs/05-authentication.md) | Identity providers, sessions, devices, account deletion |
| 06 | [Authorization / RBAC](docs/06-authorization-rbac.md) | Roles, permission keys, enforcement at the database (Row-Level Security) |
| 07 | [Task state machine](docs/07-task-state-machine.md) | States, transitions, who may trigger them, atomic claiming |
| 08 | [Notification architecture](docs/08-notifications.md) | Event → fan-out → outbox → APNs; preferences; anti-spam rules |
| 09 | [API / backend architecture](docs/09-api-backend.md) | Logical API contract, RPC list, storage, background jobs |
| 10 | [Data model relationships](docs/10-data-model-relationships.md) | ER diagram and cardinalities |
| 11 | [MVP vs Phase 2](docs/11-mvp-vs-phase2.md) | Build order and what is deliberately deferred |
| 12 | [Edge cases](docs/12-edge-cases.md) | Concurrency, membership churn, time zones, Arabic text, offline |
| 13 | [Security risks](docs/13-security-risks.md) | Threat model and the mitigation each threat maps to |
| 14 | [Recommended technology stack](docs/14-tech-stack.md) | Client, backend, push, CI, and why |

## Layout

```
almunjez/
├── README.md                     ← this index
├── docs/                         ← the 14 architecture documents
├── backend/
│   ├── README.md                 ← how to run the schema tests / apply to Supabase
│   ├── schema/001_initial.sql    ← Postgres DDL: enums, tables, RLS, RPCs, atomic claim, activity log
│   └── tests/                    ← smoke.sql (rule assertions) + claim_concurrency.sh (race) + run.sh
└── app/                          ← the Flutter iPhone app (24 MVP screens, two backends, 20 tests)
    └── README.md                 ← how to run it locally or against Supabase
```

## Status

| Layer | State |
|---|---|
| Architecture (14 docs) | complete |
| Database schema, RLS, RPCs | complete, tested on Postgres 16 (`backend/tests/run.sh`) |
| iPhone app | MVP screens complete; runs on the on-device engine now, on Supabase with two `--dart-define`s |
| Push delivery, Sign in with Apple, SMS OTP | code in place; need Apple/Firebase/Supabase accounts to switch on |
| Signed iOS build | `ios/` project generated; needs a Mac with Xcode |

The schema is not a sketch: `backend/tests/run.sh` applies it to a real Postgres 16, runs 20
groups of assertions against the rules in these documents, and races 40 concurrent claimers on one
task (exactly one wins). See doc 04 §4 for the list.

## Ground rules carried through every document

1. **The backend is the only authority.** Every permission is enforced in the database with
   Row-Level Security and in SQL functions; the client only decides what to *show*.
2. **Overdue is derived, never stored.** A task is overdue when `due_at < now()` and it is not
   finished; storing it would require a scheduler to keep it correct.
3. **Claiming is one atomic statement.** `claim_task()` succeeds for exactly one caller, whatever
   the number of simultaneous taps.
4. **The activity log is append-only** at the database level; no role, including owner, can edit it.
5. **Groups are private by default,** and an invitation code alone never grants access.
6. **Arabic is the design language,** not a translation target. Layouts are authored RTL first.
