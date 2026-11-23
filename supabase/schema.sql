-- =====================================================================
-- Lands n Lords: database setup for Supabase
--
-- How to use: Supabase dashboard > SQL Editor > New query > paste this
-- whole file > Run. It is safe to run again after changes.
--
-- What it does
--   * Creates the tables the app uses (listings, listing_contacts, admins)
--     if they do not exist yet, and adds any missing columns.
--   * Replaces ALL access rules (row level security policies) on those
--     three tables with the rules below, so no older, looser rule is left.
--   * Keeps owners' phone numbers private: anyone can read a phone number
--     only for LIVE rent and lease listings (the "directContact" setting
--     in index.html). Sale and BnB numbers are visible only to the owner
--     and to admins; those enquiries come to you.
--   * Makes sure owners cannot approve their own listings: every listing
--     an owner creates or edits goes to "pending" until an admin approves.
--   * Protects locations: for sale and BnB listings the map pin is moved
--     200-350 m from the real spot. The real spot is kept in hidden columns
--     that only the owner and admins can read.
--   * Sets up the public "photos" storage bucket; owners can upload only
--     into their own folder.
--   * Sets up the public "videos" bucket for video tours (one short video per
--     listing, up to 50 MB), with the same owner-folder rule as photos.
--   * Adds an admin-only "verified" flag (shows a Verified badge once you
--     have checked the documents).
--   * Creates the "enquiries" table where the AI assistant saves buyers'
--     and guests' names and numbers for you to call back.
--
-- If you change "directContact" in index.html, change is_public_contact()
-- below to match.
-- =====================================================================

create extension if not exists pgcrypto;

-- ---------- Tables ----------
create table if not exists public.admins (
  user_id uuid primary key references auth.users (id) on delete cascade
);

create table if not exists public.listings (
  id          uuid primary key default gen_random_uuid(),
  public_id   text unique,
  owner_id    uuid references auth.users (id) on delete cascade,
  category    text not null check (category in ('house', 'land')),
  deal        text not null check (deal in ('rent', 'sale', 'lease', 'bnb')),
  title       text not null check (char_length(title) between 1 and 80),
  area        text not null check (char_length(area) between 1 and 60),
  lat         double precision not null check (lat between -90 and 90),
  lng         double precision not null check (lng between -180 and 180),
  price       text check (char_length(price) <= 40),
  details     text check (char_length(details) <= 140),
  description text check (char_length(description) <= 600),
  video       text check (char_length(video) <= 200),
  photos      text[] not null default '{}',
  status      text not null default 'pending' check (status in ('pending', 'active', 'rejected')),
  review_note text,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  constraint land_deals check (category = 'house' or deal in ('sale', 'lease'))
);
-- Columns added after the first version of the app
alter table public.listings add column if not exists review_note text;
alter table public.listings add column if not exists updated_at timestamptz not null default now();
alter table public.listings add column if not exists photos text[] not null default '{}';
alter table public.listings add column if not exists video text;
-- Real location of sale and BnB listings (lat/lng is the public, shifted pin).
alter table public.listings add column if not exists exact_lat double precision;
alter table public.listings add column if not exists exact_lng double precision;
-- Set by admins after checking documents; shows a "Verified" badge.
alter table public.listings add column if not exists verified boolean not null default false;
-- When the admin was emailed about this listing (so each alert is sent once).
alter table public.listings add column if not exists notified_at timestamptz;

create index if not exists listings_status_idx on public.listings (status);
create index if not exists listings_owner_idx on public.listings (owner_id);

create table if not exists public.listing_contacts (
  listing_id  uuid primary key references public.listings (id) on delete cascade,
  owner_name  text check (char_length(owner_name) <= 60),
  owner_phone text check (char_length(owner_phone) <= 15)
);

-- ---------- Helper functions ----------
create or replace function public.is_admin()
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.admins where user_id = auth.uid());
$$;

-- Phone numbers that visitors may see: live rent and lease listings only.
create or replace function public.is_public_contact(lid uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.listings l
    where l.id = lid and l.status = 'active'
      and l.deal in ('rent', 'lease')
  );
$$;

create or replace function public.owns_listing(lid uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.listings l where l.id = lid and l.owner_id = auth.uid());
$$;

grant execute on function public.is_admin() to anon, authenticated;
grant execute on function public.is_public_contact(uuid) to anon, authenticated;
grant execute on function public.owns_listing(uuid) to anon, authenticated;

-- ---------- Rules enforced on every write ----------
-- Changes made in the Supabase dashboard (no signed-in app user) are left alone.
create or replace function public.listings_guard()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  app_user boolean := auth.uid() is not null;
  candidate text;
  ang double precision;
  dist double precision;
begin
  if tg_op = 'INSERT' then
    if app_user then new.owner_id := auth.uid(); end if;
    if app_user and not public.is_admin() then
      new.status := 'pending';
      new.review_note := null;
      new.verified := false;
    end if;
    if app_user then new.notified_at := null; end if;
    if new.public_id is null or new.public_id = '' then
      -- e.g. HR-48213 = House for Rent, LS-90412 = Land for Sale
      loop
        candidate := upper(left(new.category, 1)) || upper(left(new.deal, 1)) || '-'
                     || (10000 + floor(random() * 90000))::int;
        exit when not exists (select 1 from public.listings where public_id = candidate);
      end loop;
      new.public_id := candidate;
    end if;
  else
    new.id := old.id;
    new.owner_id := old.owner_id;
    new.public_id := old.public_id;
    new.created_at := old.created_at;
    new.updated_at := now();
    if app_user then new.notified_at := old.notified_at; end if;
    if app_user and not public.is_admin() then
      -- An owner's edit goes back for review before it shows on the map again,
      -- and the documents need checking again before it is marked verified.
      new.status := 'pending';
      new.review_note := null;
      new.verified := false;
      new.notified_at := null; -- so you get an email about the edit too
    end if;
  end if;

  -- Location. The app always sends the real spot in lat/lng; it is copied to
  -- exact_lat/exact_lng. Rent and lease show the real spot. Sale and BnB show a
  -- point 200-350 m away in a random direction, chosen again only when the real
  -- spot or the deal type changes, so the pin does not jump on every edit.
  if tg_op = 'INSERT' or old.exact_lat is null
     or new.lat is distinct from old.lat or new.lng is distinct from old.lng then
    new.exact_lat := new.lat;
    new.exact_lng := new.lng;
  else
    new.exact_lat := old.exact_lat;
    new.exact_lng := old.exact_lng;
  end if;
  if new.deal in ('rent', 'lease') then
    new.lat := new.exact_lat;
    new.lng := new.exact_lng;
  elsif tg_op = 'INSERT' or old.deal in ('rent', 'lease')
        or new.exact_lat is distinct from old.exact_lat or new.exact_lng is distinct from old.exact_lng then
    ang := random() * 2 * pi();
    dist := 200 + random() * 150;
    new.lat := new.exact_lat + dist * cos(ang) / 111320.0;
    new.lng := new.exact_lng + dist * sin(ang) / (111320.0 * cos(radians(new.exact_lat)));
  else
    new.lat := old.lat;
    new.lng := old.lng;
  end if;
  return new;
end;
$$;

drop trigger if exists listings_guard on public.listings;
create trigger listings_guard before insert or update on public.listings
  for each row execute function public.listings_guard();

-- Fill in hidden real locations for listings made before this version
-- (this also moves existing sale and BnB pins).
update public.listings set lat = lat where exact_lat is null;

-- Visitors and signed-in users can read every column except the real location.
-- The app asks for columns by name; if you add a column, add it here too.
revoke select on public.listings from anon, authenticated;
grant select (id, public_id, owner_id, category, deal, title, area, lat, lng, price, details,
              description, video, photos, status, review_note, verified, created_at, updated_at)
  on public.listings to anon, authenticated;

-- Real locations, for the listing's owner and for admins only.
create or replace function public.exact_locations(ids uuid[])
returns table (id uuid, lat double precision, lng double precision)
language sql stable security definer set search_path = public as $$
  select l.id, coalesce(l.exact_lat, l.lat), coalesce(l.exact_lng, l.lng)
  from public.listings l
  where l.id = any(ids) and (l.owner_id = auth.uid() or public.is_admin());
$$;
revoke execute on function public.exact_locations(uuid[]) from public, anon;
grant execute on function public.exact_locations(uuid[]) to authenticated;

-- ---------- Row level security ----------
alter table public.listings enable row level security;
alter table public.listing_contacts enable row level security;
alter table public.admins enable row level security;

-- Remove every existing rule on these tables, so only the rules below apply.
do $$
declare p record;
begin
  for p in
    select policyname, tablename from pg_policies
    where schemaname = 'public' and tablename in ('listings', 'listing_contacts', 'admins')
  loop
    execute format('drop policy %I on public.%I', p.policyname, p.tablename);
  end loop;
end $$;

-- listings
create policy "listings: read live, own, or as admin" on public.listings
  for select using (status = 'active' or owner_id = auth.uid() or public.is_admin());
create policy "listings: signed-in users add their own" on public.listings
  for insert to authenticated with check (owner_id = auth.uid());
create policy "listings: owner or admin edits" on public.listings
  for update to authenticated
  using (owner_id = auth.uid() or public.is_admin())
  with check (owner_id = auth.uid() or public.is_admin());
create policy "listings: owner or admin deletes" on public.listings
  for delete to authenticated using (owner_id = auth.uid() or public.is_admin());

-- listing_contacts (owner names and phone numbers)
create policy "contacts: public only for live rent/lease, else owner or admin" on public.listing_contacts
  for select using (public.is_public_contact(listing_id) or public.owns_listing(listing_id) or public.is_admin());
create policy "contacts: owner adds" on public.listing_contacts
  for insert to authenticated with check (public.owns_listing(listing_id) or public.is_admin());
create policy "contacts: owner or admin edits" on public.listing_contacts
  for update to authenticated
  using (public.owns_listing(listing_id) or public.is_admin())
  with check (public.owns_listing(listing_id) or public.is_admin());
create policy "contacts: owner or admin deletes" on public.listing_contacts
  for delete to authenticated using (public.owns_listing(listing_id) or public.is_admin());

-- admins: each user can only check whether they themselves are an admin.
-- Add admins from the SQL editor (see README).
create policy "admins: see yourself" on public.admins
  for select to authenticated using (user_id = auth.uid());

-- ---------- Photo storage ----------
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('photos', 'photos', true, 6291456,
        array['image/jpeg', 'image/png', 'image/webp', 'image/heic', 'image/heif'])
on conflict (id) do update
  set public = true,
      file_size_limit = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "photos: owners upload to own folder" on storage.objects;
drop policy if exists "photos: owners or admins delete" on storage.objects;
drop policy if exists "photos: owners or admins list" on storage.objects;

-- Photos are public through their links; this rule only lets owners and
-- admins look up files so they can delete them.
create policy "photos: owners or admins list" on storage.objects
  for select to authenticated
  using (bucket_id = 'photos' and ((storage.foldername(name))[1] = auth.uid()::text or public.is_admin()));

create policy "photos: owners upload to own folder" on storage.objects
  for insert to authenticated
  with check (bucket_id = 'photos' and (storage.foldername(name))[1] = auth.uid()::text);
create policy "photos: owners or admins delete" on storage.objects
  for delete to authenticated
  using (bucket_id = 'photos' and ((storage.foldername(name))[1] = auth.uid()::text or public.is_admin()));

-- ---------- Video tours ----------
-- Free Supabase plans allow files up to 50 MB and 1 GB of storage in total.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('videos', 'videos', true, 52428800,
        array['video/mp4', 'video/quicktime', 'video/webm', 'video/3gpp', 'video/x-m4v'])
on conflict (id) do update
  set public = true,
      file_size_limit = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "videos: owners upload to own folder" on storage.objects;
drop policy if exists "videos: owners or admins delete" on storage.objects;
drop policy if exists "videos: owners or admins list" on storage.objects;
create policy "videos: owners upload to own folder" on storage.objects
  for insert to authenticated
  with check (bucket_id = 'videos' and (storage.foldername(name))[1] = auth.uid()::text);
create policy "videos: owners or admins list" on storage.objects
  for select to authenticated
  using (bucket_id = 'videos' and ((storage.foldername(name))[1] = auth.uid()::text or public.is_admin()));
create policy "videos: owners or admins delete" on storage.objects
  for delete to authenticated
  using (bucket_id = 'videos' and ((storage.foldername(name))[1] = auth.uid()::text or public.is_admin()));

-- ---------- Enquiries saved by the AI assistant ----------
create table if not exists public.enquiries (
  id             uuid primary key default gen_random_uuid(),
  created_at     timestamptz not null default now(),
  name           text not null check (char_length(name) between 1 and 80),
  phone          text not null check (char_length(phone) between 10 and 20),
  listing_id     text check (char_length(listing_id) <= 20),
  message        text check (char_length(message) <= 1000),
  preferred_time text check (char_length(preferred_time) <= 120),
  source         text not null default 'assistant',
  status         text not null default 'new' check (status in ('new', 'handled'))
);
create index if not exists enquiries_created_idx on public.enquiries (created_at desc);
alter table public.enquiries enable row level security;
do $$
declare p record;
begin
  for p in select policyname from pg_policies where schemaname = 'public' and tablename = 'enquiries' loop
    execute format('drop policy %I on public.enquiries', p.policyname);
  end loop;
end $$;
-- Only admins read and update enquiries. Only the assistant (server side) adds them.
create policy "enquiries: admins read" on public.enquiries for select to authenticated using (public.is_admin());
create policy "enquiries: admins update" on public.enquiries for update to authenticated using (public.is_admin()) with check (public.is_admin());
create policy "enquiries: admins delete" on public.enquiries for delete to authenticated using (public.is_admin());

-- ---------- Daily chat limit per visitor (keeps AI costs predictable) ----------
create table if not exists public.assistant_usage (
  key   text not null,
  day   date not null default current_date,
  count int  not null default 0,
  primary key (key, day)
);
alter table public.assistant_usage enable row level security;
create or replace function public.assistant_hit(p_key text)
returns int language sql volatile security definer set search_path = public as $$
  insert into public.assistant_usage as u (key, day, count) values (p_key, current_date, 1)
  on conflict (key, day) do update set count = u.count + 1
  returning count;
$$;
revoke execute on function public.assistant_hit(text) from public, anon, authenticated;

-- ---------- Make yourself an admin (run once, with your own email) ----------
-- insert into public.admins (user_id)
-- select id from auth.users where email = 'you@example.com'
-- on conflict do nothing;
