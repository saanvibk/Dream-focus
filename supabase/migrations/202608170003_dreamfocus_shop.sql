create table if not exists public.shop_catalog (
  item_id text primary key, name text not null, category text not null, price integer not null check (price > 0), repeatable boolean not null default false
);
create table if not exists public.user_items (
  id uuid primary key default gen_random_uuid(), user_id uuid not null references auth.users(id) on delete cascade,
  item_id text not null references public.shop_catalog(item_id), purchased_at timestamptz not null default now(), price_paid integer not null check (price_paid > 0),
  unique(user_id, item_id)
);
insert into public.shop_catalog(item_id, name, category, price) values
('cozy_room','Cozy Room','Homes',500),('small_apartment','Small Apartment','Homes',2000),('family_house','Family House','Homes',5000),('dream_villa','Dream Villa','Homes',15000),
('bicycle','Bicycle','Vehicles',300),('scooter','Scooter','Vehicles',1000),('car','Car','Vehicles',5000),('sports_car','Sports Car','Vehicles',15000),
('dog','Dog','Pets',1500),('cat','Cat','Pets',1500),('golden_retriever','Golden Retriever','Pets',3000),
('desk','Desk','Furniture',300),('gaming_setup','Gaming Setup','Furniture',1000),('sofa','Sofa','Furniture',500),('bookshelf','Bookshelf','Furniture',400),
('vacation_trip','Vacation Trip','Lifestyle',3000),('beach_house_upgrade','Beach House Upgrade','Lifestyle',8000),('private_workspace','Private Workspace','Lifestyle',2500)
on conflict (item_id) do update set name = excluded.name, category = excluded.category, price = excluded.price;
alter table public.shop_catalog enable row level security;
alter table public.user_items enable row level security;
drop policy if exists "shop catalog readable" on public.shop_catalog;
create policy "shop catalog readable" on public.shop_catalog for select to authenticated using (true);
drop policy if exists "user items own rows" on public.user_items;
create policy "user items own rows" on public.user_items for select to authenticated using (user_id = (select auth.uid()));
create or replace function public.purchase_shop_item(p_item_id text)
returns jsonb language plpgsql security definer set search_path = public
as $$
declare v_user uuid := auth.uid(); v_price integer; v_repeatable boolean; v_balance integer; v_new integer;
begin
  if v_user is null then raise exception 'Authentication required'; end if;
  select price, repeatable into v_price, v_repeatable from public.shop_catalog where item_id = p_item_id;
  if v_price is null then raise exception 'Item not found'; end if;
  if not v_repeatable and exists(select 1 from public.user_items where user_id = v_user and item_id = p_item_id) then raise exception 'Item already owned'; end if;
  select coins into v_balance from public.wallets where user_id = v_user for update;
  if coalesce(v_balance, 0) < v_price then raise exception 'Not enough coins'; end if;
  v_new := v_balance - v_price;
  update public.wallets set coins = v_new, updated_at = now() where user_id = v_user;
  insert into public.user_items(user_id, item_id, price_paid) values (v_user, p_item_id, v_price);
  return jsonb_build_object('new_balance', v_new);
end;
$$;
revoke all on function public.purchase_shop_item(text) from public;
grant execute on function public.purchase_shop_item(text) to authenticated;
