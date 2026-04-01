# AGENTS.md

## Cursor Cloud specific instructions

### Overview

Pixel City is served from `index.html` plus **`assets/tailwind.css`** (built with Tailwind CLI) and **`vendor/supabase.min.js`** (vendored Supabase UMD). Run `npm ci && npm run build:css` before local preview or rely on the GitHub Pages workflow to build CSS. Runtime CDNs **Tailwind** and **esm.sh** are intentionally not used so school filters see fewer third-party domains.

### Running locally (with Supabase)

Use the dev server which injects Supabase credentials from environment variables:

```bash
python3 dev-server.py 8080
```

Requires `SUPABASE_PROJECT_URL` and `SUPABASE_PUBLISHABLE_KEY` env vars (configured as Cursor secrets). The server injects `window.__SUPABASE_URL__` and `window.__SUPABASE_ANON_KEY__` into `index.html` before serving.

Without these env vars, the dev server still runs; use **Play offline** for guest mode. Ensure `npm run build:css` has been run so `assets/tailwind.css` exists.

### Supabase project

- **Project ref:** `kmzyxujxdhxblvwbxfvq`
- **Region:** `ap-northeast-1`
- **MCP config:** `.cursor/mcp.json` (project-scoped)
- **Migration:** `supabase/migrations/001_pixel_city.sql` — already applied. Creates `profiles`, `friends`, `game_sessions` tables, RLS policies, triggers, and the `add_friend_by_username` function.
- **Auth:** Email provider enabled, `mailer_autoconfirm` is off (signups require email confirmation unless changed in dashboard)
- **DB connection (direct):** `postgresql://postgres.kmzyxujxdhxblvwbxfvq:[PASSWORD]@aws-1-ap-northeast-1.pooler.supabase.com:5432/postgres` — note `aws-1` not `aws-0`
- **DB connection (pooled):** same host, port `6543`, append `?pgbouncer=true`

### Required secrets

| Secret name | Purpose |
|---|---|
| `SUPABASE_PROJECT_URL` | Project API URL (`https://<ref>.supabase.co`) |
| `SUPABASE_ANON_KEY` | Legacy anon JWT key for client-side auth |
| `SUPABASE_PUBLISHABLE_KEY` | Newer publishable key (fallback in dev-server) |
| `PIXELCITY_SUPABASE_DB_PASSWORD` | Database password for psql access |

### Linting / Tests / Build

There is no linter, test suite, or build step configured in this repo. The deployment pipeline (`.github/workflows/pages.yml`) simply copies `index.html` into a `_site/` folder for GitHub Pages.
