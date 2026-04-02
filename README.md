# Pixel City

Browser game with **self-hosted UI** (no Tailwind CDN at runtime) and a **vendored Supabase client** (no `esm.sh`). **No payment** in this project.

**Multiplayer:** sign in → **MULTIPLAYER** → **Host — get invite link** (share URL with `?join=CODE`) or type a friend’s code → **Start game**. Same map seed + live positions (Realtime **broadcast**). **2 LOCAL** is split-screen on one device. **Play offline** skips accounts.

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
export SUPABASE_PUBLISHABLE_KEY='sb_publishable_...'
npm run inject:supabase   # writes supabase-config.js
python3 -m http.server 8080
```

(Legacy **`SUPABASE_ANON_KEY`** still works if publishable is unset.)

or run **`python3 dev-server.py 8080`** with the same env vars (it serves a generated **`/supabase-config.js`** and does not write files).

Open [http://localhost:8080](http://localhost:8080). Do not use `file://` for the game; use a local server.

## Deploy (GitHub Pages)

The workflow runs `npm ci`, builds CSS, copies static files, then writes **`supabase-config.js`** **and embeds the same keys inside `index.html`** (marker `<!--SUPABASE_BUILD_INJECT-->`). So sign-in works even if a host only syncs **`index.html`**. No `cdn.tailwindcss.com` or `esm.sh`.

### Fix “server not configured” / wire multiplayer

1. Repo → **Settings** → **Secrets and variables** → **Actions** → add **both**:
   - **`SUPABASE_PROJECT_URL`** (or **`SUPABASE_URL`**) = Supabase **Project URL**
   - **`SUPABASE_PUBLISHABLE_KEY`** = **Publishable key** from **Project Settings → API** (recommended; starts with `sb_publishable_…`)

   Optional legacy: **`SUPABASE_ANON_KEY`** (JWT `eyJ…`) if you do not use publishable keys yet.

2. If deploy uses the **`github-pages` environment**, add the **same secrets** under **Environments → github-pages**.

3. **Actions** → **Deploy to GitHub Pages** → **Run workflow** (or push to `main`).

4. Hard-refresh. **View page source**: you should see `window.__SUPABASE_PUBLISHABLE_KEY__=...` (and a duplicate assign to `__SUPABASE_ANON_KEY__` for backward compatibility).

**Custom domain:** Use the GitHub Actions deploy with secrets, or manually fill **`supabase-config.js`** with URL + publishable key.

**Security:** use only the **publishable** or **anon** client key in the browser — never **`service_role`**.

## Supabase (sign up / sign in, friends, online)

1. Create a [Supabase](https://supabase.com/) project.
2. Run SQL from `supabase/migrations/` in the **SQL Editor**.
3. In **Project Settings → API**, copy **Project URL** and **Publishable key** (preferred).
4. **Production:** GitHub secrets → deploy writes config automatically.
5. **Local:** `npm run inject:supabase` + static server, or **`dev-server.py`**.

## “State-wide blocked” at school — what actually helps

Only your **education department / IT** can remove a statewide block. This repo reduces how many **extra** domains the page hits so approval is easier:

| At page load (game + lobby) | Still needed for multiplayer |
|----------------------------|------------------------------|
| Your game host (e.g. GitHub Pages + custom domain) | Yes |
| `*.supabase.co` (REST + Realtime WebSocket) | Yes, if using accounts / online |

**No longer loaded for basic UI:** `cdn.tailwindcss.com`, `esm.sh`.

**Optional:** `google.com` (PixelPhone Web), `youtube-nocookie.com` (VidKing).

### Text you can send to IT / eSafety

> Please allowlist our educational game host **[your exact URL]** and **\*.supabase.co** for HTTPS and WSS (WebSocket) so students can use optional class accounts and paired play. The site does not use Tailwind CDN or esm.sh; static files are self-hosted.

## PixelPhone Web / VidKing

- **Web:** opens a **new tab** (URLs or Google with `safe=active`).
- **VidKing:** curated embeds on **youtube-nocookie.com**.

## Put it live on pixelcity.quest

GitHub Pages (workflow above) or any static host: upload **`index.html`**, **`supabase-config.js`**, **`assets/`**, **`vendor/`**, **`config.js`**, set custom domain in the host’s settings.
