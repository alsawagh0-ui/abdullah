// Supabase Edge Function: drains notification_outbox to APNs (doc 08 §1).
// Deploy:  supabase functions deploy push-sender --no-verify-jwt
// Secrets: supabase secrets set APNS_TEAM_ID=… APNS_KEY_ID=… APNS_BUNDLE_ID=kw.almunjez.almunjez \
//            APNS_PRIVATE_KEY="$(cat AuthKey_XXXX.p8)" APNS_ENV=sandbox|production
// Invoked every minute by pg_cron (backend/schema/002_push_cron.sql) or manually.
import { createClient } from "npm:@supabase/supabase-js@2";

const TEAM_ID = Deno.env.get("APNS_TEAM_ID")!;
const KEY_ID = Deno.env.get("APNS_KEY_ID")!;
const BUNDLE_ID = Deno.env.get("APNS_BUNDLE_ID") ?? "kw.almunjez.almunjez";
const PRIVATE_KEY = Deno.env.get("APNS_PRIVATE_KEY")!;
const HOST = (Deno.env.get("APNS_ENV") ?? "sandbox") === "production"
  ? "https://api.push.apple.com"
  : "https://api.sandbox.push.apple.com";

const db = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);

// ---- APNs provider token (ES256 JWT, valid 1h, cached per isolate)
let cachedJwt: { token: string; at: number } | null = null;
async function providerJwt(): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  if (cachedJwt && now - cachedJwt.at < 50 * 60) return cachedJwt.token;
  const pem = PRIVATE_KEY.replace(/-----[A-Z ]+-----/g, "").replace(/\s+/g, "");
  const key = await crypto.subtle.importKey("pkcs8", Uint8Array.from(atob(pem), (c) => c.charCodeAt(0)),
    { name: "ECDSA", namedCurve: "P-256" }, false, ["sign"]);
  const b64 = (o: unknown) => btoa(JSON.stringify(o)).replace(/=/g, "").replace(/\+/g, "-").replace(/\//g, "_");
  const input = `${b64({ alg: "ES256", kid: KEY_ID })}.${b64({ iss: TEAM_ID, iat: now })}`;
  const sig = new Uint8Array(await crypto.subtle.sign({ name: "ECDSA", hash: "SHA-256" }, key, new TextEncoder().encode(input)));
  const token = `${input}.${btoa(String.fromCharCode(...sig)).replace(/=/g, "").replace(/\+/g, "-").replace(/\//g, "_")}`;
  cachedJwt = { token, at: now };
  return token;
}

// ---- Arabic/English titles rendered server-side (same vocabulary as the app)
function render(type: string, d: Record<string, unknown>, locale: string, actor?: string, group?: string) {
  const ar = locale !== "en";
  const title = (d.title as string) ?? "";
  const a = actor ?? (ar ? "عضو" : "A member");
  const g = group ?? (ar ? "المجموعة" : "the group");
  const t = (x: string, y: string) => (ar ? x : y);
  const map: Record<string, [string, string]> = {
    "task.created": [`مهمة جديدة في ${g}`, `New task in ${g}`],
    "task.assigned": [t("أُسندت إليك", "Assigned to you"), title],
    "task.claimed": [`${a} ${t("تولّى", "took")}`, title],
    "task.released": [`${a} ${t("تنازل عن", "gave up")}`, title],
    "task.completed": [`${a} ${t("أنجز", "completed")}`, title],
    "task.submitted": [t("بانتظار اعتمادك", "Awaiting your approval"), title],
    "task.approved": [t("اعتُمد إنجازك", "Your completion was approved"), title],
    "task.rejected": [t("أُعيدت إليك", "Sent back to you"), title],
    "task.reassigned": [t("تغيّر المسؤول", "Assignee changed"), title],
    "task.unassigned": [t("أصبحت مفتوحة", "Now open"), title],
    "task.cancelled": [t("أُلغيت", "Cancelled"), title],
    "task.comment": [`${a} ${t("علّق على", "commented on")}`, title],
    "task.due_soon": [t("تقترب مهلة", "Deadline approaching"), title],
    "task.overdue": [t("تأخرت", "Overdue"), title],
    "join.requested": [t("طلب انضمام", "Join request"), `${a} → ${g}`],
    "join.accepted": [t("تم قبولك", "You were accepted"), g],
    "join.rejected": [t("لم يُقبل طلبك", "Request not accepted"), g],
    "member.removed": [t("أُزلت من المجموعة", "Removed from group"), g],
    "member.role_changed": [t("تغيّر دورك", "Your role changed"), g],
    "group.ownership_transferred": [t("أنت الآن المالك", "You now own"), g],
  };
  const [tt, body] = map[type] ?? [type, title];
  return { title: tt, body: (body as string).slice(0, 80) };
}

function routeFor(n: { task_id?: string; group_id?: string; type: string }) {
  if (n.task_id) return `almunjez://task/${n.task_id}`;
  if (n.type === "join.requested" && n.group_id) return `almunjez://group/${n.group_id}/requests`;
  if (n.group_id) return `almunjez://group/${n.group_id}`;
  return "almunjez://notifications";
}

Deno.serve(async () => {
  const { data: rows, error } = await db
    .from("notification_outbox")
    .select("id, attempts, collapse_key, notification:notification_id(id, user_id, type, task_id, group_id, actor_id, data), device:device_id(id, apns_token, locale)")
    .eq("status", "pending")
    .lte("next_attempt_at", new Date().toISOString())
    .limit(200);
  if (error) return new Response(error.message, { status: 500 });
  if (!rows?.length) return Response.json({ sent: 0 });

  // collapse bursts of the same type/group per device (doc 08 §3)
  const byKey = new Map<string, typeof rows>();
  for (const r of rows) {
    const k = `${(r.device as any).id}:${r.collapse_key ?? r.id}`;
    byKey.set(k, [...(byKey.get(k) ?? []), r]);
  }

  const jwt = await providerJwt();
  let sent = 0, failed = 0;
  for (const group of byKey.values()) {
    const first = group[0];
    const n = first.notification as any, dev = first.device as any;
    const [{ data: actor }, { data: grp }, { count: unread }] = await Promise.all([
      n.actor_id ? db.from("users").select("display_name").eq("id", n.actor_id).maybeSingle() : Promise.resolve({ data: null }),
      n.group_id ? db.from("groups").select("name").eq("id", n.group_id).maybeSingle() : Promise.resolve({ data: null }),
      db.from("notifications").select("id", { count: "exact", head: true }).eq("user_id", n.user_id).is("read_at", null),
    ]);
    let { title, body } = render(n.type, n.data ?? {}, dev.locale ?? "ar", actor?.display_name, grp?.name);
    if (group.length > 1) body = (dev.locale ?? "ar") !== "en" ? `${group.length} إشعارات جديدة` : `${group.length} new notifications`;

    const payload = {
      aps: { alert: { title, body }, badge: unread ?? 0, sound: "default", "thread-id": n.group_id ? `group:${n.group_id}` : "personal", "mutable-content": 1 },
      route: routeFor(n), nid: n.id, collapse: first.collapse_key,
    };
    const res = await fetch(`${HOST}/3/device/${dev.apns_token}`, {
      method: "POST",
      headers: { authorization: `bearer ${jwt}`, "apns-topic": BUNDLE_ID, "apns-push-type": "alert", "apns-priority": "10", "apns-collapse-id": (first.collapse_key ?? n.id).slice(0, 64) },
      body: JSON.stringify(payload),
    }).catch((e) => ({ status: 0, text: async () => String(e) }) as Response);

    const ids = group.map((r) => r.id);
    if (res.status === 200) {
      await db.from("notification_outbox").update({ status: "sent" }).in("id", ids);
      sent += ids.length;
    } else if (res.status === 410 || res.status === 400 && (await res.clone().text()).includes("BadDeviceToken")) {
      await db.from("devices").delete().eq("id", dev.id); // cascades the outbox rows
      failed += ids.length;
    } else {
      const attempts = first.attempts + 1;
      const backoffMin = [1, 5, 30][attempts - 1] ?? null;
      await db.from("notification_outbox").update({
        status: backoffMin === null ? "dead" : "pending",
        attempts,
        next_attempt_at: new Date(Date.now() + (backoffMin ?? 0) * 60_000).toISOString(),
        last_error: `${res.status} ${(await res.text()).slice(0, 200)}`,
      }).in("id", ids);
      failed += ids.length;
    }
  }
  return Response.json({ sent, failed });
});
