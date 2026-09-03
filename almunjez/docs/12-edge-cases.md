# 12 — Edge Cases

Each case names the rule and where it is enforced. "DB" = `001_initial.sql`; "client" = app only.

## Concurrency

| # | Case | Rule | Where |
|---|---|---|---|
| E1 | Two members tap «سأتولى المهمة» within the same second | first committed `UPDATE … WHERE assignee_id IS NULL` wins; the other gets `already_claimed` with the winner's name; the screen shows «تولّاها محمد قبل قليل» and switches to read-only | DB `claim_task` |
| E2 | Claimer taps twice (double tap / retry after timeout) | second call finds `assignee_id = self`, returns the row unchanged (idempotent) rather than an error | DB |
| E3 | Creator edits the title while the assignee completes | `update_task` requires `version`; on mismatch the editor gets `stale_version`; completion is not blocked by an edit | DB |
| E4 | Approver approves while creator cancels | both are transitions from `awaiting_approval`; whichever commits first wins, the other gets `invalid_transition` | DB |
| E5 | Offline user claims, comes online after someone else claimed | the queued call fails with `already_claimed`; the optimistic UI rolls back with a toast; queued *completion* of a task no longer owned rolls back likewise | client queue + DB |
| E6 | Recurrence scheduler runs twice (retry) | `occurrence_key` unique → second insert is a no-op | DB (Phase 2) |

## Membership churn

| # | Case | Rule | Where |
|---|---|---|---|
| E7 | Member removed while holding in-progress tasks | `remove_member` releases those tasks to open (`assignee = null`, `status = new`), writes `task.unassigned` events and notifies creators | DB |
| E8 | Member leaves voluntarily | same as E7 via `leave_group` | DB |
| E9 | Owner tries to leave / delete account | `owner_must_transfer` unless the group has no other active members, in which case `archive_group` is offered | DB |
| E10 | Admin removed by owner | tasks they created stay; their approvals already given stay; pending join requests they were going to decide remain pending for other approvers | DB (nothing to do) |
| E11 | Assigned task to a member who is then removed before starting | E7 releases it to open; the creator is notified «أُزيل أحمد، المهمة متاحة الآن» | DB |
| E12 | Rejoin after removal | membership row flips back to `active` with role `member` and fresh `joined_at`; old permissions JSON is cleared | DB `decide_join` |
| E13 | Creator of an awaiting-approval task has left the group | approval falls to `task.approve_completion` holders; if none exist (single-member group) completion becomes direct | DB `complete_task`/`approve_completion` |

## Invitations and joining

| # | Case | Rule | Where |
|---|---|---|---|
| E14 | Invitation code leaked | code only allows *requesting*; owner sees requester's name and avatar before accepting; owner regenerates the code; pending requests made with the old code stay pending (owner decides) | product + DB |
| E15 | Brute-force guessing codes | 8 chars from a 32-symbol alphabet (≈ 1.1 × 10¹² space), `preview_invite` limited to 10 attempts / 10 min / user, generic `invalid_invite` error | DB rate limit |
| E16 | User requests to join twice | unique pending request per (group, user); second call returns the same row | DB |
| E17 | Owner accepts a request from a user who deleted their account meanwhile | the user row is anonymised; `decide_join` refuses with `invalid_transition`; request auto-cancelled by `delete_account` | DB |
| E18 | QR scanned by someone without the app | QR encodes a universal link `https://almunjez.app/join/{code}` that opens the app if installed, else the App Store page carrying the code through deferred deep link | client + web |
| E19 | Group archived while requests are pending | `decide_join` refuses; requesters are notified «المجموعة مؤرشفة» | DB |

## Tasks and time

| # | Case | Rule | Where |
|---|---|---|---|
| E20 | Family members in different time zones | `due_at` is an instant; "today" sections use the caller's timezone; date-only deadlines are end-of-day in the creator's timezone | DB `my_tasks(p_tz)` |
| E21 | Device clock wrong | server timestamps only; the client never sends `now()` | DB |
| E22 | Task completed after the deadline | `completed_at > due_at` → counted as late in stats; the task is *not* overdue anymore (derived flag only applies to open tasks) | views |
| E23 | Deadline changed after a reminder was sent | `task_reminders_sent` rows for that task are cleared on `due_at` change, so the new deadline gets fresh reminders | DB trigger |
| E24 | Task with no due date | never overdue; appears under «بلا موعد» in Today only if in progress or assigned to me | views |
| E25 | Personal task moved into a group | not supported as an edit; the user creates a group task and the personal one is cancelled (avoids leaking private description history) | product |
| E26 | Subtask completed while the parent was cancelled | parent cancellation cascades first; a late subtask completion hits `invalid_transition` | DB |
| E27 | Reopen a task whose assignee left the group | reopens as `new`/open instead of `in_progress` | DB `reopen_task` |
| E28 | Points changed after completion | `update_task` is refused on terminal states; points are frozen for stats | DB |

## Proof and files (Phase 2 surfaces, MVP rules)

| # | Case | Rule | Where |
|---|---|---|---|
| E29 | Proof required but the assignee marks done from the Today swipe action | the RPC raises `proof_required`; the client opens D4 instead of failing silently | DB + client |
| E30 | Upload succeeded but `attach_file` call failed | orphaned object; nightly job deletes Storage objects with no attachment row older than 24 h | job |
| E31 | File too large | client caps 25 MB and compresses images to ≤ 2 MB / 2048 px; Storage bucket limit 30 MB as a hard stop | client + Storage |
| E32 | Proof uploaded by a non-assignee | `attach_file(kind = proof)` requires caller = assignee | DB |

## Arabic text and search

| # | Case | Rule | Where |
|---|---|---|---|
| E33 | «تكييف» vs «تكيّيف» vs «التكييف» | `normalize_ar` strips diacritics and tatweel, unifies alef/hamza forms, ة→ه, ى→ي; search matches on the normalised column; the leading «ال» is *not* stripped (too lossy) but prefix matching covers it | DB |
| E34 | Mixed Arabic/English titles | normalisation lowercases Latin; trigram index handles both | DB |
| E35 | Numbers typed in Eastern Arabic digits (٤) | normalised to ASCII digits before search and before parsing points/durations | DB + client |
| E36 | Very long titles | 200-char limit enforced by check constraint; the client counts down at 180 | DB + client |
| E37 | Emoji-only title | allowed (families use them); search treats it literally | — |

## Notifications

| # | Case | Rule | Where |
|---|---|---|---|
| E38 | User has 3 devices | one in-app row, one outbox row per device; badge count identical everywhere | DB |
| E39 | Push token rotates | `register_device` upsert on token; the old token stays until APNs returns 410 or 90 days pass | DB |
| E40 | Same device logged into a second account | the token row moves to the new user; the previous account stops receiving pushes on that device | DB |
| E41 | User turns off all notifications | in-app rows still created (they are the record); outbox skipped | DB fan-out |
| E42 | Creator is also the only approver and the assignee | approval skipped; task completes directly | DB |
| E43 | 20 tasks created in a bulk (future AI «إضافة جميع المهام») | collapse key merges into one push «٢٠ مهمة جديدة في البيت» | sender |

## Offline and sync

| # | Case | Rule | Where |
|---|---|---|---|
| E44 | App opened offline | cached lists render with a «غير متصل» banner; primary buttons stay enabled and queue (Phase 2) or are disabled with explanation (MVP) | client |
| E45 | Realtime disconnects silently | on foreground and every 60 s of visibility, the open screen re-fetches its view; Realtime is an accelerator, never the only path | client |
| E46 | Removed member still has cached group data | next fetch returns no rows; cache is cleared for that group; a courtesy notification explains | client |

## Account lifecycle

| # | Case | Rule | Where |
|---|---|---|---|
| E47 | Account deleted | anonymised in shared data; personal data hard-deleted; Apple token revoked (doc 05 §6) | DB + Edge Function |
| E48 | Apple "Hide My Email" relay address | never used for anything user-facing; phone or display name is the identity shown | product |
| E49 | Same person invited by phone but signed in with Apple | invitations are by code, not by contact, so identity provider is irrelevant to joining | product |
