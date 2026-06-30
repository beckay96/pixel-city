#!/usr/bin/env node
/**
 * Writes supabase-config.js for the _site/ deploy folder.
 * Priority: env vars → baked-in supabase-config.js → empty.
 * Stale/deprecated project refs in env are ignored so GitHub Pages uses the migrated DB.
 */
import fs from 'fs';
import path from 'path';

const outPath = process.argv[2] || 'supabase-config.js';
const srcConfig = path.resolve(path.dirname(new URL(import.meta.url).pathname), '..', 'supabase-config.js');

/** Legacy GitHub Pages secret pointed here — missing newer RPCs (list_public_servers, etc.). */
const DEPRECATED_PROJECT_REFS = ['kmzyxujxdhxblvwbxfvq'];

function readBakedConfig() {
    if (!fs.existsSync(srcConfig)) return { url: '', key: '' };
    const src = fs.readFileSync(srcConfig, 'utf8');
    const mUrl = src.match(/window\.__SUPABASE_URL__\s*=\s*"([^"]+)"/);
    const mKey = src.match(/window\.__SUPABASE_PUBLISHABLE_KEY__\s*=\s*"([^"]+)"/);
    return {
        url: (mUrl && mUrl[1] || '').trim(),
        key: (mKey && mKey[1] || '').trim(),
    };
}

let url = (
    process.env.VITE_SUPABASE_URL ||
    process.env.SUPABASE_URL ||
    process.env.SUPABASE_PROJECT_URL ||
    process.env.NEXT_PUBLIC_SUPABASE_URL ||
    ''
).trim();

let key = (
    process.env.VITE_SUPABASE_PUBLISHABLE_KEY ||
    process.env.SUPABASE_PUBLISHABLE_KEY ||
    process.env.SUPABASE_ANON_KEY ||
    ''
).trim();

if (url && DEPRECATED_PROJECT_REFS.some((ref) => url.includes(ref))) {
    console.warn('write-supabase-config: ignoring deprecated Supabase URL from env — using baked-in supabase-config.js');
    url = '';
    key = '';
}

// If env vars are empty, copy the baked-in supabase-config.js (which has the live project keys)
if (!url || !key) {
    const baked = readBakedConfig();
    if (baked.url && baked.key) {
        const body = `/* Auto-generated — do not commit real keys to a public repo. */\nwindow.__SUPABASE_URL__ = ${JSON.stringify(baked.url)};\nwindow.__SUPABASE_PUBLISHABLE_KEY__ = ${JSON.stringify(baked.key)};\nwindow.__SUPABASE_ANON_KEY__ = ${JSON.stringify(baked.key)};\n`;
        fs.writeFileSync(outPath, body, 'utf8');
        console.log('write-supabase-config:', outPath, 'ok (baked-in supabase-config.js)');
    } else if (fs.existsSync(srcConfig)) {
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
