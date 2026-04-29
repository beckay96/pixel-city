#!/usr/bin/env node
/**
 * Writes supabase-config.js for the _site/ deploy folder.
 * Priority: env vars → baked-in supabase-config.js → empty.
 * This means GitHub Actions secrets override the baked-in keys when present,
 * but the site still works if secrets are missing or stale.
 */
import fs from 'fs';
import path from 'path';

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

// If env vars are empty, copy the baked-in supabase-config.js (which has the live project keys)
if (!url || !key) {
    const srcConfig = path.resolve(path.dirname(new URL(import.meta.url).pathname), '..', 'supabase-config.js');
    if (fs.existsSync(srcConfig)) {
        fs.copyFileSync(srcConfig, outPath);
        console.log('write-supabase-config:', outPath, 'copied from baked-in supabase-config.js (no env override)');
    } else {
        const body = `/* Auto-generated — no keys configured. */\nwindow.__SUPABASE_URL__ = "";\nwindow.__SUPABASE_PUBLISHABLE_KEY__ = "";\nwindow.__SUPABASE_ANON_KEY__ = "";\n`;
        fs.writeFileSync(outPath, body, 'utf8');
        console.log('write-supabase-config:', outPath, 'written empty (no env and no baked-in config found)');
    }
} else {
    const body = `/* Auto-generated — do not commit real keys to a public repo. */\nwindow.__SUPABASE_URL__ = ${JSON.stringify(url)};\nwindow.__SUPABASE_PUBLISHABLE_KEY__ = ${JSON.stringify(key)};\nwindow.__SUPABASE_ANON_KEY__ = ${JSON.stringify(key)};\n`;
    fs.writeFileSync(outPath, body, 'utf8');
    console.log('write-supabase-config:', outPath, 'ok (url + key from env)');
}
