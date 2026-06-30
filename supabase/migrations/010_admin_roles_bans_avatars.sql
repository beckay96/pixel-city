-- Admin roles, account bans, and avatar storage bucket

alter table public.users
  add column if not exists is_admin boolean not null default false,
  add column if not exists banned_at timestamptz,
  add column if not exists ban_reason text;

create index if not exists idx_users_banned on public.users (banned_at) where banned_at is not null;
create index if not exists idx_users_is_admin on public.users (is_admin) where is_admin = true;

-- Owner = thomas username; admins = is_admin flag (cannot promote others)
create or replace function public._caller_is_owner(p_user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.users u
    where u.id = p_user_id and lower(u.username) = 'thomas' and u.banned_at is null
  );
$$;

create or replace function public._caller_is_admin_or_owner(p_user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.users u
    where u.id = p_user_id
      and u.banned_at is null
      and (lower(u.username) = 'thomas' or u.is_admin = true)
  );
$$;

-- Sign-in: reject banned accounts
create or replace function public.user_signin(
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
  u record;
  uname text := lower(trim(p_username));
begin
  select value into gw_hash from public.app_config where key = 'gateway_hash';
  if gw_hash is null or gw_hash <> crypt(p_gateway, gw_hash) then
    return jsonb_build_object('ok', false, 'error', 'Invalid gateway password');
  end if;

  select id, username, password_hash, banned_at, ban_reason, is_admin
  into u
  from public.users
  where username = uname;

  if u is null then
    return jsonb_build_object('ok', false, 'error', 'User not found');
  end if;

  if u.banned_at is not null then
    return jsonb_build_object('ok', false, 'error', 'Account banned permanently');
  end if;

  if u.password_hash <> crypt(p_password, u.password_hash) then
    return jsonb_build_object('ok', false, 'error', 'Wrong password');
  end if;

  update public.users set last_seen = now() where id = u.id;

  return jsonb_build_object(
    'ok', true,
    'user_id', u.id,
    'username', u.username,
    'is_admin', (lower(u.username) = 'thomas' or u.is_admin),
    'is_owner', (lower(u.username) = 'thomas')
  );
end;
$$;

-- Heartbeat: reject banned
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
  if not exists (select 1 from public.users where id = p_user_id and banned_at is null) then
    return;
  end if;

  if p_session_code is not null and upper(trim(p_session_code)) = 'CLEAR' then
    update public.users
    set last_seen = now(), active_session_code = null
    where id = p_user_id and banned_at is null;
  elsif p_session_code is not null and length(trim(p_session_code)) > 0 then
    update public.users
    set last_seen = now(), active_session_code = upper(trim(p_session_code))
    where id = p_user_id and banned_at is null;
  else
    update public.users set last_seen = now() where id = p_user_id and banned_at is null;
  end if;
end;
$$;

-- Profile avatar: allow emoji or https URL
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

  if not exists (select 1 from public.users where id = p_user_id and banned_at is null) then
    return jsonb_build_object('ok', false, 'error', 'Account banned');
  end if;

  if length(av) < 1 or length(av) > 512 then
    return jsonb_build_object('ok', false, 'error', 'Invalid avatar');
  end if;

  if av like 'http://%' or av like 'https://%' then
    null;
  elsif length(av) > 16 then
    return jsonb_build_object('ok', false, 'error', 'Invalid avatar');
  end if;

  update public.users set avatar = av where id = p_user_id;

  return jsonb_build_object('ok', true, 'avatar', av);
end;
$$;

-- Dashboard: owner OR admin; Thomas gets extra fields
create or replace function public.admin_dashboard_snapshot(p_user_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  is_owner boolean;
  is_admin boolean;
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

  select public._caller_is_owner(p_user_id) into is_owner;
  select public._caller_is_admin_or_owner(p_user_id) into is_admin;

  if not is_admin then
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
      'is_admin', (lower(u.username) = 'thomas' or u.is_admin),
      'banned', u.banned_at is not null
    ) order by u.last_seen desc
  ), '[]'::jsonb)
  from (
    select username, last_seen, is_admin, banned_at
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
      'is_admin', (lower(u.username) = 'thomas' or u.is_admin),
      'banned', u.banned_at is not null
    ) order by u.last_seen desc
  ), '[]'::jsonb)
  from (
    select username, last_seen, is_admin, banned_at
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
      'last_seen', to_char(u.last_seen at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
      'is_admin', (lower(u.username) = 'thomas' or u.is_admin),
      'is_owner', lower(u.username) = 'thomas',
      'banned', u.banned_at is not null,
      'win_count', coalesce(u.win_count, 0)
    ) order by lower(u.username)
  ), '[]'::jsonb)
  from public.users u
  into all_accounts;

  return jsonb_build_object(
    'ok', true,
    'is_owner', is_owner,
    'is_admin', is_admin,
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

create or replace function public.admin_promote_user(
  p_user_id uuid,
  p_target_username text
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  tid uuid;
  tun text := lower(trim(p_target_username));
begin
  if not public._caller_is_owner(p_user_id) then
    return jsonb_build_object('ok', false, 'error', 'Only Thomas can promote admins');
  end if;

  select id into tid from public.users where username = tun;
  if tid is null then
    return jsonb_build_object('ok', false, 'error', 'User not found');
  end if;

  if tun = 'thomas' then
    return jsonb_build_object('ok', false, 'error', 'Thomas is already the owner');
  end if;

  update public.users set is_admin = true where id = tid;

  return jsonb_build_object('ok', true, 'username', tun, 'is_admin', true);
end;
$$;

create or replace function public.admin_ban_user(
  p_user_id uuid,
  p_target_username text,
  p_reason text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  tid uuid;
  tun text := lower(trim(p_target_username));
  reason text := nullif(trim(coalesce(p_reason, '')), '');
begin
  if not public._caller_is_owner(p_user_id) then
    return jsonb_build_object('ok', false, 'error', 'Only Thomas can ban accounts');
  end if;

  if exists (select 1 from public.users where id = p_user_id and lower(username) = tun) then
    return jsonb_build_object('ok', false, 'error', 'You cannot ban your own account');
  end if;

  select id into tid from public.users where username = tun;
  if tid is null then
    return jsonb_build_object('ok', false, 'error', 'User not found');
  end if;

  if tun = 'thomas' then
    return jsonb_build_object('ok', false, 'error', 'Cannot ban the owner account');
  end if;

  update public.users
  set banned_at = now(),
      ban_reason = coalesce(reason, 'Banned by owner'),
      active_session_code = null,
      is_admin = false
  where id = tid;

  return jsonb_build_object('ok', true, 'username', tun, 'banned', true);
end;
$$;

grant execute on function public.admin_promote_user(uuid, text) to anon, authenticated;
grant execute on function public.admin_ban_user(uuid, text, text) to anon, authenticated;

-- Avatar uploads (public read)
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'avatars',
  'avatars',
  true,
  524288,
  array['image/jpeg', 'image/png', 'image/webp', 'image/gif']
)
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "avatars_public_read" on storage.objects;
create policy "avatars_public_read"
  on storage.objects for select
  using (bucket_id = 'avatars');

drop policy if exists "avatars_anon_upload" on storage.objects;
create policy "avatars_anon_upload"
  on storage.objects for insert
  with check (bucket_id = 'avatars');

drop policy if exists "avatars_anon_update" on storage.objects;
create policy "avatars_anon_update"
  on storage.objects for update
  using (bucket_id = 'avatars');

drop policy if exists "avatars_anon_delete" on storage.objects;
create policy "avatars_anon_delete"
  on storage.objects for delete
  using (bucket_id = 'avatars');
