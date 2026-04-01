# Pixel City

Single-file browser game: open `index.html`. **No payment** or checkout in this project.

**Multiplayer:** sign in with Supabase, choose **ONLINE**, host or join with a friend code — same world seed and live positions over Realtime **broadcast**. **Play offline** still works for local 1–2 players.

**Admin / secrets:** lobby **Admin Login** (PIN) and **Secret Modes** codes are unchanged (SONIC, RICH, GHOST, MURDER, REALITY, RARITY DROP, GODLY).

## Preview locally

**Fastest:** double-click `index.html` or drag it into Chrome / Firefox / Edge.

**Recommended (auth and Realtime work best over HTTP):**

```bash
cd /path/to/pixel-city
python3 -m http.server 8080
```

Then open [http://localhost:8080](http://localhost:8080).

## Supabase (sign up / sign in, friends, online play)

1. Create a [Supabase](https://supabase.com/) project.
2. Run the SQL in `supabase/migrations/001_pixel_city.sql` in the **SQL Editor** (tables `profiles`, `friends`, `game_sessions`, RLS, trigger, `add_friend_by_username`).
3. In **Project Settings → API**, copy the **Project URL** and **anon public** key.
4. Before loading the game, set on `window` (e.g. a small inline script above the main module, or your host’s env injection). **Never commit real keys** to git.

```html
<script>
  window.__SUPABASE_URL__ = 'https://YOUR_PROJECT.supabase.co';
  window.__SUPABASE_ANON_KEY__ = 'YOUR_ANON_KEY';
</script>
```

5. Enable **Email** auth under **Authentication → Providers** (confirm signups in dev if you turn on email confirmation).

**Behavior:**

- **Sign up / Sign in** uses Supabase Auth (email + password). Sign up asks for a **unique username** (stored in `profiles`).
- **Play offline** skips the account (guest).
- **Friends**: add by username; with Supabase, friendships sync via `add_friend_by_username`. Online/offline dots use `profiles.last_seen` heartbeats.
- **Online** mode: host gets a short **join code** and a **shared world seed** in `game_sessions`; both players join the same Realtime **broadcast** channel for live positions (cross-device). Start the game after host/join.

Realtime uses **Broadcast** only (no database replication toggle required).

## PixelPhone Web app

Opens links in a **new browser tab**: direct **https://** URLs, **www.** hostnames, or **Google search with SafeSearch** (`safe=active`) for plain text. Your school filter still applies to where the tab navigates.

## If the education filter blocks the site

Getting unblocked is usually **allowlisting**, not stripping game features. Common block reasons:

1. **Domain category** (games, social, unknown).
2. **Third-party scripts**: `cdn.tailwindcss.com`, `esm.sh` (Supabase client), `google.com` / `youtube-nocookie.com` (Web / VidKing).

**For IT:** allowlist your **game origin** first, then only what you use: **your Supabase project** (`*.supabase.co`), plus the CDNs above if needed. To reduce external hosts, you can vendor `supabase-js` on the same origin instead of `esm.sh`.

## Put it live on pixelcity.quest

Host the static files (e.g. GitHub Pages with `.github/workflows/pages.yml`), inject `window.__SUPABASE_URL__` and `window.__SUPABASE_ANON_KEY__` on the deployed page, and point your domain at the host.
