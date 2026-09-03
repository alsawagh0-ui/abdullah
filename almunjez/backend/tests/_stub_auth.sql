-- Local-only stand-in for Supabase's auth schema so 001_initial.sql and the
-- tests run on plain Postgres. Never apply this to a Supabase project.
--   auth.uid()  reads the session setting app.uid  (set app.uid = '<uuid>')
create schema if not exists auth;
create or replace function auth.uid() returns uuid
language sql stable as $$ select nullif(current_setting('app.uid', true), '')::uuid $$;
-- Supabase roles the schema's guarded grants look for
do $$ begin
  if not exists (select 1 from pg_roles where rolname = 'authenticated') then create role authenticated nologin; end if;
  if not exists (select 1 from pg_roles where rolname = 'anon') then create role anon nologin; end if;
end $$;
