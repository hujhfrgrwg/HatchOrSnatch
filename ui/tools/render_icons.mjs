// Rasterises icons_src/*.svg to icons/<slug>.png (256 px, transparent) with headless Chromium.
// Run from ui/: node tools/render_icons.mjs   (CHROME env overrides the browser path)
import { chromium } from 'playwright';
import fs from 'fs';
import path from 'path';

const src = 'icons_src', out = 'icons';
fs.mkdirSync(out, { recursive: true });
const b = await chromium.launch({ executablePath: process.env.CHROME || '/opt/pw-browsers/chromium-1194/chrome-linux/chrome' });
const p = await b.newPage({ viewport: { width: 256, height: 256 } });
for (const f of fs.readdirSync(src).filter(f => f.endsWith('.svg'))) {
  await p.setContent(`<html><body style='margin:0;background:transparent'>${fs.readFileSync(path.join(src, f), 'utf8')}</body></html>`);
  await p.screenshot({ path: path.join(out, f.replace('.svg', '.png')), omitBackground: true, clip: { x: 0, y: 0, width: 256, height: 256 } });
}
await b.close();
console.log('rendered', fs.readdirSync(out).length, 'icons');
