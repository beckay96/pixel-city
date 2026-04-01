# Pixel City

Browser game with **self-hosted UI** (no Tailwind CDN at runtime) and a **vendored Supabase client** (no `esm.sh`). **No payment** in this project.

**Multiplayer:** sign in with Supabase → **ONLINE** → host/join code → same map + live positions (Realtime **broadcast**). **Play offline** works for local 1–2 players without Supabase.

**Admin / secrets:** lobby **Admin Login** (PIN) and **Secret Modes** (SONIC, RICH, GHOST, MURDER, REALITY, RARITY DROP, GODLY).

## Run locally (needs built CSS + vendor)

The HTML expects **`assets/tailwind.css`** and **`vendor/supabase.min.js`** next to `index.html`.

```bash
cd /path/to/pixel-city
npm ci
npm run build:css
python3 -m http.server 8080
```

Open [http://localhost:8080](http://localhost:8080).

Opening `index.html` as a `file://` URL may block module scripts; use a local server.

## Deploy (GitHub Pages)

The workflow `.github/workflows/pages.yml` runs `npm ci`, builds CSS, and copies **`index.html`**, **`assets/`**, and **`vendor/`** to the site root. No `cdn.tailwindcss.com` or `esm.sh` on the live page.

## Supabase (sign up / sign in, friends, online)

1. Create a [Supabase](https://supabase.com/) project.
2. Run SQL from `supabase/migrations/` in the **SQL Editor** as documented in your migrations.
3. Copy **Project URL** and **anon public** key from **Project Settings → API**.
4. On the deployed page, set (inject before the game scripts; **never commit keys**):

```html
<script>
  window.__SUPABASE_URL__ = 'https://YOUR_PROJECT.supabase.co';
  window.__SUPABASE_ANON_KEY__ = 'YOUR_ANON_KEY';
</script>
```

## “State-wide blocked” at school — what actually helps

Only your **education department / IT** can remove a statewide block. This repo reduces how many **extra** domains the page hits so approval is easier:

| At page load (game + lobby) | Still needed for multiplayer |
|----------------------------|------------------------------|
| Your game host (e.g. GitHub Pages + custom domain) | Yes |
| `*.supabase.co` (REST + Realtime WebSocket) | Yes, if using accounts / online |

**No longer loaded for basic UI:** `cdn.tailwindcss.com`, `esm.sh`.

**Optional (only if students use these features):** `google.com` (PixelPhone Web), `youtube-nocookie.com` (VidKing). If those stay blocked, the rest of the game can still work; use **Play offline** if sign-in is blocked.

### Text you can send to IT / eSafety

> Please allowlist our educational game host **[your exact URL]** and **\*.supabase.co** for HTTPS and WSS (WebSocket) so students can use optional class accounts and paired play. The site does not use Tailwind CDN or esm.sh; static files are self-hosted. Optional: Google (safe search) and YouTube nocookie embeds for an in-game “browser” and curated video list — we can disable those features if required.

## PixelPhone Web / VidKing

- **Web:** opens a **new tab** (URLs or Google with `safe=active`).
- **VidKing:** curated embeds on **youtube-nocookie.com**.

## Put it live on pixelcity.quest

GitHub Pages (workflow above) or any static host: upload **`index.html`**, **`assets/`**, **`vendor/`**, inject Supabase globals on the live page, set custom domain in the host’s settings.
