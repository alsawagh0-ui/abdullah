# 04 — Database Schema

The authoritative definition is [`backend/schema/001_initial.sql`](../backend/schema/001_initial.sql)
(Postgres 15+, validated on Postgres 16 by `backend/tests/run.sh`). This document explains the
tables and the reasons behind their shape; the SQL is the contract.

## 1. Conventions

* Primary keys are `uuid` (`gen_random_uuid()`), except `activity_events` and `notification_outbox`
  which are `bigserial` because they are append-only streams and ordering matters.
* Every timestamp is `timestamptz` in UTC. `created_at` everywhere; `updated_at` maintained by
  trigger on `users`, `groups`, `tasks`.
* Enums are Postgres enums (`task_status`, `membership_role`, …) so an invalid value is impossible
  to store; adding a value is a one-line migration.
* Soft-delete columns (`archived_at`, `deleted_at`, `left_at`, `cancelled_at`) instead of deletes
  for anything another member has seen (doc 10 §6).
* Group-scoped rows carry `group_id`; task-scoped rows (comments, attachments, participants) reach
  the group through `tasks`, which keeps one source of truth for a task's group.

## 2. Tables

### Identity

| Table | Purpose | Key columns |
|---|---|---|
| `users` | profile row, `id` = `auth.users.id` | `display_name`, `avatar_path`, `locale` (`ar`/`en`), `timezone`, `deleted_at` (anonymised) |
| `devices` | push tokens | `apns_token` unique, `user_id`, `last_seen_at` (pruned after 90 days) |

### Groups

| Table | Purpose | Key columns / constraints |
|---|---|---|
| `groups` | tenant | `name`, `type` (`home`, `family`, `company`, `department`, `team`, `project`, `committee`, `volunteer`, `other`), `owner_id`, `parent_group_id` (unused until Phase 3), `settings` jsonb, `member_count` (trigger-maintained), `archived_at` |
| `group_invites` | invitation codes | `code` unique 8 chars from a 32-symbol alphabet; **partial unique index: one row per group where `revoked_at is null`**; `expires_at`, `use_count` |
| `join_requests` | approval gate | `status` (`pending`, `accepted`, `rejected`, `cancelled`), `invite_id`, `message`, `decided_by/at`; **partial unique: one pending per (group, user)** |
| `memberships` | who is in which group | `role` (`owner`, `admin`, `member`), `status` (`active`, `removed`, `left`), `permissions` jsonb overrides, `joined_at`, `left_at`; unique (group, user); **partial unique: one active owner per group** |

`groups.settings` keys and defaults (resolved by `group_setting(group_id, key)`):

| Key | Default | Meaning |
|---|---|---|
| `requires_approval_default` | `false` | new tasks default to needing approval |
| `gamification_enabled` | `false` | points/leaderboard shown |
| `members_can_create_tasks` | `true` | members hold `task.create` |
| `activity_visible_to_members` | `true` | members hold `activity.view` |
| `stats_visibility` | `private` for `home`/`family`, `all` otherwise | `private` / `admins` / `all` |

### Tasks

| Table | Purpose | Key columns / constraints |
|---|---|---|
| `tasks` | the task | see below |
| `task_participants` | collaborators on collaborative tasks | PK (task, user) |
| `task_attachments` | files and proof | `storage_path` unique, `kind` (`attachment`, `proof`), `mime`, `size_bytes` ≤ 30 MB |
| `task_comments` | lightweight comments | `kind` (`comment`, `proof_note`, `rejection_reason`, `system`), `edited_at`, `deleted_at` |
| `recurrence_rules` | Phase 2 templates | `template` jsonb, `rrule`, `timezone`, `next_run_at`, `active` |

`tasks` columns:

| Column | Notes |
|---|---|
| `group_id` | `null` = personal task |
| `creator_id`, `assignee_id` | assignee is the single responsible person |
| `title` 1–200, `description` ≤ 4000 | |
| `status` | `new`, `in_progress`, `awaiting_approval`, `completed`, `cancelled` (doc 07) |
| `priority` | `low`, `normal`, `high`, `urgent` |
| `assignment_mode` | `open`, `assigned`, `collaborative` |
| `due_at`, `due_date_only` | instant + display hint (doc 10 §4) |
| `points` 0–10000 | optional |
| `requires_proof`, `proof_types` (`{photo,file,note}`), `requires_approval` | completion rules |
| `parent_task_id`, `auto_complete_on_subtasks` | subtasks, depth 1 enforced by trigger |
| `recurrence_id`, `occurrence_key` (unique) | idempotent instance generation |
| `claimed_at`, `started_at`, `submitted_at`, `completed_at`, `completed_by`, `approved_by`, `approved_at`, `cancelled_at`, `cancelled_by` | lifecycle timestamps; `completed_by` freezes attribution for stats |
| `version` | optimistic lock for `update_task` |
| `search_text` | generated: `normalize_ar(title ‖ description)`, trigram-indexed |

Check constraints that encode product rules:

* `tasks_personal_self`: a personal task is always `assigned` to its creator.
* `tasks_open_unassigned`: an `open` task in `new` has no assignee.
* `tasks_assigned_has_assignee`: an `assigned` task always has one.

Indexes: `(group_id, status)`, partial on `assignee_id` and `due_at` for open statuses,
`parent_task_id`, GIN trigram on `search_text`.

### Activity and notifications

| Table | Purpose | Key columns |
|---|---|---|
| `activity_events` | immutable audit trail | `group_id`, `actor_id`, `action` (e.g. `task.claimed`), `target_type`, `target_id`, `metadata` jsonb; **UPDATE/DELETE raise `activity_log_immutable`** |
| `notifications` | in-app inbox, the record of what a user was told | `user_id`, `type`, `source_event_id`, `task_id`, `group_id`, `actor_id`, `data`, `read_at` |
| `notification_preferences` | per type: `push` on/off | PK (user, type); absence = on |
| `notification_outbox` | one row per (notification, device) for the push sender | `collapse_key`, `status` (`pending`, `sent`, `failed`, `dead`), `attempts`, `next_attempt_at`, `last_error` |
| `task_reminders_sent` | single-shot guard for deadline reminders | PK (task, threshold: `due_24h`, `due_1h`, `overdue_1..3`); cleared when `due_at` changes |
| `rate_limit_hits` | fixed-window counters | PK (key, window_start) |

The last three tables have no RLS policies and are revoked from `authenticated`: they are
server-only.

## 3. Functions that are part of the schema contract

| Kind | Names |
|---|---|
| Authorization helpers | `is_active_member[_of]`, `member_role[_of]`, `has_permission[_for]`, `members_with_permission`, `can_view_task[_as]`, `can_approve` |
| Event & fan-out | `log_event`, `create_notification`, trigger `trg_notify_fanout`, trigger `trg_comment_event` |
| RPC (write API) | listed in doc 09 §2; all `SECURITY DEFINER`, all raise stable error codes via `fail()` |
| Read | views `v_group_tasks`, `v_group_dashboard_counts`, `v_my_groups`, `v_my_permissions` (all `security_invoker`); functions `my_tasks(tz)`, `group_member_stats(group, from, to)`, `search(...)` |
| Scheduled | `enqueue_due_soon_reminders`, `enqueue_overdue_reminders`, `prune_devices` (pg_cron when present) |
| Text | `normalize_ar`, `gen_invite_code`, `check_rate_limit` |

## 4. What the tests prove (`backend/tests`)

`tests/run.sh` recreates a database, applies the stub `auth.uid()` and the schema, then runs:

* `smoke.sql` — 20 assertion groups covering: group creation and the one-active-invite rule;
  preview shows the name only; join is idempotent and never grants access; only approvers can
  decide; regenerated codes revoke the old one; admins cannot touch the owner; owners must transfer
  before leaving or deleting; open-task claim, the `already_claimed` loser, idempotent re-claim;
  approval loop with rejection reason and the full activity trail; assignee can never approve their
  own task; members cannot assign others; removing a member releases their tasks; personal tasks
  produce no events; `my_tasks` sections and derived overdue; subtask depth and parent
  auto-completion; append-only log even for the table owner; Arabic normalisation in search; RLS
  isolation for an outsider and for a member (tasks, memberships, log, invite codes, inboxes,
  outbox); stats visibility; single-shot reminders reset on deadline change; account deletion
  anonymises but keeps history.
* `claim_concurrency.sh N` — N parallel sessions claim one open task: exactly one wins, N−1 receive
  `already_claimed`, and exactly one `task.claimed` event exists. Passed with N = 40.

## 5. Migration policy

* Files are numbered; never edit `001_initial.sql` once a production database exists — add
  `002_….sql`.
* Enum additions and nullable columns are safe online; anything else ships behind a feature flag
  in the app and a two-step migration (add → backfill → switch).
* pgTAP is the target framework for CI; the current plain-psql tests are its seed.
