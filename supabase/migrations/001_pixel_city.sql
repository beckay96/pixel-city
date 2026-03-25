-- Pixel City — run in Supabase SQL Editor (or as a migration)
-- Enable required extensions (usually already on)
-- create extension if not exists "pgcrypto";

-- Public profile per auth user (username for friends list)
create table if not exists public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  username text not null unique,
  display_name text,
  last_seen timestamptz default now(),
  updated_at timestamptz default now()
);

create index if not exists idx_profiles_username lower(username);

-- Symmetric friendship: one row per direction so "my friends" is a simple query
create table if not exists public.friends (
  user_id uuid not null references public.profiles (id) on delete cascade,
  friend_id uuid not null references public.profiles (id) on delete cascade,
  created_at timestamptz default now(),
  primary key (user_id, friend_id),
  constraint friends_no_self check (user_id <> friend_id)
);

create index if not exists idx_friends_user on public.friends (user_id);

-- Short join codes for online sessions (shared world seed)
create table if not exists public.game_sessions (
  code text primary key,
  host_id uuid not null references public.profiles (id) on delete cascade,
  world_seed bigint not null,
  updated_at timestamptz default now()
);

-- Auto-create profile on signup
create or replace function public.handle_new_user ()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, username, display_name)
  values (
    new.id,
    coalesce(lower(trim(new.raw_user_meta_data->>'username')), 'user_' || substr(new.id::text, 1, 8)),
    nullif(trim(new.raw_user_meta_data->>'display_name'), '')
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- RLS
alter table public.profiles enable row level security;
alter table public.friends enable row level security;
alter table public.game_sessions enable row level security;

-- Profiles: everyone can read usernames (for friend lookup). Users update own row.
create policy "profiles_select_all" on public.profiles for select using (true);
create policy "profiles_insert_own" on public.profiles for insert with check (auth.uid() = id);
create policy "profiles_update_own" on public.profiles for update using (auth.uid() = id);

-- Friends: see rows where you are user_id or friend_id
create policy "friends_select_own" on public.friends for select
  using (auth.uid() = user_id or auth.uid() = friend_id);
create policy "friends_insert_as_user" on public.friends for insert
  with check (auth.uid() = user_id);
create policy "friends_delete_own" on public.friends for delete
  using (auth.uid() = user_id);

-- Sessions: host can manage; anyone can read by code (for join)
create policy "sessions_select" on public.game_sessions for select using (true);
create policy "sessions_insert_host" on public.game_sessions for insert
  with check (auth.uid() = host_id);
create policy "sessions_update_host" on public.game_sessions for update
  using (auth.uid() = host_id);
create policy "sessions_delete_host" on public.game_sessions for delete
  using (auth.uid() = host_id);

-- Realtime: allow postgres_changes if you use table replication (optional)
-- For Broadcast-only multiplayer you can skip this.

comment on table public.profiles is 'Pixel City player identity';
comment on table public.friends is 'Directed friendship edges (add reciprocal rows in app)';
comment on table public.game_sessions is 'Join code -> shared world seed for online co-op';

-- Add friend both ways (RLS only allows inserting rows where user_id = auth.uid())
create or replace function public.add_friend_by_username (target_username text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  me uuid := auth.uid();
  fid uuid;
  t text := lower(trim(target_username));
begin
  if me is null then raise exception 'not authenticated'; end if;
  select id into fid from public.profiles where username = t;
  if fid is null then raise exception 'user not found'; end if;
  if fid = me then raise exception 'cannot add self'; end if;
  insert into public.friends (user_id, friend_id) values (me, fid) on conflict do nothing;
  insert into public.friends (user_id, friend_id) values (fid, me) on conflict do nothing;
end;
$$;

grant execute on function public.add_friend_by_username (text) to authenticated;
