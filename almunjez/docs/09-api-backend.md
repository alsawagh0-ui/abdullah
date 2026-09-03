# 09 — API / Backend Architecture

## 1. Shape of the API

The client speaks to three surfaces, all authenticated with the same JWT:

| Surface | Used for | Transport |
|---|---|---|
| **PostgREST** (`/rest/v1/…`) | reads of tables and views under RLS; trivial own-row writes (comments, preferences, read flags) | HTTPS, JSON |
| **RPC** (`/rest/v1/rpc/{fn}`) | every state change | HTTPS, JSON → SQL function |
| **Realtime** (`/realtime/v1`) | live updates of tasks and notifications the user may see | WebSocket |
| **Storage** (`/storage/v1`) | upload attachments, fetch signed URLs | HTTPS multipart |
| **Edge Functions** (`/functions/v1/…`) | server-side integrations that need secrets (APNs, Apple token revocation, AI planner) | HTTPS |

There is no bespoke HTTP server in the MVP. This is a deliberate trade: less code, and the
authorization model is *only* the database, which is easier to audit than two layers that must
agree. Doc 09 §6 describes the escape hatch when a dedicated service is warranted.

## 2. RPC catalogue (the write API)

All functions are `SECURITY DEFINER`, `SET search_path = public`, take/return JSON-friendly types,
raise typed errors (§4), and write exactly one activity event per state change.

### Identity
| Function | Input | Output |
|---|---|---|
| `complete_profile` | display_name, avatar_path? | users row |
| `register_device` | apns_token, platform, app_version, locale | device id |
| `unregister_device` | apns_token | void |
| `delete_account` | — | void (raises `owner_must_transfer`) |

### Groups
| Function | Input | Output |
|---|---|---|
| `create_group` | name, type, settings? | group row + invite code |
| `update_group_settings` | group_id, patch | group row |
| `regenerate_invite` | group_id | new code |
| `revoke_invite` | group_id | void |
| `preview_invite` | code | {group_name, group_type, member_count} — rate-limited |
| `request_join` | code, message? | join_request row (idempotent) |
| `cancel_join_request` | request_id | void |
| `decide_join` | request_id, decision, note? | membership row on accept |
| `set_member_role` | group_id, user_id, role, permissions? | membership row |
| `remove_member` | group_id, user_id | void |
| `leave_group` | group_id | void (raises `owner_must_transfer`) |
| `transfer_ownership` | group_id, to_user_id | void |
| `archive_group` | group_id | void |

### Tasks (transitions from doc 07)
| Function | Input | Output |
|---|---|---|
| `create_task` | title, description?, group_id?, assignment_mode, assignee_id?, due_at?, priority?, points?, requires_proof?, proof_types?, requires_approval?, parent_task_id?, participant_ids? | task row |
| `update_task` | task_id, patch, version | task row (raises `stale_version`) |
| `claim_task` | task_id | task row (raises `already_claimed`) |
| `start_task` | task_id | task row |
| `release_task` | task_id | task row |
| `reassign_task` | task_id, assignee_id | task row |
| `unassign_task` | task_id | task row |
| `complete_task` | task_id, note? | task row (raises `proof_required`) |
| `approve_completion` | task_id | task row |
| `reject_completion` | task_id, reason | task row |
| `cancel_task` | task_id, reason? | task row |
| `reopen_task` | task_id | task row |
| `add_participant` / `remove_participant` | task_id, user_id | void |
| `attach_file` | task_id, storage_path, mime, size, kind | attachment row (validates path convention) |
| `get_attachment_url` | attachment_id | signed URL |

### Notifications
| Function | Input | Output |
|---|---|---|
| `mark_notification_read` | notification_id | void |
| `mark_all_read` | — | count |

### Search
| Function | Input | Output |
|---|---|---|
| `search` | query, filters {status[], member_id, group_id, priority[], due_from, due_to}, limit, cursor | {tasks[], groups[], members[]} |

## 3. Read API (views)

| View | Backs |
|---|---|
| `v_my_groups` | C1: group, my role, open-task count, pending-request count (if approver) |
| `v_my_permissions` | effective permission keys per group for the caller |
| `v_my_tasks_today` | B2/B1 counts: personal ∪ assigned ∪ claimed, with `is_overdue`, `section` |
| `v_group_tasks` | C5 list with `is_overdue`, assignee name/avatar, comment count |
| `v_task_detail` | D1 in one round trip: task + assignee + creator + participants + attachment meta + last 20 comments + last 20 events |
| `v_group_dashboard_counts` | C5 header |
| `v_group_member_stats` | C10, honouring stats visibility |
| `v_notifications` | F1 with rendered title/body in the caller's locale |

Views are `security_invoker = true` so RLS on the base tables applies.

## 4. Error contract

Functions raise `EXCEPTION` with a stable `MESSAGE` code the client maps to Arabic copy:

| Code | HTTP (PostgREST) | Arabic copy |
|---|---|---|
| `not_a_member` | 403 | لست عضواً في هذه المجموعة |
| `permission_denied` | 403 | لا تملك صلاحية هذا الإجراء |
| `already_claimed` | 409 | تولّاها {name} قبل قليل |
| `invalid_transition` | 409 | لا يمكن تنفيذ هذا الإجراء في الحالة الحالية |
| `stale_version` | 409 | عُدّلت المهمة من شخص آخر، حدّث الشاشة |
| `proof_required` | 422 | أرفق إثبات الإنجاز أولاً |
| `invalid_invite` | 404 | رمز الدعوة غير صحيح أو مُلغى |
| `already_member` | 409 | أنت عضو بالفعل |
| `owner_must_transfer` | 409 | انقل الملكية أولاً |
| `rate_limited` | 429 | حاول بعد قليل |
| `not_found` | 404 | المهمة غير موجودة |
| `unauthenticated` | 401 | سجّل الدخول أولاً |
| `assignee_required`, `assignee_not_member`, `participant_not_member` | 422 | اختر عضواً من المجموعة |
| `reason_required` | 422 | اكتب سبب الإرجاع |
| `subtask_depth_exceeded`, `subtask_group_mismatch` | 422 | لا يمكن إضافة مهمة فرعية هنا |
| `group_archived` | 409 | المجموعة مؤرشفة |
| `use_transfer_ownership` | 409 | استخدم نقل الملكية |
| `unsupported_mime`, `invalid_path` | 422 | نوع الملف غير مدعوم |
| `activity_log_immutable` | 403 | (never reaches a client through the API) |

`DETAIL` carries a JSON object with context (e.g. claimer name). No stack traces reach the client.
PostgREST returns `P0001` errors as HTTP 400 unless a custom `sqlstate` is raised; the HTTP column
above is the mapping the client applies from the `message` code, so the transport status is
informational.

## 5. Realtime subscriptions

The app holds at most three channels at a time:

| Channel | Filter | Purpose |
|---|---|---|
| `notifications:user` | `user_id = eq.{me}` | inbox and badge |
| `tasks:group` | `group_id = eq.{open group}` | live C5 |
| `task:one` | `id = eq.{open task}` | live D1 |

Realtime honours RLS (row-level filtering on `postgres_changes`), so a removed member stops
receiving events immediately.

## 6. Growth path: dedicated API service

When one of these becomes true — third-party integrations, web admin with server-rendered pages,
per-tenant rate limiting, or a need to shard — introduce a small **TypeScript (NestJS) or Go
service** that owns the JWT verification and calls the *same* SQL functions. Because every rule
already lives in SQL and RLS, the service adds no authorization logic; it adds orchestration and
caching. The Flutter client's repository layer already isolates transport, so only that layer
changes.

## 7. Background/infra components

| Component | Runtime | Secrets |
|---|---|---|
| `push-sender` | Edge Function (Deno/TS) | APNs .p8 key, team id, key id |
| `apple-revoke` | Edge Function | Sign in with Apple client secret |
| `ai-planner` (Phase 3) | Edge Function → Claude API | API key; returns proposed tasks, never writes |
| pg_cron jobs | Postgres | none |
| Storage | Supabase Storage (S3-backed) | none in client |

## 8. Observability

* Every RPC logs `(fn, uid, group_id, duration, error_code)` to `api_audit` (30-day retention).
* Outbox failure rate and APNs 410 rate are the two alerts that matter for the product promise.
* Client sends crash reports (Sentry) with the user id hashed; no task content in breadcrumbs.

## 9. Versioning

* Schema migrations are numbered SQL files under `backend/schema/`; `001_initial.sql` is the base.
* RPC signatures are additive; a breaking change ships as `fn_v2` with the old one kept for two
  app releases (App Store users update slowly).
* The app sends `x-app-version`; a `min_supported_version` row lets the backend force an update
  screen instead of failing obscurely.
