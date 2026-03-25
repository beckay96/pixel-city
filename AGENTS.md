# AGENTS.md

## Cursor Cloud specific instructions

### Overview

Pixel City is a single-file browser game (`index.html`) with zero build steps, no package manager, and no installable dependencies. All external libraries (Tailwind CSS, Supabase JS) are loaded from CDNs at runtime.

### Running locally

Start a static file server from the repo root:

```bash
python3 -m http.server 8080
```

Then open `http://localhost:8080`. The game works in offline/guest mode without any Supabase credentials.

### Supabase (optional)

Online features (auth, friends, multiplayer) require a Supabase project. See `README.md` for setup. Without Supabase credentials the game still runs fully in offline mode — the main menu simply offers "Play offline" / local split-screen.

### Linting / Tests / Build

There is no linter, test suite, or build step configured in this repo. The deployment pipeline (`.github/workflows/pages.yml`) simply copies `index.html` into a `_site/` folder for GitHub Pages.
