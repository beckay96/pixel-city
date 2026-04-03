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
| `VITE_SUPABASE_URL` | **Preferred** in CI — same as project URL |
| `VITE_SUPABASE_PUBLISHABLE_KEY` | **Preferred** in CI — publishable key |
| `SUPABASE_PROJECT_URL` | Fallback URL for deploy scripts |
| `SUPABASE_PUBLISHABLE_KEY` | Fallback publishable key |
| `SUPABASE_ANON_KEY` | Legacy JWT anon key (optional) |
| `PIXELCITY_SUPABASE_DB_PASSWORD` | Database password for psql access |

### Linting / Tests / Build

There is no linter, test suite, or build step configured in this repo. The deployment pipeline (`.github/workflows/pages.yml`) simply copies `index.html` into a `_site/` folder for GitHub Pages.
