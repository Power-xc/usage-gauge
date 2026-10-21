// Renders the frontend with mock data in headless Chrome and writes preview.png (mono dial),
// preview-styles.png (mono, iris and dot stacked) and preview-layouts.png (the four layouts in
// mono, then bars and columns in iris and dot) and preview-shapes.png (orbit, capsule,
// constellation and ruler, each in mono, iris and dot), all at 2x.
// The real frontend code runs unchanged; only the Tauri bridge is replaced by a mock.
import { execFileSync } from "node:child_process";
import { createReadStream, existsSync, readFileSync, statSync } from "node:fs";
import { writeFile } from "node:fs/promises";
import { homedir, tmpdir } from "node:os";
import { dirname, extname, join, normalize } from "node:path";
import { createServer } from "node:http";
import { fileURLToPath } from "node:url";
import puppeteer from "puppeteer-core";

const root = join(dirname(fileURLToPath(import.meta.url)), "..");
const dist = join(root, "dist");
const output = join(root, "preview.png");
const stylesOutput = join(root, "preview-styles.png");
const layoutsOutput = join(root, "preview-layouts.png");
const shapesOutput = join(root, "preview-shapes.png");
const historyOutput = join(root, "preview-history.png");
const historyFixture = join(tmpdir(), "usage-gauge-preview-history.json");
const chrome =
  process.env.CHROME_PATH ??
  join(homedir(), ".cache/puppeteer/chrome-headless-shell/mac_arm-155.0.8059.84/chrome-headless-shell-mac-arm64/chrome-headless-shell");
const SCALE = 2;
const FROZEN_SECONDS = 12.4;
const MARGIN = 28;
const STYLES = ["mono", "iris", "dot"];
const STILL_TOOLS = 2;
/** Panels of the layouts image as [style, layout], filling two columns top to bottom. */
const LAYOUT_PANELS = [
  ["mono", "dial"], ["mono", "columns"], ["iris", "bars"], ["dot", "bars"],
  ["mono", "bars"], ["mono", "figures"], ["iris", "columns"], ["dot", "columns"],
];
const LAYOUT_ROWS = 4;
/** The shape forms, each in the three styles, a form per half column. */
const SHAPE_LAYOUTS = ["orbit", "capsule", "constellation", "ruler"];
const SHAPE_ROWS = 6;
const HISTORY_LAYOUTS = ["trend", "histogram", "spark", "burst"];
const STACK_BACKGROUND = "#0b101a";
const STACK_PADDING = { x: 72, y: 77, gap: 29 };
const LAYOUTS_PADDING = { x: 72, y: 77, gap: 29 };

// The sample history comes from the Rust history code itself, so the preview shows what the app would send.
function attachSampleHistory() {
  execFileSync("cargo", ["test", "--manifest-path", join(root, "src-tauri/Cargo.toml"), "dump_preview_history", "--", "--ignored"], {
    env: { ...process.env, USAGE_GAUGE_PREVIEW_HISTORY: historyFixture },
    stdio: "ignore",
  });
  const histories = JSON.parse(readFileSync(historyFixture, "utf8"));
  for (const provider of providers) provider.history = histories[provider.id] ?? null;
}

const types = { ".html": "text/html", ".js": "text/javascript", ".css": "text/css" };

function serve() {
  const server = createServer((request, response) => {
    const path = normalize(request.url.split("?")[0]).replace(/^(\.\.[/\\])+/, "");
    const file = join(dist, path === "/" ? "index.html" : path);
    if (!file.startsWith(dist) || !existsSync(file) || !statSync(file).isFile()) {
      response.writeHead(404).end();
      return;
    }
    response.writeHead(200, { "content-type": types[extname(file)] ?? "application/octet-stream" });
    createReadStream(file).pipe(response);
  });
  return new Promise((resolve) => server.listen(0, "127.0.0.1", () => resolve(server)));
}

const window_ = (displayPercent, remainingPercent, elapsedFraction, label, countdown, countdownCompact, level = "comfortable") => ({
  displayPercent, remainingPercent, elapsedFraction, label, countdown, countdownCompact, level,
});

const providers = [
  {
    id: "claude", title: "Claude", plan: "Max", message: null,
    session: window_(94, 94, 0.234, "5시간", "3시간 50분", "3h 50m"),
    weekly: window_(37, 37, 0.57, "주간", "3일 0시간", "3d 0h"),
    // Where the usage history would put the tool an hour ago; the constellation draws a trail from it.
    hourAgo: { session: 100, weekly: 38 },
  },
  {
    id: "codex", title: "Codex", plan: "Plus", message: null,
    session: window_(8, 8, 0.843, "5시간", "47분", "47m", "critical"),
    weekly: window_(26, 26, 0.4, "주간", "6일 16시간", "6d 16h", "low"),
  },
  {
    id: "gemini", title: "Gemini", plan: "Pro", message: null,
    session: window_(71, 71, 0.6, "일간", "9시간 0분", "9h 0m"),
    weekly: window_(88, 88, 0.28, "주간", "5일 0시간", "5d 0h"),
  },
  {
    id: "cursor", title: "Cursor", plan: "Pro", message: null,
    session: window_(46, 46, 0.46, "5시간", "2시간 10분", "2h 10m"),
    weekly: window_(53, 53, 0.4, "월간", "16일 16시간", "16d 16h"),
  },
];

const mockState = {
  usage: { measuredAt: new Date(2026, 9, 21, 12, 4).getTime(), providers },
  opacity: 1,
  isShown: true,
  hasGlass: true,
  layout: "dial",
  scale: 1,
};

// Stands in for window.__TAURI_INTERNALS__ so the app's own bridge code runs in a plain browser.
function installTauriMock(state, frozenSeconds) {
  let callbackId = 0;
  window.__TAURI_INTERNALS__ = {
    metadata: { currentWindow: { label: "main" }, currentWebview: { windowLabel: "main", label: "main" } },
    transformCallback: () => ++callbackId,
    invoke: async (command) => (command === "get_state" ? state : 0),
  };
  const origin = performance.now();
  performance.now = () => origin + frozenSeconds * 1000;
}

// Draws one style's panel over `background` and returns it as a 2x PNG, `margin` points around.
async function renderPanel(browser, port, style, background, margin, layout = "dial", toolCount = STILL_TOOLS) {
  const page = await browser.newPage();
  try {
    await page.setViewport({ width: 800, height: 400, deviceScaleFactor: SCALE });
    await page.evaluateOnNewDocument(installTauriMock, { ...mockState, style, layout, usage: { ...mockState.usage, providers: providers.slice(0, toolCount) } }, FROZEN_SECONDS);
    await page.evaluateOnNewDocument(
      (css) => document.addEventListener("DOMContentLoaded", () => {
        const sheet = document.createElement("style");
        sheet.textContent = css;
        document.head.append(sheet);
      }),
      `html{background:${background}!important;padding:${margin}px}`,
    );
    await page.goto(`http://127.0.0.1:${port}/`);
    await page.waitForSelector(".panel");
    const box = await (await page.$(".panel")).boundingBox();
    return await page.screenshot({
      clip: { x: box.x - margin, y: box.y - margin, width: box.width + margin * 2, height: box.height + margin * 2 },
    });
  } finally {
    await page.close();
  }
}

// Sets the panels on one backdrop, the way the macOS reference render does: stacked in one
// column, or filling `rows` rows per column.
async function stackPanels(browser, panels, path, { x, y, gap }, rows = panels.length) {
  const page = await browser.newPage();
  try {
    const { x, y, gap } = STACK_PADDING;
    const images = panels.map((png) => `<img src="data:image/png;base64,${Buffer.from(png).toString("base64")}">`).join("");
    await page.setContent(
      `<style>body{margin:0;padding:${y}px ${x}px;background:${STACK_BACKGROUND};display:grid;grid-template-rows:repeat(${rows},auto);grid-auto-flow:column;justify-content:start;align-items:start;gap:${gap}px}img{display:block}</style>${images}`,
    );
    // The PNGs are 2x; showing them at half their pixel size makes them 1x layout points again.
    const widths = await page.$$eval("img", async (nodes, scale) => {
      await Promise.all(nodes.map((node) => node.decode()));
      nodes.forEach((node) => (node.style.width = `${node.naturalWidth / scale}px`));
      return nodes.map((node) => node.naturalWidth / scale);
    }, SCALE);
    const columns = Math.ceil(panels.length / rows);
    const width = Math.max(...widths) * columns + gap * (columns - 1) + x * 2;
    const height = await page.$eval("body", (body) => body.scrollHeight);
    await page.setViewport({ width: Math.ceil(width), height, deviceScaleFactor: SCALE });
    return await page.screenshot({ path });
  } finally {
    await page.close();
  }
}

attachSampleHistory();
const server = await serve();
const browser = await puppeteer.launch({ executablePath: chrome, headless: "shell" });
try {
  const { port } = server.address();
  const backdrop = "radial-gradient(circle at 50% 40%,#202020,#101010)";
  await writeFile(output, await renderPanel(browser, port, "mono", backdrop, MARGIN));
  console.log(`wrote ${output}`);
  const panels = [];
  for (const style of STYLES) panels.push(await renderPanel(browser, port, style, STACK_BACKGROUND, 0));
  await stackPanels(browser, panels, stylesOutput, STACK_PADDING);
  console.log(`wrote ${stylesOutput}`);
  const layoutPanels = [];
  for (const [style, layout] of LAYOUT_PANELS) {
    layoutPanels.push(await renderPanel(browser, port, style, STACK_BACKGROUND, 0, layout, providers.length));
  }
  await stackPanels(browser, layoutPanels, layoutsOutput, LAYOUTS_PADDING, LAYOUT_ROWS);
  console.log(`wrote ${layoutsOutput}`);
  const shapePanels = [];
  for (const layout of SHAPE_LAYOUTS) {
    for (const style of STYLES) shapePanels.push(await renderPanel(browser, port, style, STACK_BACKGROUND, 0, layout, providers.length));
  }
  await stackPanels(browser, shapePanels, shapesOutput, LAYOUTS_PADDING, SHAPE_ROWS);
  console.log(`wrote ${shapesOutput}`);
  const historyPanels = [];
  for (const style of STYLES) {
    for (const layout of HISTORY_LAYOUTS) historyPanels.push(await renderPanel(browser, port, style, STACK_BACKGROUND, 0, layout, providers.length));
  }
  await stackPanels(browser, historyPanels, historyOutput, LAYOUTS_PADDING, HISTORY_LAYOUTS.length);
  console.log(`wrote ${historyOutput}`);
} finally {
  await browser.close();
  server.close();
}
