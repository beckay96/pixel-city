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
```

**Multiplayer locally:** either

```bash
export SUPABASE_PROJECT_URL='https://YOUR_PROJECT.supabase.co'
export SUPABASE_ANON_KEY='YOUR_ANON_KEY'
npm run inject:supabase   # writes supabase-config.js
python3 -m http.server 8080
```

or run **`python3 dev-server.py 8080`** with the same env vars (it serves a generated **`/supabase-config.js`** and does not write files).

Open [http://localhost:8080](http://localhost:8080). Do not use `file://` for the game; use a local server.

## Deploy (GitHub Pages)

The workflow runs `npm ci`, builds CSS, copies static files, then writes **`supabase-config.js`** **and embeds the same keys inside `index.html`** (marker `<!--SUPABASE_BUILD_INJECT-->`). So sign-in works even if a host only syncs **`index.html`** (e.g. some custom-domain setups). No `cdn.tailwindcss.com` or `esm.sh`.

### Fix “server not configured” / wire multiplayer

1. Repo → **Settings** → **Secrets and variables** → **Actions** → add **both**:
   - **`SUPABASE_PROJECT_URL`** (or **`SUPABASE_URL`**) = Supabase **Project URL**
   - **`SUPABASE_ANON_KEY`** (or **`SUPABASE_PUBLISHABLE_KEY`**) = **anon public** key from **Project Settings → API**

2. If deploy uses the **`github-pages` environment**, add the **same secrets** under **Environments → github-pages** (repository secrets alone are sometimes ignored).

3. **Actions** → **Deploy to GitHub Pages** → **Run workflow** (or push to `main`).

4. Hard-refresh the site. **View page source** of the homepage: you should see a `<script>window.__SUPABASE_URL__=...` line (not only empty `supabase-config.js`). Also check **`/supabase-config.js`**.

**Custom domain (e.g. pixelcity.best):** Either point DNS at **GitHub Pages** and use the Actions deploy above (secrets on **github-pages** environment if needed), **or** if you upload by hand you must upload **`assets/`**, **`vendor/`**, **`supabase-config.js`**, and **`index.html`** — or use an **`index.html`** produced by the workflow (keys are inside it after deploy).

**Manual static host:** fill **`supabase-config.js`** with your URL + anon key; upload the full folder. Do **not** commit real keys to a **public** repo.

**Security:** use only the **anon** / **publishable** key; never the **service_role** key in the browser.

## Supabase (sign up / sign in, friends, online)

1. Create a [Supabase](https://supabase.com/) project.
2. Run SQL from `supabase/migrations/` in the **SQL Editor** as documented in your migrations.
3. Copy **Project URL** and **anon public** key from **Project Settings → API**.
4. **Production:** GitHub secrets → deploy writes **`supabase-config.js`** automatically.
5. **Local:** `npm run inject:supabase` + static server, or **`dev-server.py`** with env vars (see above).

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

GitHub Pages (workflow above) or any static host: upload **`index.html`**, **`supabase-config.js`** (with keys filled in), **`assets/`**, **`vendor/`**, **`config.js`**, set custom domain in the host’s settings.
