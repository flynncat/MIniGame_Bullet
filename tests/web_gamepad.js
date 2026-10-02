// Real-browser check: player 1 on a (mocked, W3C "standard" mapping) gamepad, player 2 on the mouse,
// both in the same session. Usage: node tests/web_gamepad.js [url] [outDir]
const path = require('path');
const { chromium } = require('playwright-core');

const URL = process.argv[2] || 'http://127.0.0.1:8765/index.html';
const OUT = process.argv[3] || path.join(__dirname, '..', 'build');
const EDGE = 'C:\\Program Files (x86)\\Microsoft\\Edge\\Application\\msedge.exe';

// Standard mapping: 0=A 1=B 2=X 3=Y 4=LB 5=RB 6=LT 7=RT 8=Back 9=Start 12..15=dpad; axes 0/1 = left stick.
const MOCK = () => {
  const pad = {
    id: 'Mock Xbox Controller (STANDARD GAMEPAD Vendor: 045e Product: 02ea)',
    index: 0, connected: true, mapping: 'standard', timestamp: 0,
    buttons: Array.from({ length: 17 }, () => ({ pressed: false, touched: false, value: 0 })),
    axes: [0, 0, 0, 0],
  };
  window.__pad = {
    press(i, down) { pad.buttons[i] = { pressed: down, touched: down, value: down ? 1 : 0 }; pad.timestamp = performance.now(); },
    axis(i, v) { pad.axes[i] = v; pad.timestamp = performance.now(); },
  };
  Object.defineProperty(Navigator.prototype, 'getGamepads', { configurable: true, value: () => [pad, null, null, null] });
};

(async () => {
  const browser = await chromium.launch({ executablePath: EDGE, headless: true,
    args: ['--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'] });
  const page = await browser.newPage({ viewport: { width: 1300, height: 1000 } });
  await page.addInitScript(MOCK);
  const errors = [];
  page.on('pageerror', e => errors.push('pageerror: ' + e.message));
  page.on('console', m => { if (m.type() === 'error' || /SCRIPT ERROR|ERROR:/.test(m.text())) errors.push(m.text()); });
  await page.goto(URL, { waitUntil: 'load' });
  await page.waitForFunction(() => { const s = document.getElementById('status'); return !s || getComputedStyle(s).display === 'none'; }, null, { timeout: 120000 });
  await page.waitForTimeout(2000);
  const press = async (i, ms = 150) => { await page.evaluate(i => __pad.press(i, true), i); await page.waitForTimeout(ms); await page.evaluate(i => __pad.press(i, false), i); };
  const shot = n => page.screenshot({ path: path.join(OUT, n) });

  await press(0);                                   // A: start game from title
  await page.waitForTimeout(600);
  await shot('pad_01_started.png');
  await page.evaluate(() => __pad.axis(0, 1));      // left stick right
  await page.waitForTimeout(900);
  await page.evaluate(() => __pad.axis(0, 0));
  await page.waitForTimeout(300);
  await shot('pad_02_moved_right.png');
  await page.evaluate(() => __pad.press(0, true));  // A: jump (hold for full height)
  await page.waitForTimeout(220);
  await shot('pad_03_jump.png');
  await page.evaluate(() => __pad.press(0, false));
  await page.waitForTimeout(800);

  // Player 2 places a turret with the mouse while player 1 is still on the pad.
  const box = await (await page.$('#canvas')).boundingBox();
  const k = Math.min(box.width / 1300, box.height / 1374);
  const ox = box.x + (box.width - 1300 * k) / 2, oy = box.y + (box.height - 1374 * k) / 2;
  const P = (x, y) => [ox + x * k, oy + y * k];
  await page.mouse.click(...P(12 + 960 + 12 + 152, 12 + 300));
  await page.waitForTimeout(200);
  const [gx, gy] = P(12 + 400, 12 + 800);
  await page.mouse.move(gx, gy); await page.mouse.down();
  await page.mouse.move(gx + 90 * k, gy, { steps: 6 });
  await page.evaluate(() => __pad.axis(0, -1));     // runner moves left at the same time
  await page.mouse.up();
  await page.waitForTimeout(700);
  await page.evaluate(() => __pad.axis(0, 0));
  await shot('pad_04_both_players.png');

  await press(9);                                   // Start: pause
  await page.waitForTimeout(400);
  await shot('pad_05_paused.png');
  await press(9);                                   // Start: resume
  await page.waitForTimeout(400);
  console.log(JSON.stringify({ errors }, null, 1));
  await browser.close();
  process.exit(errors.length ? 1 : 0);
})().catch(e => { console.error(e); process.exit(2); });
