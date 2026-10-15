// Rasterises icons_svg/*.svg to icons_raw/<slug>.png (512 px, transparent) with headless Chromium;
// then `python3 tools/outline.py --icons` adds the shared ink edge + drop shadow into icons/.
// Run from ui/: node tools/render_icons.mjs   (CHROME env overrides the browser path)
import { chromium } from 'playwright';
import fs from 'fs';
import path from 'path';

const src = 'icons_svg', out = 'icons_raw';
fs.mkdirSync(out, { recursive: true });
const b = await chromium.launch({ executablePath: process.env.CHROME || '/opt/pw-browsers/chromium-1194/chrome-linux/chrome' });
const p = await b.newPage({ viewport: { width: 512, height: 512 } });
let n = 0;
for (const f of fs.readdirSync(src).filter(f => f.endsWith('.svg'))) {
  await p.setContent(`<html><body style='margin:0;background:transparent'>${fs.readFileSync(path.join(src, f), 'utf8')}</body></html>`);
  await p.screenshot({ path: path.join(out, f.replace('.svg', '.png')), omitBackground: true, clip: { x: 0, y: 0, width: 512, height: 512 } });
  n++;
}
await b.close();
console.log('rendered', n, 'icons');
