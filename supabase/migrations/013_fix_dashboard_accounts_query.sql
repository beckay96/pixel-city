-- Harden all_accounts_list query: alias is_admin/banned_at like online lists (avoid PL/pgSQL shadowing)

create or replace function public.admin_dashboard_snapshot(p_user_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_is_owner boolean;
  v_caller_is_admin boolean;
  ucount int;
  fcount int;
  scount int;
  s7 int;
  active24 int;
  online_now int;
  online_list jsonb;
  active24_list jsonb;
  all_accounts jsonb;
begin
  if p_user_id is null then
    return jsonb_build_object('ok', false, 'error', 'Not authenticated');
  end if;

  select public._caller_is_owner(p_user_id) into v_is_owner;
  select public._caller_is_admin_or_owner(p_user_id) into v_caller_is_admin;

  if not v_caller_is_admin then
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
      'last_seen', to_char(u.last_seen at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
      'is_admin', (lower(u.username) = 'thomas' or u.user_is_admin),
      'banned', u.user_banned_at is not null
    ) order by u.last_seen desc
  ), '[]'::jsonb)
  from (
    select username, last_seen, is_admin as user_is_admin, banned_at as user_banned_at
    from public.users
    where last_seen > (now() - interval '90 seconds')
    order by last_seen desc
    limit 120
  ) u
  into online_list;

  select coalesce(jsonb_agg(
    jsonb_build_object(
      'username', u.username,
      'last_seen', to_char(u.last_seen at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
      'is_admin', (lower(u.username) = 'thomas' or u.user_is_admin),
      'banned', u.user_banned_at is not null
    ) order by u.last_seen desc
  ), '[]'::jsonb)
  from (
    select username, last_seen, is_admin as user_is_admin, banned_at as user_banned_at
    from public.users
    where last_seen > (now() - interval '24 hours')
    order by last_seen desc
    limit 200
  ) u
  into active24_list;

  select coalesce(jsonb_agg(
    jsonb_build_object(
      'user_id', u.id,
      'username', u.username,
      'created_at', to_char(u.created_at at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
      'last_seen', to_char(u.last_seen at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
      'is_admin', (lower(u.username) = 'thomas' or u.user_is_admin),
      'is_owner', lower(u.username) = 'thomas',
      'banned', u.user_banned_at is not null,
      'win_count', coalesce(u.win_count, 0)
    ) order by lower(u.username)
  ), '[]'::jsonb)
  from (
    select id, username, created_at, last_seen, is_admin as user_is_admin, banned_at as user_banned_at, win_count
    from public.users
  ) u
  into all_accounts;

  return jsonb_build_object(
    'ok', true,
    'is_owner', v_is_owner,
    'is_admin', v_caller_is_admin,
    'users_total', ucount,
    'friends_edges_total', fcount,
    'game_sessions_total', scount,
    'game_sessions_active_7d', s7,
    'users_seen_24h', active24,
    'users_online_now', online_now,
    'users_online_now_list', online_list,
    'users_seen_24h_list', active24_list,
    'all_accounts_list', all_accounts,
    'generated_at', to_char(now() at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS"Z"')
  );
end;
$$;
