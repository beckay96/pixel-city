#!/usr/bin/env node
/**
 * Injects window.__SUPABASE_* into index.html at <!--SUPABASE_BUILD_INJECT-->
 * Priority: env vars → baked-in supabase-config.js values → nothing injected.
 */
import fs from 'fs';
import path from 'path';

const htmlPath = process.argv[2] || '_site/index.html';
const marker = '<!--SUPABASE_BUILD_INJECT-->';

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

// Fall back to the baked-in supabase-config.js when env vars are absent
if (!url || !key) {
    const srcConfig = path.resolve(path.dirname(new URL(import.meta.url).pathname), '..', 'supabase-config.js');
    if (fs.existsSync(srcConfig)) {
        const src = fs.readFileSync(srcConfig, 'utf8');
        const mUrl = src.match(/window\.__SUPABASE_URL__\s*=\s*"([^"]+)"/);
        const mKey = src.match(/window\.__SUPABASE_PUBLISHABLE_KEY__\s*=\s*"([^"]+)"/);
        if (mUrl && !url) url = mUrl[1];
        if (mKey && !key) key = mKey[1];
    }
}

let html = fs.readFileSync(htmlPath, 'utf8');
if (!html.includes(marker)) {
    console.error('inject-supabase-inline: marker missing in', htmlPath);
    process.exit(1);
}

let block = '';
if (url && key) {
    block = `<script>window.__SUPABASE_URL__=${JSON.stringify(url)};window.__SUPABASE_PUBLISHABLE_KEY__=${JSON.stringify(key)};window.__SUPABASE_ANON_KEY__=${JSON.stringify(key)}</script>`;
    console.log('inject-supabase-inline: embedded keys in', htmlPath);
} else {
    console.log('inject-supabase-inline: no keys found — marker removed');
}

html = html.replace(marker, block);
fs.writeFileSync(htmlPath, html);
