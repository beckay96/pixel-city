#!/usr/bin/env node
/**
 * Injects window.__SUPABASE_* into index.html at <!--SUPABASE_BUILD_INJECT-->
 * so the game works even if supabase-config.js is missing (e.g. only index.html uploaded).
 */
import fs from 'fs';

const htmlPath = process.argv[2] || '_site/index.html';
const marker = '<!--SUPABASE_BUILD_INJECT-->';

const url = (
    process.env.SUPABASE_URL ||
    process.env.SUPABASE_PROJECT_URL ||
    process.env.NEXT_PUBLIC_SUPABASE_URL ||
    ''
).trim();

const key = (
    process.env.SUPABASE_PUBLISHABLE_KEY ||
    process.env.SUPABASE_ANON_KEY ||
    ''
).trim();

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
    console.log('inject-supabase-inline: no env keys — marker removed (use supabase-config.js or set GitHub secrets)');
}

html = html.replace(marker, block);
fs.writeFileSync(htmlPath, html);
