# 11 — MVP vs Phase 2 Feature Separation

The build order follows brief §23 exactly. "Schema-ready" means the tables/columns exist in
`001_initial.sql` so Phase 2 needs no migration of existing data.

## 1. MVP (release 1.0)

| # | Feature | Screens | Backend | Notes |
|---|---|---|---|---|
| 1 | Authentication (Apple, phone OTP) | A1–A5 | Supabase Auth, `users` trigger, `register_device` | |
| 2 | User profile | A4, G1, G2 | `complete_profile`, `delete_account` | account deletion is mandatory for review |
| 3 | Create group | C1, C2 | `create_group` | group types list |
| 4 | Join through code / QR | C3, C4 | `preview_invite`, `request_join`, `regenerate_invite`, `revoke_invite` | QR payload = `almunjez://join/{code}` |
| 5 | Join approval | C6 | `decide_join` | |
| 6 | Membership and roles | C7, C9 | `set_member_role`, `remove_member`, `leave_group`, `transfer_ownership` | owner/admin/member; JSON overrides exist but the UI exposes only the role in 1.0 |
| 7 | Create task | D2 | `create_task` | title, group, mode, assignee, due, priority; points/proof/approval toggles exist in the form but collapsed under «خيارات إضافية» |
| 8 | Open task claiming | D1 | `claim_task`, `release_task` | atomic |
| 9 | Direct assignment | D2, D1 | `create_task(assigned)`, `reassign_task`, `unassign_task`, `start_task` | |
| 10 | Task lifecycle | D1 | `complete_task`, `approve_completion`, `reject_completion`, `cancel_task`, `reopen_task` | approval flow included because it is one boolean and two RPCs; proof upload is not |
| 11 | Push notifications | A5, F1 | outbox, `push-sender`, pg_cron reminders | all `✓` types in doc 08 §2 |
| 12 | My Tasks / Today | B2, E1 | `v_my_tasks_today` | personal tasks included |
| 13 | Group task views | C5 | `v_group_tasks`, filters | |
| 14 | Basic activity log | C8 | `activity_events`, append-only trigger | |
| 15 | Basic statistics | B1 counts, G1, C10 (numbers only) | `v_group_member_stats` | completed / in progress / on time / overdue for week and month; visibility setting |
| — | Comments | D1 | direct insert under RLS | lightweight, in MVP because the completion flow needs «سبب الإرجاع» |
| — | Search | F2 | `search` | tasks + groups + members, status/member/group filters |
| — | Arabic + English | all | `users.locale`, server templates | Arabic default; English strings complete |

## 2. Phase 2 (release 1.x)

| Feature | Schema-ready in MVP? | Adds |
|---|---|---|
| Recurring tasks | ✓ `recurrence_rules`, `tasks.recurrence_id`, `occurrence_key` | rule editor in D2, `materialise_recurrences` job |
| Proof of completion (photo/file) | ✓ `requires_proof`, `proof_types`, `task_attachments.kind` | D4, D5 upload UI, Storage policies, thumbnail extension |
| Attachments on tasks | ✓ | upload in D2/D1 |
| Points | ✓ `tasks.points`, `stats` | shown on cards, per-user totals |
| Leaderboard | ✓ visibility setting | C10 ranking, `gamification_enabled` gate |
| Advanced statistics | ✓ events | weekly summary notification, trends, on-time rate charts |
| Collaborative tasks UI | ✓ `task_participants`, `parent_task_id` | participants picker, subtask list, auto-complete parent |
| Granular admin permissions UI | ✓ `memberships.permissions` | toggles per admin |
| Quiet hours / notification batching UI | ✓ preferences table | G3 additions |
| Email magic link | Auth config | web admin groundwork |
| Date/priority/member filters in search | ✓ | chips |
| Offline write queue | client only | optimistic queue with conflict UI |

## 3. Phase 3 (organisation and AI)

| Feature | Requires |
|---|---|
| Group hierarchy (company → department → team) | `groups.parent_group_id` (present, unused), org-level roles, inherited membership rules |
| Custom roles | `roles` table materialised into `memberships.permissions` |
| SSO | Auth provider |
| Web admin | dedicated API service (doc 09 §6) |
| AI planner («عندنا عزيمة الجمعة…» → proposed task list) | `ai-planner` Edge Function → proposals screen → `create_task` in batch; nothing written until «إضافة جميع المهام» |
| AI project plan for business (tasks, priorities, dependencies, deadlines) | `task_dependencies` table (new), timeline view |
| Data export / audit export for companies | CSV/PDF from `activity_events` |

## 4. Explicitly out of scope (all phases)

* Public groups or discovery
* Chat beyond task comments
* Time tracking / billing
* Android in the MVP — the stack allows it (doc 14) but the brief targets iPhone; Android is a
  build-target decision, not an architecture one.
