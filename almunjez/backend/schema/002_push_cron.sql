-- Invoke the push-sender Edge Function every minute through pg_net (Supabase).
-- Run once after deploying the function; replace the two placeholders.
--   select set_config('app.settings.supabase_url', 'https://xxx.supabase.co', false);
create extension if not exists pg_net;

create or replace function invoke_push_sender() returns void
language plpgsql security definer set search_path = public as $$
declare v_url text := current_setting('app.settings.supabase_url', true);
begin
  if v_url is null or not exists (select 1 from notification_outbox where status = 'pending' and next_attempt_at <= now()) then return; end if;
  perform net.http_post(
    url := v_url || '/functions/v1/push-sender',
    headers := jsonb_build_object('Content-Type', 'application/json'),
    body := '{}'::jsonb);
end $$;

do $$
begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    perform cron.schedule('almunjez_push_sender', '* * * * *', $j$select invoke_push_sender()$j$);
  end if;
end $$;
