# AGENTS.md

## Cursor Cloud specific instructions

### Overview

Pixel City is served from `index.html` plus **`assets/tailwind.css`** (built with Tailwind CLI) and **`vendor/supabase.min.js`** (vendored Supabase UMD). Run `npm ci && npm run build:css` before local preview or rely on the GitHub Pages workflow to build CSS. Runtime CDNs **Tailwind** and **esm.sh** are intentionally not used so school filters see fewer third-party domains.

### Running locally (with Supabase)

Use the dev server which serves **`/supabase-config.js`** from environment variables:

```bash
python3 dev-server.py 8080
```

Prefers **`VITE_SUPABASE_URL`** + **`VITE_SUPABASE_PUBLISHABLE_KEY`**, then `SUPABASE_PROJECT_URL` / `SUPABASE_PUBLISHABLE_KEY` / legacy `SUPABASE_ANON_KEY`. Or run `npm run inject:supabase` with env set, then any static server.

Without env vars, use **Play offline**. Ensure `npm run build:css` has been run so `assets/tailwind.css` exists.

### Supabase project

- **Project ref:** `nswxprmypvhyudazenyy`
- **Region:** `ap-northeast-1`
- **MCP config:** `.cursor/mcp.json` (project-scoped) — update to new ref if needed
- **Migrations applied:** `001_pixel_city` through `004_public_server_stats` (custom auth: `users`, `friends`, `game_sessions`, all RPCs including `user_signup`, `user_signin`, `add_friend_by_username`, `remove_friend`, `user_heartbeat`, `admin_dashboard_snapshot`, `public_server_stats`)
- **Auth:** Custom auth via `user_signup`/`user_signin` RPCs — gateway password `feluga`, no Supabase Auth email flow
- **Owner account:** `thomas` / `francis` (created in migration 004)
- **Keys baked into `supabase-config.js`** in source — safe to commit (publishable key only)

### Required secrets

| Secret name | Purpose |
|---|---|
| `VITE_SUPABASE_URL` | **Preferred** in CI — `https://nswxprmypvhyudazenyy.supabase.co` |
| `VITE_SUPABASE_PUBLISHABLE_KEY` | **Preferred** in CI — `sb_publishable_tAQV5FqN4zfUqSzLOj7FtQ_uHW6WsgQ` |
| `SUPABASE_PROJECT_URL` | Fallback URL for deploy scripts |
| `SUPABASE_PUBLISHABLE_KEY` | Fallback publishable key |
| `SUPABASE_ANON_KEY` | Legacy JWT anon key (optional) |
| `PIXELCITY_SUPABASE_DB_PASSWORD` | Database password for psql access |

**Note:** The keys are also baked directly into `supabase-config.js` in the repo so the game works immediately on GitHub Pages without secrets. The GitHub Actions secrets override this during deploy — update them to the new project values above.

### Linting / Tests / Build

There is no linter, test suite, or build step configured in this repo. The deployment pipeline (`.github/workflows/pages.yml`) simply copies `index.html` into a `_site/` folder for GitHub Pages.
