-- Return a friend's active game session code (if they have one updated within 4 hours)
-- Safe: only returns code + updated_at, no private data
CREATE OR REPLACE FUNCTION public.get_friend_session(p_username text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  uid uuid;
  sess record;
BEGIN
  SELECT id INTO uid FROM public.users WHERE username = lower(trim(p_username));
  IF uid IS NULL THEN RETURN jsonb_build_object('ok', false, 'error', 'User not found'); END IF;

  SELECT code, updated_at INTO sess
  FROM public.game_sessions
  WHERE host_id = uid
    AND updated_at > (now() - interval '4 hours')
  ORDER BY updated_at DESC
  LIMIT 1;

  IF sess IS NULL THEN RETURN jsonb_build_object('ok', true, 'code', null); END IF;
  RETURN jsonb_build_object('ok', true, 'code', sess.code, 'updated_at', sess.updated_at);
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_friend_session(text) TO anon, authenticated;
