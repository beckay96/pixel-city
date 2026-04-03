-- Reserve username "thomas" for site owner dashboard (no public signup as thomas)
-- Create Thomas once in SQL Editor (replace YOUR_PASSWORD):
--   insert into public.users (username, password_hash)
--   select 'thomas', crypt('YOUR_PASSWORD', gen_salt('bf'))
--   where not exists (select 1 from public.users where username = 'thomas');

drop function if exists public.user_signup(text, text, text);

create or replace function public.user_signup(
  p_gateway text,
  p_username text,
  p_password text
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  gw_hash text;
  uid uuid;
  uname text := lower(trim(p_username));
begin
  select value into gw_hash from public.app_config where key = 'gateway_hash';
  if gw_hash is null or gw_hash <> crypt(p_gateway, gw_hash) then
    return jsonb_build_object('ok', false, 'error', 'Invalid gateway password');
  end if;

  if length(uname) < 2 then
    return jsonb_build_object('ok', false, 'error', 'Username must be at least 2 characters');
  end if;
  if uname = 'thomas' then
    return jsonb_build_object('ok', false, 'error', 'Username reserved');
  end if;
  if length(p_password) < 6 then
    return jsonb_build_object('ok', false, 'error', 'Password must be at least 6 characters');
  end if;

  if exists (select 1 from public.users where username = uname) then
    return jsonb_build_object('ok', false, 'error', 'Username already taken');
  end if;

  insert into public.users (username, password_hash)
  values (uname, crypt(p_password, gen_salt('bf')))
  returning id into uid;

  return jsonb_build_object('ok', true, 'user_id', uid, 'username', uname);
end;
$$;

grant execute on function public.user_signup(text, text, text) to anon, authenticated;

-- Admin analytics: only the user with username thomas may call (verified server-side)
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

  return jsonb_build_object(
    'ok', true,
    'users_total', ucount,
    'friends_edges_total', fcount,
    'game_sessions_total', scount,
    'game_sessions_active_7d', s7,
    'users_seen_24h', active24,
    'generated_at', to_char(now() at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS"Z"')
  );
end;
$$;

grant execute on function public.admin_dashboard_snapshot(uuid) to anon, authenticated;

comment on function public.admin_dashboard_snapshot(uuid) is 'Owner-only analytics; caller must be user thomas';
