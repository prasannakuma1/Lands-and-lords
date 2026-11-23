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
- Rent and lease (houses and land): contact the owner directly by WhatsApp or call, with directions
- Sale and BnB: WhatsApp and Call go to your number, so enquiries (and your commission) come through you. The owner's number is never shown.
- BnB booking request with dates and guests, sent on WhatsApp
- Save listings with the heart (kept on the device); list view with Nearest, Newest and Saved
- "New" badge for listings posted in the last 7 days, and how long ago each was listed
- Sale and BnB pins sit about 200–350 m from the real spot, with an "approximate area" circle; the real location is hidden from visitors in the database and only owners and admins can read it
- **AI assistant ("Ask us")**: answers visitors instantly, day and night, in English, Telugu or Hindi. It searches live listings, explains details, shares owner contacts only for rent and lease, and for sale and BnB takes the visitor's name and number and saves an enquiry for you
- Commission guard: phone numbers, emails and WhatsApp links typed into sale or BnB listing text are refused when posting, flagged to the admin, and hidden from visitors
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
- Enquiries inbox: everyone who left their number with the assistant, with WhatsApp and Call buttons and a "handled" marker

## Setup

### 1. Settings in `index.html`
Open `index.html` and find the `CONFIG` block near the top of the script:

| Setting | What to put |
| --- | --- |
| `whatsappNumber` | Your business WhatsApp number, country code first, digits only, e.g. `919876543210`. **Required:** the main contact buttons do nothing without it. |
| `callNumber` | Number visitors call for sale and BnB listings. Falls back to `whatsappNumber` if empty. |
| `supabaseUrl`, `supabaseKey` | Your Supabase project URL and publishable (anon) key. Both are public by design. |
| `directContact` | Which listings show the owner's phone to visitors. Default: rent and lease (houses and land). |

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
- Sale and BnB listings show a map pin 200–350 m from the real spot. The real location is stored in hidden columns that only the owner and admins can read.
- Only admins can read enquiries; only the assistant (server side) can add them.
- Owner phone numbers are readable by visitors only for **live rent and lease** listings. Sale and BnB numbers are seen only by the owner and admins.
- Owners cannot approve their own listings. New listings and any owner edit go to "Waiting" until an admin approves.
- Owners can only edit or delete their own listings and photos.

The script removes all older access rules on the `listings`, `listing_contacts` and `admins` tables so that only these rules apply. If you previously added your own rules for the `photos` storage bucket, check them under **Storage > Policies**.

### 3. AI assistant
The assistant runs as a Supabase Edge Function (`supabase/functions/assistant/index.ts`) and uses Claude through the Anthropic API, so your API key stays on the server.

1. Get an API key at [console.anthropic.com](https://console.anthropic.com) (Settings > API keys) and add billing credit.
2. Supabase > **Edge Functions** > **Secrets**: add `ANTHROPIC_API_KEY` (your key) and `BUSINESS_PHONE` (e.g. `+917780602824`).
3. Supabase > **Edge Functions** > **Deploy a new function** > **Via Editor**. Name it `assistant`, paste the whole of `supabase/functions/assistant/index.ts`, and deploy.
4. Open the function's settings and turn **off** "Enforce JWT verification" (visitors are not signed in).
   - With the Supabase CLI instead: `supabase functions deploy assistant --no-verify-jwt` and `supabase secrets set ANTHROPIC_API_KEY=... BUSINESS_PHONE=...`.
5. Open the app and tap **Ask us**. Enquiries appear under **My account > Enquiries**.

Notes:
- If your Supabase project uses only the new publishable/secret keys, also add secrets `PUBLIC_KEY` (the publishable key) and `SECRET_KEY` (a secret key).
- Cost control: each visitor (by IP address) can send up to 80 messages a day (`DAILY_LIMIT` in the function). The model is set in `MODEL`; Claude Opus 5.5 is used by default with quick ("low effort") replies. If a safety check declines a reply, the API retries on a suitable model automatically.
- The assistant reads listings with the public key, so the database rules apply to it: it cannot see sale or BnB owner numbers or real locations even if a visitor tries to trick it.
- To switch the chat off, set `assistant: false` in `CONFIG`.

### 4. Sign-in emails
In Supabase > **Authentication > URL Configuration**:
- Set **Site URL** to the address where the app is hosted.
- Add the same address under **Redirect URLs**, so password-reset and confirmation links come back to the app.

### 5. Host it
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
supabase/schema.sql     database tables, access rules, photo storage, enquiries
supabase/functions/assistant/index.ts   the AI assistant (Supabase Edge Function)
```
