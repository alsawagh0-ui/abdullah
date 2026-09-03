# 05 — Authentication Model

## 1. Identity providers

| Provider | Priority | Why |
|---|---|---|
| **Sign in with Apple** | primary on iPhone | one tap, App Store rule (required once any third-party login exists), hides email, no password to leak |
| **Phone number + SMS OTP** | secondary | the natural identity in the Arabic market; families invite by phone; works for members without an Apple ID they use |
| Email magic link | Phase 2 | organisations; enables the future web admin |
| SSO (SAML/OIDC) | Organisation stage | enterprise tenants |

No passwords anywhere in the MVP. Both MVP providers are supported natively by Supabase Auth,
which issues the JWT the database trusts.

## 2. Account model

```
auth.users (managed by Supabase Auth)   1 ── 1   public.users (profile)
                                        1 ── n   public.devices (push tokens)
```

* `public.users.id` **is** `auth.users.id`; a trigger on `auth.users` insert creates the profile
  row so a profile always exists once a session does.
* Linking: a user who signed in with Apple can later add a phone (Supabase identity linking). The
  UI offers this in الإعدادات so a family member invited "by phone" can be found.
* Display name is required (pre-filled from Apple's one-time name payload; Apple sends it only on
  the first authorisation, so the app persists it immediately).

## 3. Session and token policy

| Item | Value |
|---|---|
| Access token | JWT, RS256, **1 hour** |
| Refresh token | rotating, single-use, 30-day inactivity expiry; reuse detection revokes the family |
| Storage on device | Keychain (via `flutter_secure_storage`), never `UserDefaults` |
| Claims used by RLS | `sub` (user id), `role = authenticated` |
| Custom claims | none in MVP; group roles are looked up from `memberships` on each policy check (cheap, indexed, always fresh — no stale-claim problem when a member is removed) |

Sign-out revokes the refresh token server-side and deletes the device row for that token.

## 4. Devices and push tokens

`register_device(apns_token, platform, app_version, locale)`:

* upsert on `apns_token` — if the token moves to another user (shared iPad, re-login), the row is
  reassigned, so notifications never reach a previous account;
* `last_seen_at` updated on every app foreground; tokens unseen for 90 days are pruned;
* APNs feedback (`410 Unregistered`) deletes the row.

## 5. Re-authentication for sensitive actions

The following require a fresh session (< 5 minutes) or Face ID/Touch ID via `local_auth`:

* transfer group ownership
* delete account
* revoke all invitation codes of a group

## 6. Account deletion

Required by App Store Review Guideline 5.1.1(v). Implemented as `delete_account()`:

1. refuse if the user is the sole owner of a group that has other active members → the client
   directs them to transfer ownership or archive the group;
2. delete `devices`, personal tasks (`group_id IS NULL`), notifications, join requests;
3. anonymise `users` (display_name → «عضو سابق», avatar removed, `deleted_at` set);
4. leave group tasks, comments and activity events in place, attributed to the anonymised id, so
   the group's record stays consistent;
5. delete `auth.users` (cascades the session); the Apple token is revoked via the Sign in with
   Apple REST API from an Edge Function.

## 7. Rate limits on auth endpoints

| Endpoint | Limit |
|---|---|
| OTP send | 3 / phone / 10 min, 10 / IP / hour |
| OTP verify | 5 attempts per code, then the code is invalidated |
| Sign in with Apple | provider-limited; server verifies the identity token's audience and nonce |

## 8. What the client is allowed to assume

Nothing. The client caches the last known memberships to render quickly, but every screen reload
re-reads them through RLS. A removed member's app shows the group until the next fetch, at which
point the rows simply disappear; no special "you were removed" API is needed (a notification is
sent as a courtesy).
