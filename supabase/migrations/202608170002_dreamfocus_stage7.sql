create table if not exists public.goals (
  id uuid primary key default gen_random_uuid(), user_id uuid not null unique references auth.users(id) on delete cascade,
  daily_target_minutes integer not null default 60 check (daily_target_minutes between 1 and 1440),
  weekly_target_minutes integer not null default 420 check (weekly_target_minutes between 1 and 10080),
  created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table if not exists public.user_achievements (
  id uuid primary key default gen_random_uuid(), user_id uuid not null references auth.users(id) on delete cascade,
  achievement_id text not null, unlocked_at timestamptz not null default now(), unique(user_id, achievement_id)
);
alter table public.goals enable row level security;
alter table public.user_achievements enable row level security;
drop policy if exists "goals own rows" on public.goals;
create policy "goals own rows" on public.goals for all to authenticated using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));
drop policy if exists "achievements own rows" on public.user_achievements;
create policy "achievements own rows" on public.user_achievements for all to authenticated using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));
insert into public.goals (user_id) select id from auth.users on conflict (user_id) do nothing;
