-- Dream World placement is separate from purchase ownership.
-- Existing ownership rows are preserved and backfilled into the world.

create table if not exists public.dream_world_items (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  item_id text not null references public.shop_items(id),
  price_paid integer not null check (price_paid >= 0),
  purchased_at timestamptz not null default now(),
  position_x double precision not null default 0.5,
  position_y double precision not null default 0.5,
  rotation double precision not null default 0,
  scale double precision not null default 1,
  is_placed boolean not null default true,
  unique (user_id, item_id)
);

alter table public.dream_world_items enable row level security;
drop policy if exists "dream world items own" on public.dream_world_items;
create policy "dream world items own" on public.dream_world_items
  for all to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

-- Preserve any existing layout values while moving the layout ownership out
-- of user_items. Missing placements receive sensible defaults.
insert into public.dream_world_items
  (user_id, item_id, price_paid, purchased_at, position_x, position_y, rotation, scale, is_placed)
select u.user_id, u.item_id, u.price_paid, u.purchased_at,
       coalesce(u.position_x, 0.5), coalesce(u.position_y, 0.5),
       coalesce(u.rotation, 0), coalesce(u.scale, 1), coalesce(u.is_placed, true)
from public.user_items u
on conflict (user_id, item_id) do nothing;

-- user_items remains purchase/ownership history only.
alter table public.user_items
  drop column if exists position_x,
  drop column if exists position_y,
  drop column if exists rotation,
  drop column if exists scale,
  drop column if exists is_placed;

create or replace function public.purchase_shop_item(p_item_id text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_user_id uuid := auth.uid();
  v_item public.shop_items%rowtype;
  v_balance integer;
  v_new_balance integer;
begin
  if v_user_id is null then raise exception 'Authentication required'; end if;
  select * into v_item from public.shop_items where id = p_item_id;
  if not found then raise exception 'Item not found'; end if;
  if not v_item.repeatable and exists (
    select 1 from public.user_items where user_id = v_user_id and item_id = v_item.id
  ) then raise exception 'Item already owned'; end if;
  select coins into v_balance from public.wallets where user_id = v_user_id for update;
  if not found then raise exception 'Wallet not found'; end if;
  if v_balance < v_item.price then raise exception 'Not enough coins'; end if;
  v_new_balance := v_balance - v_item.price;
  update public.wallets set coins = v_new_balance, updated_at = now()
    where user_id = v_user_id;
  insert into public.user_items(user_id, item_id, price_paid)
    values (v_user_id, v_item.id, v_item.price);
  insert into public.dream_world_items(user_id, item_id, price_paid, purchased_at)
    values (v_user_id, v_item.id, v_item.price, now());
  return jsonb_build_object('item_id', v_item.id, 'name', v_item.name,
    'price_paid', v_item.price, 'new_balance', v_new_balance);
end;
$$;

revoke all on function public.purchase_shop_item(text) from public;
grant execute on function public.purchase_shop_item(text) to authenticated;
notify pgrst, 'reload schema';
