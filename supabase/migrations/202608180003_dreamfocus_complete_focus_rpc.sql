-- RPC contract used by lib/services/focus_storage.dart.
-- Argument names intentionally match the Supabase Flutter RPC call.
create or replace function public.complete_focus_session(
  p_duration_seconds integer,
  p_end_time timestamptz,
  p_start_time timestamptz
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_coins integer;
  v_balance integer;
begin
  if v_user_id is null then
    raise exception 'Authentication required';
  end if;
  if p_duration_seconds <= 0 or p_end_time < p_start_time then
    raise exception 'Invalid focus session';
  end if;

  v_coins := floor(p_duration_seconds / 60.0)::integer * 3;

  insert into public.wallets (user_id)
  values (v_user_id)
  on conflict (user_id) do nothing;

  insert into public.focus_sessions (
    user_id, start_time, end_time, duration_seconds, coins_earned
  ) values (
    v_user_id, p_start_time, p_end_time, p_duration_seconds, v_coins
  );

  select coins into v_balance
  from public.wallets
  where user_id = v_user_id
  for update;

  v_balance := coalesce(v_balance, 0) + v_coins;
  if v_balance < 0 then
    raise exception 'Wallet balance cannot be negative';
  end if;

  update public.wallets
  set coins = v_balance, updated_at = now()
  where user_id = v_user_id;

  return jsonb_build_object(
    'new_balance', v_balance,
    'coins_earned', v_coins
  );
end;
$$;

revoke all on function public.complete_focus_session(integer, timestamptz, timestamptz) from public;
grant execute on function public.complete_focus_session(integer, timestamptz, timestamptz) to authenticated;

notify pgrst, 'reload schema';
