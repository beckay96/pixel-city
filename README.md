# Pixel City

Browser game with **self-hosted UI** (no Tailwind CDN at runtime) and a **vendored Supabase client** (no `esm.sh`). **No payment** in this project.

**Multiplayer:** sign in → **MULTIPLAYER** → **Host — get invite link** (share URL with `?join=CODE`) or type a friend’s code → **Start game**. Same map seed + live positions (Realtime **broadcast**). **2 LOCAL** is split-screen on one device. **Play offline** skips accounts.

## School-safe mode (scaffold)

A **placeholder** for policies you will define later (IT allowlists, content rules, in-game web restrictions, and so on). The game already exposes a **School-safe** flag and UI hooks; behavior stays the same until you implement rules in code.

| How to enable | Effect today |
|---------------|--------------|
| `?schoolSafe=1` or `?school=1` in the URL | Sets mode on and persists the choice in `localStorage` (`pixelCitySchoolSafe` = `1` or `0` when you turn it off with `0` / `false`). |
| `localStorage.setItem('pixelCitySchoolSafe', '1')` | Same, without a query string (next load). |
| A script **before** the main module: `window.__PIXELCITY_SCHOOL_SAFE__ = true;` | Highest priority (build-time or inline injection). Skips URL/localStorage. |

- **`state.schoolSafe`**: set on load; use in game logic when you add restrictions.
- **`document.body.dataset.schoolSafe`**: `"1"` or `"0"` for CSS, e.g. `body[data-school-safe="1"] .some-panel { display: none; }`.
- **`applySchoolSafeGameRules()`** in `index.html`: add future school-only behavior here.
- A small **“School mode”** label appears in the top-right and in the lobby when active.

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
export VITE_SUPABASE_URL='https://YOUR_PROJECT.supabase.co'
export VITE_SUPABASE_PUBLISHABLE_KEY='sb_publishable_...'
npm run inject:supabase   # writes supabase-config.js
python3 -m http.server 8080
```

(Fallbacks: **`SUPABASE_PROJECT_URL`** / **`SUPABASE_PUBLISHABLE_KEY`** / legacy **`SUPABASE_ANON_KEY`**.)

or run **`python3 dev-server.py 8080`** with the same env vars (it serves a generated **`/supabase-config.js`** and does not write files).

Open [http://localhost:8080](http://localhost:8080). Do not use `file://` for the game; use a local server.

## Deploy (GitHub Pages)

The workflow runs `npm ci`, builds CSS, copies static files, then writes **`supabase-config.js`** **and embeds the same keys inside `index.html`** (marker `<!--SUPABASE_BUILD_INJECT-->`). So sign-in works even if a host only syncs **`index.html`**. No `cdn.tailwindcss.com` or `esm.sh`.

### Fix “server not configured” / wire multiplayer

**Common mistake:** Secrets under **Codespaces** or **Dependabot** are **not** used by GitHub Pages. You need **Actions** secrets (or **Environment** secrets for `github-pages`).

After each deploy, open **Actions** → latest **Deploy to GitHub Pages** run → check the **Summary** at the bottom: it shows ✅/❌ for whether URL and key were found (no secret values printed).

1. Repo → **Settings** → **Secrets and variables** → **Actions** → add **both** (Vite-style names are checked first by the deploy scripts):
   - **`VITE_SUPABASE_URL`** = Supabase **Project URL** (`https://….supabase.co`)
   - **`VITE_SUPABASE_PUBLISHABLE_KEY`** = **Publishable key** from **Project Settings → API** (`sb_publishable_…`)

   Fallbacks: **`SUPABASE_PROJECT_URL`** + **`SUPABASE_PUBLISHABLE_KEY`**, or **`SUPABASE_ANON_KEY`** (JWT).

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

### “Server not configured” on the live site

The game only works online if the **deployed** files contain your Supabase **Project URL** and **publishable** (or legacy anon) key. If they are empty, you see that message when you tap **Sign in**.

1. **Fix for everyone (proper):** In the GitHub repo, **Settings → Secrets and variables → Actions** (and if you use the `github-pages` **Environment**, the same variables there): add **`VITE_SUPABASE_URL`** and **`VITE_SUPABASE_PUBLISHABLE_KEY`**. Push to `main` or run **Actions → Deploy to GitHub Pages → Run workflow**. **Codespaces-only secrets do not apply** to Pages.

**Developer / one-browser test (not shown in the public game UI):** In the browser devtools console on this origin, you can set optional overrides then reload:  
`localStorage.setItem('pixelCitySupabaseUrl', 'https://YOUR_PROJECT.supabase.co')` and `localStorage.setItem('pixelCitySupabaseKey', 'YOUR_PUBLISHABLE_KEY')`  
To clear: `localStorage.removeItem('pixelCitySupabaseUrl')` and `localStorage.removeItem('pixelCitySupabaseKey')`. Use only the **publishable** (or legacy anon) client key — never **service_role**.

### Owner dashboard (username `thomas` only)

1. Run **`supabase/migrations/003_admin_dashboard.sql`** then **`004_admin_online_now.sql`** in the SQL Editor (owner dashboard + “online now” count from `last_seen`). Optionally run **`005_thomas_owner_account.sql`** to create the reserved **`thomas`** user with password **`francis`** (skipped if the row already exists). If you created `thomas` earlier, update the password in SQL:  
   `update public.users set password_hash = crypt('francis', gen_salt('bf')) where username = 'thomas';`
2. **Gateway password** (first field on sign-in): this is **not** your user password. It is checked against `app_config` (migration **002** seeds **`feluga`**; change the hash in Supabase if you want a different site-wide gate).
3. Sign in: gateway + username **`thomas`** + your user password. A **chart** button (owner dashboard) appears. `thomas` is treated as **owner admin** (PixelPhone `/notice`, dashboard **Broadcast to everyone**): a popup is sent to **all signed-in clients** over a global Realtime channel (separate from friend session codes). Guests / offline do not receive it.
4. If sign-in still fails, confirm the deploy injected **`VITE_SUPABASE_URL`** + **`VITE_SUPABASE_PUBLISHABLE_KEY`**, then hard-refresh.

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
