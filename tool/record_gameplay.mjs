// Records Keeper of the Cove gameplay for the Play Store preview video.
// Needs: `flutter build web --release --dart-define=KEEPER_PREVIEW=true`
// served at http://localhost:8766/ (the preview flag exposes the semantics tree
// and the #/watch/<night> route where the keeper bot plays), `npm i playwright`,
// `npx playwright install ffmpeg`, Microsoft Edge.
// Output: clips/<name>/*.webm plus marks.json (seconds to keep from each clip).
// tool/make_video.py joins them into store/gameplay.mp4.
import { chromium } from 'playwright';
import fs from 'fs';
import { midYear } from './preview_save.mjs';

const URL = 'http://localhost:8766/';
const VP = { width: 540, height: 960 };
const wait = (p, ms) => p.waitForTimeout(ms);
const btn = (p, name) => p.getByRole('button', { name }).first();
async function tap(p, name, after = 900) {
  await btn(p, name).click({ timeout: 10000 });
  await wait(p, after);
}

const browser = await chromium.launch({ channel: 'msedge' });
// Optional clip names on the command line re-record only those clips.
const only = process.argv.slice(2);
const marks = fs.existsSync('marks.json') ? JSON.parse(fs.readFileSync('marks.json', 'utf8')) : {};

async function clip(name, save, body) {
  if (only.length && !only.includes(name)) return;
  fs.rmSync(`clips/${name}`, { recursive: true, force: true });
  const ctx = await browser.newContext({ viewport: VP, recordVideo: { dir: `clips/${name}`, size: VP } });
  if (save) {
    await ctx.addInitScript((s) => {
      if (!localStorage.getItem('flutter.cove_save_v1')) {
        localStorage.setItem('flutter.cove_save_v1', JSON.stringify(JSON.stringify(s)));
      }
    }, save);
  }
  const t0 = Date.now();
  const p = await ctx.newPage();
  const m = await body(p, () => (Date.now() - t0) / 1000);
  await ctx.close();
  marks[name] = m;
  console.log(name, m);
}

// A — a new player: First Light, the practice sea, the cove, the first night.
await clip('a_first', null, async (p, now) => {
  await p.goto(URL);
  await p.waitForSelector('flutter-view', { timeout: 30000 });
  const start = now() + 0.3;
  await btn(p, 'Next').waitFor({ timeout: 20000 });
  await wait(p, 600);
  // Sweep the practice beam across, then hold it on the boat's line.
  await p.mouse.move(400, 300);
  await p.mouse.down();
  for (let i = 0; i <= 20; i++) { await p.mouse.move(400 - i * 9, 300 + i * 2); await wait(p, 60); }
  for (let i = 0; i < 30; i++) { await p.mouse.move(230 + Math.sin(i / 4) * 6, 330); await wait(p, 100); }
  await p.mouse.up();
  await tap(p, 'Next', 700);
  await tap(p, 'Next', 700);
  await tap(p, 'Begin the watch', 1800);
  await tap(p, /^Tend the Light/, 600);
  // Night 1: hold the beam along the first boats' line, then follow them.
  await p.mouse.move(306, 497);
  await p.mouse.down();
  for (let i = 0; i < 90; i++) { await p.mouse.move(306 + Math.sin(i / 9) * 30, 497 + i * 0.6); await wait(p, 100); }
  await p.mouse.up();
  return { start, end: now() };
});

// B — a winter night with bell buoys, played by the keeper bot.
await clip('b_winter', midYear, async (p, now) => {
  await p.goto(`${URL}#/watch/44`);
  await p.waitForSelector('flutter-view', { timeout: 30000 });
  await wait(p, 22000);
  return { start: now() - 7, end: now() };
});

// C — a convoy night on the Squall Coast.
await clip('c_convoy', midYear, async (p, now) => {
  await p.goto(`${URL}#/watch/30`);
  await p.waitForSelector('flutter-view', { timeout: 30000 });
  await wait(p, 18000);
  return { start: now() - 6, end: now() };
});

// D — the cove, the chart, the Daily Tide, the Chandlery and the log.
await clip('d_tour', midYear, async (p, now) => {
  await p.goto(`${URL}#/hub`);
  await btn(p, /The sea chart/).waitFor({ timeout: 30000 });
  await wait(p, 1500);
  const start = now();
  await wait(p, 1800);
  await tap(p, /The sea chart/, 1600);
  await p.mouse.move(270, 600);
  for (let i = 0; i < 8; i++) { await p.mouse.wheel(0, 140); await wait(p, 90); }
  await wait(p, 600);
  await tap(p, 'Back', 1000);
  await tap(p, /The tide bell/, 2000);
  await tap(p, 'Back', 900);
  await tap(p, /The boathouse/, 1200);
  await tap(p, /^Rose dawn glass/, 900);
  await tap(p, /^Buy for/, 1600);
  await tap(p, 'Back', 1000);
  await tap(p, /logbook/, 1400);
  for (let i = 0; i < 8; i++) { await p.mouse.wheel(0, 160); await wait(p, 90); }
  await wait(p, 700);
  return { start, end: now() };
});

// E — a night kept: the bot brings night 2 home and dawn comes up.
await clip('e_dawn', midYear, async (p, now) => {
  await p.goto(`${URL}#/watch/2`);
  await p.waitForSelector('flutter-view', { timeout: 30000 });
  await p.getByText('Sail on').first().waitFor({ timeout: 90000 });
  // The recording runs a few seconds behind the page; hold on dawn long
  // enough that the cut keeps the night's last boat and the dawn screen.
  const at = now();
  await wait(p, 8000);
  return { start: at + 0.8, end: now() };
});

await browser.close();
fs.writeFileSync('marks.json', JSON.stringify(marks, null, 1));
