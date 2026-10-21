// Drives the built frontend in headless Chrome and checks the interaction layer: tabs open a tool's
// page, hover reveals the detail line in place (never over a bar, a rule or the next row), the
// one-chart forms focus the hovered tool, the picker lists the twelve forms in the macOS order and
// persists through the backend, a fresh reading glides, the window follows a page change in small steps and many tools
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
/** The twelve forms in the macOS order, as the backend lists them. */
const FORMS = [
  ["dial", "다이얼"],
  ["bars", "바"],
  ["figures", "숫자"],
  ["columns", "막대 그래프"],
  ["capsule", "캡슐"],
  ["ruler", "눈금자"],
  ["orbit", "궤도"],
  ["constellation", "별자리"],
  ["trend", "추이"],
  ["histogram", "히스토그램"],
  ["spark", "스파크 바"],
  ["burst", "버스트"],
];
const ONE_CHART_FORMS = ["orbit", "constellation"];
const STYLES = ["iris", "mono", "dot"];
const DIMMED_OPACITY = 0.5;
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
    hourAgo: null,
    history: null,
  };
};
const providers = (count, remaining = 80) =>
  TOOL_NAMES.slice(0, count).map((title) => view(title, remaining));
const layouts = FORMS.map(([id, title]) => ({ id, title }));

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
  layout = "dial",
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
    layout,
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

/** Ring of the second tool in a 150-point orbit of four rings (see `orbit-rings.ts`), from the middle. */
const ORBIT_RINGS_RADIUS = 59;
const HOVER_SETTLE_MS = 300;

/** Which marks of a one-chart form are brightened and which are dimmed. */
const focusOf = (page, selector) =>
  page.$$eval(
    selector,
    (nodes, dimmedOpacity) => ({
      hovered: nodes.filter((node) => node.classList.contains("hovered")).map((node) => node.dataset.tool),
      dimmed: nodes
        .filter((node) => node.classList.contains("dimmed") && Number(getComputedStyle(node).opacity) <= dimmedOpacity + 0.01)
        .map((node) => node.dataset.tool),
    }),
    DIMMED_OPACITY,
  );

// Runs in the page: what in the hovered cell the revealed line lands on. The line must sit inside
// the cell, and no element that is showing (a canvas, a text, a bar) may share its box, except
// the caption slot that it replaces.
function overlapsOfReveal(tool) {
  const cell = document.querySelector(`.cell[data-tool="${tool}"]`);
  const line = cell.querySelector(".reveal");
  if (!line) return [];
  const area = line.getBoundingClientRect();
  const home = cell.getBoundingClientRect();
  const found = [];
  if (area.left < home.left - 0.5 || area.right > home.right + 0.5) found.push("the cell's edge");
  const isShowing = (node) => {
    for (let at = node; at && at !== cell; at = at.parentElement) if (Number(getComputedStyle(at).opacity) < 0.05) return false;
    return true;
  };
  const isLeaf = (node) => node.children.length === 0 || node.tagName === "CANVAS";
  for (const node of cell.querySelectorAll("*")) {
    if (node === line || line.parentElement.contains(node) || !isLeaf(node) || !isShowing(node)) continue;
    const box = node.getBoundingClientRect();
    if (box.width < 1 || box.height < 1) continue;
    const isHidden = getComputedStyle(node).visibility === "hidden";
    const isEmpty = node.tagName !== "CANVAS" && !node.textContent.trim() && getComputedStyle(node).backgroundColor === "rgba(0, 0, 0, 0)";
    if (isHidden || isEmpty) continue;
    const overlaps = box.left < area.right - 0.5 && box.right > area.left + 0.5 && box.top < area.bottom - 0.5 && box.bottom > area.top + 0.5;
    if (overlaps) found.push(`${node.tagName.toLowerCase()}.${node.className}`);
  }
  return found;
}

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
  assert.deepEqual(
    await page.$$eval(".choice", (nodes) => nodes.map((node) => node.dataset.layout)),
    FORMS.map(([id]) => id),
    "the picker lists the twelve forms in the macOS order",
  );
  await page.click('.choice[data-layout="columns"]');
  assert.deepEqual(await calls(page, "choose_layout"), [{ id: "columns" }]);
  await page.evaluate(() => window.__emit("panel-layout", "dial"));
  assert.ok(await page.$('.choice[data-layout="dial"].selected'));
  await page.close();

  // Hover reveals the times where the caption was: the line stays inside its cell and clear of
  // every bar, rule and number that is still showing, in every grid form and style.
  for (const style of STYLES) {
    for (const [layout] of FORMS.filter(([id]) => !ONE_CHART_FORMS.includes(id) && id !== "constellation")) {
      page = await open(browser, port, 4, style, false, layout);
      await page.hover('.cell[data-tool="codex"]');
      await wait(page, HOVER_SETTLE_MS);
      const crossings = await page.evaluate(overlapsOfReveal, "codex");
      assert.deepEqual(crossings, [], `${style} ${layout}: the reveal line overlaps ${crossings.join(", ")}`);
      await page.close();
    }
  }

  // One-chart forms: the hovered tool's marks brighten and the others dim; a click opens its tab.
  for (const style of STYLES) {
    page = await open(browser, port, 4, style, false, "constellation");
    await page.hover('.constellation-node[data-tool="codex"] .tag-slot');
    await wait(page, HOVER_SETTLE_MS);
    assert.deepEqual(await focusOf(page, ".constellation-node"), { hovered: ["codex"], dimmed: ["claude", "gemini", "cursor"] }, `${style} constellation focus`);
    assert.equal(await page.$eval('.footnote-time[data-follows="codex"]', (node) => getComputedStyle(node).opacity), "1", "the times show under the field");
    await page.mouse.move(2, 2);
    await wait(page, HOVER_SETTLE_MS);
    assert.deepEqual(await focusOf(page, ".constellation-node"), { hovered: [], dimmed: [] }, "focus ends with the pointer");
    await page.click('.constellation-node[data-tool="gemini"] .tag-slot');
    await wait(page, TRANSITION_MS);
    assert.equal(await page.$eval(".tab.selected", (node) => node.dataset.tab), "gemini");
    await page.close();

    page = await open(browser, port, 4, style, false, "orbit");
    await page.hover('.orbit-row[data-tool="gemini"]');
    await wait(page, HOVER_SETTLE_MS);
    assert.deepEqual(await focusOf(page, ".orbit-ring"), { hovered: ["gemini"], dimmed: ["claude", "codex", "cursor"] }, `${style} orbit focus from the legend`);
    const box = await (await page.$(".orbit-hit")).boundingBox();
    const secondRing = ORBIT_RINGS_RADIUS;
    await page.mouse.move(box.x + box.width / 2 + secondRing, box.y + box.height / 2);
    await wait(page, HOVER_SETTLE_MS);
    assert.deepEqual((await focusOf(page, ".orbit-ring")).hovered, ["codex"], `${style} orbit focus from the ring`);
    assert.equal(await page.$eval(".orbit-hit", (node) => getComputedStyle(node).cursor), "pointer");
    await page.mouse.click(box.x + box.width / 2 + secondRing, box.y + box.height / 2);
    await wait(page, TRANSITION_MS);
    assert.equal(await page.$eval(".tab.selected", (node) => node.dataset.tab), "codex");
    await page.close();
  }

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
