-- Add the first image-backed Dream World home to the existing shop catalog.
insert into public.shop_items (id, name, category, description, price, repeatable)
values (
  'cozy_cabin',
  'Cozy Cabin',
  'Home',
  'A peaceful pixel-art cabin for your dream world.',
  3500,
  false
)
on conflict (id) do nothing;

notify pgrst, 'reload schema';
