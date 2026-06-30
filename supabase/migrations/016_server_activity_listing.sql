-- List servers by last player activity (4h idle = hidden); join checks activity not just updated_at

create or replace function public.session_last_activity(p_code text)
returns timestamptz
language sql
stable
security definer
set search_path = public
as $$
  select greatest(
    gs.updated_at,
    coalesce((
      select max(pu.last_seen)
      from public.users pu
      where pu.active_session_code = upper(trim(p_code))
        and pu.banned_at is null
    ), gs.updated_at)
  )
  from public.game_sessions gs
  where gs.code = upper(trim(p_code));
$$;

create or replace function public.list_public_servers(p_user_id uuid default null)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  result jsonb;
begin
  select coalesce(jsonb_agg(row order by (row->>'is_mine')::boolean desc, (row->>'players_online')::int desc, row->>'updated_at' desc), '[]'::jsonb)
  into result
  from (
    select jsonb_build_object(
      'code', gs.code,
      'host_id', gs.host_id,
      'host_username', u.username,
      'is_mine', (p_user_id is not null and gs.host_id = p_user_id),
      'is_multiplayer', (
        select count(*)::int >= 2
        from public.users pu
        where pu.active_session_code = gs.code
          and pu.last_seen > (now() - interval '90 seconds')
          and pu.banned_at is null
      ),
      'players_online', (
        select count(*)::int
        from public.users pu
        where pu.active_session_code = gs.code
          and pu.last_seen > (now() - interval '90 seconds')
          and pu.banned_at is null
      ),
      'updated_at', to_char(public.session_last_activity(gs.code) at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS"Z"')
    ) as row
    from public.game_sessions gs
    inner join public.users u on u.id = gs.host_id
    where u.banned_at is null
      and public.session_last_activity(gs.code) > (now() - interval '4 hours')
  ) sub;

  return jsonb_build_object('ok', true, 'servers', coalesce(result, '[]'::jsonb));
end;
$$;

create or replace function public.get_friend_session(p_username text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid;
  sess record;
  active_code text;
  last_act timestamptz;
begin
  select id, active_session_code into uid, active_code
  from public.users
  where username = lower(trim(p_username));

  if uid is null then
    return jsonb_build_object('ok', false, 'error', 'User not found');
  end if;

  if active_code is not null then
    select code, updated_at, host_id into sess
    from public.game_sessions
    where code = active_code;

    if sess is not null then
      last_act := public.session_last_activity(sess.code);
      if last_act > (now() - interval '4 hours') then
        return jsonb_build_object(
          'ok', true,
          'code', sess.code,
          'updated_at', sess.updated_at,
          'is_host', sess.host_id = uid
        );
      end if;
    end if;
  end if;

  select code, updated_at, host_id into sess
  from public.game_sessions
  where host_id = uid
  order by updated_at desc
  limit 1;

  if sess is null then
    return jsonb_build_object('ok', true, 'code', null);
  end if;

  last_act := public.session_last_activity(sess.code);
  if last_act <= (now() - interval '4 hours') then
    return jsonb_build_object('ok', true, 'code', null);
  end if;

  return jsonb_build_object(
    'ok', true,
    'code', sess.code,
    'updated_at', sess.updated_at,
    'is_host', true
  );
end;
$$;

grant execute on function public.session_last_activity(text) to anon, authenticated;
