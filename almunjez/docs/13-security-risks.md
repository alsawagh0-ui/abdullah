# 13 — Security Risks and Mitigations

Threat model: the attacker is an authenticated user of the app (any member of any group), or an
outsider holding a leaked invitation code, or a former member with a stale client. The assets are
private group content, membership lists, files, and the integrity of the activity record.

## 1. Threats and controls

| # | Threat | Impact | Control | Verified by |
|---|---|---|---|---|
| T1 | **IDOR** — reading another group's tasks by guessing/changing IDs | disclosure of private group data | Row-Level Security on every table using `is_active_member` / `can_view_task`; UUIDv4 ids; no list endpoint without a group filter | pgTAP: member of A selects from tasks of B → 0 rows; RPC with foreign id → `not_a_member` |
| T2 | **Privilege escalation** — member updates their own `memberships.role` via PostgREST | takeover of group | no UPDATE policy on `memberships`; role changes only via `set_member_role` which checks `group.manage_members` and the admin/owner separation rules | pgTAP |
| T3 | **Invitation code brute force** | join-request spam, group discovery | 32-symbol × 8-char code; `preview_invite` / `request_join` rate limit 10 / 10 min / user and 30 / hour / IP (edge); generic error; owner can revoke | rate-limit test |
| T4 | **Leaked code used at scale** | many bogus join requests | approval gate; code regeneration; requester profile shown before accept; block list per group (Phase 2) | product review |
| T5 | **Stale client after removal** | ex-member still sees cached data, tries writes | every write is re-authorised in DB; Realtime filtered by RLS; client clears cache on first `not_a_member` | integration test |
| T6 | **Storage path guessing** | download of another group's files | private bucket; object policy parses `groups/{gid}/tasks/{tid}/…` and calls `can_view_task`; signed URLs 60 s; `attach_file` validates that the path's group/task match the task row | Storage policy test |
| T7 | **Activity log tampering** by an owner | loss of audit value for companies | `BEFORE UPDATE OR DELETE` trigger raises on `activity_events`; no policy allows it; service role only used by Edge Functions that never touch this table | pgTAP |
| T8 | **JWT theft** from device | account takeover | tokens in Keychain; 1-hour access token; rotating refresh with reuse detection; sensitive actions require re-auth (doc 05 §5) | review |
| T9 | **Service-role key in the app** | total bypass of RLS | the key exists only in Edge Function secrets; CI grep fails the build if `service_role` appears in `app/` | CI check |
| T10 | **Notification content leakage** on lock screen | private task titles visible to bystanders | payload carries title + short body only; comments truncated to 80 chars; no phone numbers; user can choose «إخفاء المحتوى» which sends «لديك إشعار جديد» and relies on the in-app row | product |
| T11 | **Enumeration of users** by phone number | privacy | no "search users by phone" endpoint; members are only visible inside a shared group; `preview_invite` returns counts, never names | API review |
| T12 | **SQL injection via search** | disclosure | parameterised functions; `search` uses `plainto_tsquery`/`ILIKE` with escaped input; no dynamic SQL from user text | code review |
| T13 | **Approval self-dealing** | fake completions in companies | assignee can never approve own task, even as owner | pgTAP |
| T14 | **Admin abuse** — admin removes owner or another admin | takeover | forbidden in `set_member_role` / `remove_member`; only the owner touches admins | pgTAP |
| T15 | **Account deletion used to escape audit** | broken records | anonymisation keeps event rows; only personal data is removed | test |
| T16 | **Push token hijack** — registering someone else's APNs token | receiving their notifications | tokens are opaque and device-bound by Apple; the outbox only sends to devices whose `user_id` = recipient, and re-registration moves the token — the only way to "steal" it is to possess the device | — |
| T17 | **Denial of service via mass task creation** | noise, cost | per-user write limit 60 mutations / min at the edge; group-level limit 500 tasks / day in MVP; collapse keys keep push volume bounded | rate-limit test |
| T18 | **Malicious file upload** | client exploitation | MIME allow-list (`image/jpeg, image/png, image/heic, application/pdf`), size caps, no execution/inline rendering of unknown types; images re-encoded on device before upload | client + Storage |
| T19 | **Cross-group data in unified views** | disclosure via `my_tasks` | views are `security_invoker`; the union is over rows RLS already allows | pgTAP |
| T20 | **Timing/side-channel on invite preview** | code validity oracle | constant error shape; rate limit; no difference between "revoked" and "nonexistent" | review |

## 2. Data classification

| Data | Class | Handling |
|---|---|---|
| Task titles, descriptions, comments | private group content | RLS; encrypted at rest (platform); never in logs |
| Attachments / proof photos | private group content | private bucket; signed URLs; EXIF stripped on device |
| Phone numbers, Apple relay emails | personal identifiers | only in `auth.users`; never selected by the app; never in notifications |
| Display name, avatar | shared inside groups | visible only to co-members |
| Activity events | audit | immutable; exportable by owner (Phase 3) |
| Push tokens | device secrets | server only; deleted on sign-out |

## 3. Platform and compliance items

* App Store: privacy manifest (`PrivacyInfo.xcprivacy`) listing required-reason APIs
  (UserDefaults, file timestamps); account deletion in-app; Sign in with Apple offered whenever
  another third-party login is.
* Data residency: choose the closest Supabase region to the Gulf (eu-central or ap-south at the
  time of writing); document it in the privacy policy.
* Logging: RPC audit stores ids and error codes only, 30-day retention.
* Backups: daily PITR; restore drill once before launch.
* Secrets: APNs key, Apple client secret, AI key only in Edge Function secrets; rotated yearly.

## 4. Security testing plan before 1.0

1. pgTAP suite covering every row in §1 marked "pgTAP" — runs in CI on every schema change.
2. A scripted "two users, two groups" scenario against a staging project hitting PostgREST directly
   with each user's JWT, asserting empty results and 403s.
3. Concurrency test: 50 parallel `claim_task` calls → exactly one success.
4. Manual review of Storage policies with a forged path.
5. Dependency audit of the Flutter app (`flutter pub outdated`, `osv-scanner`).
