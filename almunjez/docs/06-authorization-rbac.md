# 06 — Authorization / RBAC Model

## 1. Principle

Authorization lives in **two places only**, both server-side:

1. **Row-Level Security policies** decide which rows a user can *read* (and which simple writes,
   e.g. their own comments, they can perform directly).
2. **SQL functions** (`SECURITY DEFINER`) decide whether a *state change* is allowed, using the
   same helper predicates the policies use.

The client receives the effective permission set for each group (`v_my_permissions`) purely to
decide which buttons to draw.

## 2. Roles

| Role | Arabic | Count per group | Default grants |
|---|---|---|---|
| `owner` | المالك | exactly 1 | everything, including transfer/archive |
| `admin` | مشرف | 0..n | administrative set below, individually adjustable by the owner |
| `member` | عضو | 0..n | participate |

Roles are stored on `memberships.role`. Finer grants are stored on `memberships.permissions`
(JSONB) as overrides: `{"task.cancel_any": false, "stats.view_all": true}`. This gives "more
granular permissions later" (brief §3) without a schema change: a Phase 3 custom-role table can
simply materialise into the same JSON.

## 3. Permission keys

| Key | Owner | Admin (default) | Member | Notes |
|---|---|---|---|---|
| `group.manage_settings` | ✓ | ✓ | – | name, type, defaults, gamification, stats visibility |
| `group.manage_members` | ✓ | ✓ | – | remove members, promote/demote **admins cannot touch the owner or other admins** |
| `group.approve_joins` | ✓ | ✓ | – | decide join requests |
| `group.manage_invite` | ✓ | ✓ | – | regenerate/revoke code |
| `group.transfer` | ✓ | – | – | not overridable |
| `group.archive` | ✓ | – | – | not overridable |
| `task.create` | ✓ | ✓ | ✓* | *group setting `members_can_create_tasks` (default true; a company may turn it off) |
| `task.assign_others` | ✓ | ✓ | – | assigned mode to someone else; reassign; unassign |
| `task.edit_any` | ✓ | ✓ | – | edit tasks created by others; reopen |
| `task.cancel_any` | ✓ | ✓ | – | cancel tasks created by others |
| `task.approve_completion` | ✓ | ✓ | – | approve/reject; the creator always can regardless of role |
| `activity.view` | ✓ | ✓ | ✓ | may be restricted to admins by setting |
| `stats.view_all` | ✓ | ✓ | per setting | see doc 06 §6 |
| `comment.moderate` | ✓ | ✓ | – | delete others' comments |

Implicit, role-independent rights (checked by ownership, not by key):

* creator: edit, cancel, approve own tasks;
* assignee: start, complete, release own task;
* author: edit/delete own comment within 15 minutes;
* self: leave group (owner must transfer first).

## 4. Separation-of-duty rules

* The assignee **never approves their own completion**, even as owner. Approval falls to the
  creator or another approver; if the creator is the assignee and no other approver exists, the
  task's `requires_approval` is effectively ignored and completion is direct (documented to the
  user in D2 as «لا يوجد مُعتمِد آخر»).
* Admins cannot change the role of, or remove, the owner or another admin.
* The last owner cannot be demoted; ownership is transferred, not vacated.

## 5. Enforcement in the database

Helper predicates (all `STABLE`, `SECURITY DEFINER`, indexed on `(group_id, user_id)`):

```sql
is_active_member(group_id)            -- membership exists and status = 'active'
member_role(group_id)                 -- owner | admin | member | null
has_permission(group_id, key)         -- role default ∪ JSON override, owner ⇒ true
can_view_task(task_id)                -- personal: creator; group: active member
```

Policy summary (full text in `backend/schema/001_initial.sql`):

| Table | SELECT | INSERT | UPDATE | DELETE |
|---|---|---|---|---|
| users | any authenticated (name, avatar only via view) | trigger only | self | never (anonymised by function) |
| groups | active member | function only | function only | never (archive) |
| group_invites | `group.manage_invite` | function | function | function |
| join_requests | requester, or `group.approve_joins` | function | function | requester (cancel while pending) |
| memberships | active member of same group | function | function | function |
| tasks | `can_view_task` | function | function | never (cancel) |
| task_participants | can_view_task | function | – | function |
| task_attachments | can_view_task | uploader = self ∧ can_view_task | – | uploader (before completion) or `comment.moderate` |
| task_comments | can_view_task | author = self ∧ can_view_task | author, 15 min | author or `comment.moderate` (soft) |
| activity_events | `activity.view` in group | trigger only | **denied by trigger** | **denied by trigger** |
| notifications | recipient | function/trigger | recipient (`read_at` only) | recipient |
| notification_preferences | self | self | self | self |
| devices | self | function | function | self |

RLS is *enabled* but not *forced*: the table-owner role bypasses policies, which is what lets the
`SECURITY DEFINER` helper functions read `memberships` without recursing into their own policy.
That owner role, like the Supabase service role used by Edge Functions, is never exposed to the
app; clients only ever run as `authenticated`. Server-only tables (`notification_outbox`,
`task_reminders_sent`, `rate_limit_hits`) have no policies at all and are revoked from
`authenticated`, so they are unreachable from a client even through PostgREST.

## 6. Statistics visibility (brief §11)

`groups.settings.stats_visibility ∈ {private, admins, all}`:

| Setting | Who sees whose numbers |
|---|---|
| `private` (default for بيت/عائلة) | each member sees only their own |
| `admins` | owner/admins see everyone; members see their own |
| `all` (default for شركة/فريق/مشروع) | everyone sees everyone; leaderboard enabled only here and only when `gamification_enabled` |

Enforced in `v_group_member_stats` with a `WHERE` that references the setting and the caller.

## 7. Storage authorization

Bucket `task-files` is private. Object path convention:

```
groups/{group_id}/tasks/{task_id}/{attachment_id}.{ext}
personal/{user_id}/tasks/{task_id}/{attachment_id}.{ext}
```

Storage policies parse the path and call `can_view_task(task_id)`. The client never builds a
public URL; it asks for a signed URL (60 s for images, 5 min for files) through PostgREST, which
runs the same check.

## 8. Permission resolution order (for `has_permission`)

1. caller not an active member → **false**
2. role = owner → **true**
3. key is `group.transfer` or `group.archive` → **false** (owner-only)
4. `memberships.permissions ->> key` present → that boolean
5. key is `task.create` → group setting `members_can_create_tasks` (admins always true)
6. role default from the table in §3
