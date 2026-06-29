-- Unban accounts (Thomas only)

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

  return jsonb_build_object('ok', true, 'username', tun, 'banned', false);
end;
$$;

grant execute on function public.admin_unban_user(uuid, text) to anon, authenticated;
