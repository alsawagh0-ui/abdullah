# 03 — User Flows

Each flow lists the screens (doc 02 IDs), the backend operation (doc 09), the activity event
written (doc 13 §activity), and the notification emitted (doc 08). Tap counts start after the
app is open on the relevant screen.

## F1. First sign-in

```
A1 مرحباً ─▶ A2 تسجيل الدخول ─▶ [Apple sheet] ─▶ A4 إكمال الملف ─▶ A5 إذن الإشعارات ─▶ B1 الرئيسية
                     └─▶ رقم الجوال ─▶ A3 رمز التحقق ─┘
```

* Backend: Supabase Auth creates `auth.users`; trigger `on_auth_user_created` inserts `users`.
* On A5 accept: app registers the APNs token → `register_device(token, platform, app_version)`.
* Empty home shows two cards: «أنشئ مجموعتك الأولى» and «لديك رمز دعوة؟».

## F2. Create a group and invite

```
C1 ─▶ C2 إنشاء مجموعة (name: البيت, type: بيت) ─▶ C3 دعوة الأعضاء (code + QR) ─▶ share sheet
```

* RPC `create_group(name, type, settings)` → inserts group, owner membership, first invite code.
  Event `group.created`.
* C3 offers: نسخ الرمز / مشاركة الرابط / عرض QR / **إعادة توليد الرمز** / **إيقاف الدعوات**.
* `regenerate_invite(group_id)` revokes the current code (sets `revoked_at`) and creates a new one;
  pending requests made with the old code stay valid (they were already reviewed by nothing but
  the code; the owner still decides).

## F3. Join through code or QR, with approval

```
Member:  C1 ─▶ C4 الانضمام ─▶ enter code / scan QR ─▶ preview «البيت — ٤ أعضاء» ─▶ طلب الانضمام ─▶ «بانتظار الموافقة»
Owner:   push «طلب انضمام: سارة → البيت» ─▶ C6 طلبات الانضمام ─▶ قبول
Member:  push «تم قبولك في البيت» ─▶ C5 لوحة المجموعة
```

* `preview_invite(code)` returns only `{group_name, member_count, group_type}` — never members.
  Rate-limited: 10 attempts / 10 min / user (doc 13 §T3).
* `request_join(code, message?)` → `join_requests(pending)`. Duplicate pending request is a no-op
  returning the existing row. A user already active in the group gets `already_member`.
* `decide_join(request_id, accept|reject)` → on accept inserts `memberships(member)`. Requires
  permission `group.approve_joins`. Events `join.requested`, `join.accepted` / `join.rejected`.
* Notifications: to all users with `group.approve_joins` on request; to the requester on decision.
* Reject is silent to the group; the requester is told «لم يُقبل طلبك» without a reason field
  (avoids conflict; the owner can message outside the app).

## F4. Create an open task → claim → complete (the critical path)

```
Creator:  B1 ─▶ (+ مهمة) ─▶ D2: title «إصلاح التكييف», group «البيت», mode «مفتوحة» ─▶ إضافة        [3 taps + typing]
Members:  push «مهمة جديدة في البيت: إصلاح التكييف»
Mohammed: tap push ─▶ D1 ─▶ «سأتولى المهمة»                                                       [1 tap]
Everyone: D1/C5 re-render: «قيد التنفيذ — محمد»   (realtime)
Mohammed: D1 ─▶ «تم الإنجاز»                                                                       [1 tap]
Creator:  push «محمد أنجز: إصلاح التكييف»
```

* `create_task(payload)` → `tasks(status=new, assignment_mode=open)`, event `task.created`,
  notification `task.created` to eligible members except the creator.
* `claim_task(task_id)` — atomic (doc 07 §4). Second simultaneous caller receives
  `already_claimed` with the claimer's name, and the screen shows «تولّاها محمد قبل قليل».
* `complete_task(task_id, proof?)` → `completed`, or `awaiting_approval` when the task has
  `requires_approval`. Event `task.completed` / `task.submitted`. Notification to creator (and
  approvers when awaiting).

## F5. Assigned task

```
Creator: D2 mode «محددة» ─▶ pick أحمد ─▶ إضافة
Ahmed:   push «أُسندت إليك: أخذ السيارة للصيانة» ─▶ D1 shows «جديدة — لك» with «ابدأ» and «تم الإنجاز»
```

* Assigned tasks are `new` with `assignee_id` set. «ابدأ» → `start_task` (in_progress). Skipping
  straight to «تم الإنجاز» is allowed; the state machine permits `new → completed` for the assignee.
* Assignee may «التنازل عن المهمة» → `release_task` → task becomes open (`assignee_id = null`)
  and the creator is notified. Creator/admin may `reassign_task`.

## F6. Completion with approval

```
Mohammed: D1 ─▶ «تم الإنجاز» ─▶ (D4 إثبات الإنجاز if required: photo/file/note) ─▶ إرسال
Creator:  push «بانتظار اعتمادك: إصلاح التكييف» ─▶ D5 مراجعة الإنجاز ─▶ اعتماد | إرجاع + سبب
Mohammed: push «اعتُمد إنجازك» | «أُعيدت إليك المهمة: السبب…»
```

* Who approves: the creator, or anyone with `task.approve_completion` (owner/admin by default).
  The assignee can never approve their own task even if they are owner (doc 06 §4).
* `reject_completion(task_id, reason)` → back to `in_progress`, comment auto-added with the reason.

## F7. Collaborative task with subtasks (Phase 2 surface, MVP data model)

```
Creator: D2 mode «تعاونية» ─▶ add participants ─▶ optional subtasks ─▶ إضافة
Participants: each subtask behaves as an open/assigned task inside the parent
Parent completes when all subtasks complete (auto), or manually by creator
```

## F8. Personal task

```
Tab مهامي ─▶ segment «الخاصة» ─▶ (+ مهمة) ─▶ D2 with group = «بلا مجموعة (خاصة)» ─▶ إضافة
```

* `tasks.group_id IS NULL`, `creator_id = assignee_id = me`. RLS: visible only to the creator.
  No events, no notifications, no points.

## F9. Today view

```
Tab مهامي ─▶ «اليوم» (default)
   sections: متأخرة (red)  /  اليوم  /  قيد التنفيذ بلا موعد  /  قادمة (collapsed)
   row: [group chip] title  ·  due  ·  state pill  ·  quick action (✓ or سأتولى)
```

* One query on `v_my_tasks_today`. Swipe actions: right = تم الإنجاز, left = تأجيل (only for my
  tasks) which just edits `due_at`.

## F10. Notifications inbox and deep links

```
Push (system) ─tap─▶ route ─▶ screen; the in-app row is marked read on open.
F1 الإشعارات: grouped by day, swipe to mark read, «تعليم الكل كمقروء».
```

## F11. Manage members and roles

```
C7 الأعضاء ─▶ tap member ─▶ sheet: ترقية إلى مشرف / إلغاء الإشراف / إزالة من المجموعة
C9 ─▶ نقل الملكية ─▶ pick member ─▶ confirm (biometric or re-auth)
C9 ─▶ مغادرة المجموعة (blocked for owner until transfer)
```

* `set_member_role`, `remove_member`, `transfer_ownership`, `leave_group`. Removing a member with
  in-progress tasks: those tasks are released to open and the creator notified (doc 12 §E7).

## F12. Search

```
B1/C5 search icon ─▶ F2: query + filter chips ─▶ results in three sections: المهام / المجموعات / الأعضاء
```

* Server-side full-text search on a normalised Arabic column (doc 12 §E12) restricted by RLS.

## F13. Account deletion (App Store requirement)

```
G2 ─▶ حذف الحساب ─▶ explain consequences ─▶ re-auth ─▶ delete
```

* Blocked while the user is the sole owner of any group with other members: they must transfer or
  archive first. Then `delete_account()` anonymises the user row (name → «عضو سابق»), removes
  devices and personal tasks, keeps group tasks and activity events attributed to the anonymised id.
