-- User profiles: avatar, win count, and active session for friend join

alter table public.users
  add column if not exists avatar text not null default '😀',
  add column if not exists win_count integer not null default 0,
  add column if not exists active_session_code text;

-- Heartbeat: optional session code ('' clears active session)
create or replace function public.user_heartbeat(
  p_user_id uuid,
  p_session_code text default null
)
returns void
language plpgsql
security definer
set search_path = public, extensions
as $$
begin
  if p_user_id is null then return; end if;

  if p_session_code is not null and upper(trim(p_session_code)) = 'CLEAR' then
    update public.users
    set last_seen = now(), active_session_code = null
    where id = p_user_id;
  elsif p_session_code is not null and length(trim(p_session_code)) > 0 then
    update public.users
    set last_seen = now(), active_session_code = upper(trim(p_session_code))
    where id = p_user_id;
  else
    update public.users set last_seen = now() where id = p_user_id;
  end if;
end;
$$;

-- Friend session: active session first, then hosted session
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
    where code = active_code
      and updated_at > (now() - interval '4 hours');

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
    and updated_at > (now() - interval '4 hours')
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

create or replace function public.get_friend_profile(
  p_user_id uuid,
  p_friend_username text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  fid uuid;
  fu record;
  online boolean;
  sess jsonb;
  sess_code text;
begin
  if p_user_id is null then
    return jsonb_build_object('ok', false, 'error', 'Not authenticated');
  end if;

  select u.id, u.username, u.avatar, u.win_count, u.last_seen, u.active_session_code
  into fu
  from public.users u
  where u.username = lower(trim(p_friend_username));

  if fu.id is null then
    return jsonb_build_object('ok', false, 'error', 'User not found');
  end if;

  if not exists (
    select 1 from public.friends
    where user_id = p_user_id and friend_id = fu.id
  ) then
    return jsonb_build_object('ok', false, 'error', 'Not friends');
  end if;

  online := fu.last_seen is not null and fu.last_seen > (now() - interval '90 seconds');

  sess := public.get_friend_session(fu.username);
  sess_code := case when sess ->> 'code' is null then null else sess ->> 'code' end;

  return jsonb_build_object(
    'ok', true,
    'user_id', fu.id,
    'username', fu.username,
    'avatar', coalesce(nullif(trim(fu.avatar), ''), '😀'),
    'win_count', coalesce(fu.win_count, 0),
    'online', online,
    'session_code', sess_code,
    'in_game', sess_code is not null,
    'is_hosting', coalesce((sess ->> 'is_host')::boolean, false)
  );
end;
$$;

create or replace function public.update_user_profile(
  p_user_id uuid,
  p_avatar text
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  av text := trim(coalesce(p_avatar, ''));
begin
  if p_user_id is null then
    return jsonb_build_object('ok', false, 'error', 'Not authenticated');
  end if;

  if length(av) < 1 or length(av) > 16 then
    return jsonb_build_object('ok', false, 'error', 'Invalid avatar');
  end if;

  update public.users set avatar = av where id = p_user_id;

  return jsonb_build_object('ok', true, 'avatar', av);
end;
$$;

create or replace function public.sync_user_win_count(
  p_user_id uuid,
  p_win_count integer
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  merged integer;
begin
  if p_user_id is null then
    return jsonb_build_object('ok', false, 'error', 'Not authenticated');
  end if;

  if p_win_count is null or p_win_count < 0 then
    return jsonb_build_object('ok', false, 'error', 'Invalid win count');
  end if;

  update public.users
  set win_count = greatest(coalesce(win_count, 0), p_win_count)
  where id = p_user_id
  returning win_count into merged;

  return jsonb_build_object('ok', true, 'win_count', coalesce(merged, 0));
end;
$$;

grant execute on function public.get_friend_profile(uuid, text) to anon, authenticated;
grant execute on function public.update_user_profile(uuid, text) to anon, authenticated;
grant execute on function public.sync_user_win_count(uuid, integer) to anon, authenticated;
