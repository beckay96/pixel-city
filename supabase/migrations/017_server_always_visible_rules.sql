-- Yours, friends', and thomas' servers stay listed/joinable forever (until deleted).
-- Only global (stranger) servers use the 4h activity window.

create or replace function public.server_always_visible(p_host_id uuid, p_viewer_id uuid, p_host_username text)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select
    (p_viewer_id is not null and p_host_id = p_viewer_id)
    or lower(trim(coalesce(p_host_username, ''))) = 'thomas'
    or (
      p_viewer_id is not null
      and exists (
        select 1 from public.friends f
        where f.user_id = p_viewer_id and f.friend_id = p_host_id
      )
    );
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
  select coalesce(jsonb_agg(row order by (row->>'is_mine')::boolean desc, (row->>'is_friend')::boolean desc, (row->>'players_online')::int desc, row->>'updated_at' desc), '[]'::jsonb)
  into result
  from (
    select jsonb_build_object(
      'code', gs.code,
      'host_id', gs.host_id,
      'host_username', u.username,
      'is_mine', (p_user_id is not null and gs.host_id = p_user_id),
      'is_friend', (
        p_user_id is not null and exists (
          select 1 from public.friends f
          where f.user_id = p_user_id and f.friend_id = gs.host_id
        )
      ),
      'is_thomas', lower(u.username) = 'thomas',
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
      and (
        public.server_always_visible(gs.host_id, p_user_id, u.username)
        or public.session_last_activity(gs.code) > (now() - interval '4 hours')
      )
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
      return jsonb_build_object(
        'ok', true,
        'code', sess.code,
        'updated_at', sess.updated_at,
        'is_host', sess.host_id = uid
      );
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

  return jsonb_build_object(
    'ok', true,
    'code', sess.code,
    'updated_at', sess.updated_at,
    'is_host', true
  );
end;
$$;

grant execute on function public.server_always_visible(uuid, uuid, text) to anon, authenticated;
