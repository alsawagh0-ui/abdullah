# 08 — Notification Architecture

## 1. Pipeline

```
 mutation RPC ─┐
 pg_cron job  ─┼─▶ activity_events / scheduler ─▶ notify_fanout() ─▶ notifications (in-app, 1 row per recipient)
               │                                                         │
               │                                                         ├─▶ Realtime → app inbox badge
               │                                                         │
               │                                                         └─▶ notification_outbox (1 row per recipient device)
               │                                                                    │
               │                                              Edge Function `push-sender` (invoked by DB webhook,
               │                                              retried by pg_cron every minute for failed rows)
               │                                                                    │
               └───────────────────────────────────────────────────────────────── APNs (HTTP/2, token auth .p8)
```

Design points:

* **The in-app notification is the source of truth.** Push is a delivery hint; if APNs fails the
  user still sees the item in الإشعارات and the badge count comes from unread rows, not from APNs.
* **Fan-out happens in the same transaction as the mutation** (trigger on `activity_events`), so
  a task can never be claimed without the creator's notification row existing.
* **Delivery is asynchronous and idempotent.** Outbox rows carry `attempts`, `next_attempt_at`,
  `status ∈ {pending, sent, failed, dead}`. The sender marks `sent` only on APNs 200; `410` deletes
  the device; other errors back off exponentially (1 m, 5 m, 30 m, then dead).

## 2. Notification types

| Type | Recipients | Arabic title template | Route | MVP |
|---|---|---|---|---|
| `task.created` | eligible group members except creator (open mode only) | مهمة جديدة في {group}: {title} | task | ✓ |
| `task.assigned` | assignee | أُسندت إليك: {title} | task | ✓ |
| `task.claimed` | creator | {actor} تولّى: {title} | task | ✓ |
| `task.released` | creator | {actor} تنازل عن: {title} | task | ✓ |
| `task.completed` | creator (+ participants) | {actor} أنجز: {title} | task | ✓ |
| `task.submitted` | creator + approvers | بانتظار اعتمادك: {title} | task | ✓ |
| `task.approved` | assignee | اعتُمد إنجازك: {title} | task | ✓ |
| `task.rejected` | assignee | أُعيدت إليك: {title} | task | ✓ |
| `task.reassigned` | old + new assignee | تغيّر المسؤول عن: {title} | task | ✓ |
| `task.cancelled` | assignee | أُلغيت: {title} | task | ✓ |
| `task.comment` | creator, assignee, participants, prior commenters (except author) | {actor} علّق على: {title} | task | ✓ |
| `task.due_soon` | assignee (or creator if unassigned) | تقترب مهلة: {title} — خلال {n} ساعة | task | ✓ |
| `task.overdue` | assignee (or creator if unassigned) | تأخرت: {title} | task | ✓ |
| `join.requested` | members with `group.approve_joins` | طلب انضمام: {actor} → {group} | group/requests | ✓ |
| `join.accepted` | requester | تم قبولك في {group} | group | ✓ |
| `join.rejected` | requester | لم يُقبل طلبك للانضمام إلى {group} | group | ✓ |
| `member.removed` | removed user | أُزلت من {group} | notifications | ✓ |
| `member.role_changed` | member | أصبحت {role} في {group} | group | ✓ |
| `group.ownership_transferred` | new owner + admins | أنت الآن مالك {group} | group | ✓ |
| `recurrence.instance_created` | as `task.created` | (same) | task | Phase 2 |
| `stats.weekly_summary` | user | ملخص أسبوعك | notifications | Phase 2 |

Eligible members for `task.created` = active members of the group. Phase 3 may narrow this by
team/skill when hierarchy is introduced.

## 3. Anti-spam rules (brief §7 "avoid unnecessary notification spam")

1. **Never notify the actor** about their own action.
2. **Collapse bursts.** A creator adding 8 tasks in 2 minutes produces one push per recipient:
   «٨ مهام جديدة في البيت». Implementation: outbox rows share `collapse_key = type:group_id`; the
   sender groups pending rows for the same device and collapse key created within 120 s and
   renders a summary body. In-app rows stay individual.
3. **Deadline reminders are single-shot per threshold.** `task.due_soon` fires once at 24 h and
   once at 1 h before `due_at` (per task, tracked in `task_reminders_sent`); `task.overdue` fires
   once when the deadline passes and then at most once per day while still open, max 3 times.
4. **Comment notifications are throttled** to one per task per recipient per 10 minutes
   («٣ تعليقات جديدة على…»).
5. **Quiet hours** (Phase 2): per-user window during which pushes are held and delivered at the
   window's end, except `task.assigned` marked urgent.
6. **Preferences are honoured at fan-out**, so disabled types do not even create outbox rows.

## 4. Scheduled producers (pg_cron)

| Job | Cadence | Work |
|---|---|---|
| `remind_due_soon` | every 5 min | tasks with `due_at` in (now+55m, now+65m] or (now+23h55m, now+24h05m] and open → enqueue `task.due_soon` if not already sent for that threshold |
| `mark_overdue_notifications` | every 15 min | open tasks with `due_at < now()` and no overdue reminder in the last 24 h (≤ 3 total) → enqueue `task.overdue` |
| `retry_outbox` | every 1 min | invoke `push-sender` for `pending` rows with `next_attempt_at <= now()` |
| `prune_devices` | daily | delete devices unseen for 90 days |
| `materialise_recurrences` | every 15 min (Phase 2) | create next instances |

Scheduled jobs run with the service role, but they only *enqueue*; visibility is not a concern
because recipients are computed from memberships at enqueue time.

## 5. User preferences

`notification_preferences(user_id, type, push boolean, in_app boolean)`; absence of a row means
both on. The settings screen G3 groups types under: المهام / المواعيد / المجموعات / التعليقات.
`task.assigned` and `join.accepted` cannot be turned off for push (they are the product), only
switched to silent delivery.

## 6. Payload design

APNs payload (≤ 4 KB, minimal personal data on the lock screen):

```json
{
  "aps": {
    "alert": { "title": "مهمة جديدة في البيت", "body": "إصلاح التكييف" },
    "badge": 3,
    "sound": "default",
    "thread-id": "group:{group_id}",
    "mutable-content": 1
  },
  "route": "almunjez://task/{task_id}",
  "nid": "{notification_id}",
  "collapse": "task.created:{group_id}"
}
```

* `thread-id` groups notifications per group in Notification Centre.
* `badge` = unread in-app count, computed at send time.
* Notification Service Extension (Phase 2) can localise or attach a proof thumbnail.
* Group names and task titles are already known to the recipient; nothing else (no phone numbers,
  no comments bodies beyond 80 chars) is sent to APNs.

## 7. Localisation

Templates are stored server-side keyed by `type` and `locale` (`ar`, `en`); the recipient's
`users.locale` selects the template at outbox time, so a mixed-language family gets each member's
language.

## 8. Client behaviour

* Foreground: no system banner; the inbox badge and any visible list update through Realtime, and
  a light in-app toast is shown for `task.assigned` and `task.submitted` only.
* Background/cold: tap → router resolves `route`; the notification row is marked read via
  `mark_notification_read(nid)`.
* Badge is cleared only by opening الإشعارات or «تعليم الكل كمقروء».
