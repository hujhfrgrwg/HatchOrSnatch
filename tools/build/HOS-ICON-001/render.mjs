// HOS-ICON-001 v2: renders emote_crate_3d.html to docs/HOS-ICON-001/emote_crate_icon.png (512 x 512, transparent).
//   npm i three@0.169.0 playwright-core@1.56.1   (in any folder; pass it as NODE_MODULES)
//   NODE_MODULES=/path/to/node_modules node tools/build/HOS-ICON-001/render.mjs [query]
// It copies the page and three.js into a temp folder (the page imports ./vendor/three.module.js), opens it in the
// pre-installed headless Chromium with software WebGL, and screenshots the 512 x 512 stage at 2x, then the caller
// (or PIL) scales it down. Extra query: az / el / dist / lift (camera), e.g. "az=30&el=18".
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { createRequire } from 'node:module';

const here = path.dirname(fileURLToPath(import.meta.url));
const repo = path.resolve(here, '..', '..', '..');
const nm = process.env.NODE_MODULES;
if (!nm) throw new Error('set NODE_MODULES to a node_modules with three and playwright-core');
const require = createRequire(path.join(nm, 'x.js'));
const { chromium } = require('playwright-core');

const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'crate3d-'));
fs.copyFileSync(path.join(here, 'emote_crate_3d.html'), path.join(tmp, 'index.html'));
fs.mkdirSync(path.join(tmp, 'vendor', 'addons', 'geometries'), { recursive: true });
fs.mkdirSync(path.join(tmp, 'vendor', 'addons', 'environments'), { recursive: true });
const three = path.join(nm, 'three');
fs.copyFileSync(path.join(three, 'build', 'three.module.js'), path.join(tmp, 'vendor', 'three.module.js'));
if (fs.existsSync(path.join(three, 'build', 'three.core.js'))) fs.copyFileSync(path.join(three, 'build', 'three.core.js'), path.join(tmp, 'vendor', 'three.core.js'));
for (const f of ['geometries/RoundedBoxGeometry.js', 'environments/RoomEnvironment.js']) {
  fs.copyFileSync(path.join(three, 'examples', 'jsm', f), path.join(tmp, 'vendor', 'addons', f));
}

const exe = ['/opt/pw-browsers/chromium-1194/chrome-linux/chrome', '/opt/pw-browsers/chromium/chrome-linux/chrome']
  .find(p => fs.existsSync(p));
const browser = await chromium.launch({ executablePath: exe, args: ['--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--allow-file-access-from-files'] });
const page = await browser.newPage({ viewport: { width: 512, height: 512 }, deviceScaleFactor: 2 });
const errors = [];
page.on('pageerror', e => errors.push(String(e)));
page.on('console', m => { if (m.type() === 'error') errors.push(m.text()); });
const query = process.argv[2] ? '?' + process.argv[2] : '';
await page.goto('file://' + path.join(tmp, 'index.html') + query);
await page.waitForFunction(() => window.__ready === true, null, { timeout: 60000 }).catch(() => {});
await page.waitForTimeout(400);
const out = path.join(repo, 'docs', 'HOS-ICON-001', process.env.OUT_NAME || 'emote_crate_icon_3d@2x.png');
await page.locator('#stage').screenshot({ path: out, omitBackground: true });
await browser.close();
if (errors.length) console.log('page errors:\n' + errors.join('\n'));
console.log('wrote', out);
