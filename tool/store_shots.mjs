// Play Store phone screenshots (1080 x 1920) from the web preview build.
// Needs: `flutter build web --release --dart-define=KEEPER_PREVIEW=true`
// served at http://localhost:8766/, `npm i playwright`, Microsoft Edge.
// Usage: node store_shots.mjs <outDir>
import { chromium } from 'playwright';
import fs from 'fs';

const URL = 'http://localhost:8766/';
const out = process.argv[2] || 'store';
fs.mkdirSync(out, { recursive: true });

import { midYear } from './preview_save.mjs';

const shots = [
  { name: '01-hub', route: 'hub', at: 4500 },
  { name: '02-night-winter', route: 'watch/44', at: 21000 },
  { name: '03-night-convoy', route: 'watch/30', at: 17000 },
  { name: '04-night-fog', route: 'watch/16', at: 15000 },
  { name: '05-dawn', route: 'watch/2', at: 36000 },
  { name: '06-sea-chart', route: 'chart', at: 4500 },
  { name: '07-chandlery', route: 'shop', at: 3500 },
];

const browser = await chromium.launch({ channel: 'msedge' });
for (const s of shots) {
  const ctx = await browser.newContext({ viewport: { width: 540, height: 960 }, deviceScaleFactor: 2 });
  await ctx.addInitScript((save) => localStorage.setItem('flutter.cove_save_v1', JSON.stringify(JSON.stringify(save))), midYear);
  const page = await ctx.newPage();
  await page.goto(`${URL}#/${s.route}`);
  await page.waitForSelector('flutter-view', { timeout: 30000 });
  await page.waitForTimeout(s.at);
  await page.screenshot({ path: `${out}/${s.name}.png` });
  console.log('shot', s.name);
  await ctx.close();
}
await browser.close();
