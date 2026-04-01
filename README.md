# Pixel City — School Edition

Single-file browser game: open `index.html`. **No payment** or checkout in this project.

For classrooms: the in-game **Web** app only opens **Kiddle** (kids search) or a short **allow list** (Wikipedia, NASA kids, Khan Academy, Scratch, etc.). Random URLs are blocked. **Do not commit Supabase keys** in `index.html`; inject them at deploy time (see below).

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
4. Before loading the game, set on `window` (e.g. in a small inline script above the main module, or via your host’s env injection):

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

## Why a school filter might block the site (even if it worked yesterday)

Common causes:

1. **Category change** — the domain was reclassified (games, social, “unknown”, proxy/anonymizer).
2. **New third-party hosts** — e.g. `esm.sh` (Supabase JS), `cdn.tailwindcss.com`, `youtube-nocookie.com` (VidKing embeds), or `kiddle.co` (Web app). One new blocked host can break part of the page.
3. **Keyword / SSL / policy updates** — filter lists and TLS inspection rules change often.
4. **Stricter “no account / chat” rules** — sign-up, friends, or realtime can trip policies even when the game is harmless.

**For IT:** allowlist your **game origin** first, then only the CDNs you need. To avoid `esm.sh`, bundle `supabase-js` with your deploy or vendor it on the same origin.

## Put it live on pixelcity.quest

Host the static files (e.g. GitHub Pages with `.github/workflows/pages.yml`), inject `window.__SUPABASE_URL__` and `window.__SUPABASE_ANON_KEY__` on the deployed page (never commit keys), and point your domain at the host.
