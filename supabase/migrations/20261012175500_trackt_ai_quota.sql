create table if not exists public.trackt_ai_usage (
  user_id uuid not null references auth.users(id) on delete cascade,
  usage_date date not null default current_date,
  requests integer not null default 0 check (requests >= 0),
  primary key (user_id, usage_date)
);

alter table public.trackt_ai_usage enable row level security;
revoke all on public.trackt_ai_usage from anon, authenticated;
grant all on public.trackt_ai_usage to service_role;

create or replace function public.consume_trackt_ai_request(p_user_id uuid)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  user_requests integer;
  total_requests integer;
  usage_day date := (now() at time zone 'UTC')::date;
begin
  -- Serialize quota checks across Edge Function instances before spending.
  perform pg_catalog.pg_advisory_xact_lock(782349102143);

  select coalesce(sum(requests), 0) into total_requests
  from public.trackt_ai_usage where usage_date = usage_day;
  select coalesce(requests, 0) into user_requests
  from public.trackt_ai_usage
  where user_id = p_user_id and usage_date = usage_day;

  if total_requests >= 100 or coalesce(user_requests, 0) >= 20 then
    return false;
  end if;

  insert into public.trackt_ai_usage (user_id, usage_date, requests)
  values (p_user_id, usage_day, 1)
  on conflict (user_id, usage_date)
  do update set requests = public.trackt_ai_usage.requests + 1;
  return true;
end;
$$;

revoke all on function public.consume_trackt_ai_request(uuid) from public, anon, authenticated;
grant execute on function public.consume_trackt_ai_request(uuid) to service_role;
