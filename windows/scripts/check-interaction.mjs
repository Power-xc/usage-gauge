// Drives the built frontend in headless Chrome and checks the interaction layer: tabs open a tool's
// page, hover reveals the detail line, the picker lists every form and persists through the
// backend, a fresh reading glides, the window follows a page change in small steps and many tools
// never collide in the tab row. Run `npm run build` first.
// The Tauri bridge is a mock that records every command and lets the test emit backend events.
import assert from "node:assert/strict";
import { createReadStream, existsSync, statSync } from "node:fs";
import { homedir } from "node:os";
import { dirname, extname, join, normalize } from "node:path";
import { createServer } from "node:http";
import { fileURLToPath } from "node:url";
import puppeteer from "puppeteer-core";

const dist = join(dirname(fileURLToPath(import.meta.url)), "..", "dist");
const chrome =
  process.env.CHROME_PATH ??
  join(
    homedir(),
    ".cache/puppeteer/chrome-headless-shell/mac_arm-155.0.8059.84/chrome-headless-shell-mac-arm64/chrome-headless-shell",
  );
const types = {
  ".html": "text/html",
  ".js": "text/javascript",
  ".css": "text/css",
};
const TRANSITION_MS = 450;
const REDUCED_MOTION_MS = 250;
const GLIDE_MIDWAY_MS = 250;
const FORMS = 12;
const TOOL_NAMES = [
  "Claude",
  "Codex",
  "Gemini",
  "Cursor",
  "Copilot",
  "Windsurf",
  "Antigravity",
  "Perplexity",
  "Replit",
  "Zed",
];

const view = (title, remaining) => {
  const window_ = {
    displayPercent: remaining,
    remainingPercent: remaining,
    elapsedFraction: 0.3,
    label: "5시간",
    countdown: "1시간 0분",
    countdownCompact: "1h 0m",
    resetsAt: 1_800_000_000_000,
    level: "comfortable",
  };
  return {
    id: title.toLowerCase(),
    title,
    plan: "Pro",
    message: null,
    measuredAt: 1_799_999_000_000,
    session: window_,
    weekly: { ...window_, label: "주간" },
  };
};
const providers = (count, remaining = 80) =>
  TOOL_NAMES.slice(0, count).map((title) => view(title, remaining));
const layouts = Array.from({ length: FORMS }, (_, index) => ({
  id: index === 0 ? "dial" : `form${index}`,
  title: `형태${index}`,
}));

function serve() {
  const server = createServer((request, response) => {
    const path = normalize(request.url.split("?")[0]).replace(
      /^(\.\.[/\\])+/,
      "",
    );
    const file = join(dist, path === "/" ? "index.html" : path);
    if (!file.startsWith(dist) || !existsSync(file) || !statSync(file).isFile())
      return response.writeHead(404).end();
    response.writeHead(200, {
      "content-type": types[extname(file)] ?? "application/octet-stream",
    });
    createReadStream(file).pipe(response);
  });
  return new Promise((resolve) =>
    server.listen(0, "127.0.0.1", () => resolve(server)),
  );
}

// Stands in for the Tauri bridge.
function installTauriMock(state) {
  const callbacks = new Map();
  const listeners = new Map();
  window.__calls = [];
  window.__emit = (event, payload) =>
    callbacks.get(listeners.get(event))?.({ event, id: 0, payload });
  window.__TAURI_INTERNALS__ = {
    metadata: {
      currentWindow: { label: "main" },
      currentWebview: { windowLabel: "main", label: "main" },
    },
    transformCallback: (callback) => {
      const id = callbacks.size + 1;
      callbacks.set(id, callback);
      return id;
    },
    invoke: async (command, args) => {
      if (command === "plugin:event|listen")
        listeners.set(args.event, args.handler);
      if (command === "get_state") return state;
      window.__calls.push([command, args]);
      return 0;
    },
  };
}

async function open(
  browser,
  port,
  count,
  style = "mono",
  reducedMotion = false,
) {
  const page = await browser.newPage();
  await page.setViewport({ width: 800, height: 600 });
  if (reducedMotion)
    await page.emulateMediaFeatures([
      { name: "prefers-reduced-motion", value: "reduce" },
    ]);
  const state = {
    usage: { measuredAt: Date.now(), providers: providers(count) },
    opacity: 1,
    isShown: true,
    hasGlass: true,
    style,
    layout: "dial",
    layouts,
    scale: 1,
  };
  await page.evaluateOnNewDocument(installTauriMock, state);
  await page.goto(`http://127.0.0.1:${port}/`);
  await page.waitForSelector(".panel");
  return page;
}

const wait = (page, ms) =>
  page.evaluate(
    (delay) => new Promise((resolve) => setTimeout(resolve, delay)),
    ms,
  );
const calls = (page, command) =>
  page.evaluate(
    (name) =>
      window.__calls
        .filter(([called]) => called === name)
        .map(([, args]) => args),
    command,
  );
const pageCount = (page) =>
  page.$$eval(".grid-slot > *", (nodes) => nodes.length);

const server = await serve();
const browser = await puppeteer.launch({
  executablePath: chrome,
  headless: "shell",
});
try {
  const { port } = server.address();

  // Tabs open a tool's page and leave nothing of the old one behind; the window follows in steps.
  let page = await open(browser, port, 4, "iris");
  await page.click('.tab[data-tab="codex"]');
  await wait(page, TRANSITION_MS);
  assert.equal(
    await pageCount(page),
    1,
    "old page is removed after the crossfade",
  );
  assert.ok(await page.$(".detail-page"), "the tool page is shown");
  assert.match(
    await page.$eval(".tool-reset", (node) => node.textContent),
    /초기화 · 1시간 0분 후/,
  );
  assert.equal(
    await page.$eval(".tab.selected", (node) => node.dataset.tab),
    "codex",
  );
  const heights = (await calls(page, "resize_panel")).map(
    (args) => args.height,
  );
  assert.ok(
    new Set(heights).size > 4,
    `the window resizes in steps, saw ${new Set(heights).size} sizes`,
  );
  await page.click('.tab[data-tab=""]');
  await wait(page, TRANSITION_MS);
  assert.ok(await page.$(".grid"), "the overview returns");

  // Hover reveals the line in place and a click opens the tool.
  await page.hover('.cell[data-tool="gemini"]');
  assert.match(
    await page.$eval(
      '.cell[data-tool="gemini"] .reveal',
      (node) => node.textContent,
    ),
    /^초기화 .* · 측정 /,
  );
  assert.ok(await page.$('.cell[data-tool="gemini"].hovered.clickable'));
  await page.click('.cell[data-tool="gemini"]');
  await wait(page, TRANSITION_MS);
  assert.equal(
    await page.$eval(".tab.selected", (node) => node.dataset.tab),
    "gemini",
  );

  // The picker lists every form and a choice goes to the backend; the panel follows the event.
  await page.click('.glyph[aria-label="그래프 모양"]');
  assert.equal(await page.$$eval(".choice", (nodes) => nodes.length), FORMS);
  await page.click('.choice[data-layout="form3"]');
  assert.deepEqual(await calls(page, "choose_layout"), [{ id: "form3" }]);
  await page.evaluate(() => window.__emit("panel-layout", "dial"));
  assert.ok(await page.$('.choice[data-layout="dial"].selected'));
  await page.close();

  // A fresh reading glides: mid-way the dial shows neither the old nor the new share.
  page = await open(browser, port, 2, "mono");
  const sample = () =>
    page.evaluate(() =>
      document
        .querySelector(".dial canvas")
        .getContext("2d")
        .getImageData(0, 0, 144, 144)
        .data.join(","),
    );
  const before = await sample();
  await page.evaluate((next) => window.__emit("usage", next), {
    measuredAt: Date.now(),
    providers: providers(2, 20),
  });
  await wait(page, GLIDE_MIDWAY_MS);
  const middle = await sample();
  await wait(page, TRANSITION_MS);
  const after = await sample();
  assert.ok(
    before !== middle && middle !== after && before !== after,
    "dial moves through in-between values",
  );
  await page.close();

  // Many tools never collide: every tab label stays inside its tab and on one line.
  for (const style of ["iris", "mono", "dot"]) {
    for (const count of [2, 5, 8, 10]) {
      page = await open(browser, port, count, style);
      const crowded = await page.$$eval(
        ".tab",
        (tabs) =>
          tabs.filter(
            (tab) =>
              tab.querySelector(".tab-label").getBoundingClientRect().width >
                tab.clientWidth + 0.5 ||
              tab.getBoundingClientRect().height > 40,
          ).length,
      );
      assert.equal(
        crowded,
        0,
        `${style} with ${count} tools: no tab overflows`,
      );
      await page.close();
    }
  }

  // Reduced motion shortens the crossfade to a plain, quick fade.
  page = await open(browser, port, 3, "mono", true);
  await page.click('.tab[data-tab="claude"]');
  await wait(page, REDUCED_MOTION_MS);
  assert.equal(
    await pageCount(page),
    1,
    "reduced motion finishes the page change quickly",
  );
  await page.close();

  console.log("interaction checks passed");
} finally {
  await browser.close();
  server.close();
}
