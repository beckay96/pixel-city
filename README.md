# Pixel City

Single-file browser game: open `index.html`.

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

## Preview locally

**Fastest:** double-click `index.html` or drag it into Chrome / Firefox / Edge.

**Recommended (Firebase and some APIs behave better over HTTP):**

```bash
cd /path/to/pixel-city
python3 -m http.server 8080
```

Then open [http://localhost:8080](http://localhost:8080).

## Sign-in and the real $1 fee

1. Everyone sees a **sign-in** screen first and must enter a **name**.
2. If the name is exactly **`4789`**, the lobby opens with **no payment** (bypass).
3. Any other name requires a **one-time real $1 USD** card payment before the lobby appears. The game stores access in `localStorage` on this browser after a successful return from checkout.

### Stripe Payment Link (required for real charges)

1. In [Stripe Dashboard](https://dashboard.stripe.com/) create a **Payment Link** for a **$1.00** product.
2. Set **After payment → Redirect** to your live site URL **including** the query flag the game expects, for example:  
   `https://pixelcity.quest/?access=paid`  
   (Use your real domain or `http://localhost:8080/?access=paid` while testing.)
3. In `index.html`, set `STRIPE_PAYMENT_LINK_URL` to the full Payment Link URL (the `https://buy.stripe.com/...` string).

Until that constant is set, the **Pay $1 USD** button explains that checkout is not configured yet.

## Put it live on pixelcity.quest

This repo cannot configure your domain or DNS for you. You connect **pixelcity.quest** where you host the files.

### Option A — GitHub Pages (free)

1. Merge `index.html` to your default branch (e.g. `main`).
2. In the repo: **Settings → Pages → Build and deployment → Source: GitHub Actions**.
3. The workflow `.github/workflows/pages.yml` deploys on every push to `main`.
4. **Settings → Pages → Custom domain:** enter `pixelcity.quest`, save, and follow the DNS instructions (usually `CNAME` to `<user>.github.io` or the host GitHub shows).
5. At your domain registrar, add the DNS records GitHub lists. Wait for propagation (often minutes, sometimes up to 48h).

### Option B — Netlify / Cloudflare Pages / Vercel

Connect this GitHub repo, set **publish directory** to the repo root (or `/`), no build command. In the host’s UI, add **custom domain** `pixelcity.quest` and apply the DNS records they give you.

### Option C — Any static host + manual upload

Upload `index.html` to S3, a VPS, etc., then point `pixelcity.quest` at that host with `A`/`CNAME` as your provider documents.

If you say which host you use (GitHub Pages vs Netlify vs Cloudflare, etc.), the exact clicks vary only in that product’s dashboard.
