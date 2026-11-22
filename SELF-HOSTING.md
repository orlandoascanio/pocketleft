# Run Pocket on your own server

Pocket for Mac works fine on its own: your money stays in one file on your Mac. If you also want it on your
phone or another computer, give Pocket a server of your own. It's a free Supabase project that only you can
read, and setting it up takes about five minutes.

Your Mac keeps a full copy and keeps working offline. The server is the main copy, so every device agrees.

## 1. Make a Supabase project

1. Create a free account at [supabase.com](https://supabase.com) and make a new project. Any name and region work.
2. Wait until it says the project is ready.

You can also run Supabase yourself with Docker ([guide](https://supabase.com/docs/guides/self-hosting)).
Pocket only needs the database and its REST API.

## 2. Load Pocket's database

Run the files in [`supabase/migrations`](supabase/migrations) **in order** (oldest first). Use either method:

- **SQL editor:** in your project, open *SQL Editor*, paste each file, and click *Run*.
- **Supabase CLI:** from this repository, run `supabase link --project-ref <your-project-ref>` and then
  `supabase db push`.

All tables are locked. Apps can only call Pocket's `pocket_*` functions, and every function except setup and
pairing needs a key that only your devices hold.

## 3. Set up from your Mac

1. In your project, open *Project Settings → API* and copy the **Project URL** and the **publishable** key
   (`sb_publishable_…`, also called the anon key). Never use the secret or service-role key.
2. In Pocket for Mac, open **Settings → Sync → Connect…**, expand **Server**, and paste both.
3. Click **Set Up This Server**.

Pocket creates your account on that server with a random key that never leaves your Mac (it's stored in the
Keychain), then uploads everything that's already on your Mac. Do this right after step 2: until it's done,
the first app to set up an empty server claims it. Once set up, a server refuses any other setup.

## 4. Add your phone

On the Mac, open **Settings → Sync → Pair…**. You get a 6-digit code and a link. Open the link on your phone:
it opens the Pocket web app already pointed at your server, with the code filled in. Tap **Pair**, then
*Add to Home Screen* so it works like an app.

Alternatively, open [pocketleft.app/app](https://pocketleft.app/app/) on any device,
choose **Use your own server**, enter the same URL and publishable key, and type a code.

To host the browser app yourself, publish the contents of [`web/public/app/`](web/public/app/) on a static host
and serve it at a URL ending in `/` so its relative asset links resolve. The pairing link from the Mac opens
`pocketleft.app`, so open your own web app URL and pair with the six-digit code when using your deployment.

## Keep it awake

Free Supabase projects pause after a week with no requests. Pocket for Mac checks in every 30 seconds while
it's running, so a Mac that's on most days keeps the project awake. For a safety net, copy
[`.github/workflows/keepalive.yml`](.github/workflows/keepalive.yml) into your fork and change the URL and
`apikey` to yours. It calls `pocket_ping` once a day, which reveals nothing.

## Removing a device or starting over

- **Remove a device:** Settings → Sync → Devices (Mac), or Settings → Devices (web). A removed device is
  locked out right away.
- **Leave the server:** on the Mac, Settings → Sync → Disconnect. The Mac keeps everything as a local copy.
- **Start over:** delete the Supabase project (or run the migrations on a new one) and set up again.
