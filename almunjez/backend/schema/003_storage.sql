-- ---------------------------------------------------------------------------
-- 003_storage.sql — private bucket for task attachments and proof photos
-- (doc 06 §7, doc 04 task_attachments). Run after 001_initial.sql.
--
-- Object path convention, enforced by attach_file() on the row and by the
-- policies below on the object itself:
--   groups/<group_id>/tasks/<task_id>/<file>     visible to active members
--   personal/<user_id>/tasks/<task_id>/<file>    visible to the owner only
-- ---------------------------------------------------------------------------

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('task-files', 'task-files', false, 30 * 1024 * 1024,
        array['image/jpeg','image/png','image/heic','application/pdf'])
on conflict (id) do update
   set public = excluded.public,
       file_size_limit = excluded.file_size_limit,
       allowed_mime_types = excluded.allowed_mime_types;

-- Who may see an object at this path? Same rule as can_view_task, derived
-- from the path so it holds even before the task_attachments row exists.
create or replace function storage_path_visible(p_name text) returns boolean
language plpgsql stable security definer set search_path = public as $$
declare v_uid uuid := auth.uid(); parts text[] := string_to_array(p_name, '/');
begin
  if v_uid is null or array_length(parts, 1) < 4 then return false; end if;
  if parts[1] = 'personal' then
    return parts[2] = v_uid::text and parts[3] = 'tasks';
  elsif parts[1] = 'groups' then
    return parts[3] = 'tasks' and is_active_member_of(v_uid, parts[2]::uuid)
       and exists (select 1 from tasks t where t.id = parts[4]::uuid and t.group_id = parts[2]::uuid);
  end if;
  return false;
exception when others then
  return false; -- malformed uuid segments
end $$;

alter table storage.objects enable row level security;

drop policy if exists "task-files read"   on storage.objects;
drop policy if exists "task-files insert" on storage.objects;
drop policy if exists "task-files delete" on storage.objects;

create policy "task-files read" on storage.objects for select
  using (bucket_id = 'task-files' and storage_path_visible(name));

-- Upload where you can view; attach_file() then decides whether the row
-- counts as proof (assignee only) and logs the event.
create policy "task-files insert" on storage.objects for insert
  with check (bucket_id = 'task-files' and storage_path_visible(name) and owner = auth.uid());

-- Only the uploader removes an object; the task_attachments row goes with it.
create policy "task-files delete" on storage.objects for delete
  using (bucket_id = 'task-files' and owner = auth.uid());

create or replace function detach_file(p_attachment uuid) returns void
language plpgsql volatile security definer set search_path = public as $$
declare v_uid uuid := require_uid(); a task_attachments;
begin
  select * into a from task_attachments where id = p_attachment;
  if a.id is null then perform fail('not_found'); end if;
  if a.uploader_id <> v_uid then perform fail('permission_denied'); end if;
  delete from task_attachments where id = a.id;
end $$;

do $$ begin
  if exists (select 1 from pg_roles where rolname = 'authenticated') then
    grant execute on function detach_file(uuid) to authenticated;
  end if;
end $$;
