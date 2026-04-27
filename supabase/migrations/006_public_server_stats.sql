-- Public aggregate stats (no per-user data) for lobby "server activity" when unlocked with admin PIN in the game UI.
-- Safe to call with anon key; returns only counts.

create or replace function public.public_server_stats()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  ucount int;
  scount int;
  active24 int;
  online_now int;
begin
  select count(*)::int from public.users into ucount;
  select count(*)::int from public.game_sessions into scount;
  select count(*)::int from public.users
    where last_seen > (now() - interval '24 hours') into active24;
  select count(*)::int from public.users
    where last_seen > (now() - interval '90 seconds') into online_now;

  return jsonb_build_object(
    'ok', true,
    'users_total', ucount,
    'game_sessions_total', scount,
    'users_seen_24h', active24,
    'users_online_now', online_now,
    'generated_at', to_char(now() at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS"Z"')
  );
end;
$$;

grant execute on function public.public_server_stats() to anon, authenticated;

comment on function public.public_server_stats is 'Public aggregate game stats; safe for anon';
