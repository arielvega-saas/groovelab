const puppeteer = require('puppeteer');
const path = require('path');
const fs = require('fs');

const SCREENSHOT_DIR = path.join(__dirname, 'store_assets', 'screenshots');
const APP_URL = 'https://arieldev-docs.web.app/';

// 360x640 viewport at 3x DPR = 1080x1920 screenshots (9:16 ratio)
const VIEWPORT = { width: 360, height: 640, deviceScaleFactor: 3 };

async function delay(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

async function takeScreenshots() {
  // Clean screenshots directory
  if (fs.existsSync(SCREENSHOT_DIR)) {
    fs.rmSync(SCREENSHOT_DIR, { recursive: true });
  }
  fs.mkdirSync(SCREENSHOT_DIR, { recursive: true });

  const browser = await puppeteer.launch({
    headless: 'new',
    args: ['--no-sandbox', '--disable-setuid-sandbox']
  });

  const page = await browser.newPage();
  await page.setViewport(VIEWPORT);

  // Create CDP session for real input events
  const client = await page.target().createCDPSession();

  // CDP click function - sends real mouse events that Flutter processes
  const cdpClick = async (x, y) => {
    await client.send('Input.dispatchMouseEvent', {
      type: 'mousePressed',
      x: x, y: y,
      button: 'left',
      clickCount: 1
    });
    await delay(50);
    await client.send('Input.dispatchMouseEvent', {
      type: 'mouseReleased',
      x: x, y: y,
      button: 'left',
      clickCount: 1
    });
  };

  // First load to set localStorage (skip onboarding)
  console.log('Setting up localStorage...');
  await page.goto(APP_URL, { waitUntil: 'domcontentloaded', timeout: 30000 });
  await delay(2000);

  await page.evaluate(() => {
    localStorage.setItem('flutter.onboardingComplete', 'true');
  });

  // Reload to apply
  console.log('Reloading app without onboarding...');
  await page.reload({ waitUntil: 'networkidle2', timeout: 30000 });
  await delay(5000);

  // Check if onboarding is still showing by checking screenshot
  await page.screenshot({
    path: path.join(SCREENSHOT_DIR, '_check.png'),
    type: 'png'
  });
  console.log('Check screenshot saved - verify onboarding dismissed');

  // If onboarding is still showing, click Skip
  // Skip button is approximately at center, y ~= 500 in viewport
  console.log('Attempting to click Skip just in case...');
  await cdpClick(180, 510);
  await delay(1500);

  // Bottom nav tab positions for 360px wide viewport with 6 tabs:
  // From the screenshot, bottom nav shows: Metrónomo, Batería, Record, Práctica, Biblioteca, Estadísti...
  // 6 tabs: each ~60px wide. Centers at: 30, 90, 150, 210, 270, 330
  // Nav bar is at the bottom, y ≈ 620

  const NAV_Y = 622;
  const tabPositions = {
    metronome: 30,
    drums: 90,
    record: 150,
    practice: 210,
    library: 270,
    stats: 330
  };

  // Screenshot 1: Metronome main screen (click tab first to be sure)
  console.log('Taking screenshot 1: Metronome');
  await cdpClick(tabPositions.metronome, NAV_Y);
  await delay(2000);
  await page.screenshot({
    path: path.join(SCREENSHOT_DIR, 'screenshot_01_metronome.png'),
    type: 'png'
  });

  // Screenshot 2: Batería (Drum Pattern)
  console.log('Taking screenshot 2: Drum pattern');
  await cdpClick(tabPositions.drums, NAV_Y);
  await delay(2000);
  await page.screenshot({
    path: path.join(SCREENSHOT_DIR, 'screenshot_02_drums.png'),
    type: 'png'
  });

  // Screenshot 3: Record
  console.log('Taking screenshot 3: Record');
  await cdpClick(tabPositions.record, NAV_Y);
  await delay(2000);
  await page.screenshot({
    path: path.join(SCREENSHOT_DIR, 'screenshot_03_record.png'),
    type: 'png'
  });

  // Screenshot 4: Práctica
  console.log('Taking screenshot 4: Practice');
  await cdpClick(tabPositions.practice, NAV_Y);
  await delay(2000);
  await page.screenshot({
    path: path.join(SCREENSHOT_DIR, 'screenshot_04_practice.png'),
    type: 'png'
  });

  // Screenshot 5: Biblioteca
  console.log('Taking screenshot 5: Library');
  await cdpClick(tabPositions.library, NAV_Y);
  await delay(2000);
  await page.screenshot({
    path: path.join(SCREENSHOT_DIR, 'screenshot_05_library.png'),
    type: 'png'
  });

  // Screenshot 6: Estadísticas
  console.log('Taking screenshot 6: Stats');
  await cdpClick(tabPositions.stats, NAV_Y);
  await delay(2000);
  await page.screenshot({
    path: path.join(SCREENSHOT_DIR, 'screenshot_06_stats.png'),
    type: 'png'
  });

  console.log('\nAll screenshots taken!');

  // Report
  const files = fs.readdirSync(SCREENSHOT_DIR).filter(f => f.startsWith('screenshot'));
  const sizes = new Set();
  for (const f of files) {
    const stats = fs.statSync(path.join(SCREENSHOT_DIR, f));
    sizes.add(stats.size);
    console.log(`  ${f}: ${(stats.size / 1024).toFixed(1)} KB`);
  }
  console.log(`\nUnique file sizes: ${sizes.size} (${sizes.size > 1 ? 'DIFFERENT screens!' : 'ALL SAME - navigation failed'})`);

  // Clean up check file
  try { fs.unlinkSync(path.join(SCREENSHOT_DIR, '_check.png')); } catch(e) {}

  await browser.close();
}

takeScreenshots().catch(err => {
  console.error('Error:', err);
  process.exit(1);
});
