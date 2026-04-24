#!/usr/bin/env node
/**
 * Writes supabase-config.js (plain JS) so the browser sets window.__SUPABASE_* before the game module runs.
 * Prefers VITE_SUPABASE_URL + VITE_SUPABASE_PUBLISHABLE_KEY (Vite/GitHub naming), then legacy names.
 */
import fs from 'fs';

const outPath = process.argv[2] || 'supabase-config.js';

const url = (
    process.env.VITE_SUPABASE_URL ||
    process.env.SUPABASE_URL ||
    process.env.SUPABASE_PROJECT_URL ||
    process.env.NEXT_PUBLIC_SUPABASE_URL ||
    ''
).trim();

const key = (
    process.env.VITE_SUPABASE_PUBLISHABLE_KEY ||
    process.env.SUPABASE_PUBLISHABLE_KEY ||
    process.env.SUPABASE_ANON_KEY ||
    ''
).trim();

const body = `/* Auto-generated — do not commit real keys to a public repo. */
window.__SUPABASE_URL__ = ${JSON.stringify(url)};
window.__SUPABASE_PUBLISHABLE_KEY__ = ${JSON.stringify(key)};
window.__SUPABASE_ANON_KEY__ = ${JSON.stringify(key)};
`;

fs.writeFileSync(outPath, body, 'utf8');

if (url && key) {
    console.log('write-supabase-config:', outPath, 'ok (url + key set)');
} else {
    console.log('write-supabase-config:', outPath, 'written with empty url/key (add env or GitHub secrets)');
}
