# Lands n Lords

Verified houses and lands on a satellite map. Visitors browse pins for houses (rent, sale, lease, BnB stays) and plots (sale, lease), see photos and video, and contact the owner or Lands n Lords on WhatsApp. Owners sign up, post a property for free, and an admin approves it before it appears on the map.

The whole app is one static page (`index.html`), so it can be hosted anywhere that serves files, such as GitHub Pages or Netlify. Accounts, listings and photos live in [Supabase](https://supabase.com).

## Features

**Visitors**
- Satellite or street map; nearby pins group into numbered bubbles when zoomed out
- Filters for Houses and Lands, and for Rent, Sale, Lease and BnB
- Place search with suggestions, and a "near me" view
- List view of listings in the current map area, nearest first
- Listing card with photos (full-screen viewer with swipe), YouTube video, price and details
- Houses for rent: contact the owner directly by call or WhatsApp
- Sale, lease, BnB and plots: a single "Call now" button rings your number, and you connect the caller to the owner. The owner's number is never shown.
- Share links to any listing
- About page with how it works and a plain-language privacy note
- Installable on phones (Add to Home screen), with a link-preview image for WhatsApp shares

**Owners**
- Create an account, sign in, reset a forgotten password
- Post a property: details, location (GPS or tap on the map), up to 4 photos (resized automatically), YouTube link
- My listings: see status, read the reason if a listing was not approved, edit, delete

**Admin**
- Review waiting listings with the owner's contact details, approve, or reject with a reason the owner sees
- Remove live listings from the map, and restore rejected ones

## Setup

### 1. Settings in `index.html`
Open `index.html` and find the `CONFIG` block near the top of the script:

| Setting | What to put |
| --- | --- |
| `whatsappNumber` | Your business WhatsApp number, country code first, digits only, e.g. `919876543210`. **Required:** the main contact buttons do nothing without it. |
| `callNumber` | Number visitors call for sale, lease, BnB and plot listings (you then connect them to the owner). Falls back to `whatsappNumber` if empty. |
| `supabaseUrl`, `supabaseKey` | Your Supabase project URL and publishable (anon) key. Both are public by design. |
| `directContact` | Which listings show the owner's phone to visitors. Default: house rent only. |

### 2. Database (Supabase)
1. Supabase dashboard > **SQL Editor** > New query.
2. Paste all of [`supabase/schema.sql`](supabase/schema.sql) and click **Run**. It is safe to run again later.
3. Make yourself the admin (use the email you signed up with in the app):
   ```sql
   insert into public.admins (user_id)
   select id from auth.users where email = 'you@example.com'
   on conflict do nothing;
   ```

What the SQL file enforces, whatever the app does:
- Owner phone numbers are readable by visitors only for **live house rent** listings. Sale, lease, plot and BnB numbers are seen only by the owner and admins.
- Owners cannot approve their own listings. New listings and any owner edit go to "Waiting" until an admin approves.
- Owners can only edit or delete their own listings and photos.

The script removes all older access rules on the `listings`, `listing_contacts` and `admins` tables so that only these rules apply. If you previously added your own rules for the `photos` storage bucket, check them under **Storage > Policies**.

### 3. Sign-in emails
In Supabase > **Authentication > URL Configuration**:
- Set **Site URL** to the address where the app is hosted.
- Add the same address under **Redirect URLs**, so password-reset and confirmation links come back to the app.

### 4. Host it
For GitHub Pages: repository **Settings > Pages**, deploy from the `main` branch, root folder. Then:
- Update `og:image` in `index.html` to the full address (e.g. `https://yourname.github.io/Lands-and-lords/icons/og-image.jpg`) so WhatsApp shows the preview image.
- Set the Supabase Site URL (step 3) to the Pages address.

## Without Supabase
If `supabaseUrl` is empty, the app reads listings from a Google Sheet published as CSV (`sheetCsvUrl`), or shows sample listings when that is empty too. Owner accounts and posting need Supabase.

## Files
```
index.html              the app (HTML, CSS and JavaScript)
manifest.webmanifest    install-to-home-screen details
icons/                  app icons and the link-preview image
supabase/schema.sql     database tables, access rules and photo storage
```
