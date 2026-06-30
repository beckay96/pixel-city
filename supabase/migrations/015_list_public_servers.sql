-- Browse active multiplayer servers (lobby Servers tab)

create or replace function public.list_public_servers(p_user_id uuid default null)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  result jsonb;
begin
  select coalesce(jsonb_agg(row order by row->>'is_mine' desc, (row->>'updated_at') desc), '[]'::jsonb)
  into result
  from (
    select jsonb_build_object(
      'code', gs.code,
      'host_id', gs.host_id,
      'host_username', u.username,
      'is_mine', (p_user_id is not null and gs.host_id = p_user_id),
      'players_online', (
        select count(*)::int
        from public.users pu
        where pu.active_session_code = gs.code
          and pu.last_seen > (now() - interval '90 seconds')
          and pu.banned_at is null
      ),
      'updated_at', to_char(gs.updated_at at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS"Z"')
    ) as row
    from public.game_sessions gs
    inner join public.users u on u.id = gs.host_id
    where gs.updated_at > (now() - interval '4 hours')
      and u.banned_at is null
  ) sub;

  return jsonb_build_object('ok', true, 'servers', coalesce(result, '[]'::jsonb));
end;
$$;

grant execute on function public.list_public_servers(uuid) to anon, authenticated;

comment on function public.list_public_servers(uuid) is 'Active game_sessions in last 4h with host username and online player count';
