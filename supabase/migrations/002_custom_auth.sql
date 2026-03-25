-- Migration: Replace Supabase Auth with custom users table + gateway password
-- Gateway password is hashed and checked server-side via security definer RPCs.

create extension if not exists pgcrypto;

-- Drop old auth-dependent objects
drop trigger if exists on_auth_user_created on auth.users;
drop function if exists public.handle_new_user();

-- Drop old tables (cascade removes friends/game_sessions FKs)
drop table if exists public.friends cascade;
drop table if exists public.game_sessions cascade;
drop table if exists public.profiles cascade;

-- New users table (no dependency on auth.users)
create table public.users (
  id uuid primary key default gen_random_uuid(),
  username text not null unique,
  password_hash text not null,
  display_name text,
  last_seen timestamptz default now(),
  created_at timestamptz default now()
);

create index idx_users_username on public.users (lower(username));

-- Friends (symmetric, same structure)
create table public.friends (
  user_id uuid not null references public.users (id) on delete cascade,
  friend_id uuid not null references public.users (id) on delete cascade,
  created_at timestamptz default now(),
  primary key (user_id, friend_id),
  constraint friends_no_self check (user_id <> friend_id)
);

create index idx_friends_user on public.friends (user_id);

-- Game sessions
create table public.game_sessions (
  code text primary key,
  host_id uuid not null references public.users (id) on delete cascade,
  world_seed bigint not null,
  updated_at timestamptz default now()
);

-- RLS: open reads, writes go through security definer RPCs
alter table public.users enable row level security;
alter table public.friends enable row level security;
alter table public.game_sessions enable row level security;

create policy "users_select_all" on public.users for select using (true);
create policy "friends_select_all" on public.friends for select using (true);
create policy "sessions_select_all" on public.game_sessions for select using (true);
create policy "sessions_insert_anon" on public.game_sessions for insert with check (true);
create policy "sessions_update_anon" on public.game_sessions for update using (true);
create policy "sessions_delete_anon" on public.game_sessions for delete using (true);

-- Gateway password stored as a bcrypt hash (password: feluga)
create table if not exists public.app_config (
  key text primary key,
  value text not null
);
alter table public.app_config enable row level security;
-- No select policy = not readable by anon/public API

insert into public.app_config (key, value)
values ('gateway_hash', crypt('feluga', gen_salt('bf')))
on conflict (key) do update set value = excluded.value;

-- Sign up: checks gateway, hashes password, creates user, returns id + username
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

-- Sign in: checks gateway + credentials, returns id + username
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

  select id, username, password_hash into u
  from public.users
  where username = uname;

  if u is null then
    return jsonb_build_object('ok', false, 'error', 'User not found');
  end if;

  if u.password_hash <> crypt(p_password, u.password_hash) then
    return jsonb_build_object('ok', false, 'error', 'Wrong password');
  end if;

  update public.users set last_seen = now() where id = u.id;

  return jsonb_build_object('ok', true, 'user_id', u.id, 'username', u.username);
end;
$$;

-- Add friend by username (requires caller's user_id)
create or replace function public.add_friend_by_username(
  p_user_id uuid,
  p_target_username text
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  fid uuid;
  t text := lower(trim(p_target_username));
begin
  if p_user_id is null then
    return jsonb_build_object('ok', false, 'error', 'Not authenticated');
  end if;

  select id into fid from public.users where username = t;
  if fid is null then
    return jsonb_build_object('ok', false, 'error', 'User not found');
  end if;
  if fid = p_user_id then
    return jsonb_build_object('ok', false, 'error', 'Cannot add yourself');
  end if;

  insert into public.friends (user_id, friend_id) values (p_user_id, fid) on conflict do nothing;
  insert into public.friends (user_id, friend_id) values (fid, p_user_id) on conflict do nothing;

  return jsonb_build_object('ok', true);
end;
$$;

-- Remove friend
create or replace function public.remove_friend(
  p_user_id uuid,
  p_friend_username text
)
returns void
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  fid uuid;
begin
  select id into fid from public.users where username = lower(trim(p_friend_username));
  if fid is null then return; end if;
  delete from public.friends where user_id = p_user_id and friend_id = fid;
  delete from public.friends where user_id = fid and friend_id = p_user_id;
end;
$$;

-- Heartbeat (update last_seen)
create or replace function public.user_heartbeat(p_user_id uuid)
returns void
language plpgsql
security definer
set search_path = public, extensions
as $$
begin
  update public.users set last_seen = now() where id = p_user_id;
end;
$$;

-- Grant execute to anon role (publishable key uses anon)
grant execute on function public.user_signup(text, text, text) to anon, authenticated;
grant execute on function public.user_signin(text, text, text) to anon, authenticated;
grant execute on function public.add_friend_by_username(uuid, text) to anon, authenticated;
grant execute on function public.remove_friend(uuid, text) to anon, authenticated;
grant execute on function public.user_heartbeat(uuid) to anon, authenticated;

comment on table public.users is 'Pixel City players — custom auth with gateway password';
comment on table public.friends is 'Directed friendship edges';
comment on table public.game_sessions is 'Join code -> shared world seed for online co-op';
