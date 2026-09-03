# 02 — Screen Map

Navigation is a four-tab bar plus one floating primary action. Tabs read right-to-left.

```
┌───────────────────────────────────────────────┐
│  الإشعارات   المجموعات    مهامي    الرئيسية    │   ← tab bar (RTL order)
└───────────────────────────────────────────────┘
                     (+ مهمة)                      ← floating CTA, always visible on tabs 1–3
```

## 1. Complete screen list

| ID | Screen (Arabic title) | Purpose | Entry points | Primary action |
|---|---|---|---|---|
| **A. Onboarding & auth** | | | | |
| A1 | مرحباً بك | Value proposition in 3 slides, skip-able | first launch | تسجيل الدخول |
| A2 | تسجيل الدخول | Sign in with Apple (primary) / رقم الجوال | A1, signed-out state | Apple button |
| A3 | رمز التحقق | 6-digit OTP for phone sign-in | A2 | auto-submit on 6 digits |
| A4 | إكمال الملف | Display name (pre-filled from Apple), optional photo | first successful sign-in | متابعة |
| A5 | إذن الإشعارات | Explain why, then request APNs permission | after A4, or later from settings | تفعيل |
| **B. Home** | | | | |
| B1 | الرئيسية | Greeting, today's counts (جديدة / قيد التنفيذ / أُنجزت اليوم), pending join requests I must decide, my groups | tab 1 | + مهمة |
| B2 | مهامي اليوم | Unified list: personal + assigned + claimed, sections: متأخرة / اليوم / بلا موعد | B1 counts, tab 2 default | tap task → D1 |
| **C. Groups** | | | | |
| C1 | المجموعات | My groups with open-task badge; empty state offers create/join | tab 3 | إنشاء مجموعة / انضمام |
| C2 | إنشاء مجموعة | Name, type (بيت/عائلة/شركة/…), optional defaults (approval, gamification) | C1 | إنشاء |
| C3 | دعوة الأعضاء | Shows code + QR, share sheet, regenerate/revoke | after C2, C7 | مشاركة |
| C4 | الانضمام إلى مجموعة | Enter code or scan QR; shows group name before requesting | C1 | طلب الانضمام |
| C5 | لوحة المجموعة | Counts, filter chips (الكل/جديدة/قيد التنفيذ/مكتملة/لي/متأخرة), task list, join-request badge for admins | C1, deep link | + مهمة |
| C6 | طلبات الانضمام | Pending requests with accept/reject | C5 badge, notification | قبول / رفض |
| C7 | الأعضاء | Members with role chips; owner/admin can change role, remove | C5 | — |
| C8 | سجل النشاط | Immutable timeline of group events | C5 | — |
| C9 | إعدادات المجموعة | Name, type, approval default, gamification on/off, stats visibility, who may create tasks, transfer ownership, leave, archive | C5 (owner/admin) | حفظ |
| C10 | إحصاءات المجموعة | Per-member contribution (respecting visibility), leaderboard when gamification on | C5 | — |
| **D. Tasks** | | | | |
| D1 | تفاصيل المهمة | Large state header, owner, due, description, proof, comments, activity | everywhere | context-dependent: سأتولى المهمة / تم الإنجاز / اعتماد |
| D2 | مهمة جديدة | Title (focused, keyboard up), group picker (default: current context), assignment mode, assignee, due, priority, points, proof toggle | FAB, C5 | إضافة |
| D3 | تعديل المهمة | Same form, prefilled | D1 (creator/admin) | حفظ |
| D4 | إثبات الإنجاز | Camera/photo/file/note before completing | D1 when proof required | إرسال |
| D5 | مراجعة الإنجاز | Approver sees proof, approves or rejects with reason | D1, notification | اعتماد / إرجاع |
| **E. Personal** | | | | |
| E1 | مهامي الخاصة | Private tasks only, no group | tab 2 segment | + مهمة (personal preselected) |
| **F. Notifications & search** | | | | |
| F1 | الإشعارات | Inbox grouped by day, tap → deep link, mark all read | tab 4 | — |
| F2 | البحث | Tasks / groups / members; filters: status, member, date, priority, group | search icon on B1, C5 | — |
| **G. Profile & settings** | | | | |
| G1 | الملف الشخصي | Name, photo, my stats across groups | avatar on B1 | — |
| G2 | الإعدادات | Language (العربية/English), notification preferences per type, delete account | G1 | — |
| G3 | إعدادات الإشعارات | Toggle per notification type (doc 08 §5) | G2, A5 | — |

Total: 29 screens, of which the MVP ships 24 (C10 leaderboard part, D4, D5 proof upload, and
recurrence settings inside D2 are Phase 2; the screens exist as placeholders in the router).

## 2. The critical path, screen by screen

The single most important interaction (brief §21):

```
Push: «مهمة جديدة في البيت: إصلاح التكييف»
   │ tap
   ▼
D1 تفاصيل المهمة   ← state header «جديدة»,  big button «سأتولى المهمة»
   │ tap (1)
   ▼
D1 (same screen)   ← header becomes «قيد التنفيذ — محمد», button becomes «تم الإنجاز»
   │ … later, tap (2)
   ▼
D1 (same screen)   ← «مكتملة» or «بانتظار الاعتماد»
```

Two taps after opening the notification. The task detail screen never navigates away on a
state change; it re-renders in place with a haptic and the optimistic state.

## 3. State header vocabulary (large, readable, colour-coded)

| Status | Arabic label | Colour token | Shown with |
|---|---|---|---|
| new (open) | جديدة — متاحة | accent | «سأتولى المهمة» |
| new (assigned to me) | جديدة — لك | accent | «ابدأ» / «تم الإنجاز» |
| new (assigned to other) | جديدة — أحمد | neutral | — |
| in_progress | قيد التنفيذ — محمد | progress | «تم الإنجاز» (if mine) |
| awaiting_approval | بانتظار الاعتماد | warning | «اعتماد» (if approver) |
| completed | مكتملة ✓ | success | — |
| cancelled | ملغاة | muted | — |
| derived overdue | متأخرة (badge over any of the above) | danger | — |

## 4. Deep links

Every push notification carries a route. The router resolves them even when the app is cold.

| Route | Target |
|---|---|
| `almunjez://task/{task_id}` | D1 |
| `almunjez://group/{group_id}` | C5 |
| `almunjez://group/{group_id}/requests` | C6 |
| `almunjez://join/{code}` | C4 with code prefilled (also the QR payload) |
| `almunjez://notifications` | F1 |

## 5. RTL rules applied to every screen

* Leading edge is the right edge: back chevron points right, lists indent from the right, the
  primary button sits at the trailing (left) end of a row only when paired with a secondary one.
* Numbers use Eastern Arabic digits (٠١٢…) by default with a per-user override; dates use the
  Gregorian calendar with Arabic month names; times are 12-hour with ص/م.
* Text fields are RTL by default and flip automatically when the first strong character is Latin.
* Icons that imply direction (send, reply, forward, progress chevrons) are mirrored; icons that
  do not (clock, camera, check) are not.
* Long Arabic words never truncate mid-word; task titles wrap to two lines then ellipsise.
