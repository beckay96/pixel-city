#!/usr/bin/env node
/**
 * Injects Supabase URL + anon key into the built index.html for GitHub Pages.
 * Reads SUPABASE_URL and SUPABASE_ANON_KEY from the environment (GitHub Actions secrets).
 * Safe for JWT special characters: config is embedded as JSON with < escaped for HTML.
 */
import fs from 'fs';

const indexPath = process.argv[2] || '_site/index.html';
const url = (process.env.SUPABASE_URL || '').trim();
const key = (process.env.SUPABASE_ANON_KEY || '').trim();

const marker = '<!--PIXEL_CITY_SUPABASE_INJECT-->';

let html = fs.readFileSync(indexPath, 'utf8');
if (!html.includes(marker)) {
    console.error('inject-supabase-config: marker not found in', indexPath);
    process.exit(1);
}

const payload = JSON.stringify({ url, key });
const safeJson = payload.replace(/</g, '\\u003c');

const block = `<!-- supabase-injected-at-deploy -->
<script type="application/json" id="pixel-city-supabase-config">${safeJson}</script>
<script>
(function () {
  var el = document.getElementById('pixel-city-supabase-config');
  if (!el) return;
  try {
    var j = JSON.parse(el.textContent || '{}');
    if (j.url && j.key) {
      window.__SUPABASE_URL__ = j.url;
      window.__SUPABASE_ANON_KEY__ = j.key;
    }
  } catch (e) { console.warn('Pixel City: Supabase config parse failed', e); }
})();
</script>`;

html = html.replace(marker, block);
fs.writeFileSync(indexPath, html);

if (url && key) {
    console.log('inject-supabase-config: injected Supabase URL + anon key (length', key.length, ')');
} else {
    console.log('inject-supabase-config: no SUPABASE_URL / SUPABASE_ANON_KEY — site will show "server not configured" until secrets are set');
}
