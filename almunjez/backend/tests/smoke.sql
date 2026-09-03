-- Smoke test for 001_initial.sql on plain Postgres (after _stub_auth.sql).
-- Each block asserts rules from the architecture docs and prints "ok: …".
\set ON_ERROR_STOP on
\set QUIET on

create temp table ctx (k text primary key, v text);
grant select on ctx to authenticated;
create or replace function ctx_set(p_k text, p_v anyelement) returns void language sql as
  $$ insert into ctx values (p_k, p_v::text) on conflict (k) do update set v = excluded.v $$;
create or replace function ctx(p_k text) returns uuid language sql stable as $$ select v::uuid from ctx where k = p_k $$;
create or replace function ctxt(p_k text) returns text language sql stable as $$ select v from ctx where k = p_k $$;
create or replace function t_as(p uuid) returns void language sql as $$ select set_config('app.uid', p::text, false) $$;
create or replace function t_expect_error(p_sql text, p_code text) returns void language plpgsql as $$
begin
  execute p_sql;
  raise exception 'expected error % but call succeeded: %', p_code, p_sql;
exception when others then
  if sqlerrm <> p_code then raise exception 'expected % got % for: %', p_code, sqlerrm, p_sql; end if;
end $$;

insert into users (id, display_name) values
  ('11111111-1111-1111-1111-111111111111', 'عبدالله'),
  ('22222222-2222-2222-2222-222222222222', 'محمد'),
  ('33333333-3333-3333-3333-333333333333', 'خالد'),
  ('44444444-4444-4444-4444-444444444444', 'سارة'),
  ('55555555-5555-5555-5555-555555555555', 'غريب');
select ctx_set('abdullah', '11111111-1111-1111-1111-111111111111'::uuid),
       ctx_set('mohammed', '22222222-2222-2222-2222-222222222222'::uuid),
       ctx_set('khaled',   '33333333-3333-3333-3333-333333333333'::uuid),
       ctx_set('sara',     '44444444-4444-4444-4444-444444444444'::uuid),
       ctx_set('outsider', '55555555-5555-5555-5555-555555555555'::uuid);

-- ---------------------------------------------------------------- groups & joining
do $$ declare g jsonb; r1 join_requests; r2 join_requests; begin
  perform t_as(ctx('abdullah'));
  g := create_group('البيت', 'home');
  perform ctx_set('gid', (g ->> 'group_id')::uuid), ctx_set('code', g ->> 'invite_code');
  assert (select count(*) from memberships where group_id = ctx('gid') and role = 'owner') = 1;
  assert (select member_count from groups where id = ctx('gid')) = 1;
  assert length(ctxt('code')) = 8;
  raise notice 'ok: create_group makes owner + one active 8-char invite';

  perform t_as(ctx('mohammed'));
  assert preview_invite(ctxt('code')) ->> 'group_name' = 'البيت';
  perform t_expect_error($q$select preview_invite('ZZZZZZZZ')$q$, 'invalid_invite');
  r1 := request_join(ctxt('code')); r2 := request_join(ctxt('code'));
  assert r1.id = r2.id;
  assert not is_active_member_of(ctx('mohammed'), ctx('gid'));
  perform ctx_set('jr_m', r1.id);
  raise notice 'ok: preview shows name only; request_join idempotent; code alone grants nothing';

  perform t_as(ctx('khaled'));  perform ctx_set('jr_k', (request_join(ctxt('code'))).id);
  perform t_as(ctx('sara'));    perform ctx_set('jr_s', (request_join(ctxt('code'))).id);

  perform t_as(ctx('mohammed'));
  perform t_expect_error(format($q$select decide_join(%L, true)$q$, ctx('jr_k')), 'permission_denied');

  perform t_as(ctx('abdullah'));
  perform decide_join(ctx('jr_m'), true); perform decide_join(ctx('jr_k'), true); perform decide_join(ctx('jr_s'), false);
  assert is_active_member_of(ctx('mohammed'), ctx('gid')) and is_active_member_of(ctx('khaled'), ctx('gid')) and not is_active_member_of(ctx('sara'), ctx('gid'));
  assert (select count(*) from notifications where user_id = ctx('abdullah') and type = 'join.requested') = 3;
  assert (select type from notifications where user_id = ctx('sara')) = 'join.rejected';
  assert (select member_count from groups where id = ctx('gid')) = 3;
  raise notice 'ok: approval gate; notifications to approver and requester; member_count';

  perform ctx_set('code2', regenerate_invite(ctx('gid')));
  perform t_as(ctx('sara'));
  perform t_expect_error(format($q$select request_join(%L)$q$, ctxt('code')), 'invalid_invite');
  assert preview_invite(ctxt('code2')) ->> 'group_name' = 'البيت';
  raise notice 'ok: regenerate_invite revokes the old code';
end $$;

-- ---------------------------------------------------------------- roles
do $$ begin
  perform t_as(ctx('abdullah'));
  perform set_member_role(ctx('gid'), ctx('khaled'), 'admin');
  perform t_as(ctx('khaled'));
  perform t_expect_error(format($q$select set_member_role(%L, %L, 'admin')$q$, ctx('gid'), ctx('abdullah')), 'permission_denied');
  perform t_expect_error(format($q$select remove_member(%L, %L)$q$, ctx('gid'), ctx('abdullah')), 'permission_denied');
  perform t_as(ctx('abdullah'));
  perform t_expect_error(format($q$select leave_group(%L)$q$, ctx('gid')), 'owner_must_transfer');
  perform t_expect_error($q$select delete_account()$q$, 'owner_must_transfer');
  raise notice 'ok: admin cannot touch owner; owner must transfer before leaving/deleting';
end $$;

-- ---------------------------------------------------------------- open task → claim → complete with approval
do $$ declare t tasks; begin
  perform t_as(ctx('abdullah'));
  t := create_task('إصلاح التكييف', ctx('gid'), p_requires_approval => true);
  perform ctx_set('task1', t.id);
  assert (select count(*) from notifications where task_id = t.id and type = 'task.created') = 2;   -- mohammed + khaled
  raise notice 'ok: task.created notifies eligible members except the creator';

  perform t_as(ctx('mohammed'));
  t := claim_task(t.id); assert t.status = 'in_progress' and t.assignee_id = ctx('mohammed');
  perform t_as(ctx('khaled'));
  perform t_expect_error(format($q$select claim_task(%L)$q$, t.id), 'already_claimed');
  perform t_as(ctx('mohammed'));
  t := claim_task(t.id); assert t.assignee_id = ctx('mohammed');
  assert (select count(*) from notifications where task_id = t.id and type = 'task.claimed' and user_id = ctx('abdullah')) = 1;
  raise notice 'ok: first claim wins; second gets already_claimed; re-claim by winner is idempotent';

  t := complete_task(t.id); assert t.status = 'awaiting_approval';
  perform t_expect_error(format($q$select approve_completion(%L)$q$, t.id), 'permission_denied');   -- assignee never approves own work
  perform t_as(ctx('abdullah'));
  t := reject_completion(t.id, 'الفني لم يأتِ بعد'); assert t.status = 'in_progress';
  perform t_as(ctx('mohammed'));
  t := complete_task(t.id);
  perform t_as(ctx('abdullah'));
  t := approve_completion(t.id); assert t.status = 'completed' and t.completed_by = ctx('mohammed') and t.approved_by = ctx('abdullah');
  assert exists (select 1 from task_comments where task_id = t.id and kind = 'rejection_reason');
  assert (select array_agg(action order by id) from activity_events where target_id = t.id)
         = array['task.created','task.claimed','task.submitted','task.rejected','task.submitted','task.approved'];
  assert (select count(*) from notifications where task_id = t.id and user_id = ctx('mohammed') and type in ('task.rejected','task.approved')) = 2;
  perform t_expect_error(format($q$select claim_task(%L)$q$, t.id), 'invalid_transition');
  raise notice 'ok: approval loop; rejection reason stored; full activity trail; terminal state locked';
end $$;

-- ---------------------------------------------------------------- assigned task, member removal releases tasks
do $$ declare t tasks; begin
  perform t_as(ctx('abdullah'));
  t := create_task('أخذ السيارة للصيانة', ctx('gid'), p_assignment_mode => 'assigned', p_assignee_id => ctx('khaled'));
  perform ctx_set('task2', t.id);
  assert (select count(*) from notifications where task_id = t.id and type = 'task.assigned' and user_id = ctx('khaled')) = 1;
  perform t_as(ctx('mohammed'));
  perform t_expect_error(format($q$select create_task('x', %L, p_assignment_mode => 'assigned', p_assignee_id => %L)$q$, ctx('gid'), ctx('khaled')), 'permission_denied');
  perform t_as(ctx('khaled'));
  t := start_task(t.id); assert t.status = 'in_progress';
  perform t_as(ctx('abdullah'));
  perform remove_member(ctx('gid'), ctx('khaled'));
  select * into t from tasks where id = t.id;
  assert t.status = 'new' and t.assignee_id is null and t.assignment_mode = 'open';
  assert (select count(*) from notifications where user_id = ctx('khaled') and type = 'member.removed') = 1;
  raise notice 'ok: members cannot assign others; removing a member releases their tasks to open';
end $$;

-- ---------------------------------------------------------------- personal tasks + my_tasks + subtasks
do $$ declare p tasks; l tasks; parent tasks; s1 tasks; s2 tasks; begin
  perform t_as(ctx('mohammed'));
  p := create_task('شراء الخبز', p_due_at => now() + interval '2 hours');
  l := create_task('مهمة متأخرة', p_due_at => now() - interval '1 hour');
  assert p.group_id is null and p.assignee_id = ctx('mohammed');
  assert (select count(*) from activity_events where target_id = p.id) = 0;
  assert (select section from my_tasks() where (task).id = p.id) = 'today';
  assert (select section from my_tasks() where (task).id = l.id) = 'overdue';
  assert (select is_overdue from my_tasks() where (task).id = l.id);
  assert (select count(*) from my_tasks()) = 2;
  raise notice 'ok: personal tasks have no events; my_tasks sections; derived overdue';

  perform t_as(ctx('abdullah'));
  parent := create_task('تجهيز البيت للعزيمة', ctx('gid'), p_assignment_mode => 'collaborative', p_participant_ids => array[ctx('mohammed')]);
  s1 := create_task('شراء الثلج', ctx('gid'), p_parent_task_id => parent.id);
  s2 := create_task('تنظيف المجلس', ctx('gid'), p_parent_task_id => parent.id);
  perform t_expect_error(format($q$select create_task('عمق 2', %L, p_parent_task_id => %L)$q$, ctx('gid'), s1.id), 'subtask_depth_exceeded');
  perform t_as(ctx('mohammed'));
  perform claim_task(s1.id); perform complete_task(s1.id);
  assert (select status from tasks where id = parent.id) = 'new';
  perform claim_task(s2.id); perform complete_task(s2.id);
  assert (select status from tasks where id = parent.id) = 'completed';
  raise notice 'ok: subtask depth limit; parent auto-completes when all subtasks complete';
end $$;

-- ---------------------------------------------------------------- append-only log, normalisation
do $$ begin
  begin
    update activity_events set action = 'x' where id = (select min(id) from activity_events);
    raise exception 'should not update';
  exception when others then assert sqlerrm = 'activity_log_immutable'; end;
  begin
    delete from activity_events;
    raise exception 'should not delete';
  exception when others then assert sqlerrm = 'activity_log_immutable'; end;
  raise notice 'ok: activity log immutable even for the table owner';

  assert normalize_ar('التَّكْيِيف') = 'التكييف';
  assert normalize_ar('إصلاح') = 'اصلاح';
  assert normalize_ar('٤ مهام') = '4 مهام';
  perform t_as(ctx('mohammed'));
  assert jsonb_array_length(search('تكييف') -> 'tasks') = 1;
  assert jsonb_array_length(search('اصلاح') -> 'tasks') = 1;
  raise notice 'ok: Arabic normalisation and search';
end $$;

-- ---------------------------------------------------------------- RLS isolation (as the authenticated role)
do $$ declare g jsonb; t tasks; begin
  perform t_as(ctx('outsider'));
  g := create_group('الشركة', 'company'); perform ctx_set('gid2', (g ->> 'group_id')::uuid);
  t := create_task('تقرير المبيعات', ctx('gid2')); perform ctx_set('task3', t.id);
end $$;

set role authenticated;
do $$ begin
  perform t_as(ctx('outsider'));
  assert (select count(*) from tasks where group_id = ctx('gid')) = 0;
  assert (select count(*) from tasks where id = ctx('task1')) = 0;
  assert (select count(*) from memberships where group_id = ctx('gid')) = 0;
  assert (select count(*) from activity_events where group_id = ctx('gid')) = 0;
  assert (select count(*) from users where id = ctx('mohammed')) = 0;     -- no shared group ⇒ invisible
  assert (select count(*) from group_invites) = 1;                          -- only own group's code
  assert (select count(*) from v_my_groups) = 1;
  perform t_expect_error(format($q$select claim_task(%L)$q$, ctx('task2')), 'not_a_member');
  perform t_expect_error(format($q$select approve_completion(%L)$q$, ctx('task1')), 'not_a_member');
  raise notice 'ok: RLS — outsider sees nothing of البيت (tasks, members, log, code) and RPCs refuse';

  begin
    update memberships set role = 'owner' where user_id = ctx('outsider') and group_id = ctx('gid');
  exception when insufficient_privilege then null; end;
  assert (select count(*) from memberships where user_id = ctx('outsider') and group_id = ctx('gid')) = 0;
  begin
    insert into activity_events (group_id, actor_id, action, target_type) values (ctx('gid2'), ctx('outsider'), 'forged', 'group');
    raise exception 'forged event inserted';
  exception when insufficient_privilege then null; end;
  begin
    insert into notification_outbox (notification_id, device_id) select null, null;
    raise exception 'outbox reachable';
  exception when insufficient_privilege then null; end;
  raise notice 'ok: RLS — no direct role edits, no forged activity events, outbox is server-only';

  perform t_as(ctx('mohammed'));
  assert (select count(*) from tasks where group_id = ctx('gid')) = 5;
  assert (select count(*) from tasks where group_id = ctx('gid2')) = 0;
  assert (select count(*) from group_invites) = 0;                          -- member lacks manage_invite
  assert (select new_count from v_group_dashboard_counts where group_id = ctx('gid')) = 1;
  assert (select completed_count from v_group_dashboard_counts where group_id = ctx('gid')) = 4;
  assert (select (permissions ->> 'task.create')::boolean from v_my_permissions where group_id = ctx('gid'));
  assert not (select (permissions ->> 'group.manage_members')::boolean from v_my_permissions where group_id = ctx('gid'));
  insert into task_comments (task_id, author_id, body) values (ctx('task1'), ctx('mohammed'), 'تواصلت مع الفني، سيأتي الساعة 4.');
  assert (select count(*) from notifications where user_id = ctx('abdullah')) = 0;   -- RLS hides others' inboxes
  begin
    insert into task_comments (task_id, author_id, body) values (ctx('task3'), ctx('mohammed'), 'تسلل');
    raise exception 'comment on foreign task inserted';
  exception when others then assert sqlstate = '42501'; end;
  raise notice 'ok: RLS — member sees own group only; dashboard counts; permissions view; no cross-group comment; inboxes private';
end $$;
reset role;
do $$ begin
  assert (select count(*) from notifications where user_id = ctx('abdullah') and type = 'task.comment') = 1;
  raise notice 'ok: comment inserted under RLS fans out to the creator';
end $$;

-- ---------------------------------------------------------------- stats visibility
do $$ begin
  perform t_as(ctx('mohammed'));
  assert (select count(*) from group_member_stats(ctx('gid'), now() - interval '7 days', now())) = 1;   -- home ⇒ private ⇒ self only
  perform t_as(ctx('abdullah'));
  perform update_group_settings(ctx('gid'), p_settings => '{"stats_visibility":"all"}');
  perform t_as(ctx('mohammed'));
  assert (select count(*) from group_member_stats(ctx('gid'), now() - interval '7 days', now())) = 2;
  assert (select completed from group_member_stats(ctx('gid'), now() - interval '7 days', now()) where user_id = ctx('mohammed')) = 4;   -- task1 + 2 subtasks + auto-completed parent
  raise notice 'ok: stats visibility private for home groups; "all" exposes everyone';
end $$;

-- ---------------------------------------------------------------- reminders + account deletion
do $$ declare t tasks; begin
  perform t_as(ctx('abdullah'));
  t := create_task('موعد قريب', ctx('gid'), p_assignment_mode => 'assigned', p_assignee_id => ctx('mohammed'), p_due_at => now() + interval '1 hour');
  assert enqueue_due_soon_reminders() = 1;
  assert enqueue_due_soon_reminders() = 0;                                  -- single-shot per threshold
  assert (select count(*) from notifications where task_id = t.id and type = 'task.due_soon' and user_id = ctx('mohammed')) = 1;
  perform update_task(t.id, '{"due_at": null}'::jsonb, (select version from tasks where id = t.id));
  assert (select count(*) from task_reminders_sent where task_id = t.id) = 0;  -- reset on deadline change
  raise notice 'ok: due-soon reminder fires once; deadline change resets reminders';

  perform t_as(ctx('mohammed'));
  perform delete_account();
  assert (select display_name from users where id = ctx('mohammed')) = 'عضو سابق';
  assert (select count(*) from tasks where creator_id = ctx('mohammed') and group_id is null) = 0;
  assert (select completed_by from tasks where id = ctx('task1')) = ctx('mohammed');        -- history kept
  assert (select status from memberships where user_id = ctx('mohammed') and group_id = ctx('gid')) = 'left';
  assert (select status from tasks where id = t.id) = 'new' and (select assignee_id from tasks where id = t.id) is null;
  raise notice 'ok: delete_account anonymises, releases tasks, keeps group history';
end $$;

\echo smoke: all assertions passed
