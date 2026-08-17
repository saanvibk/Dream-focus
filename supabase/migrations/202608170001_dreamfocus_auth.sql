-- DreamFocus user-owned data. Run this migration in the DreamFocus Supabase project.
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null default 'Dreamer',
  bio text not null default 'Building my dream life one focused session at a time.',
  avatar_url text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

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

alter table public.profiles enable row level security;
alter table public.wallets enable row level security;
alter table public.focus_sessions enable row level security;

drop policy if exists "profiles own row" on public.profiles;
create policy "profiles own row" on public.profiles for all to authenticated
  using (id = (select auth.uid())) with check (id = (select auth.uid()));
drop policy if exists "wallet own row" on public.wallets;
create policy "wallet own row" on public.wallets for select to authenticated
  using (user_id = (select auth.uid()));
drop policy if exists "sessions own rows" on public.focus_sessions;
create policy "sessions own rows" on public.focus_sessions for select to authenticated
  using (user_id = (select auth.uid()));

create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public
as $$
begin
  insert into public.profiles (id, display_name)
  values (new.id, coalesce(nullif(new.raw_user_meta_data ->> 'display_name', ''), 'Dreamer'))
  on conflict (id) do nothing;
  insert into public.wallets (user_id) values (new.id) on conflict (user_id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users
for each row execute procedure public.handle_new_user();

-- Also initialize users that existed before this migration was applied.
insert into public.profiles (id, display_name)
select id, coalesce(nullif(raw_user_meta_data ->> 'display_name', ''), 'Dreamer')
from auth.users on conflict (id) do nothing;
insert into public.wallets (user_id)
select id from auth.users on conflict (user_id) do nothing;

create or replace function public.complete_focus_session(
  p_start_time timestamptz,
  p_end_time timestamptz,
  p_duration_seconds integer
)
returns public.focus_sessions
language plpgsql security definer set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_coins integer;
  v_session public.focus_sessions;
begin
  if v_user_id is null then raise exception 'Authentication required'; end if;
  if p_duration_seconds <= 0 or p_end_time < p_start_time then raise exception 'Invalid focus session'; end if;
  v_coins := floor(p_duration_seconds / 60.0)::integer * 3;
  insert into public.focus_sessions(user_id, start_time, end_time, duration_seconds, coins_earned)
  values (v_user_id, p_start_time, p_end_time, p_duration_seconds, v_coins)
  returning * into v_session;
  insert into public.wallets(user_id, coins) values (v_user_id, v_coins)
  on conflict (user_id) do update set coins = wallets.coins + excluded.coins, updated_at = now();
  return v_session;
end;
$$;

revoke all on function public.complete_focus_session(timestamptz, timestamptz, integer) from public;
grant execute on function public.complete_focus_session(timestamptz, timestamptz, integer) to authenticated;
