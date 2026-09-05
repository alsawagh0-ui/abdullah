-- Storage policies of 003_storage.sql: members see group files, owners see
-- personal files, nobody else sees or writes anything. Runs after smoke.sql.
reset role;
do $$ declare g jsonb; t tasks; p tasks; begin
  perform t_as(ctx('abdullah'));
  g := create_group('ملفات', 'family'); perform ctx_set('sg', (g ->> 'group_id')::uuid);
  t := create_task('صورة الإثبات', ctx('sg')); perform ctx_set('st', t.id);
  perform ctx_set('sjr', (select id from group_invites where group_id = ctx('sg') and revoked_at is null));
  perform t_as(ctx('sara'));
  perform ctx_set('sreq', (request_join((select code from group_invites where id = ctx('sjr')))).id);
  perform t_as(ctx('abdullah'));
  perform decide_join(ctx('sreq'), true);
  perform t_as(ctx('sara'));
  t := claim_task(ctx('st'));
  p := create_task('خاصة'); perform ctx_set('sp', p.id);
end $$;

set role authenticated;
do $$ declare denied boolean; n int; begin
  -- assignee uploads proof under the group path, then registers it
  perform t_as(ctx('sara'));
  insert into storage.objects (bucket_id, name, owner)
    values ('task-files', 'groups/' || ctx('sg') || '/tasks/' || ctx('st') || '/proof.jpg', ctx('sara'));
  perform attach_file(ctx('st'), 'groups/' || ctx('sg') || '/tasks/' || ctx('st') || '/proof.jpg', 'image/jpeg', 1234, 'proof');
  assert (select count(*) from task_attachments where task_id = ctx('st') and kind = 'proof') = 1;
  -- personal path is owner-only
  insert into storage.objects (bucket_id, name, owner)
    values ('task-files', 'personal/' || ctx('sara') || '/tasks/' || ctx('sp') || '/note.pdf', ctx('sara'));

  -- another member sees the group file but not sara's personal one
  perform t_as(ctx('abdullah'));
  select count(*) into n from storage.objects where name like 'groups/' || ctx('sg') || '/%'; assert n = 1;
  select count(*) into n from storage.objects where name like 'personal/%';                assert n = 0;
  -- and cannot delete it (not the owner)
  delete from storage.objects where name like 'groups/' || ctx('sg') || '/%';
  select count(*) into n from storage.objects where name like 'groups/' || ctx('sg') || '/%'; assert n = 1;
  raise notice 'ok: members read group files, personal files stay private, only the uploader deletes';

  -- outsider: sees nothing, cannot write into the group path
  perform t_as(ctx('outsider'));
  select count(*) into n from storage.objects; assert n = 0;
  denied := false;
  begin
    insert into storage.objects (bucket_id, name, owner)
      values ('task-files', 'groups/' || ctx('sg') || '/tasks/' || ctx('st') || '/x.jpg', ctx('outsider'));
  exception when insufficient_privilege then denied := true; end;
  assert denied, 'outsider insert must hit RLS';
  -- nor spoof the owner column
  denied := false;
  begin
    insert into storage.objects (bucket_id, name, owner)
      values ('task-files', 'personal/' || ctx('sara') || '/tasks/' || ctx('sp') || '/y.jpg', ctx('sara'));
  exception when insufficient_privilege then denied := true; end;
  assert denied, 'owner spoof must hit RLS';
  -- malformed paths never pass
  assert not storage_path_visible('groups/not-a-uuid/tasks/x/y');
  assert not storage_path_visible('avatars/whatever');
  raise notice 'ok: outsider sees nothing and cannot write';

  -- detach_file: only the uploader
  perform t_as(ctx('abdullah'));
  perform t_expect_error(format('select detach_file(%L)', (select id from task_attachments where task_id = ctx('st'))), 'permission_denied');
  perform t_as(ctx('sara'));
  perform detach_file((select id from task_attachments where task_id = ctx('st')));
  assert (select count(*) from task_attachments where task_id = ctx('st')) = 0;
  raise notice 'ok: detach_file is uploader-only';
end $$;
reset role;
\echo storage: all assertions passed
