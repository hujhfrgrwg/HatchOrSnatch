// Renders pages to shots/<page>.png at 2x (headless Chromium). Run from ui/ with the server up:
//   node tools/shoot.mjs [page ...]      (default: every page in index order)
import { chromium } from 'playwright';
import fs from 'fs';
const port = process.env.PORT || 8870;
const pages = process.argv.slice(2).length ? process.argv.slice(2) : fs.readdirSync('.').filter(f => f.endsWith('.html') && f !== 'index.html').map(f => f.slice(0, -5));
fs.mkdirSync('shots', { recursive: true });
const b = await chromium.launch({ executablePath: process.env.CHROME || '/opt/pw-browsers/chromium-1194/chrome-linux/chrome' });
for (const p of pages) {
  const pg = await b.newPage({ viewport: { width: 1920, height: 1080 }, deviceScaleFactor: +(process.env.DPR || 1) });
  await pg.goto(`http://127.0.0.1:${port}/${p}.html?raw`, { waitUntil: 'networkidle' });
  await pg.evaluate(() => document.fonts.ready);
  await pg.waitForTimeout(400);
  const h = await pg.evaluate(() => document.getElementById('stage').offsetHeight);
  await pg.setViewportSize({ width: 1920, height: h });
  const chk = await pg.evaluate(() => checkOverflow());
  await pg.screenshot({ path: `shots/${p}.png`, clip: { x: 0, y: 0, width: 1920, height: h } });
  console.log(p, JSON.stringify(chk));
  await pg.close();
}
await b.close();
