-- Owner dashboard: usernames for online-now and last-24h lists (Thomas only)

create or replace function public.admin_dashboard_snapshot(p_user_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  is_thomas boolean;
  ucount int;
  fcount int;
  scount int;
  s7 int;
  active24 int;
  online_now int;
  online_list jsonb;
  active24_list jsonb;
begin
  if p_user_id is null then
    return jsonb_build_object('ok', false, 'error', 'Not authenticated');
  end if;

  select exists (
    select 1 from public.users u
    where u.id = p_user_id and lower(u.username) = 'thomas'
  ) into is_thomas;

  if not is_thomas then
    return jsonb_build_object('ok', false, 'error', 'Forbidden');
  end if;

  select count(*)::int from public.users into ucount;
  select count(*)::int from public.friends into fcount;
  select count(*)::int from public.game_sessions into scount;
  select count(*)::int from public.game_sessions
    where updated_at > (now() - interval '7 days') into s7;
  select count(*)::int from public.users
    where last_seen > (now() - interval '24 hours') into active24;
  select count(*)::int from public.users
    where last_seen > (now() - interval '90 seconds') into online_now;

  select coalesce(jsonb_agg(
    jsonb_build_object(
      'username', u.username,
      'last_seen', to_char(u.last_seen at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS"Z"')
    ) order by u.last_seen desc
  ), '[]'::jsonb)
  from (
    select username, last_seen
    from public.users
    where last_seen > (now() - interval '90 seconds')
    order by last_seen desc
    limit 120
  ) u
  into online_list;

  select coalesce(jsonb_agg(
    jsonb_build_object(
      'username', u.username,
      'last_seen', to_char(u.last_seen at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS"Z"')
    ) order by u.last_seen desc
  ), '[]'::jsonb)
  from (
    select username, last_seen
    from public.users
    where last_seen > (now() - interval '24 hours')
    order by last_seen desc
    limit 200
  ) u
  into active24_list;

  return jsonb_build_object(
    'ok', true,
    'users_total', ucount,
    'friends_edges_total', fcount,
    'game_sessions_total', scount,
    'game_sessions_active_7d', s7,
    'users_seen_24h', active24,
    'users_online_now', online_now,
    'users_online_now_list', online_list,
    'users_seen_24h_list', active24_list,
    'generated_at', to_char(now() at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS"Z"')
  );
end;
$$;

grant execute on function public.admin_dashboard_snapshot(uuid) to anon, authenticated;

comment on function public.admin_dashboard_snapshot(uuid) is 'Owner-only analytics + player username lists; caller must be user thomas';
