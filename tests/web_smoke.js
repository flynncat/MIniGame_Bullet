// Real-browser smoke test of the exported web build (Edge + playwright-core).
// Usage: node tests/web_smoke.js [url] [outDir]
const path = require('path');
const { chromium } = require('playwright-core');

const URL = process.argv[2] || 'http://127.0.0.1:8765/index.html';
const OUT = process.argv[3] || path.join(__dirname, '..', 'build');
const EDGE = 'C:\\Program Files (x86)\\Microsoft\\Edge\\Application\\msedge.exe';

(async () => {
  const browser = await chromium.launch({
    executablePath: EDGE, headless: true,
    args: ['--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist', '--autoplay-policy=no-user-gesture-required'],
  });
  const page = await browser.newPage({ viewport: { width: 1300, height: 1000 } });
  const errors = [];
  const logs = [];
  page.on('pageerror', e => errors.push('pageerror: ' + e.message));
  page.on('console', m => {
    const t = m.text();
    logs.push('[' + m.type() + '] ' + t);
    if (m.type() === 'error' || /SCRIPT ERROR|ERROR:/.test(t)) errors.push('console: ' + t);
  });
  const t0 = Date.now();
  await page.goto(URL, { waitUntil: 'load' });
  // Godot hides #status once the engine is running.
  await page.waitForFunction(() => {
    const s = document.getElementById('status');
    return !s || getComputedStyle(s).display === 'none' || s.style.visibility === 'hidden';
  }, null, { timeout: 120000 });
  const bootMs = Date.now() - t0;
  await page.waitForTimeout(2500);
  const canvas = await page.$('#canvas');
  const box = await canvas.boundingBox();
  await page.screenshot({ path: path.join(OUT, 'web_01_title.png') });

  // Start (Enter) and play as runner.
  await page.mouse.click(box.x + box.width / 2, box.y + 10);
  await page.keyboard.press('Enter');
  await page.waitForTimeout(800);
  await page.keyboard.down('ArrowRight');
  await page.waitForTimeout(500);
  await page.keyboard.press('Space');
  await page.waitForTimeout(250);
  await page.keyboard.up('ArrowRight');
  await page.waitForTimeout(600);
  await page.screenshot({ path: path.join(OUT, 'web_02_play.png') });

  // Player 2: click the turret card in the side panel, then drag in the game view to place.
  // Layout (design px): margin 12, game view 960 wide, gap 12, panel 304 -> cards start near y~330.
  const sx = box.width / 1300, sy = box.height / 1374;
  const scale = Math.min(sx, sy);
  const offX = box.x + (box.width - 1300 * scale) / 2, offY = box.y + (box.height - 1374 * scale) / 2;
  const P = (x, y) => [offX + x * scale, offY + y * scale];
  let [cx, cy] = P(12 + 960 + 12 + 152, 12 + 330);
  await page.mouse.click(cx, cy);
  await page.waitForTimeout(300);
  let [gx, gy] = P(12 + 600, 12 + 700);
  await page.mouse.move(gx, gy);
  await page.mouse.down();
  await page.mouse.move(gx - 80 * scale, gy, { steps: 6 });
  await page.waitForTimeout(150);
  await page.screenshot({ path: path.join(OUT, 'web_03_placing.png') });
  await page.mouse.up();
  await page.waitForTimeout(1200);
  await page.screenshot({ path: path.join(OUT, 'web_04_placed.png') });
  await page.waitForTimeout(3000);
  await page.screenshot({ path: path.join(OUT, 'web_05_armed.png') });

  // Coin abilities with an empty wallet: Q (shield) / E (screen clear) show a "not enough coins" toast.
  await page.keyboard.press('KeyQ');
  await page.waitForTimeout(250);
  await page.screenshot({ path: path.join(OUT, 'web_05b_ability_toast.png') });
  await page.keyboard.press('KeyE');
  await page.waitForTimeout(250);

  // Shop: "升级" button under the turret icon (engine coords 1032,365).
  let [ux, uy] = P(1032, 365);
  await page.mouse.click(ux, uy);
  await page.waitForTimeout(400);
  await page.screenshot({ path: path.join(OUT, 'web_05c_upgrade_clicked.png') });

  // Settings: gear button (top-right) -> dialog -> Esc closes.
  let [sx2, sy2] = P(1300 - 48, 44);
  await page.mouse.click(sx2, sy2);
  await page.waitForTimeout(500);
  await page.screenshot({ path: path.join(OUT, 'web_06_settings.png') });
  await page.keyboard.press('Escape');
  await page.waitForTimeout(400);
  await page.screenshot({ path: path.join(OUT, 'web_07_settings_closed.png') });

  console.log(JSON.stringify({ bootMs, canvas: box, errors, lastLogs: logs.slice(-15) }, null, 1));
  browser.close().catch(() => {});
  process.exit(errors.length ? 1 : 0);
})().catch(e => { console.error(e); process.exit(2); });
