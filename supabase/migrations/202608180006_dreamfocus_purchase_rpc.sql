-- Purchase backend. Assumes public.shop_items already exists and is seeded.
-- This migration intentionally does not create or modify the catalog.

create table if not exists public.user_items (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  item_id text not null references public.shop_items(id),
  price_paid integer not null check (price_paid >= 0),
  purchased_at timestamptz not null default now(),
  unique (user_id, item_id)
);

do $$ begin
  if not exists (
    select 1 from pg_constraint
    where conrelid = 'public.user_items'::regclass
      and contype = 'f'
      and pg_get_constraintdef(oid) like '%(item_id)%shop_items%'
  ) then
    alter table public.user_items add constraint user_items_item_id_fkey
      foreign key (item_id) references public.shop_items(id);
  end if;
end $$;

do $$ begin
  if not exists (
    select 1 from pg_constraint
    where conrelid = 'public.user_items'::regclass
      and contype = 'u'
      and pg_get_constraintdef(oid) like '%(user_id, item_id)%'
  ) then
    alter table public.user_items add constraint user_items_user_item_unique unique (user_id, item_id);
  end if;
end $$;

alter table public.user_items enable row level security;
drop policy if exists "user items own rows" on public.user_items;
drop policy if exists "user items own select" on public.user_items;
drop policy if exists "user items own" on public.user_items;
create policy "user items own select" on public.user_items
  for select to authenticated using (user_id = auth.uid());

create or replace function public.purchase_shop_item(p_item_id text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_item public.shop_items%rowtype;
  v_balance integer;
  v_new_balance integer;
begin
  if v_user_id is null then
    raise exception 'Authentication required';
  end if;

  select * into v_item
  from public.shop_items
  where id = p_item_id;
  if not found then
    raise exception 'Item not found';
  end if;

  if not v_item.repeatable and exists (
    select 1 from public.user_items
    where user_id = v_user_id and item_id = v_item.id
  ) then
    raise exception 'Item already owned';
  end if;

  select coins into v_balance
  from public.wallets
  where user_id = v_user_id
  for update;
  if not found then
    raise exception 'Wallet not found';
  end if;
  if v_balance < v_item.price then
    raise exception 'Not enough coins';
  end if;

  v_new_balance := v_balance - v_item.price;
  update public.wallets
  set coins = v_new_balance, updated_at = now()
  where user_id = v_user_id;

  insert into public.user_items(user_id, item_id, price_paid)
  values (v_user_id, v_item.id, v_item.price);

  return jsonb_build_object(
    'item_id', v_item.id,
    'name', v_item.name,
    'price_paid', v_item.price,
    'new_balance', v_new_balance
  );
end;
$$;

revoke all on function public.purchase_shop_item(text) from public;
grant execute on function public.purchase_shop_item(text) to authenticated;
notify pgrst, 'reload schema';
