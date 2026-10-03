import { chromium } from "playwright";
import { mkdir } from "node:fs/promises";
import assert from "node:assert/strict";

const url = process.argv[2] ?? "http://127.0.0.1:8099";
const output = process.env.CAPTURE_DIR ?? "/tmp/opencode";
await mkdir(output, { recursive: true });
const browser = await chromium.launch({
  executablePath: process.env.CHROME_BIN ?? Bun.which("google-chrome") ?? undefined,
  headless: true,
  args: ["--enable-unsafe-swiftshader", "--autoplay-policy=document-user-activation-required"],
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
  const checkViewport = async (label: string) => {
    await page.waitForFunction(() => {
      const canvas = document.getElementById("canvas") as HTMLCanvasElement;
      return canvas.width === innerWidth && canvas.height === innerHeight;
    });
    const layout = await page.evaluate(() => {
      const rect = (id: string) => {
        const bounds = document.getElementById(id)!.getBoundingClientRect();
        return [bounds.x, bounds.y, bounds.width, bounds.height];
      };
      return {
        stage: rect("stage"), canvas: rect("canvas"), viewport: [0, 0, innerWidth, innerHeight],
        overflow: document.documentElement.scrollWidth > innerWidth || document.documentElement.scrollHeight > innerHeight,
      };
    });
    check(layout.stage.every((value, index) => Math.abs(value - layout.viewport[index]!) < 1), `${label}: stage fills the browser window`);
    check(layout.canvas.every((value, index) => Math.abs(value - layout.viewport[index]!) < 1), `${label}: canvas fills the browser window`);
    check(!layout.overflow, `${label}: no page scrollbars`);
  };
  const clickGame = async (x: number, y: number) => {
    const point = await page.locator("#canvas").evaluate((canvas, position) => {
      const bounds = canvas.getBoundingClientRect();
      const scale = Math.min(bounds.width / 480, bounds.height / 270);
      return {
        x: bounds.x + (bounds.width - 480 * scale) / 2 + position.x * scale,
        y: bounds.y + (bounds.height - 270 * scale) / 2 + position.y * scale,
      };
    }, { x, y });
    await page.mouse.click(point.x, point.y);
  };
  const waitForGame = async () => {
    await page.waitForFunction(() => document.documentElement.dataset.boot === "ready");
    await state("menu");
  };
  await page.goto(url, { waitUntil: "networkidle" });
  // Playwright's DOM evaluations can grant user activation. Probe startup via
  // CDP with userGesture:false before any selectors, evaluations or input.
  const cdp = await page.context().newCDPSession(page);
  const bootResult = await cdp.send("Runtime.evaluate", {
    userGesture: false, awaitPromise: true, returnByValue: true,
    expression: `new Promise((resolve, reject) => {
      const observer = new MutationObserver(read);
      const timeout = setTimeout(() => { observer.disconnect(); reject(new Error('Automatic boot timed out')); }, 60000);
      function read() {
        const data = document.documentElement.dataset;
        if (data.boot === 'error') {
          clearTimeout(timeout); observer.disconnect(); reject(new Error(document.getElementById('status').textContent));
        } else if (data.boot === 'ready' && data.gameState === 'menu') {
          clearTimeout(timeout); observer.disconnect();
          resolve({
            noGate: !document.getElementById('play'),
            noGesture: !navigator.userActivation.hasBeenActive,
            focused: document.activeElement.id === 'canvas',
            retryHidden: document.getElementById('retry').hidden,
            overlayHidden: document.getElementById('overlay').hidden,
            audioSuspended: window.audioProbe.contexts.length > 0 && window.audioProbe.contexts.every(context => context.state === 'suspended')
          });
        }
      }
      observer.observe(document.documentElement, { attributes: true });
      read();
    })`,
  });
  if (bootResult.exceptionDetails || !bootResult.result.value) throw new Error("Automatic boot probe failed: " + JSON.stringify(bootResult.exceptionDetails));
  const boot = bootResult.result.value as Record<string, boolean>;
  check(boot.noGate, "no Connect & play gate exists");
  check(boot.noGesture, "game boots to its title screen without any user gesture");
  check(boot.focused, "auto-start focuses the game for keyboard menus");
  check(boot.retryHidden, "retry control stays hidden on successful startup");
  check(boot.audioSuspended, "strict autoplay policy does not block startup while audio awaits input");
  check(boot.overlayHidden, "loader closes after WASM startup");
  const title = await cdp.send("Page.captureScreenshot", { format: "png" });
  await Bun.write(`${output}/dead-signal-web-title.png`, Buffer.from(title.data, "base64"));
  await page.keyboard.press("Enter");
  await state("difficulty");
  await page.waitForFunction(() => (window as unknown as { audioProbe: { contexts: AudioContext[] } }).audioProbe.contexts.some(context => context.state === "running"));
  check(true, "the first game keypress unlocks audio without a separate activation button");
  await checkViewport("desktop");
  check(await page.locator("header, footer, iframe, .toolbar, .controls").count() === 0, "no surrounding page chrome or embedded-player layout");
  await clickGame(240, 172);
  await state("playing");
  check(true, "keyboard and scaled mouse menu input start the real campaign");
  check(await page.locator("#utilities").isHidden(), "all HTML utility controls disappear during gameplay");
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
  await checkViewport("fullscreen");
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
  await waitForGame();
  await page.keyboard.press("ArrowDown");
  await page.keyboard.press("Enter");
  await state("playing");
  check(true, "Continue Run restores the saved campaign after a page reload");
  await page.keyboard.press("KeyP");
  await state("paused");
  for (const viewport of [
    { width: 1280, height: 720 },
    { width: 1024, height: 768 },
    { width: 2560, height: 1080 },
    { width: 390, height: 844 },
  ]) {
    await page.setViewportSize(viewport);
    await checkViewport(`${viewport.width}×${viewport.height}`);
    await clickGame(240, 105);
    await state("playing");
    check(true, `${viewport.width}×${viewport.height}: menu mouse targets remain aligned after resize`);
    await page.waitForFunction(() => document.pointerLockElement?.id === "canvas");
    await page.keyboard.press("KeyP");
    await state("paused");
  }
  await page.screenshot({ path: `${output}/dead-signal-web-mobile.png`, fullPage: true });
  const failurePage = await browser.newPage();
  failurePage.setDefaultTimeout(60_000);
  try {
    await failurePage.route("**/*.pck", route => route.abort());
    await failurePage.goto(url);
    await failurePage.waitForFunction(() => document.documentElement.dataset.boot === "error");
    check(await failurePage.locator("#retry").isVisible(), "a failed automatic download offers a retry button");
    check((await failurePage.locator("#status").innerText()).length > 0, "automatic startup failures show a readable error");
    await failurePage.unroute("**/*.pck");
    await failurePage.locator("#retry").click();
    await failurePage.waitForFunction(() => document.documentElement.dataset.boot === "ready");
    check(true, "retry reloads and boots straight into the game");
  } finally {
    await failurePage.close();
  }
  check(errors.length === 0, `no JavaScript/engine console errors: ${errors.join("\n")}`);
  console.log(JSON.stringify({ url, checks, errors, performance: performanceReport, gameplayFrames: frameReport }, null, 2));
} finally {
  await browser.close();
}
