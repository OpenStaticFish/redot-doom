import { chromium } from "playwright";
import { mkdir } from "node:fs/promises";
import assert from "node:assert/strict";

const url = process.argv[2] ?? "http://127.0.0.1:8099";
const output = process.env.CAPTURE_DIR ?? "/tmp/opencode";
await mkdir(output, { recursive: true });
const browser = await chromium.launch({
  executablePath: process.env.CHROME_BIN ?? Bun.which("google-chrome") ?? undefined,
  headless: true,
  args: ["--enable-unsafe-swiftshader"],
  ignoreDefaultArgs: ["--mute-audio"],
});
const errors: string[] = [];
let checks = 0;
function check(condition: unknown, message: string): void {
  assert.ok(condition, message);
  checks += 1;
}

try {
  const page = await browser.newPage({ viewport: { width: 1280, height: 900 } });
  page.setDefaultTimeout(60_000);
  page.on("pageerror", error => errors.push(error.message));
  page.on("console", message => {
    if (message.type() === "error") errors.push(message.text());
  });
  await page.addInitScript(() => {
    const webProbe = { lcpMs: 0, cls: 0 };
    new PerformanceObserver(list => {
      for (const entry of list.getEntries()) webProbe.lcpMs = entry.startTime;
    }).observe({ type: "largest-contentful-paint", buffered: true });
    new PerformanceObserver(list => {
      for (const entry of list.getEntries() as (PerformanceEntry & { hadRecentInput: boolean; value: number })[]) {
        if (!entry.hadRecentInput) webProbe.cls += entry.value;
      }
    }).observe({ type: "layout-shift", buffered: true });
    Object.defineProperty(window, "webProbe", { value: webProbe });
    const contexts: AudioContext[] = [];
    let sampleStarts = 0;
    const Base = window.AudioContext;
    window.AudioContext = class extends Base {
      constructor(options?: AudioContextOptions) { super(options); contexts.push(this); }
    };
    const start = AudioBufferSourceNode.prototype.start;
    AudioBufferSourceNode.prototype.start = function (...args) {
      sampleStarts += 1;
      return start.apply(this, args);
    };
    Object.defineProperty(window, "audioProbe", { value: { contexts, get starts() { return sampleStarts; } } });
  });
  const state = (value: string) => page.waitForFunction(expected => document.documentElement.dataset.gameState === expected, value);
  const startGame = async () => {
    await page.locator("#play").click();
    await page.waitForFunction(() => document.documentElement.dataset.boot === "ready");
    await state("menu");
  };
  await page.goto(url, { waitUntil: "networkidle" });
  check(await page.locator("#play").isEnabled(), "accessible click-to-start loader");
  await page.screenshot({ path: `${output}/dead-signal-web-landing.png`, fullPage: true });
  await startGame();
  check(await page.locator("#overlay").isHidden(), "loader closes after WASM startup");
  const dimensions = await page.locator("#canvas").evaluate((canvas: HTMLCanvasElement) => [canvas.width, canvas.height]);
  check(dimensions[0] === 480 && dimensions[1] === 270, "fixed low-resolution framebuffer");
  await page.keyboard.press("Enter");
  await state("difficulty");
  await page.keyboard.press("ArrowDown");
  await page.keyboard.press("Enter");
  await state("playing");
  check(true, "title and difficulty navigation start the real campaign");
  await page.waitForFunction(() => document.pointerLockElement?.id === "canvas");
  check(true, "mouse capture works from a real user gesture");
  await page.keyboard.down("KeyW");
  await page.waitForTimeout(350);
  await page.keyboard.up("KeyW");
  const audio = () => page.evaluate(() => {
    const probe = (window as unknown as { audioProbe: { contexts: AudioContext[]; starts: number } }).audioProbe;
    return { running: probe.contexts.some(context => context.state === "running"), starts: probe.starts };
  });
  const before = await audio();
  await page.mouse.down();
  await page.waitForTimeout(350);
  await page.mouse.up();
  const after = await audio();
  check(after.running && after.starts > before.starts, "low-latency WebAudio samples play when firing");
  const frameReport = await page.evaluate(async () => {
    const intervals: number[] = [];
    let previous = performance.now();
    for (let i = 0; i < 90; i += 1) {
      const now = await new Promise<number>(resolve => requestAnimationFrame(resolve));
      if (i > 9) intervals.push(now - previous);
      previous = now;
    }
    intervals.sort((a, b) => a - b);
    return { medianMs: intervals[Math.floor(intervals.length / 2)], p95Ms: intervals[Math.floor(intervals.length * 0.95)] };
  });
  await page.screenshot({ path: `${output}/dead-signal-web-playing.png`, fullPage: true });
  await page.keyboard.press("Tab");
  await page.screenshot({ path: `${output}/dead-signal-web-map.png`, fullPage: true });
  await page.keyboard.press("Tab");
  await page.keyboard.press("KeyP");
  await state("paused");
  check(true, "P pauses without relying on browser Escape handling");
  await page.keyboard.press("Enter");
  await state("playing");
  await page.waitForFunction(() => document.pointerLockElement?.id === "canvas");
  await page.evaluate(() => document.exitPointerLock());
  await state("paused");
  check(true, "losing pointer lock automatically pauses gameplay");
  await page.keyboard.press("ArrowDown");
  await page.keyboard.press("Enter");
  await state("paused");
  await page.waitForFunction(async () => {
    for (const database of await indexedDB.databases()) {
      if (!database.name) continue;
      const found = await new Promise<boolean>((resolve, reject) => {
        const request = indexedDB.open(database.name!);
        request.onerror = () => reject(request.error);
        request.onsuccess = () => {
          const db = request.result;
          if (!db.objectStoreNames.contains("FILE_DATA")) { db.close(); resolve(false); return; }
          const transaction = db.transaction("FILE_DATA", "readonly");
          const keys = transaction.objectStore("FILE_DATA").getAllKeys();
          keys.onsuccess = () => { resolve(keys.result.some(key => String(key).endsWith("dead_signal.save"))); db.close(); };
          keys.onerror = () => { db.close(); reject(keys.error); };
        };
      });
      if (found) return true;
    }
    return false;
  });
  check(true, "run is flushed to persistent IndexedDB storage");
  await page.locator("#fullscreen").click();
  await page.waitForFunction(() => document.fullscreenElement?.id === "stage");
  check(true, "fullscreen button works");
  await page.evaluate(() => document.exitFullscreen());
  const performanceReport = await page.evaluate(() => ({
    ttfbMs: (performance.getEntriesByType("navigation")[0] as PerformanceNavigationTiming).responseStart,
    vitals: (window as unknown as { webProbe: { lcpMs: number; cls: number } }).webProbe,
    bootMs: performance.getEntriesByName("game-boot")[0]?.duration,
    paints: performance.getEntriesByType("paint").map(entry => ({ name: entry.name, ms: entry.startTime })),
    resources: (performance.getEntriesByType("resource") as PerformanceResourceTiming[])
      .filter(entry => /\.(wasm|pck|js)$/.test(entry.name))
      .map(entry => ({ name: entry.name.split("/").pop(), wireBytes: entry.encodedBodySize, decodedBytes: entry.decodedBodySize, ms: entry.duration })),
  }));
  await page.reload({ waitUntil: "networkidle" });
  await startGame();
  await page.keyboard.press("ArrowDown");
  await page.keyboard.press("Enter");
  await state("playing");
  check(true, "Continue Run restores the saved campaign after a page reload");
  await page.keyboard.press("KeyP");
  await state("paused");
  await page.setViewportSize({ width: 390, height: 844 });
  check(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth), "mobile-size page has no horizontal overflow");
  await page.screenshot({ path: `${output}/dead-signal-web-mobile.png`, fullPage: true });
  check(errors.length === 0, `no JavaScript/engine console errors: ${errors.join("\n")}`);
  console.log(JSON.stringify({ url, checks, errors, performance: performanceReport, gameplayFrames: frameReport }, null, 2));
} finally {
  await browser.close();
}
