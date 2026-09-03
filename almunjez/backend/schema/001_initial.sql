-- =============================================================================
-- AlMunjez (المنجز) — 001_initial.sql
-- Postgres 15+. Written for Supabase (assumes auth.uid()), runs on plain
-- Postgres with a stub auth.uid() — see backend/tests/_stub_auth.sql.
--
-- Contents
--   §1  extensions, enums, helpers (normalize_ar, invite codes, rate limit)
--   §2  tables
--   §3  authorization helpers (is_active_member, has_permission, can_view_task)
--   §4  triggers: updated_at, member_count, append-only activity, reminders reset,
--       subtask auto-complete, comment events, auth.users → users
--   §5  activity log + notification fan-out
--   §6  RPC: identity, groups, membership, tasks, notifications
--   §7  views and read functions
--   §8  row-level security
--   §9  scheduled jobs (pg_cron, guarded)
--   §10 grants (guarded)
-- =============================================================================

-- ---------------------------------------------------------------------------
-- §1 extensions, enums, helpers
-- ---------------------------------------------------------------------------
create extension if not exists pgcrypto;
create extension if not exists pg_trgm;

create type group_type          as enum ('home','family','company','department','team','project','committee','volunteer','other');
create type membership_role     as enum ('owner','admin','member');
create type membership_status   as enum ('active','removed','left');
create type join_request_status as enum ('pending','accepted','rejected','cancelled');
create type task_status         as enum ('new','in_progress','awaiting_approval','completed','cancelled');
create type task_priority       as enum ('low','normal','high','urgent');
create type assignment_mode     as enum ('open','assigned','collaborative');
create type attachment_kind     as enum ('attachment','proof');
create type outbox_status       as enum ('pending','sent','failed','dead');

-- Arabic-aware normalisation for search (doc 12 §E33): strip diacritics and
-- tatweel, unify alef/hamza forms, ة→ه, ى→ي, Eastern digits → ASCII, lowercase.
create or replace function normalize_ar(p text) returns text
language sql immutable strict as $$
  select lower(
    regexp_replace(
      translate(p,
        'أإآٱةىؤئ٠١٢٣٤٥٦٧٨٩',
        'ااااهيوي0123456789'),
      '[ً-ْـ]', '', 'g'));
$$;

-- 8-char code from a 32-symbol alphabet without ambiguous glyphs (0/O, 1/I).
create or replace function gen_invite_code() returns text
language plpgsql volatile as $$
declare
  alphabet constant text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  v_bytes bytea;
  v_code  text;
begin
  loop
    v_bytes := gen_random_bytes(8);
    v_code := '';
    for i in 0..7 loop
      v_code := v_code || substr(alphabet, (get_byte(v_bytes, i) % 32) + 1, 1);
    end loop;
    exit when not exists (select 1 from group_invites where group_invites.code = v_code);
  end loop;
  return v_code;
end $$;

-- Fixed-window rate limiter used by invite preview/join and comments.
create table rate_limit_hits (
  key          text        not null,
  window_start timestamptz not null,
  hits         int         not null default 0,
  primary key (key, window_start)
);

create or replace function check_rate_limit(p_key text, p_max int, p_window interval) returns void
language plpgsql volatile security definer set search_path = public as $$
declare
  v_window timestamptz := date_bin(p_window, now(), timestamptz '2000-01-01');
  v_hits int;
begin
  insert into rate_limit_hits (key, window_start, hits) values (p_key, v_window, 1)
  on conflict (key, window_start) do update set hits = rate_limit_hits.hits + 1
  returning hits into v_hits;
  if v_hits > p_max then
    raise exception using errcode = 'P0001', message = 'rate_limited';
  end if;
end $$;

-- Typed error helper: MESSAGE is the stable code the client maps to Arabic copy.
create or replace function fail(p_code text, p_detail jsonb default '{}'::jsonb) returns void
language plpgsql as $$
begin
  raise exception using errcode = 'P0001', message = p_code, detail = p_detail::text;
end $$;

-- ---------------------------------------------------------------------------
-- §2 tables
-- ---------------------------------------------------------------------------
create table users (
  id           uuid primary key,                     -- = auth.users.id
  display_name text not null default '' check (char_length(display_name) <= 60),
  avatar_path  text,
  locale       text not null default 'ar' check (locale in ('ar','en')),
  timezone     text not null default 'Asia/Kuwait',
  deleted_at   timestamptz,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);

create table devices (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null references users(id) on delete cascade,
  apns_token   text not null unique,
  platform     text not null default 'ios',
  app_version  text,
  locale       text,
  last_seen_at timestamptz not null default now(),
  created_at   timestamptz not null default now()
);
create index devices_user_idx on devices(user_id);

create table groups (
  id              uuid primary key default gen_random_uuid(),
  name            text not null check (char_length(name) between 1 and 80),
  type            group_type not null default 'other',
  owner_id        uuid not null references users(id),
  parent_group_id uuid references groups(id),        -- organisation stage (doc 01 §5)
  settings        jsonb not null default '{}'::jsonb,
  member_count    int  not null default 0,
  archived_at     timestamptz,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);
create index groups_owner_idx on groups(owner_id);

-- Effective group setting with product defaults (doc 06 §3, §6).
create or replace function group_setting(p_group uuid, p_key text) returns jsonb
language sql stable security definer set search_path = public as $$
  select coalesce(
    (select settings -> p_key from groups where id = p_group),
    case p_key
      when 'requires_approval_default'   then 'false'::jsonb
      when 'gamification_enabled'        then 'false'::jsonb
      when 'members_can_create_tasks'    then 'true'::jsonb
      when 'activity_visible_to_members' then 'true'::jsonb
      when 'stats_visibility' then
        case (select type from groups where id = p_group)
          when 'home' then '"private"'::jsonb
          when 'family' then '"private"'::jsonb
          else '"all"'::jsonb
        end
      else 'null'::jsonb
    end);
$$;

create table group_invites (
  id         uuid primary key default gen_random_uuid(),
  group_id   uuid not null references groups(id) on delete cascade,
  code       text not null unique,
  created_by uuid not null references users(id),
  created_at timestamptz not null default now(),
  expires_at timestamptz,
  revoked_at timestamptz,
  use_count  int not null default 0
);
create unique index group_invites_one_active on group_invites(group_id) where revoked_at is null;

create table join_requests (
  id         uuid primary key default gen_random_uuid(),
  group_id   uuid not null references groups(id) on delete cascade,
  user_id    uuid not null references users(id) on delete cascade,
  invite_id  uuid references group_invites(id),
  status     join_request_status not null default 'pending',
  message    text check (char_length(message) <= 300),
  decided_by uuid references users(id),
  decided_at timestamptz,
  created_at timestamptz not null default now()
);
create unique index join_requests_one_pending on join_requests(group_id, user_id) where status = 'pending';
create index join_requests_group_status_idx on join_requests(group_id, status);

create table memberships (
  id          uuid primary key default gen_random_uuid(),
  group_id    uuid not null references groups(id) on delete cascade,
  user_id     uuid not null references users(id) on delete cascade,
  role        membership_role   not null default 'member',
  status      membership_status not null default 'active',
  permissions jsonb not null default '{}'::jsonb,   -- per-admin overrides (doc 06 §2)
  joined_at   timestamptz not null default now(),
  left_at     timestamptz,
  unique (group_id, user_id)
);
create index memberships_user_active_idx on memberships(user_id) where status = 'active';
create unique index memberships_one_owner on memberships(group_id) where role = 'owner' and status = 'active';

create table recurrence_rules (                      -- Phase 2; present so no migration is needed
  id          uuid primary key default gen_random_uuid(),
  group_id    uuid references groups(id) on delete cascade,
  creator_id  uuid not null references users(id),
  template    jsonb not null,
  rrule       text  not null,
  timezone    text  not null default 'Asia/Kuwait',
  next_run_at timestamptz,
  last_run_at timestamptz,
  active      boolean not null default true,
  created_at  timestamptz not null default now()
);

create table tasks (
  id                        uuid primary key default gen_random_uuid(),
  group_id                  uuid references groups(id) on delete cascade,   -- null = personal
  creator_id                uuid not null references users(id),
  title                     text not null check (char_length(title) between 1 and 200),
  description               text check (char_length(description) <= 4000),
  status                    task_status     not null default 'new',
  priority                  task_priority   not null default 'normal',
  assignment_mode           assignment_mode not null default 'open',
  assignee_id               uuid references users(id),
  due_at                    timestamptz,
  due_date_only             boolean not null default false,
  points                    int check (points is null or points between 0 and 10000),
  requires_proof            boolean not null default false,
  proof_types               text[]  not null default '{photo,file,note}',
  requires_approval         boolean not null default false,
  parent_task_id            uuid references tasks(id) on delete cascade,
  auto_complete_on_subtasks boolean not null default true,
  recurrence_id             uuid references recurrence_rules(id) on delete set null,
  occurrence_key            text unique,
  claimed_at                timestamptz,
  started_at                timestamptz,
  submitted_at              timestamptz,
  completed_at              timestamptz,
  completed_by              uuid references users(id),
  approved_by               uuid references users(id),
  approved_at               timestamptz,
  cancelled_at              timestamptz,
  cancelled_by              uuid references users(id),
  version                   int not null default 1,
  search_text               text generated always as (normalize_ar(title || ' ' || coalesce(description, ''))) stored,
  created_at                timestamptz not null default now(),
  updated_at                timestamptz not null default now(),
  -- personal tasks are always self-assigned and never open
  constraint tasks_personal_self check (group_id is not null or (assignee_id = creator_id and assignment_mode = 'assigned')),
  -- open tasks in 'new' have no assignee; assigned tasks always have one
  constraint tasks_open_unassigned check (not (assignment_mode = 'open' and status = 'new' and assignee_id is not null)),
  constraint tasks_assigned_has_assignee check (not (assignment_mode = 'assigned' and assignee_id is null))
);
create index tasks_group_status_idx   on tasks(group_id, status);
create index tasks_assignee_idx       on tasks(assignee_id) where status in ('new','in_progress','awaiting_approval');
create index tasks_creator_idx        on tasks(creator_id);
create index tasks_due_idx            on tasks(due_at) where status in ('new','in_progress','awaiting_approval');
create index tasks_parent_idx         on tasks(parent_task_id);
create index tasks_search_trgm_idx    on tasks using gin (search_text gin_trgm_ops);

create table task_participants (
  task_id   uuid not null references tasks(id) on delete cascade,
  user_id   uuid not null references users(id) on delete cascade,
  joined_at timestamptz not null default now(),
  primary key (task_id, user_id)
);

create table task_attachments (
  id           uuid primary key default gen_random_uuid(),
  task_id      uuid not null references tasks(id) on delete cascade,
  uploader_id  uuid not null references users(id),
  storage_path text not null unique,
  mime         text not null,
  size_bytes   bigint not null check (size_bytes between 1 and 30 * 1024 * 1024),
  kind         attachment_kind not null default 'attachment',
  created_at   timestamptz not null default now()
);
create index task_attachments_task_idx on task_attachments(task_id);

create table task_comments (
  id         uuid primary key default gen_random_uuid(),
  task_id    uuid not null references tasks(id) on delete cascade,
  author_id  uuid not null references users(id),
  body       text not null check (char_length(body) between 1 and 2000),
  kind       text not null default 'comment' check (kind in ('comment','proof_note','rejection_reason','system')),
  created_at timestamptz not null default now(),
  edited_at  timestamptz,
  deleted_at timestamptz
);
create index task_comments_task_idx on task_comments(task_id, created_at);

create table activity_events (
  id          bigserial primary key,
  group_id    uuid references groups(id) on delete cascade,
  actor_id    uuid references users(id),
  action      text not null,
  target_type text not null,
  target_id   uuid,
  metadata    jsonb not null default '{}'::jsonb,
  created_at  timestamptz not null default now()
);
create index activity_events_group_idx  on activity_events(group_id, created_at desc);
create index activity_events_target_idx on activity_events(target_type, target_id);

create table notifications (
  id              uuid primary key default gen_random_uuid(),
  user_id         uuid not null references users(id) on delete cascade,
  type            text not null,
  source_event_id bigint references activity_events(id) on delete set null,
  task_id         uuid references tasks(id) on delete cascade,
  group_id        uuid references groups(id) on delete cascade,
  actor_id        uuid references users(id),
  data            jsonb not null default '{}'::jsonb,
  read_at         timestamptz,
  created_at      timestamptz not null default now()
);
create index notifications_user_unread_idx on notifications(user_id, created_at desc) where read_at is null;
create index notifications_user_idx        on notifications(user_id, created_at desc);

create table notification_preferences (
  user_id uuid not null references users(id) on delete cascade,
  type    text not null,
  push    boolean not null default true,
  in_app  boolean not null default true,
  primary key (user_id, type)
);

create table notification_outbox (
  id              bigserial primary key,
  notification_id uuid not null references notifications(id) on delete cascade,
  device_id       uuid not null references devices(id) on delete cascade,
  collapse_key    text,
  status          outbox_status not null default 'pending',
  attempts        int not null default 0,
  next_attempt_at timestamptz not null default now(),
  last_error      text,
  created_at      timestamptz not null default now()
);
create index notification_outbox_pending_idx on notification_outbox(next_attempt_at) where status = 'pending';

create table task_reminders_sent (
  task_id   uuid not null references tasks(id) on delete cascade,
  threshold text not null,           -- 'due_24h' | 'due_1h' | 'overdue_1' | 'overdue_2' | 'overdue_3'
  sent_at   timestamptz not null default now(),
  primary key (task_id, threshold)
);

-- ---------------------------------------------------------------------------
-- §3 authorization helpers (doc 06)
-- ---------------------------------------------------------------------------
create or replace function is_active_member_of(p_user uuid, p_group uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from memberships where group_id = p_group and user_id = p_user and status = 'active');
$$;

create or replace function is_active_member(p_group uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select is_active_member_of(auth.uid(), p_group);
$$;

create or replace function member_role_of(p_user uuid, p_group uuid) returns membership_role
language sql stable security definer set search_path = public as $$
  select role from memberships where group_id = p_group and user_id = p_user and status = 'active';
$$;

create or replace function member_role(p_group uuid) returns membership_role
language sql stable security definer set search_path = public as $$
  select member_role_of(auth.uid(), p_group);
$$;

-- Resolution order: not member → false; owner → true; owner-only keys → false;
-- JSON override; task.create by group setting; role default (doc 06 §8).
create or replace function has_permission_for(p_user uuid, p_group uuid, p_key text) returns boolean
language plpgsql stable security definer set search_path = public as $$
declare
  v_role membership_role;
  v_override jsonb;
begin
  select role, permissions -> p_key into v_role, v_override
    from memberships where group_id = p_group and user_id = p_user and status = 'active';
  if v_role is null then return false; end if;
  if v_role = 'owner' then return true; end if;
  if p_key in ('group.transfer','group.archive') then return false; end if;
  if v_override is not null and jsonb_typeof(v_override) = 'boolean' then return (v_override)::boolean; end if;
  if p_key = 'task.create' then
    return v_role = 'admin' or (group_setting(p_group, 'members_can_create_tasks'))::boolean;
  end if;
  if p_key = 'activity.view' then
    return v_role = 'admin' or (group_setting(p_group, 'activity_visible_to_members'))::boolean;
  end if;
  if p_key = 'stats.view_all' then
    return v_role = 'admin' and group_setting(p_group, 'stats_visibility') #>> '{}' in ('admins','all')
        or group_setting(p_group, 'stats_visibility') #>> '{}' = 'all';
  end if;
  if v_role = 'admin' then
    return p_key in ('group.manage_settings','group.manage_members','group.approve_joins','group.manage_invite',
                     'task.assign_others','task.edit_any','task.cancel_any','task.approve_completion','comment.moderate');
  end if;
  return false;   -- member: nothing else
end $$;

create or replace function has_permission(p_group uuid, p_key text) returns boolean
language sql stable security definer set search_path = public as $$
  select has_permission_for(auth.uid(), p_group, p_key);
$$;

create or replace function members_with_permission(p_group uuid, p_key text) returns setof uuid
language sql stable security definer set search_path = public as $$
  select m.user_id from memberships m
   where m.group_id = p_group and m.status = 'active' and has_permission_for(m.user_id, p_group, p_key);
$$;

create or replace function can_view_task_as(p_user uuid, p_task uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from tasks t
     where t.id = p_task
       and ((t.group_id is null and t.creator_id = p_user)
         or (t.group_id is not null and is_active_member_of(p_user, t.group_id))));
$$;

create or replace function can_view_task(p_task uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select can_view_task_as(auth.uid(), p_task);
$$;

create or replace function require_uid() returns uuid
language plpgsql stable as $$
declare v uuid := auth.uid();
begin
  if v is null then perform fail('unauthenticated'); end if;
  return v;
end $$;

-- ---------------------------------------------------------------------------
-- §4 triggers
-- ---------------------------------------------------------------------------
create or replace function trg_set_updated_at() returns trigger language plpgsql as $$
begin new.updated_at := now(); return new; end $$;
create trigger users_updated_at  before update on users  for each row execute function trg_set_updated_at();
create trigger groups_updated_at before update on groups for each row execute function trg_set_updated_at();
create trigger tasks_updated_at  before update on tasks  for each row execute function trg_set_updated_at();

create or replace function trg_refresh_member_count() returns trigger language plpgsql security definer set search_path = public as $$
declare g uuid := coalesce(new.group_id, old.group_id);
begin
  update groups set member_count = (select count(*) from memberships where group_id = g and status = 'active') where id = g;
  return null;
end $$;
create trigger memberships_count after insert or update or delete on memberships for each row execute function trg_refresh_member_count();

-- activity log is append-only for everyone (doc 13 §T7)
create or replace function trg_deny_change() returns trigger language plpgsql as $$
begin raise exception using errcode = 'P0001', message = 'activity_log_immutable'; end $$;
create trigger activity_events_immutable before update or delete on activity_events for each row execute function trg_deny_change();

-- deadline change resets reminders (doc 12 §E23)
create or replace function trg_reset_reminders() returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.due_at is distinct from old.due_at then
    delete from task_reminders_sent where task_id = new.id;
  end if;
  return new;
end $$;
create trigger tasks_reset_reminders after update of due_at on tasks for each row execute function trg_reset_reminders();

-- subtask depth = 1 (doc 07 §6)
create or replace function trg_check_subtask_depth() returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.parent_task_id is not null then
    if exists (select 1 from tasks p where p.id = new.parent_task_id and p.parent_task_id is not null) then
      perform fail('subtask_depth_exceeded');
    end if;
    if exists (select 1 from tasks p where p.id = new.parent_task_id and p.group_id is distinct from new.group_id) then
      perform fail('subtask_group_mismatch');
    end if;
  end if;
  return new;
end $$;
create trigger tasks_subtask_depth before insert or update of parent_task_id on tasks for each row execute function trg_check_subtask_depth();

-- ---------------------------------------------------------------------------
-- §5 activity log + notification fan-out (doc 08)
-- ---------------------------------------------------------------------------
create or replace function log_event(p_group uuid, p_action text, p_target_type text, p_target_id uuid, p_metadata jsonb default '{}'::jsonb)
returns bigint language plpgsql volatile security definer set search_path = public as $$
declare v_id bigint;
begin
  insert into activity_events (group_id, actor_id, action, target_type, target_id, metadata)
  values (p_group, auth.uid(), p_action, p_target_type, p_target_id, coalesce(p_metadata, '{}'::jsonb))
  returning id into v_id;
  return v_id;
end $$;

-- One in-app row (unless in_app disabled) and one outbox row per device (unless push disabled).
create or replace function create_notification(p_user uuid, p_type text, p_task uuid, p_group uuid, p_actor uuid, p_event bigint, p_data jsonb default '{}'::jsonb)
returns void language plpgsql volatile security definer set search_path = public as $$
declare
  v_push boolean := true;
  v_nid uuid;
begin
  if p_user is null or p_user = p_actor then return; end if;        -- never notify the actor
  if exists (select 1 from users where id = p_user and deleted_at is not null) then return; end if;
  select push into v_push from notification_preferences where user_id = p_user and type = p_type;
  -- the in-app row is always written: it is the record (doc 08 §1); preferences only gate push
  insert into notifications (user_id, type, source_event_id, task_id, group_id, actor_id, data)
  values (p_user, p_type, p_event, p_task, p_group, p_actor, coalesce(p_data, '{}'::jsonb))
  returning id into v_nid;
  if coalesce(v_push, true) then
    insert into notification_outbox (notification_id, device_id, collapse_key)
    select v_nid, d.id, p_type || ':' || coalesce(p_group::text, 'personal')
      from devices d where d.user_id = p_user;
  end if;
end $$;

create or replace function trg_notify_fanout() returns trigger language plpgsql security definer set search_path = public as $$
declare
  t tasks%rowtype;
  r uuid;
  v_type text := new.action;
  v_data jsonb := new.metadata;
begin
  if new.target_type = 'task' then
    select * into t from tasks where id = new.target_id;
    v_data := v_data || jsonb_build_object('title', t.title);
  end if;

  case new.action
    when 'task.created' then
      if t.assignment_mode = 'assigned' then
        perform create_notification(t.assignee_id, 'task.assigned', t.id, t.group_id, new.actor_id, new.id, v_data);
      else
        for r in select user_id from memberships where group_id = t.group_id and status = 'active' loop
          perform create_notification(r, 'task.created', t.id, t.group_id, new.actor_id, new.id, v_data);
        end loop;
        for r in select user_id from task_participants where task_id = t.id loop
          perform create_notification(r, 'task.assigned', t.id, t.group_id, new.actor_id, new.id, v_data);
        end loop;
      end if;
    when 'task.claimed', 'task.released', 'task.completed', 'task.started' then
      if new.action <> 'task.started' then
        perform create_notification(t.creator_id, new.action, t.id, t.group_id, new.actor_id, new.id, v_data);
      end if;
    when 'task.submitted' then
      perform create_notification(t.creator_id, 'task.submitted', t.id, t.group_id, new.actor_id, new.id, v_data);
      for r in select * from members_with_permission(t.group_id, 'task.approve_completion') loop
        if r <> t.creator_id then
          perform create_notification(r, 'task.submitted', t.id, t.group_id, new.actor_id, new.id, v_data);
        end if;
      end loop;
    when 'task.approved', 'task.rejected', 'task.cancelled', 'task.reopened' then
      perform create_notification(t.assignee_id, new.action, t.id, t.group_id, new.actor_id, new.id, v_data);
    when 'task.reassigned' then
      perform create_notification((v_data ->> 'old_assignee_id')::uuid, 'task.reassigned', t.id, t.group_id, new.actor_id, new.id, v_data);
      perform create_notification((v_data ->> 'new_assignee_id')::uuid, 'task.assigned',   t.id, t.group_id, new.actor_id, new.id, v_data);
    when 'task.unassigned' then
      perform create_notification((v_data ->> 'old_assignee_id')::uuid, 'task.unassigned', t.id, t.group_id, new.actor_id, new.id, v_data);
      perform create_notification(t.creator_id, 'task.unassigned', t.id, t.group_id, new.actor_id, new.id, v_data);
    when 'task.updated' then
      if v_data ? 'due_at' or v_data ? 'priority' then
        perform create_notification(t.assignee_id, 'task.updated', t.id, t.group_id, new.actor_id, new.id, v_data);
      end if;
    when 'task.comment' then
      for r in
        select distinct u from (
          select t.creator_id as u union select t.assignee_id
          union select user_id from task_participants where task_id = t.id
          union select author_id from task_comments where task_id = t.id and kind = 'comment' and deleted_at is null
        ) s where u is not null
      loop
        perform create_notification(r, 'task.comment', t.id, t.group_id, new.actor_id, new.id, v_data);
      end loop;
    when 'join.requested' then
      for r in select * from members_with_permission(new.group_id, 'group.approve_joins') loop
        perform create_notification(r, 'join.requested', null, new.group_id, new.actor_id, new.id, v_data);
      end loop;
    when 'join.accepted', 'join.rejected', 'member.removed', 'member.role_changed' then
      perform create_notification((v_data ->> 'user_id')::uuid, new.action, null, new.group_id, new.actor_id, new.id, v_data);
    when 'group.ownership_transferred' then
      perform create_notification((v_data ->> 'new_owner_id')::uuid, new.action, null, new.group_id, new.actor_id, new.id, v_data);
      for r in select user_id from memberships where group_id = new.group_id and status = 'active' and role = 'admin' loop
        perform create_notification(r, new.action, null, new.group_id, new.actor_id, new.id, v_data);
      end loop;
    else
      null;  -- group.created, task.updated (other fields), etc.: recorded, not notified
  end case;
  return null;
end $$;
create trigger activity_events_fanout after insert on activity_events for each row execute function trg_notify_fanout();

-- Comments are inserted directly under RLS; the event (and fan-out) comes from this trigger.
create or replace function trg_comment_event() returns trigger language plpgsql security definer set search_path = public as $$
declare g uuid;
begin
  if new.kind = 'comment' then
    select group_id into g from tasks where id = new.task_id;
    perform log_event(g, 'task.comment', 'task', new.task_id, jsonb_build_object('comment_id', new.id, 'excerpt', left(new.body, 80)));
  end if;
  return null;
end $$;
create trigger task_comments_event after insert on task_comments for each row execute function trg_comment_event();

-- Parent auto-completion (doc 07 §6)
create or replace function trg_subtask_completed() returns trigger language plpgsql security definer set search_path = public as $$
declare p tasks%rowtype;
begin
  if new.parent_task_id is null or new.status <> 'completed' or old.status = 'completed' then return null; end if;
  select * into p from tasks where id = new.parent_task_id for update;
  if p.auto_complete_on_subtasks and p.status in ('new','in_progress')
     and not exists (select 1 from tasks s where s.parent_task_id = p.id and s.status not in ('completed','cancelled')) then
    update tasks set status = 'completed', completed_at = now(), completed_by = new.completed_by, version = version + 1 where id = p.id;
    perform log_event(p.group_id, 'task.completed', 'task', p.id, jsonb_build_object('via', 'subtasks'));
  end if;
  return null;
end $$;
create trigger tasks_subtask_completed after update of status on tasks for each row execute function trg_subtask_completed();

-- Profile row for every auth user (Supabase). Guarded: auth.users may not exist locally.
create or replace function handle_new_auth_user() returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into users (id, display_name)
  values (new.id, coalesce(new.raw_user_meta_data ->> 'full_name', new.raw_user_meta_data ->> 'name', ''))
  on conflict (id) do nothing;
  return new;
end $$;
do $$
begin
  if to_regclass('auth.users') is not null then
    execute 'create trigger on_auth_user_created after insert on auth.users for each row execute function public.handle_new_auth_user()';
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- §6 RPC — identity
-- ---------------------------------------------------------------------------
create or replace function complete_profile(p_display_name text, p_avatar_path text default null, p_locale text default null, p_timezone text default null)
returns users language plpgsql volatile security definer set search_path = public as $$
declare v_uid uuid := require_uid(); r users;
begin
  if coalesce(btrim(p_display_name), '') = '' then perform fail('display_name_required'); end if;
  update users set display_name = btrim(p_display_name),
                   avatar_path  = coalesce(p_avatar_path, avatar_path),
                   locale       = coalesce(p_locale, locale),
                   timezone     = coalesce(p_timezone, timezone)
   where id = v_uid returning * into r;
  if r.id is null then perform fail('profile_missing'); end if;
  return r;
end $$;

create or replace function register_device(p_apns_token text, p_platform text default 'ios', p_app_version text default null, p_locale text default null)
returns uuid language plpgsql volatile security definer set search_path = public as $$
declare v_uid uuid := require_uid(); v_id uuid;
begin
  insert into devices (user_id, apns_token, platform, app_version, locale)
  values (v_uid, p_apns_token, p_platform, p_app_version, p_locale)
  on conflict (apns_token) do update
    set user_id = excluded.user_id, platform = excluded.platform, app_version = excluded.app_version,
        locale = excluded.locale, last_seen_at = now()
  returning id into v_id;
  return v_id;
end $$;

create or replace function unregister_device(p_apns_token text) returns void
language sql volatile security definer set search_path = public as $$
  delete from devices where apns_token = p_apns_token and user_id = auth.uid();
$$;

create or replace function delete_account() returns void
language plpgsql volatile security definer set search_path = public as $$
declare v_uid uuid := require_uid();
begin
  if exists (select 1 from groups g where g.owner_id = v_uid and g.archived_at is null
              and exists (select 1 from memberships m where m.group_id = g.id and m.status = 'active' and m.user_id <> v_uid)) then
    perform fail('owner_must_transfer');
  end if;
  update groups set archived_at = now() where owner_id = v_uid and archived_at is null;
  delete from devices where user_id = v_uid;
  delete from tasks where group_id is null and creator_id = v_uid;
  delete from notifications where user_id = v_uid;
  delete from notification_preferences where user_id = v_uid;
  update join_requests set status = 'cancelled' where user_id = v_uid and status = 'pending';
  update memberships set status = 'left', left_at = now() where user_id = v_uid and status = 'active';
  update tasks set assignee_id = null, status = 'new', assignment_mode = 'open', version = version + 1
   where assignee_id = v_uid and status in ('new','in_progress') and group_id is not null;
  update users set display_name = 'عضو سابق', avatar_path = null, deleted_at = now() where id = v_uid;
  if to_regclass('auth.users') is not null then
    execute 'delete from auth.users where id = $1' using v_uid;
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- §6 RPC — groups and invitations
-- ---------------------------------------------------------------------------
create or replace function create_group(p_name text, p_type group_type default 'other', p_settings jsonb default '{}'::jsonb)
returns jsonb language plpgsql volatile security definer set search_path = public as $$
declare v_uid uuid := require_uid(); v_gid uuid; v_code text;
begin
  insert into groups (name, type, owner_id, settings) values (btrim(p_name), p_type, v_uid, coalesce(p_settings, '{}'::jsonb)) returning id into v_gid;
  insert into memberships (group_id, user_id, role) values (v_gid, v_uid, 'owner');
  v_code := gen_invite_code();
  insert into group_invites (group_id, code, created_by) values (v_gid, v_code, v_uid);
  perform log_event(v_gid, 'group.created', 'group', v_gid, jsonb_build_object('name', btrim(p_name), 'type', p_type));
  return jsonb_build_object('group_id', v_gid, 'invite_code', v_code);
end $$;

create or replace function update_group_settings(p_group uuid, p_name text default null, p_type group_type default null, p_settings jsonb default null)
returns groups language plpgsql volatile security definer set search_path = public as $$
declare r groups;
begin
  perform require_uid();
  if not has_permission(p_group, 'group.manage_settings') then perform fail('permission_denied'); end if;
  update groups set name = coalesce(btrim(p_name), name), type = coalesce(p_type, type),
                    settings = case when p_settings is null then settings else settings || p_settings end
   where id = p_group and archived_at is null returning * into r;
  if r.id is null then perform fail('invalid_transition'); end if;
  perform log_event(p_group, 'group.updated', 'group', p_group, coalesce(p_settings, '{}'::jsonb));
  return r;
end $$;

create or replace function regenerate_invite(p_group uuid) returns text
language plpgsql volatile security definer set search_path = public as $$
declare v_uid uuid := require_uid(); v_code text;
begin
  if not has_permission(p_group, 'group.manage_invite') then perform fail('permission_denied'); end if;
  update group_invites set revoked_at = now() where group_id = p_group and revoked_at is null;
  v_code := gen_invite_code();
  insert into group_invites (group_id, code, created_by) values (p_group, v_code, v_uid);
  perform log_event(p_group, 'invite.regenerated', 'group', p_group);
  return v_code;
end $$;

create or replace function revoke_invite(p_group uuid) returns void
language plpgsql volatile security definer set search_path = public as $$
begin
  perform require_uid();
  if not has_permission(p_group, 'group.manage_invite') then perform fail('permission_denied'); end if;
  update group_invites set revoked_at = now() where group_id = p_group and revoked_at is null;
  perform log_event(p_group, 'invite.revoked', 'group', p_group);
end $$;

create or replace function find_active_invite(p_code text) returns group_invites
language sql stable security definer set search_path = public as $$
  select i.* from group_invites i join groups g on g.id = i.group_id
   where i.code = upper(btrim(p_code)) and i.revoked_at is null
     and (i.expires_at is null or i.expires_at > now()) and g.archived_at is null;
$$;

create or replace function preview_invite(p_code text) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare v_uid uuid := require_uid(); i group_invites; g groups;
begin
  perform check_rate_limit('invite:' || v_uid::text, 10, interval '10 minutes');
  i := find_active_invite(p_code);
  if i.id is null then perform fail('invalid_invite'); end if;
  select * into g from groups where id = i.group_id;
  return jsonb_build_object('group_name', g.name, 'group_type', g.type, 'member_count', g.member_count,
                            'already_member', is_active_member_of(v_uid, g.id),
                            'pending', exists (select 1 from join_requests where group_id = g.id and user_id = v_uid and status = 'pending'));
end $$;

create or replace function request_join(p_code text, p_message text default null) returns join_requests
language plpgsql volatile security definer set search_path = public as $$
declare v_uid uuid := require_uid(); i group_invites; r join_requests;
begin
  perform check_rate_limit('invite:' || v_uid::text, 10, interval '10 minutes');
  i := find_active_invite(p_code);
  if i.id is null then perform fail('invalid_invite'); end if;
  if is_active_member_of(v_uid, i.group_id) then perform fail('already_member'); end if;
  select * into r from join_requests where group_id = i.group_id and user_id = v_uid and status = 'pending';
  if r.id is not null then return r; end if;                              -- idempotent (doc 12 §E16)
  insert into join_requests (group_id, user_id, invite_id, message) values (i.group_id, v_uid, i.id, p_message) returning * into r;
  update group_invites set use_count = use_count + 1 where id = i.id;
  perform log_event(i.group_id, 'join.requested', 'join_request', r.id, jsonb_build_object('user_id', v_uid));
  return r;
end $$;

create or replace function cancel_join_request(p_request uuid) returns void
language plpgsql volatile security definer set search_path = public as $$
declare v_uid uuid := require_uid();
begin
  update join_requests set status = 'cancelled', decided_at = now() where id = p_request and user_id = v_uid and status = 'pending';
  if not found then perform fail('invalid_transition'); end if;
end $$;

create or replace function decide_join(p_request uuid, p_accept boolean) returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare v_uid uuid := require_uid(); r join_requests; m memberships;
begin
  select * into r from join_requests where id = p_request for update;
  if r.id is null then perform fail('not_found'); end if;
  if not has_permission(r.group_id, 'group.approve_joins') then perform fail('permission_denied'); end if;
  if r.status <> 'pending' then perform fail('invalid_transition'); end if;
  if exists (select 1 from groups where id = r.group_id and archived_at is not null) then perform fail('invalid_transition'); end if;
  if exists (select 1 from users where id = r.user_id and deleted_at is not null) then
    update join_requests set status = 'cancelled', decided_at = now() where id = r.id;
    perform fail('invalid_transition');
  end if;
  if p_accept then
    insert into memberships (group_id, user_id, role, status, permissions, joined_at, left_at)
    values (r.group_id, r.user_id, 'member', 'active', '{}'::jsonb, now(), null)
    on conflict (group_id, user_id) do update
      set role = 'member', status = 'active', permissions = '{}'::jsonb, joined_at = now(), left_at = null
    returning * into m;
    update join_requests set status = 'accepted', decided_by = v_uid, decided_at = now() where id = r.id;
    perform log_event(r.group_id, 'join.accepted', 'join_request', r.id, jsonb_build_object('user_id', r.user_id));
    return jsonb_build_object('membership_id', m.id, 'status', 'accepted');
  else
    update join_requests set status = 'rejected', decided_by = v_uid, decided_at = now() where id = r.id;
    perform log_event(r.group_id, 'join.rejected', 'join_request', r.id, jsonb_build_object('user_id', r.user_id));
    return jsonb_build_object('status', 'rejected');
  end if;
end $$;

-- Release every open/in-progress task held by a user in a group (doc 12 §E7/E8).
create or replace function release_tasks_of(p_group uuid, p_user uuid) returns void
language plpgsql volatile security definer set search_path = public as $$
declare t record;
begin
  for t in select id from tasks where group_id = p_group and assignee_id = p_user and status in ('new','in_progress') loop
    update tasks set assignee_id = null, status = 'new', assignment_mode = 'open', claimed_at = null, started_at = null, version = version + 1 where id = t.id;
    perform log_event(p_group, 'task.unassigned', 'task', t.id, jsonb_build_object('old_assignee_id', p_user, 'reason', 'member_left'));
  end loop;
end $$;

create or replace function set_member_role(p_group uuid, p_user uuid, p_role membership_role, p_permissions jsonb default null)
returns memberships language plpgsql volatile security definer set search_path = public as $$
declare v_uid uuid := require_uid(); v_caller membership_role; v_target membership_role; m memberships;
begin
  v_caller := member_role_of(v_uid, p_group);
  if not has_permission(p_group, 'group.manage_members') then perform fail('permission_denied'); end if;
  if p_role = 'owner' then perform fail('use_transfer_ownership'); end if;
  v_target := member_role_of(p_user, p_group);
  if v_target is null then perform fail('not_a_member'); end if;
  if v_target = 'owner' then perform fail('permission_denied'); end if;
  if v_caller = 'admin' and (v_target = 'admin' or p_user = v_uid) then perform fail('permission_denied'); end if;  -- admins never touch admins
  update memberships set role = p_role, permissions = coalesce(p_permissions, case when p_role = 'member' then '{}'::jsonb else permissions end)
   where group_id = p_group and user_id = p_user and status = 'active' returning * into m;
  perform log_event(p_group, 'member.role_changed', 'membership', m.id, jsonb_build_object('user_id', p_user, 'role', p_role));
  return m;
end $$;

create or replace function remove_member(p_group uuid, p_user uuid) returns void
language plpgsql volatile security definer set search_path = public as $$
declare v_uid uuid := require_uid(); v_caller membership_role; v_target membership_role; v_mid uuid;
begin
  v_caller := member_role_of(v_uid, p_group);
  if not has_permission(p_group, 'group.manage_members') then perform fail('permission_denied'); end if;
  v_target := member_role_of(p_user, p_group);
  if v_target is null then perform fail('not_a_member'); end if;
  if v_target = 'owner' or p_user = v_uid then perform fail('permission_denied'); end if;
  if v_caller = 'admin' and v_target = 'admin' then perform fail('permission_denied'); end if;
  update memberships set status = 'removed', left_at = now(), permissions = '{}'::jsonb
   where group_id = p_group and user_id = p_user and status = 'active' returning id into v_mid;
  perform release_tasks_of(p_group, p_user);
  perform log_event(p_group, 'member.removed', 'membership', v_mid, jsonb_build_object('user_id', p_user));
end $$;

create or replace function leave_group(p_group uuid) returns void
language plpgsql volatile security definer set search_path = public as $$
declare v_uid uuid := require_uid(); v_role membership_role; v_mid uuid;
begin
  v_role := member_role_of(v_uid, p_group);
  if v_role is null then perform fail('not_a_member'); end if;
  if v_role = 'owner' then perform fail('owner_must_transfer'); end if;
  update memberships set status = 'left', left_at = now(), permissions = '{}'::jsonb
   where group_id = p_group and user_id = v_uid and status = 'active' returning id into v_mid;
  perform release_tasks_of(p_group, v_uid);
  perform log_event(p_group, 'member.left', 'membership', v_mid, jsonb_build_object('user_id', v_uid));
end $$;

create or replace function transfer_ownership(p_group uuid, p_to_user uuid) returns void
language plpgsql volatile security definer set search_path = public as $$
declare v_uid uuid := require_uid();
begin
  if member_role_of(v_uid, p_group) is distinct from 'owner' then perform fail('permission_denied'); end if;
  if not is_active_member_of(p_to_user, p_group) then perform fail('not_a_member'); end if;
  if p_to_user = v_uid then return; end if;
  update memberships set role = 'admin' where group_id = p_group and user_id = v_uid and status = 'active';
  update memberships set role = 'owner', permissions = '{}'::jsonb where group_id = p_group and user_id = p_to_user and status = 'active';
  update groups set owner_id = p_to_user where id = p_group;
  perform log_event(p_group, 'group.ownership_transferred', 'group', p_group, jsonb_build_object('new_owner_id', p_to_user, 'old_owner_id', v_uid));
end $$;

create or replace function archive_group(p_group uuid) returns void
language plpgsql volatile security definer set search_path = public as $$
begin
  perform require_uid();
  if not has_permission(p_group, 'group.archive') then perform fail('permission_denied'); end if;
  update groups set archived_at = now() where id = p_group and archived_at is null;
  update group_invites set revoked_at = now() where group_id = p_group and revoked_at is null;
  update join_requests set status = 'cancelled', decided_at = now() where group_id = p_group and status = 'pending';
  perform log_event(p_group, 'group.archived', 'group', p_group);
end $$;

-- ---------------------------------------------------------------------------
-- §6 RPC — tasks (transitions T1–T13, doc 07)
-- ---------------------------------------------------------------------------
create or replace function get_task_for_update(p_task uuid) returns tasks
language plpgsql volatile security definer set search_path = public as $$
declare t tasks;
begin
  select * into t from tasks where id = p_task for update;
  if t.id is null then perform fail('not_found'); end if;
  if t.group_id is not null and not is_active_member(t.group_id) then perform fail('not_a_member'); end if;
  if t.group_id is null and t.creator_id <> auth.uid() then perform fail('not_found'); end if;
  return t;
end $$;

create or replace function create_task(
  p_title text, p_group_id uuid default null, p_description text default null,
  p_assignment_mode assignment_mode default 'open', p_assignee_id uuid default null,
  p_due_at timestamptz default null, p_due_date_only boolean default false,
  p_priority task_priority default 'normal', p_points int default null,
  p_requires_proof boolean default false, p_proof_types text[] default '{photo,file,note}',
  p_requires_approval boolean default null, p_parent_task_id uuid default null,
  p_participant_ids uuid[] default '{}')
returns tasks language plpgsql volatile security definer set search_path = public as $$
declare
  v_uid uuid := require_uid();
  v_mode assignment_mode := p_assignment_mode;
  v_assignee uuid := p_assignee_id;
  v_approval boolean := p_requires_approval;
  v_status task_status := 'new';
  t tasks; p uuid;
begin
  if p_group_id is null then                                  -- personal task
    v_mode := 'assigned'; v_assignee := v_uid; v_approval := false;
  else
    if not is_active_member(p_group_id) then perform fail('not_a_member'); end if;
    if exists (select 1 from groups where id = p_group_id and archived_at is not null) then perform fail('group_archived'); end if;
    if not has_permission(p_group_id, 'task.create') then perform fail('permission_denied'); end if;
    if v_mode = 'assigned' then
      if v_assignee is null then perform fail('assignee_required'); end if;
      if not is_active_member_of(v_assignee, p_group_id) then perform fail('assignee_not_member'); end if;
      if v_assignee <> v_uid and not has_permission(p_group_id, 'task.assign_others') then perform fail('permission_denied'); end if;
    else
      v_assignee := null;
    end if;
    if v_approval is null then v_approval := (group_setting(p_group_id, 'requires_approval_default'))::boolean; end if;
    foreach p in array coalesce(p_participant_ids, '{}'::uuid[]) loop
      if not is_active_member_of(p, p_group_id) then perform fail('participant_not_member'); end if;
    end loop;
  end if;

  insert into tasks (group_id, creator_id, title, description, status, priority, assignment_mode, assignee_id,
                     due_at, due_date_only, points, requires_proof, proof_types, requires_approval, parent_task_id)
  values (p_group_id, v_uid, btrim(p_title), nullif(btrim(p_description), ''), v_status, p_priority, v_mode, v_assignee,
          p_due_at, coalesce(p_due_date_only, false), p_points, coalesce(p_requires_proof, false),
          coalesce(p_proof_types, '{photo,file,note}'), coalesce(v_approval, false), p_parent_task_id)
  returning * into t;

  if v_mode = 'collaborative' then
    insert into task_participants (task_id, user_id)
    select t.id, unnest(coalesce(p_participant_ids, '{}'::uuid[])) on conflict do nothing;
  end if;

  if p_group_id is not null then
    perform log_event(p_group_id, 'task.created', 'task', t.id,
      jsonb_build_object('assignment_mode', v_mode, 'assignee_id', v_assignee, 'parent_task_id', p_parent_task_id));
  end if;
  return t;
end $$;

-- T2: the atomic claim (doc 07 §4)
create or replace function claim_task(p_task uuid) returns tasks
language plpgsql volatile security definer set search_path = public as $$
declare v_uid uuid := require_uid(); t tasks; v_gid uuid; v_claimer text;
begin
  select group_id into v_gid from tasks where id = p_task;
  if v_gid is null then perform fail('not_found'); end if;
  if not is_active_member(v_gid) then perform fail('not_a_member'); end if;

  update tasks
     set assignee_id = v_uid, status = 'in_progress', claimed_at = now(), started_at = now(), version = version + 1
   where id = p_task and status = 'new' and assignment_mode = 'open' and assignee_id is null
  returning * into t;

  if t.id is null then
    select * into t from tasks where id = p_task;
    if t.assignee_id = v_uid and t.status = 'in_progress' then return t; end if;    -- idempotent (doc 12 §E2)
    if t.assignee_id is not null and t.status in ('new','in_progress') then
      select display_name into v_claimer from users where id = t.assignee_id;
      perform fail('already_claimed', jsonb_build_object('assignee_id', t.assignee_id, 'assignee_name', v_claimer));
    end if;
    perform fail('invalid_transition', jsonb_build_object('status', t.status));
  end if;
  perform log_event(t.group_id, 'task.claimed', 'task', t.id);
  return t;
end $$;

-- T3
create or replace function start_task(p_task uuid) returns tasks
language plpgsql volatile security definer set search_path = public as $$
declare v_uid uuid := require_uid(); t tasks;
begin
  t := get_task_for_update(p_task);
  if t.assignee_id is distinct from v_uid then perform fail('permission_denied'); end if;
  if t.status <> 'new' then perform fail('invalid_transition', jsonb_build_object('status', t.status)); end if;
  update tasks set status = 'in_progress', started_at = now(), version = version + 1 where id = t.id returning * into t;
  if t.group_id is not null then perform log_event(t.group_id, 'task.started', 'task', t.id); end if;
  return t;
end $$;

-- T8
create or replace function release_task(p_task uuid) returns tasks
language plpgsql volatile security definer set search_path = public as $$
declare v_uid uuid := require_uid(); t tasks;
begin
  t := get_task_for_update(p_task);
  if t.group_id is null then perform fail('invalid_transition'); end if;
  if t.assignee_id is distinct from v_uid then perform fail('permission_denied'); end if;
  if t.status not in ('new','in_progress') then perform fail('invalid_transition', jsonb_build_object('status', t.status)); end if;
  update tasks set assignee_id = null, status = 'new', assignment_mode = 'open', claimed_at = null, started_at = null, version = version + 1
   where id = t.id returning * into t;
  perform log_event(t.group_id, 'task.released', 'task', t.id, jsonb_build_object('old_assignee_id', v_uid));
  return t;
end $$;

-- T9
create or replace function reassign_task(p_task uuid, p_assignee uuid) returns tasks
language plpgsql volatile security definer set search_path = public as $$
declare v_uid uuid := require_uid(); t tasks; v_old uuid;
begin
  t := get_task_for_update(p_task);
  if t.group_id is null then perform fail('invalid_transition'); end if;
  if not (t.creator_id = v_uid or has_permission(t.group_id, 'task.assign_others')) then perform fail('permission_denied'); end if;
  if not is_active_member_of(p_assignee, t.group_id) then perform fail('assignee_not_member'); end if;
  if t.status not in ('new','in_progress') then perform fail('invalid_transition', jsonb_build_object('status', t.status)); end if;
  v_old := t.assignee_id;
  update tasks set assignee_id = p_assignee, status = 'new', assignment_mode = 'assigned', claimed_at = null, started_at = null, version = version + 1
   where id = t.id returning * into t;
  perform log_event(t.group_id, 'task.reassigned', 'task', t.id, jsonb_build_object('old_assignee_id', v_old, 'new_assignee_id', p_assignee));
  return t;
end $$;

-- T10
create or replace function unassign_task(p_task uuid) returns tasks
language plpgsql volatile security definer set search_path = public as $$
declare v_uid uuid := require_uid(); t tasks; v_old uuid;
begin
  t := get_task_for_update(p_task);
  if t.group_id is null then perform fail('invalid_transition'); end if;
  if not (t.creator_id = v_uid or has_permission(t.group_id, 'task.assign_others')) then perform fail('permission_denied'); end if;
  if t.status not in ('new','in_progress') or t.assignee_id is null then perform fail('invalid_transition', jsonb_build_object('status', t.status)); end if;
  v_old := t.assignee_id;
  update tasks set assignee_id = null, status = 'new', assignment_mode = 'open', claimed_at = null, started_at = null, version = version + 1
   where id = t.id returning * into t;
  perform log_event(t.group_id, 'task.unassigned', 'task', t.id, jsonb_build_object('old_assignee_id', v_old));
  return t;
end $$;

-- T4 / T5
create or replace function complete_task(p_task uuid, p_note text default null) returns tasks
language plpgsql volatile security definer set search_path = public as $$
declare v_uid uuid := require_uid(); t tasks; v_has_proof boolean; v_needs_approval boolean;
begin
  t := get_task_for_update(p_task);
  if t.assignee_id is distinct from v_uid then perform fail('permission_denied'); end if;
  if t.status not in ('new','in_progress') then perform fail('invalid_transition', jsonb_build_object('status', t.status)); end if;

  if t.requires_proof then
    v_has_proof := exists (select 1 from task_attachments a where a.task_id = t.id and a.kind = 'proof' and a.uploader_id = v_uid)
                   or (coalesce(btrim(p_note), '') <> '' and 'note' = any (t.proof_types));
    if not v_has_proof then perform fail('proof_required', jsonb_build_object('proof_types', t.proof_types)); end if;
  end if;
  if coalesce(btrim(p_note), '') <> '' then
    insert into task_comments (task_id, author_id, body, kind) values (t.id, v_uid, btrim(p_note), 'proof_note');
  end if;

  -- approval only if someone other than the assignee can approve (doc 06 §4, doc 12 §E42)
  v_needs_approval := t.group_id is not null and t.requires_approval and (
      t.creator_id <> v_uid
      or exists (select 1 from members_with_permission(t.group_id, 'task.approve_completion') u where u <> v_uid));

  if v_needs_approval then
    update tasks set status = 'awaiting_approval', submitted_at = now(), version = version + 1 where id = t.id returning * into t;
    perform log_event(t.group_id, 'task.submitted', 'task', t.id);
  else
    update tasks set status = 'completed', completed_at = now(), completed_by = v_uid, version = version + 1 where id = t.id returning * into t;
    if t.group_id is not null then perform log_event(t.group_id, 'task.completed', 'task', t.id, jsonb_build_object('late', t.due_at is not null and t.completed_at > t.due_at)); end if;
  end if;
  return t;
end $$;

create or replace function can_approve(t tasks, p_user uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select t.group_id is not null and p_user <> t.assignee_id
     and (t.creator_id = p_user or has_permission_for(p_user, t.group_id, 'task.approve_completion'));
$$;

-- T6
create or replace function approve_completion(p_task uuid) returns tasks
language plpgsql volatile security definer set search_path = public as $$
declare v_uid uuid := require_uid(); t tasks;
begin
  t := get_task_for_update(p_task);
  if t.status <> 'awaiting_approval' then perform fail('invalid_transition', jsonb_build_object('status', t.status)); end if;
  if not can_approve(t, v_uid) then perform fail('permission_denied'); end if;
  update tasks set status = 'completed', completed_at = now(), completed_by = assignee_id, approved_by = v_uid, approved_at = now(), version = version + 1
   where id = t.id returning * into t;
  perform log_event(t.group_id, 'task.approved', 'task', t.id, jsonb_build_object('late', t.due_at is not null and t.submitted_at > t.due_at));
  return t;
end $$;

-- T7
create or replace function reject_completion(p_task uuid, p_reason text) returns tasks
language plpgsql volatile security definer set search_path = public as $$
declare v_uid uuid := require_uid(); t tasks;
begin
  if coalesce(btrim(p_reason), '') = '' then perform fail('reason_required'); end if;
  t := get_task_for_update(p_task);
  if t.status <> 'awaiting_approval' then perform fail('invalid_transition', jsonb_build_object('status', t.status)); end if;
  if not can_approve(t, v_uid) then perform fail('permission_denied'); end if;
  update tasks set status = 'in_progress', submitted_at = null, version = version + 1 where id = t.id returning * into t;
  insert into task_comments (task_id, author_id, body, kind) values (t.id, v_uid, btrim(p_reason), 'rejection_reason');
  perform log_event(t.group_id, 'task.rejected', 'task', t.id, jsonb_build_object('reason', left(btrim(p_reason), 200)));
  return t;
end $$;

-- T11 (cascades to subtasks)
create or replace function cancel_task(p_task uuid, p_reason text default null) returns tasks
language plpgsql volatile security definer set search_path = public as $$
declare v_uid uuid := require_uid(); t tasks; s record;
begin
  t := get_task_for_update(p_task);
  if not (t.creator_id = v_uid or (t.group_id is not null and has_permission(t.group_id, 'task.cancel_any'))) then perform fail('permission_denied'); end if;
  if t.status in ('completed','cancelled') then perform fail('invalid_transition', jsonb_build_object('status', t.status)); end if;
  for s in select id from tasks where parent_task_id = t.id and status not in ('completed','cancelled') loop
    update tasks set status = 'cancelled', cancelled_at = now(), cancelled_by = v_uid, version = version + 1 where id = s.id;
    if t.group_id is not null then perform log_event(t.group_id, 'task.cancelled', 'task', s.id, jsonb_build_object('via', 'parent')); end if;
  end loop;
  update tasks set status = 'cancelled', cancelled_at = now(), cancelled_by = v_uid, version = version + 1 where id = t.id returning * into t;
  if t.group_id is not null then perform log_event(t.group_id, 'task.cancelled', 'task', t.id, jsonb_build_object('reason', left(coalesce(p_reason, ''), 200))); end if;
  return t;
end $$;

-- T12
create or replace function reopen_task(p_task uuid) returns tasks
language plpgsql volatile security definer set search_path = public as $$
declare v_uid uuid := require_uid(); t tasks; v_keep boolean;
begin
  t := get_task_for_update(p_task);
  if not (t.creator_id = v_uid or (t.group_id is not null and has_permission(t.group_id, 'task.edit_any'))) then perform fail('permission_denied'); end if;
  if t.status <> 'completed' or t.completed_at < now() - interval '30 days' then perform fail('invalid_transition', jsonb_build_object('status', t.status)); end if;
  v_keep := t.assignee_id is not null and (t.group_id is null or is_active_member_of(t.assignee_id, t.group_id));   -- doc 12 §E27
  update tasks
     set status = case when v_keep then 'in_progress'::task_status else 'new'::task_status end,
         assignee_id = case when v_keep then assignee_id else null end,
         assignment_mode = case when v_keep then assignment_mode else 'open'::assignment_mode end,
         completed_at = null, completed_by = null, approved_by = null, approved_at = null, submitted_at = null, version = version + 1
   where id = t.id returning * into t;
  if t.group_id is not null then perform log_event(t.group_id, 'task.reopened', 'task', t.id); end if;
  return t;
end $$;

-- T13 with optimistic locking
create or replace function update_task(p_task uuid, p_patch jsonb, p_version int) returns tasks
language plpgsql volatile security definer set search_path = public as $$
declare v_uid uuid := require_uid(); t tasks;
begin
  t := get_task_for_update(p_task);
  if not (t.creator_id = v_uid or (t.group_id is not null and has_permission(t.group_id, 'task.edit_any'))) then perform fail('permission_denied'); end if;
  if t.status in ('completed','cancelled') then perform fail('invalid_transition', jsonb_build_object('status', t.status)); end if;
  if t.version <> p_version then perform fail('stale_version', jsonb_build_object('version', t.version)); end if;
  if t.status = 'awaiting_approval' and p_patch ? 'requires_approval' then perform fail('invalid_transition'); end if;
  update tasks set
    title             = coalesce(nullif(btrim(p_patch ->> 'title'), ''), title),
    description       = case when p_patch ? 'description' then nullif(btrim(p_patch ->> 'description'), '') else description end,
    due_at            = case when p_patch ? 'due_at' then (p_patch ->> 'due_at')::timestamptz else due_at end,
    due_date_only     = coalesce((p_patch ->> 'due_date_only')::boolean, due_date_only),
    priority          = coalesce((p_patch ->> 'priority')::task_priority, priority),
    points            = case when p_patch ? 'points' then (p_patch ->> 'points')::int else points end,
    requires_proof    = coalesce((p_patch ->> 'requires_proof')::boolean, requires_proof),
    requires_approval = coalesce((p_patch ->> 'requires_approval')::boolean, requires_approval),
    version           = version + 1
  where id = t.id returning * into t;
  if t.group_id is not null then perform log_event(t.group_id, 'task.updated', 'task', t.id, p_patch - 'description'); end if;
  return t;
end $$;

create or replace function add_participant(p_task uuid, p_user uuid) returns void
language plpgsql volatile security definer set search_path = public as $$
declare v_uid uuid := require_uid(); t tasks;
begin
  t := get_task_for_update(p_task);
  if t.group_id is null or not (t.creator_id = v_uid or has_permission(t.group_id, 'task.assign_others')) then perform fail('permission_denied'); end if;
  if not is_active_member_of(p_user, t.group_id) then perform fail('participant_not_member'); end if;
  insert into task_participants (task_id, user_id) values (t.id, p_user) on conflict do nothing;
  perform log_event(t.group_id, 'task.participant_added', 'task', t.id, jsonb_build_object('user_id', p_user));
end $$;

create or replace function remove_participant(p_task uuid, p_user uuid) returns void
language plpgsql volatile security definer set search_path = public as $$
declare v_uid uuid := require_uid(); t tasks;
begin
  t := get_task_for_update(p_task);
  if t.group_id is null or not (t.creator_id = v_uid or p_user = v_uid or has_permission(t.group_id, 'task.assign_others')) then perform fail('permission_denied'); end if;
  delete from task_participants where task_id = t.id and user_id = p_user;
  perform log_event(t.group_id, 'task.participant_removed', 'task', t.id, jsonb_build_object('user_id', p_user));
end $$;

-- Registers an uploaded object; validates the path convention of doc 06 §7.
create or replace function attach_file(p_task uuid, p_storage_path text, p_mime text, p_size bigint, p_kind attachment_kind default 'attachment')
returns task_attachments language plpgsql volatile security definer set search_path = public as $$
declare v_uid uuid := require_uid(); t tasks; a task_attachments; v_expected text;
begin
  t := get_task_for_update(p_task);
  if t.status in ('completed','cancelled') then perform fail('invalid_transition'); end if;
  if p_kind = 'proof' and t.assignee_id is distinct from v_uid then perform fail('permission_denied'); end if;
  if p_mime not in ('image/jpeg','image/png','image/heic','application/pdf') then perform fail('unsupported_mime'); end if;
  v_expected := case when t.group_id is null then 'personal/' || v_uid || '/tasks/' || t.id || '/'
                     else 'groups/' || t.group_id || '/tasks/' || t.id || '/' end;
  if left(p_storage_path, char_length(v_expected)) <> v_expected then perform fail('invalid_path'); end if;
  insert into task_attachments (task_id, uploader_id, storage_path, mime, size_bytes, kind)
  values (t.id, v_uid, p_storage_path, p_mime, p_size, p_kind) returning * into a;
  if t.group_id is not null then perform log_event(t.group_id, 'task.attachment_added', 'task', t.id, jsonb_build_object('kind', p_kind)); end if;
  return a;
end $$;

-- ---------------------------------------------------------------------------
-- §6 RPC — notifications
-- ---------------------------------------------------------------------------
create or replace function mark_notification_read(p_id uuid) returns void
language sql volatile security definer set search_path = public as $$
  update notifications set read_at = coalesce(read_at, now()) where id = p_id and user_id = auth.uid();
$$;

create or replace function mark_all_read() returns int
language plpgsql volatile security definer set search_path = public as $$
declare n int;
begin
  update notifications set read_at = now() where user_id = auth.uid() and read_at is null;
  get diagnostics n = row_count;
  return n;
end $$;

-- ---------------------------------------------------------------------------
-- §7 views and read functions (security_invoker ⇒ RLS of base tables applies)
-- ---------------------------------------------------------------------------
create or replace function is_overdue(t tasks) returns boolean
language sql stable as $$
  select t.due_at is not null and t.due_at < now() and t.status in ('new','in_progress','awaiting_approval');
$$;

create view v_group_tasks with (security_invoker = true) as
select t.*, is_overdue(t) as is_overdue,
       u.display_name as assignee_name, u.avatar_path as assignee_avatar,
       c.display_name as creator_name,
       (select count(*) from task_comments x where x.task_id = t.id and x.deleted_at is null) as comment_count,
       (select count(*) from task_attachments x where x.task_id = t.id) as attachment_count
  from tasks t
  left join users u on u.id = t.assignee_id
  left join users c on c.id = t.creator_id
 where t.group_id is not null;

create view v_group_dashboard_counts with (security_invoker = true) as
select group_id,
       count(*) filter (where status = 'new')                                   as new_count,
       count(*) filter (where status = 'in_progress')                           as in_progress_count,
       count(*) filter (where status = 'awaiting_approval')                     as awaiting_count,
       count(*) filter (where status = 'completed')                             as completed_count,
       count(*) filter (where status = 'completed' and completed_at::date = current_date) as completed_today_count,
       count(*) filter (where is_overdue(tasks))                                as overdue_count,
       count(*) filter (where assignee_id = auth.uid() and status in ('new','in_progress','awaiting_approval')) as mine_count
  from tasks
 where group_id is not null
 group by group_id;

create view v_my_groups with (security_invoker = true) as
select g.id, g.name, g.type, g.member_count, g.archived_at, m.role,
       (select count(*) from tasks t where t.group_id = g.id and t.status = 'new' and t.assignee_id is null) as open_count,
       (select count(*) from tasks t where t.group_id = g.id and t.assignee_id = auth.uid() and t.status in ('new','in_progress')) as mine_count,
       case when has_permission(g.id, 'group.approve_joins')
            then (select count(*) from join_requests j where j.group_id = g.id and j.status = 'pending') else 0 end as pending_requests
  from groups g join memberships m on m.group_id = g.id and m.user_id = auth.uid() and m.status = 'active';

create view v_my_permissions with (security_invoker = true) as
select m.group_id, m.role,
       (select jsonb_object_agg(k, has_permission(m.group_id, k)) from unnest(array[
          'group.manage_settings','group.manage_members','group.approve_joins','group.manage_invite','group.transfer','group.archive',
          'task.create','task.assign_others','task.edit_any','task.cancel_any','task.approve_completion',
          'activity.view','stats.view_all','comment.moderate']) k) as permissions
  from memberships m where m.user_id = auth.uid() and m.status = 'active';

-- Today view (doc 03 §F9): personal ∪ assigned ∪ claimed; "today" in the caller's timezone.
create or replace function my_tasks(p_tz text default null)
returns table (task tasks, is_overdue boolean, section text, group_name text)
language sql stable security invoker as $$
  with me as (select auth.uid() as uid, coalesce(p_tz, (select timezone from users where id = auth.uid()), 'Asia/Kuwait') as tz)
  select t, is_overdue(t),
         case when is_overdue(t) then 'overdue'
              when t.due_at is not null and (t.due_at at time zone me.tz)::date = (now() at time zone me.tz)::date then 'today'
              when t.due_at is null then 'no_date'
              else 'upcoming' end,
         g.name
    from tasks t cross join me left join groups g on g.id = t.group_id
   where t.status in ('new','in_progress','awaiting_approval')
     and (t.assignee_id = me.uid or (t.group_id is null and t.creator_id = me.uid)
          or exists (select 1 from task_participants p where p.task_id = t.id and p.user_id = me.uid))
   order by is_overdue(t) desc, t.due_at nulls last, t.priority desc, t.created_at;
$$;

-- Contribution numbers with the group's visibility policy (doc 06 §6).
create or replace function group_member_stats(p_group uuid, p_from timestamptz, p_to timestamptz)
returns table (user_id uuid, display_name text, completed int, on_time int, late int, in_progress int, overdue int, points int)
language sql stable security definer set search_path = public as $$
  with vis as (
    select group_setting(p_group, 'stats_visibility') #>> '{}' as v, member_role(p_group) as r
  )
  select m.user_id, u.display_name,
         count(t.id) filter (where t.status = 'completed' and t.completed_at between p_from and p_to)::int,
         count(t.id) filter (where t.status = 'completed' and t.completed_at between p_from and p_to and (t.due_at is null or t.completed_at <= t.due_at))::int,
         count(t.id) filter (where t.status = 'completed' and t.completed_at between p_from and p_to and t.due_at is not null and t.completed_at > t.due_at)::int,
         count(t.id) filter (where t.status = 'in_progress')::int,
         count(t.id) filter (where is_overdue(t))::int,
         coalesce(sum(t.points) filter (where t.status = 'completed' and t.completed_at between p_from and p_to), 0)::int
    from memberships m join users u on u.id = m.user_id cross join vis
    left join tasks t on (t.group_id = p_group and t.completed_by = m.user_id) or (t.group_id = p_group and t.assignee_id = m.user_id and t.status <> 'completed')
   where m.group_id = p_group and m.status = 'active' and is_active_member(p_group)
     and (m.user_id = auth.uid() or vis.v = 'all' or (vis.v = 'admins' and vis.r in ('owner','admin')))
   group by m.user_id, u.display_name;
$$;

-- Search across tasks / groups / members the caller can see (doc 03 §F12).
create or replace function search(p_query text, p_group uuid default null, p_status task_status[] default null, p_assignee uuid default null, p_limit int default 20)
returns jsonb language sql stable security invoker as $$
  with q as (select normalize_ar(coalesce(p_query, '')) as nq)
  select jsonb_build_object(
    'tasks', (select coalesce(jsonb_agg(jsonb_build_object('id', t.id, 'title', t.title, 'status', t.status, 'group_id', t.group_id, 'assignee_id', t.assignee_id, 'due_at', t.due_at, 'is_overdue', is_overdue(t))), '[]'::jsonb)
                from (select t.* from tasks t, q
                       where (q.nq = '' or t.search_text like '%' || q.nq || '%')
                         and (p_group is null or t.group_id = p_group)
                         and (p_status is null or t.status = any (p_status))
                         and (p_assignee is null or t.assignee_id = p_assignee)
                       order by t.created_at desc limit p_limit) t),
    'groups', (select coalesce(jsonb_agg(jsonb_build_object('id', g.id, 'name', g.name, 'type', g.type)), '[]'::jsonb)
                 from (select g.* from groups g, q where q.nq <> '' and normalize_ar(g.name) like '%' || q.nq || '%' limit p_limit) g),
    'members', (select coalesce(jsonb_agg(jsonb_build_object('user_id', m.user_id, 'group_id', m.group_id, 'display_name', m.display_name)), '[]'::jsonb)
                  from (select distinct m.user_id, m.group_id, u.display_name
                          from memberships m join users u on u.id = m.user_id, q
                         where q.nq <> '' and m.status = 'active' and normalize_ar(u.display_name) like '%' || q.nq || '%'
                           and (p_group is null or m.group_id = p_group) limit p_limit) m));
$$;

-- ---------------------------------------------------------------------------
-- §8 row-level security (doc 06 §5). Table owner bypasses RLS so the
-- SECURITY DEFINER helpers above work; the owner role is never exposed to clients.
-- ---------------------------------------------------------------------------
alter table users                    enable row level security;
alter table devices                  enable row level security;
alter table groups                   enable row level security;
alter table group_invites            enable row level security;
alter table join_requests            enable row level security;
alter table memberships              enable row level security;
alter table recurrence_rules         enable row level security;
alter table tasks                    enable row level security;
alter table task_participants        enable row level security;
alter table task_attachments         enable row level security;
alter table task_comments            enable row level security;
alter table activity_events          enable row level security;
alter table notifications            enable row level security;
alter table notification_preferences enable row level security;
alter table notification_outbox      enable row level security;
alter table task_reminders_sent      enable row level security;
alter table rate_limit_hits          enable row level security;

-- users: profiles of people who share a group with me, plus myself
create policy users_select on users for select using (
  id = auth.uid() or exists (
    select 1 from memberships a join memberships b on a.group_id = b.group_id
     where a.user_id = auth.uid() and a.status = 'active' and b.user_id = users.id and b.status = 'active'));
create policy users_update_self on users for update using (id = auth.uid()) with check (id = auth.uid());

create policy devices_self on devices for all using (user_id = auth.uid()) with check (user_id = auth.uid());

create policy groups_select on groups for select using (is_active_member(id));

create policy invites_select on group_invites for select using (has_permission(group_id, 'group.manage_invite'));

create policy join_requests_select on join_requests for select using (user_id = auth.uid() or has_permission(group_id, 'group.approve_joins'));

create policy memberships_select on memberships for select using (is_active_member(group_id));

create policy recurrence_select on recurrence_rules for select using (is_active_member(group_id));

create policy tasks_select on tasks for select using (can_view_task(id));

create policy participants_select on task_participants for select using (can_view_task(task_id));

create policy attachments_select on task_attachments for select using (can_view_task(task_id));
create policy attachments_delete on task_attachments for delete using (
  (uploader_id = auth.uid() and exists (select 1 from tasks t where t.id = task_id and t.status not in ('completed','cancelled')))
  or exists (select 1 from tasks t where t.id = task_id and t.group_id is not null and has_permission(t.group_id, 'comment.moderate')));

create policy comments_select on task_comments for select using (can_view_task(task_id));
create policy comments_insert on task_comments for insert with check (author_id = auth.uid() and kind = 'comment' and can_view_task(task_id));
create policy comments_update on task_comments for update
  using (author_id = auth.uid() and created_at > now() - interval '15 minutes')
  with check (author_id = auth.uid());
create policy comments_moderate on task_comments for update
  using (exists (select 1 from tasks t where t.id = task_id and t.group_id is not null and has_permission(t.group_id, 'comment.moderate')));

create policy activity_select on activity_events for select using (group_id is not null and has_permission(group_id, 'activity.view'));

create policy notifications_select on notifications for select using (user_id = auth.uid());
create policy notifications_update on notifications for update using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy notifications_delete on notifications for delete using (user_id = auth.uid());

create policy prefs_self on notification_preferences for all using (user_id = auth.uid()) with check (user_id = auth.uid());

-- outbox, reminders, rate limits: server only (no policies ⇒ no client access)

-- ---------------------------------------------------------------------------
-- §9 scheduled producers (doc 08 §4). Functions always exist; cron is guarded.
-- ---------------------------------------------------------------------------
create or replace function enqueue_due_soon_reminders() returns int
language plpgsql volatile security definer set search_path = public as $$
declare n int := 0; r record;
begin
  for r in
    select t.*, th.threshold from tasks t
    cross join lateral (values ('due_24h', interval '24 hours'), ('due_1h', interval '1 hour')) th(threshold, win)
    where t.status in ('new','in_progress') and t.due_at is not null
      and t.due_at between now() + th.win - interval '5 minutes' and now() + th.win + interval '5 minutes'
      and not exists (select 1 from task_reminders_sent s where s.task_id = t.id and s.threshold = th.threshold)
  loop
    perform create_notification(coalesce(r.assignee_id, r.creator_id), 'task.due_soon', r.id, r.group_id, null, null,
                                jsonb_build_object('title', r.title, 'threshold', r.threshold, 'due_at', r.due_at));
    insert into task_reminders_sent (task_id, threshold) values (r.id, r.threshold) on conflict do nothing;
    n := n + 1;
  end loop;
  return n;
end $$;

create or replace function enqueue_overdue_reminders() returns int
language plpgsql volatile security definer set search_path = public as $$
declare n int := 0; r record; k int;
begin
  for r in
    select t.*, (select count(*) from task_reminders_sent s where s.task_id = t.id and s.threshold like 'overdue_%') as sent,
           (select max(sent_at) from task_reminders_sent s where s.task_id = t.id and s.threshold like 'overdue_%') as last_sent
      from tasks t
     where t.status in ('new','in_progress') and t.due_at is not null and t.due_at < now()
  loop
    if r.sent >= 3 or (r.last_sent is not null and r.last_sent > now() - interval '24 hours') then continue; end if;
    k := r.sent + 1;
    perform create_notification(coalesce(r.assignee_id, r.creator_id), 'task.overdue', r.id, r.group_id, null, null,
                                jsonb_build_object('title', r.title, 'due_at', r.due_at, 'nth', k));
    insert into task_reminders_sent (task_id, threshold) values (r.id, 'overdue_' || k) on conflict do nothing;
    n := n + 1;
  end loop;
  return n;
end $$;

create or replace function prune_devices() returns int
language plpgsql volatile security definer set search_path = public as $$
declare n int;
begin
  delete from devices where last_seen_at < now() - interval '90 days';
  get diagnostics n = row_count;
  delete from rate_limit_hits where window_start < now() - interval '1 day';
  return n;
end $$;

do $$
begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    perform cron.schedule('almunjez_due_soon', '*/5 * * * *',  $j$select enqueue_due_soon_reminders()$j$);
    perform cron.schedule('almunjez_overdue',  '*/15 * * * *', $j$select enqueue_overdue_reminders()$j$);
    perform cron.schedule('almunjez_prune',    '30 3 * * *',   $j$select prune_devices()$j$);
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- §10 grants (Supabase roles; guarded so the file runs on plain Postgres)
-- ---------------------------------------------------------------------------
do $$
begin
  if exists (select 1 from pg_roles where rolname = 'authenticated') then
    grant usage on schema public to authenticated;
    grant select on all tables in schema public to authenticated;
    grant insert, update on task_comments to authenticated;
    grant update on users, notifications to authenticated;
    grant delete on notifications, task_attachments, devices to authenticated;
    grant insert, update, delete on notification_preferences to authenticated;
    grant execute on all functions in schema public to authenticated;
    -- server-only surfaces
    revoke all on notification_outbox, task_reminders_sent, rate_limit_hits from authenticated;
    revoke execute on function enqueue_due_soon_reminders(), enqueue_overdue_reminders(), prune_devices(),
                               create_notification(uuid, text, uuid, uuid, uuid, bigint, jsonb),
                               log_event(uuid, text, text, uuid, jsonb), release_tasks_of(uuid, uuid) from authenticated;
  end if;
  if exists (select 1 from pg_roles where rolname = 'anon') then
    revoke all on all tables in schema public from anon;
    revoke execute on all functions in schema public from anon;
  end if;
end $$;
