// HOS-SHOW-002: render the mockup pages to PNG with Playwright's Chromium (node render_mock.mjs)
import { createRequire } from "node:module";
const require = createRequire(import.meta.url);
const { chromium } = require(process.env.PLAYWRIGHT_MODULE || "playwright");
import { pathToFileURL } from "node:url";
import path from "node:path";

const here = path.dirname(new URL(import.meta.url).pathname);
const pages = [
	["mock_sheet.html", 1480, 1060],
	["mock_sword.html", 1663, 793],
	["mock_pets.html", 1663, 793],
	["mock_emotes.html", 1663, 793],
];
const browser = await chromium.launch({ executablePath: "/opt/pw-browsers/chromium-1194/chrome-linux/chrome" });
for (const [file, w, h] of pages) {
	const page = await browser.newPage({ viewport: { width: w, height: h } });
	await page.goto(pathToFileURL(path.join(here, file)).href);
	await page.evaluate(() => document.fonts.ready);
	await page.screenshot({ path: path.join(here, file.replace(".html", ".png")), fullPage: true });
	await page.close();
}
await browser.close();
console.log("rendered", pages.length, "pages");
