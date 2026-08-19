-- Idempotent schema repair for Dream Life item placement.
-- This migration only adds missing columns/constraints; it never removes or
-- rewrites ownership, wallet, or purchase rows.

alter table public.user_items
  add column if not exists position_x double precision not null default 0.5,
  add column if not exists position_y double precision not null default 0.5,
  add column if not exists rotation double precision not null default 0,
  add column if not exists scale double precision not null default 1,
  add column if not exists is_placed boolean not null default true;

-- Existing rows receive the defaults above. Keep these updates defensive for
-- installations where columns were previously nullable.
update public.user_items
set position_x = coalesce(position_x, 0.5),
    position_y = coalesce(position_y, 0.5),
    rotation = coalesce(rotation, 0),
    scale = coalesce(scale, 1),
    is_placed = coalesce(is_placed, true)
where position_x is null
   or position_y is null
   or rotation is null
   or scale is null
   or is_placed is null;

alter table public.user_items
  alter column position_x set default 0.5,
  alter column position_y set default 0.5,
  alter column rotation set default 0,
  alter column scale set default 1,
  alter column is_placed set default true,
  alter column position_x set not null,
  alter column position_y set not null,
  alter column rotation set not null,
  alter column scale set not null,
  alter column is_placed set not null;

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conrelid = 'public.user_items'::regclass
      and contype = 'f'
      and pg_get_constraintdef(oid) like '%(item_id)%shop_items%'
  ) then
    alter table public.user_items add constraint user_items_item_id_fkey
      foreign key (item_id) references public.shop_items(id);
  end if;

  if not exists (
    select 1 from pg_constraint
    where conrelid = 'public.user_items'::regclass
      and contype = 'u'
      and pg_get_constraintdef(oid) like '%(user_id, item_id)%'
  ) then
    alter table public.user_items add constraint user_items_user_item_unique
      unique (user_id, item_id);
  end if;
end $$;

alter table public.user_items enable row level security;
