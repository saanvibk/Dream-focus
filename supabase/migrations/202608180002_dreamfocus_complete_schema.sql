-- DreamFocus schema repair. Safe to run against a project that already has
-- public.wallets: this migration never drops or recreates that table.

-- Reconcile the existing wallet table without changing balances.
alter table public.wallets add column if not exists coins integer not null default 0;
alter table public.wallets add column if not exists updated_at timestamptz not null default now();
do $$ begin
  if not exists (select 1 from pg_constraint where conname = 'wallets_coins_nonnegative') then
    alter table public.wallets add constraint wallets_coins_nonnegative check (coins >= 0) not valid;
  end if;
end $$;
alter table public.wallets validate constraint wallets_coins_nonnegative;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null default 'Dreamer',
  bio text not null default '',
  avatar_url text,
  created_at timestamptz not null default now(),
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

create table if not exists public.goals (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  daily_target_minutes integer not null default 60,
  weekly_target_minutes integer not null default 420,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id)
);

create table if not exists public.user_achievements (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  achievement_id text not null,
  unlocked_at timestamptz not null default now(),
  unique (user_id, achievement_id)
);

create table if not exists public.user_items (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  item_id text not null,
  price_paid integer not null check (price_paid > 0),
  purchased_at timestamptz not null default now(),
  unique (user_id, item_id)
);

do $$ declare t text; begin
  foreach t in array array['profiles','wallets','focus_sessions','goals','user_achievements','user_items'] loop
    execute format('alter table public.%I enable row level security', t);
  end loop;
end $$;

drop policy if exists "profiles own row" on public.profiles;
create policy "profiles own row" on public.profiles for all to authenticated
  using (id = auth.uid()) with check (id = auth.uid());
drop policy if exists "wallet own row" on public.wallets;
create policy "wallet own row" on public.wallets for select to authenticated
  using (user_id = auth.uid());
drop policy if exists "wallet create own row" on public.wallets;
create policy "wallet create own row" on public.wallets for insert to authenticated
  with check (user_id = auth.uid());
drop policy if exists "focus sessions own rows" on public.focus_sessions;
create policy "focus sessions own rows" on public.focus_sessions for select to authenticated
  using (user_id = auth.uid());
drop policy if exists "goals own rows" on public.goals;
create policy "goals own rows" on public.goals for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());
drop policy if exists "achievements own rows" on public.user_achievements;
create policy "achievements own rows" on public.user_achievements for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());
drop policy if exists "user items own rows" on public.user_items;
create policy "user items own rows" on public.user_items for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public
as $$ begin
  insert into public.profiles (id, display_name) values
    (new.id, coalesce(nullif(new.raw_user_meta_data ->> 'display_name', ''), 'Dreamer'))
    on conflict (id) do nothing;
  insert into public.wallets (user_id) values (new.id) on conflict (user_id) do nothing;
  insert into public.goals (user_id) values (new.id) on conflict (user_id) do nothing;
  return new;
end $$;
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users
for each row execute procedure public.handle_new_user();

insert into public.profiles (id) select id from auth.users on conflict (id) do nothing;
insert into public.wallets (user_id) select id from auth.users on conflict (user_id) do nothing;
insert into public.goals (user_id) select id from auth.users on conflict (user_id) do nothing;

notify pgrst, 'reload schema';
