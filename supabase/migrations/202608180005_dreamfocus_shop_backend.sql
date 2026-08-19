-- Complete, idempotent Shop backend.  This migration never creates user rows.

create table if not exists public.shop_items (
  id text primary key,
  name text not null,
  category text not null,
  description text,
  price integer not null check (price >= 0),
  repeatable boolean not null default false,
  created_at timestamptz not null default now()
);

insert into public.shop_items (id, name, category, price, repeatable) values
  ('cozy_room','Cozy Room','Home',500,false), ('small_apartment','Small Apartment','Home',2000,false),
  ('family_house','Family House','Home',5000,false), ('dream_villa','Dream Villa','Home',15000,false),
  ('bicycle','Bicycle','Vehicles',300,false), ('scooter','Scooter','Vehicles',1000,false),
  ('car','Car','Vehicles',5000,false), ('sports_car','Sports Car','Vehicles',15000,false),
  ('dog','Dog','Pets',1500,false), ('cat','Cat','Pets',1500,false),
  ('golden_retriever','Golden Retriever','Pets',3000,false), ('desk','Desk','Furniture',300,false),
  ('gaming_setup','Gaming Setup','Furniture',1000,false), ('sofa','Sofa','Furniture',500,false),
  ('bookshelf','Bookshelf','Furniture',400,false), ('vacation_trip','Vacation Trip','Lifestyle',3000,false),
  ('beach_house_upgrade','Beach House Upgrade','Lifestyle',8000,false),
  ('private_workspace','Private Workspace','Lifestyle',2500,false)
on conflict (id) do nothing;

alter table public.shop_items enable row level security;
drop policy if exists "shop items readable" on public.shop_items;
create policy "shop items readable" on public.shop_items for select to anon, authenticated using (true);

create table if not exists public.user_items (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  item_id text not null references public.shop_items(id),
  price_paid integer not null check (price_paid >= 0),
  purchased_at timestamptz not null default now(),
  unique (user_id, item_id)
);

do $$ begin
  if not exists (select 1 from pg_constraint where conname = 'user_items_item_id_fkey') then
    alter table public.user_items add constraint user_items_item_id_fkey
      foreign key (item_id) references public.shop_items(id);
  end if;
end $$;
alter table public.user_items enable row level security;
drop policy if exists "user items own rows" on public.user_items;
drop policy if exists "user items own select" on public.user_items;
create policy "user items own select" on public.user_items for select to authenticated using (user_id = auth.uid());

create or replace function public.purchase_shop_item(p_item_id text)
returns jsonb language plpgsql security definer set search_path = public
as $$
declare v_user uuid := auth.uid(); v_item public.shop_items%rowtype;
  v_balance integer; v_new_balance integer;
begin
  if v_user is null then raise exception 'Authentication required'; end if;
  select * into v_item from public.shop_items where id = p_item_id;
  if not found then raise exception 'Item not found'; end if;
  if not v_item.repeatable and exists (select 1 from public.user_items where user_id = v_user and item_id = v_item.id) then
    raise exception 'Item already owned';
  end if;
  select coins into v_balance from public.wallets where user_id = v_user for update;
  if not found or v_balance < v_item.price then raise exception 'Not enough coins'; end if;
  v_new_balance := v_balance - v_item.price;
  update public.wallets set coins = v_new_balance, updated_at = now() where user_id = v_user;
  insert into public.user_items(user_id, item_id, price_paid) values (v_user, v_item.id, v_item.price);
  return jsonb_build_object('item_id', v_item.id, 'name', v_item.name,
    'price_paid', v_item.price, 'new_balance', v_new_balance);
end $$;
revoke all on function public.purchase_shop_item(text) from public;
grant execute on function public.purchase_shop_item(text) to authenticated;
notify pgrst, 'reload schema';
