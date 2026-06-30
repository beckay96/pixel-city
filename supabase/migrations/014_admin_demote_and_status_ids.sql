-- Demote admins (Thomas only) + return target user_id from admin account RPCs

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

  return jsonb_build_object('ok', true, 'username', tun, 'user_id', tid, 'is_admin', true);
end;
$$;

create or replace function public.admin_demote_user(
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
    return jsonb_build_object('ok', false, 'error', 'Only Thomas can remove admins');
  end if;

  if tun = 'thomas' then
    return jsonb_build_object('ok', false, 'error', 'Cannot remove owner admin status');
  end if;

  select id into tid from public.users where username = tun;
  if tid is null then
    return jsonb_build_object('ok', false, 'error', 'User not found');
  end if;

  update public.users set is_admin = false where id = tid;

  return jsonb_build_object('ok', true, 'username', tun, 'user_id', tid, 'is_admin', false);
end;
$$;

create or replace function public.admin_unban_user(
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
    return jsonb_build_object('ok', false, 'error', 'Only Thomas can unban accounts');
  end if;

  select id into tid from public.users where username = tun;
  if tid is null then
    return jsonb_build_object('ok', false, 'error', 'User not found');
  end if;

  update public.users
  set banned_at = null,
      ban_reason = null
  where id = tid;

  return jsonb_build_object('ok', true, 'username', tun, 'user_id', tid, 'banned', false);
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

  return jsonb_build_object('ok', true, 'username', tun, 'user_id', tid, 'banned', true);
end;
$$;

grant execute on function public.admin_demote_user(uuid, text) to anon, authenticated;
