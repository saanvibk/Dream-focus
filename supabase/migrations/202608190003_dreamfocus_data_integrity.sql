-- Repair Dream World storage without touching purchases, wallets, or sessions.
create table if not exists public.dream_world_items (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  item_id text not null references public.shop_items(id) on delete cascade,
  position_x double precision not null default 0.5,
  position_y double precision not null default 0.5,
  rotation double precision not null default 0,
  scale double precision not null default 1,
  is_placed boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, item_id)
);

alter table public.dream_world_items add column if not exists position_x double precision not null default 0.5;
alter table public.dream_world_items add column if not exists position_y double precision not null default 0.5;
alter table public.dream_world_items add column if not exists rotation double precision not null default 0;
alter table public.dream_world_items add column if not exists scale double precision not null default 1;
alter table public.dream_world_items add column if not exists is_placed boolean not null default true;
alter table public.dream_world_items add column if not exists created_at timestamptz not null default now();
alter table public.dream_world_items add column if not exists updated_at timestamptz not null default now();

alter table public.dream_world_items enable row level security;
drop policy if exists "dream world items own" on public.dream_world_items;
create policy "dream world items own" on public.dream_world_items
  for all to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());

-- The composite key ensures a placement can only exist for an owned item.
do $$ begin
  if not exists (select 1 from pg_constraint where conname = 'user_items_user_item_unique') then
    alter table public.user_items add constraint user_items_user_item_unique unique (user_id, item_id);
  end if;
  if not exists (select 1 from pg_constraint where conname = 'dream_world_items_owned_item_fkey') then
    alter table public.dream_world_items add constraint dream_world_items_owned_item_fkey
      foreign key (user_id, item_id) references public.user_items(user_id, item_id) on delete cascade;
  end if;
end $$;

insert into public.dream_world_items (user_id, item_id)
select u.user_id, u.item_id from public.user_items u
on conflict (user_id, item_id) do nothing;

create or replace function public.purchase_shop_item(p_item_id text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_user_id uuid := auth.uid(); v_item public.shop_items%rowtype;
  v_balance integer; v_new_balance integer;
begin
  if v_user_id is null then raise exception 'Authentication required'; end if;
  select * into v_item from public.shop_items where id = p_item_id;
  if not found then raise exception 'Item not found'; end if;
  if not v_item.repeatable and exists (select 1 from public.user_items where user_id = v_user_id and item_id = v_item.id) then
    raise exception 'Item already owned';
  end if;
  insert into public.wallets(user_id) values (v_user_id) on conflict (user_id) do nothing;
  select coins into v_balance from public.wallets where user_id = v_user_id for update;
  if v_balance < v_item.price then raise exception 'Not enough coins'; end if;
  v_new_balance := v_balance - v_item.price;
  update public.wallets set coins = v_new_balance, updated_at = now() where user_id = v_user_id;
  insert into public.user_items(user_id, item_id, price_paid) values (v_user_id, v_item.id, v_item.price);
  insert into public.dream_world_items(user_id, item_id) values (v_user_id, v_item.id);
  return jsonb_build_object('item_id', v_item.id, 'name', v_item.name, 'price_paid', v_item.price, 'new_balance', v_new_balance);
end; $$;

revoke all on function public.purchase_shop_item(text) from public;
grant execute on function public.purchase_shop_item(text) to authenticated;
notify pgrst, 'reload schema';
