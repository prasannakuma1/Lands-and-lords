# Lands n Lords: setup guide

A step-by-step guide with no coding. Do the parts in order. Each part says roughly how long it takes.
Use a laptop or desktop if you can; these dashboards are hard to use on a phone.

Your app's address will be: **https://prasannakuma1.github.io/Lands-and-lords/**

---

## Part A. Put the app online (5 minutes)

1. Open **github.com/prasannakuma1/Lands-and-lords** and sign in.
2. Click **Settings** (top row of tabs), then **Pages** (left menu).
3. Under **Build and deployment**: Source = **Deploy from a branch**, Branch = **main**, folder = **/(root)**. Click **Save**.
4. Wait 2–3 minutes and refresh. It shows "Your site is live at https://prasannakuma1.github.io/Lands-and-lords/".

✅ Open that address on your phone. You should see the map.

---

## Part B. Set up the database (10 minutes)

1. Open **github.com/prasannakuma1/Lands-and-lords/blob/main/supabase/schema.sql**.
2. Click the **copy icon** ("Copy raw file") at the top right of the file.
3. Go to **supabase.com/dashboard**, sign in, and open your project (its address contains `gnntittzeamfejbhtvdo`).
4. Left menu: **SQL Editor** → **New query**. Paste (Ctrl+V) and click **Run**.
5. You should see **"Success. No rows returned"**. If it warns about "destructive operations", click **Run** again: that is expected (it replaces old access rules).

> Run this file again whenever it is updated in future. It is safe to run more than once.

---

## Part C. Sign-in settings (3 minutes)

1. Supabase left menu: **Authentication** → **URL Configuration**.
2. **Site URL**: `https://prasannakuma1.github.io/Lands-and-lords/` → **Save**.
3. **Redirect URLs** → **Add URL** → paste the same address → **Save**.

This makes "confirm your email" and "reset password" links open your app.

---

## Part D. Make yourself the admin (5 minutes)

1. Open your app → tap **+ Post property** → **Create a new account**. Use your own email.
2. Open the confirmation email and tap the link.
   - No email after 10 minutes? Supabase → **Authentication** → **Sign In / Providers** → **Email** → turn **off** "Confirm email" → Save, then sign up again.
3. Supabase → **SQL Editor** → **New query**. Paste this, **put your email in place of you@example.com**, and click **Run**:
   ```sql
   insert into public.admins (user_id)
   select id from auth.users where email = 'you@example.com'
   on conflict do nothing;
   ```
4. In the app: **My account** → **Sign out**, then sign in again.

✅ **My account** now shows **Review listings** and **Enquiries**.

---

## Part E. Switch on the AI assistant (20 minutes)

**E1. Get a Claude API key**
1. Go to **console.anthropic.com** and create an account.
2. **Settings** → **Billing**: add some credit (pay as you go; start small).
3. **Settings** → **API Keys** → **Create Key**, name it `lands-n-lords`.
4. Copy the key (starts with `sk-ant-`). It is shown only once.
   **Never** put this key in `index.html` or send it to anyone. It goes only into Supabase.

**E2. Give the key to Supabase**
1. Supabase → **Edge Functions** → **Secrets**.
2. Add: Name `ANTHROPIC_API_KEY`, Value = your key → **Save**.
3. Add: Name `BUSINESS_PHONE`, Value `+917780602824` → **Save**.
4. Add: Name `APP_URL`, Value `https://prasannakuma1.github.io/Lands-and-lords/` → **Save**.

**E3. Create the assistant**
1. Open **github.com/prasannakuma1/Lands-and-lords/blob/main/supabase/functions/assistant/index.ts** and click the **copy icon**.
2. Supabase → **Edge Functions** → **Functions** → **Deploy a new function** → **Via Editor**.
3. Delete the sample code, paste yours, set the name to exactly **`assistant`**, click **Deploy function**.
4. **Important:** open the `assistant` function, find **"Enforce JWT Verification"** (Details or Settings tab), switch it **off**, and save. Without this the chat does not work for visitors.

✅ In the app tap **Ask us** and type "Any houses for rent?". A reply should come in a few seconds.

---

## Part F. Email alerts for new leads and listings (10 minutes, recommended)

Without this you only see new enquiries when you open the app (the red number on **My account**).

1. Go to **resend.com** and create a free account **with the email where you want alerts**.
2. **API Keys** → **Create API Key** → copy it (starts with `re_`).
3. Supabase → **Edge Functions** → **Secrets**, add:
   - `RESEND_API_KEY` = the key
   - `ALERT_EMAIL` = the same email you signed up to Resend with
4. Supabase → **Edge Functions** → `assistant` → re-deploy it (open it, then **Deploy** again) so it picks up the new secrets.

✅ Test: in the chat, ask for a site visit and give a name and number. You should get an email titled "New enquiry".

---

## Part G. Test everything (10 minutes)

On your phone:
1. **Post** a test house **for sale**: fill the form, **record a short video**, add a photo, set the location, send.
2. **Approve it**: My account → Review listings → tick **Documents checked** → **Approve**.
3. Find it on the map: it has a dashed "approximate area" circle, **Verified** and **▶ Video tour** badges, and only *your* WhatsApp/Call buttons.
4. Tap **Chat now**, ask a question, then ask for a site visit with a name and number. Check **My account → Enquiries**.
5. Delete the test listing: My account → My listings → Delete (tap twice).

If anything fails, take a screenshot and share it.

---

## Part H. Your daily routine

- **Red number on "My account"**: listings waiting for approval plus new enquiries.
- **Review listings**: check the details, video and photos. Tick **Documents checked** only after you have actually seen the documents (title deed, EC, layout approval). Approve, or Reject with a reason the owner will see.
- **Enquiries**: call or WhatsApp each person, then tap **Mark handled**.
- When an owner edits a listing, it comes back to **Waiting** for you to approve again.

---

## Part I. Before you announce the app publicly

**Legal and business**
- [ ] Register as an agent with **AP RERA** (rera.ap.gov.in → Agent registration).
- [ ] Put your RERA number in the app (see "How to change a setting" below): `reraNumber: "your number"`.
- [ ] Get an advocate to draft a **seller commission agreement** and a **site-visit register**.
- [ ] Load **30–50 real listings** before you advertise.

**Settings**
- [ ] Replace the temporary number with the business number: in `index.html` change `whatsappNumber` (digits only, e.g. `919876543210`) and `callNumber` (e.g. `+919876543210`). Also update the `BUSINESS_PHONE` secret in Supabase.
- [ ] Sign-up emails for many owners: Supabase's built-in email sends only a few per hour. Connect a free email service (e.g. Brevo) in Supabase → **Authentication** → **Emails** → **SMTP settings**.
- [ ] Keep Supabase awake: free projects pause after about a week with no visits. Open the app regularly, or move to the Pro plan once you're live.
- [ ] Storage: the free plan holds about 20–30 video tours. Move to Pro when it fills (Supabase → **Storage** shows usage).
- [ ] Keep some credit in your Anthropic account for the assistant.

---

## How to change a setting (no coding)

1. Open **github.com/prasannakuma1/Lands-and-lords/blob/main/index.html**.
2. Click the **pencil icon** (Edit this file).
3. Press **Ctrl+F** and search for the setting name, e.g. `reraNumber`.
4. Change only the text between the quotes, e.g. `reraNumber: "A/VSP/2026/000123",`
5. Click **Commit changes…** → **Commit changes**. The live app updates in 2–3 minutes.

---

## When there's an update from Claude

1. Open the pull request link you are given and click **Merge pull request** → **Confirm merge**.
2. If `supabase/schema.sql` changed: repeat **Part B**.
3. If `supabase/functions/assistant/index.ts` changed: repeat **Part E3** (paste the new code into the existing `assistant` function and deploy).

---

## If something goes wrong

| Problem | Fix |
| --- | --- |
| Chat says "Sorry, I can't answer right now" | Part E3 step 4 (JWT off); check secret names are spelled exactly; check Anthropic credit |
| "Could not load enquiries" or video upload fails | Run Part B again |
| Sign-up email never arrives | Part D step 2 tip, or set up SMTP (Part I) |
| Map shows no listings | Listings appear only after you approve them |
| A video is rejected | Keep it under 1½ minutes and 50 MB; record in HD (720p/1080p), not 4K |
