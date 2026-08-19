-- Repair migration for projects where the original auth migration was not
-- applied. This is idempotent and preserves existing wallet balances.
create table if not exists public.wallets (
  user_id uuid primary key references auth.users(id) on delete cascade,
  coins integer not null default 0 check (coins >= 0),
  updated_at timestamptz not null default now()
);

create table if not exists public.focus_sessions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  start_time timestamptz not null,
  end_time timestamptz not null,
  duration_seconds integer not null check (duration_seconds > 0),
  coins_earned integer not null check (coins_earned >= 0),
  created_at timestamptz not null default now(),
  constraint focus_sessions_time_order check (end_time >= start_time)
);

alter table public.wallets enable row level security;
alter table public.focus_sessions enable row level security;

drop policy if exists "wallet own row" on public.wallets;
create policy "wallet own row" on public.wallets for select to authenticated
  using (user_id = (select auth.uid()));
drop policy if exists "wallet create own row" on public.wallets;
create policy "wallet create own row" on public.wallets for insert to authenticated
  with check (user_id = (select auth.uid()));
drop policy if exists "sessions own rows" on public.focus_sessions;
create policy "sessions own rows" on public.focus_sessions for select to authenticated
  using (user_id = (select auth.uid()));

-- Existing balances are preserved; only missing users receive a zero wallet.
insert into public.wallets (user_id)
select id from auth.users on conflict (user_id) do nothing;

-- Return the committed wallet total from the atomic completion transaction.
drop function if exists public.complete_focus_session(timestamptz, timestamptz, integer);
create or replace function public.complete_focus_session(
  p_start_time timestamptz,
  p_end_time timestamptz,
  p_duration_seconds integer
)
returns jsonb
language plpgsql security definer set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_coins integer;
  v_balance integer;
begin
  if v_user_id is null then raise exception 'Authentication required'; end if;
  if p_duration_seconds <= 0 or p_end_time < p_start_time then raise exception 'Invalid focus session'; end if;
  v_coins := floor(p_duration_seconds / 60.0)::integer * 3;
  insert into public.wallets(user_id) values (v_user_id) on conflict (user_id) do nothing;
  insert into public.focus_sessions(user_id, start_time, end_time, duration_seconds, coins_earned)
    values (v_user_id, p_start_time, p_end_time, p_duration_seconds, v_coins);
  select coins into v_balance from public.wallets where user_id = v_user_id for update;
  v_balance := v_balance + v_coins;
  update public.wallets set coins = v_balance, updated_at = now() where user_id = v_user_id;
  return jsonb_build_object('new_balance', v_balance, 'coins_earned', v_coins);
end;
$$;
revoke all on function public.complete_focus_session(timestamptz, timestamptz, integer) from public;
grant execute on function public.complete_focus_session(timestamptz, timestamptz, integer) to authenticated;
