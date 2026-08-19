create table if not exists public.shop_catalog (
  item_id text primary key, name text not null, category text not null,
  price integer not null check (price > 0), repeatable boolean not null default false
);
create table if not exists public.user_items (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  item_id text not null, price_paid integer not null check (price_paid > 0),
  purchased_at timestamptz not null default now(), unique(user_id, item_id)
);
alter table public.shop_catalog enable row level security;
alter table public.user_items enable row level security;
drop policy if exists "shop catalog readable" on public.shop_catalog;
create policy "shop catalog readable" on public.shop_catalog for select to authenticated using (true);
drop policy if exists "user items own rows" on public.user_items;
create policy "user items own rows" on public.user_items for select to authenticated using (user_id = auth.uid());

create or replace function public.purchase_shop_item(p_item_id text)
returns jsonb language plpgsql security definer set search_path = public
as $$
declare v_user uuid := auth.uid(); v_price integer; v_balance integer; v_new integer;
begin
  if v_user is null then raise exception 'Authentication required'; end if;
  select price into v_price from public.shop_catalog where item_id = p_item_id;
  if v_price is null then raise exception 'Item not found'; end if;
  if exists(select 1 from public.user_items where user_id = v_user and item_id = p_item_id) then raise exception 'Already owned'; end if;
  insert into public.wallets(user_id) values (v_user) on conflict (user_id) do nothing;
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
notify pgrst, 'reload schema';
