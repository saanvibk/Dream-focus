-- Persistent Dream Life layout. Existing purchases are preserved.
alter table public.user_items add column if not exists position_x double precision not null default 0.5;
alter table public.user_items add column if not exists position_y double precision not null default 0.5;
alter table public.user_items add column if not exists rotation double precision not null default 0;
alter table public.user_items add column if not exists scale double precision not null default 1;
alter table public.user_items add column if not exists is_placed boolean not null default false;

alter table public.user_items enable row level security;
drop policy if exists "user items own layout update" on public.user_items;
create policy "user items own layout update" on public.user_items
  for update to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

notify pgrst, 'reload schema';
