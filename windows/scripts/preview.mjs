// Renders the frontend with mock data in headless Chrome and writes four images at 2x:
// preview.png (the panel: dial, mono), preview-graphs.png (all twelve forms, each labelled),
// preview-styles.png (the dial in mono, iris and dot) and preview-interaction.png (per style a
// tool's page opened from its tab, the overview with one cell hovered and a one-chart form with
// one tool focused).
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
const graphsOutput = join(root, "preview-graphs.png");
const stylesOutput = join(root, "preview-styles.png");
const interactionOutput = join(root, "preview-interaction.png");
const historyFixture = join(tmpdir(), "usage-gauge-preview-history.json");
const chrome =
  process.env.CHROME_PATH ??
  join(
    homedir(),
    ".cache/puppeteer/chrome-headless-shell/mac_arm-155.0.8059.84/chrome-headless-shell-mac-arm64/chrome-headless-shell",
  );
const SCALE = 2;
const FROZEN_SECONDS = 12.4;
const MARGIN = 28;
const STYLES = ["mono", "iris", "dot"];
const STILL_TOOLS = 2;
const SETTLE_MS = 700;
const BACKDROP = "#0b101a";
const LABEL_COLOR = "rgb(255 255 255 / 0.55)";
const SHEET_PADDING = { x: 56, y: 48, gap: 32 };

/** The twelve forms in the macOS order, as [id, Korean name]. */
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
const GRAPH_COLUMNS = 3;
/** Mostly mono, calmly mixed: one row of the graphs sheet in iris, one in dot. */
const GRAPH_ROW_STYLES = ["mono", "iris", "mono", "dot"];

/** What the interaction image shows: a tool's page, a hovered cell, a focused one-chart form. */
const INTERACTION_TOOL = "claude";
const INTERACTION_HOVERED = "codex";
const FOCUS_FORMS = {
  mono: ["orbit", `.orbit-row[data-tool="${INTERACTION_HOVERED}"]`],
  iris: ["constellation", `.constellation-node[data-tool="${INTERACTION_HOVERED}"] .tag-slot`],
  dot: ["orbit", `.orbit-row[data-tool="${INTERACTION_HOVERED}"]`],
};

// The sample history comes from the Rust history code itself, so the preview shows what the app would send.
function attachSampleHistory() {
  execFileSync(
    "cargo",
    [
      "test",
      "--manifest-path",
      join(root, "src-tauri/Cargo.toml"),
      "dump_preview_history",
      "--",
      "--ignored",
    ],
    {
      env: { ...process.env, USAGE_GAUGE_PREVIEW_HISTORY: historyFixture },
      stdio: "ignore",
    },
  );
  const histories = JSON.parse(readFileSync(historyFixture, "utf8"));
  for (const provider of providers)
    provider.history = onSampleMoment(histories[provider.id] ?? null);
}

// The fixture is dated by the Rust test's clock; moves it onto the preview's moment so no time in
// the history disagrees with the header or the hover lines.
function onSampleMoment(history) {
  if (!history) return null;
  const shift = NOW - history.now;
  const moved = (time) => (time === null ? null : time + shift);
  return {
    ...history,
    now: NOW,
    periodStart: moved(history.periodStart),
    periodEnd: moved(history.periodEnd),
    projectedEmpty: moved(history.projectedEmpty),
    points: history.points.map((point) => ({ ...point, at: point.at + shift })),
  };
}

const types = {
  ".html": "text/html",
  ".js": "text/javascript",
  ".css": "text/css",
};

function serve() {
  const server = createServer((request, response) => {
    const path = normalize(request.url.split("?")[0]).replace(
      /^(\.\.[/\\])+/,
      "",
    );
    const file = join(dist, path === "/" ? "index.html" : path);
    if (
      !file.startsWith(dist) ||
      !existsSync(file) ||
      !statSync(file).isFile()
    ) {
      response.writeHead(404).end();
      return;
    }
    response.writeHead(200, {
      "content-type": types[extname(file)] ?? "application/octet-stream",
    });
    createReadStream(file).pipe(response);
  });
  return new Promise((resolve) =>
    server.listen(0, "127.0.0.1", () => resolve(server)),
  );
}

// One sample moment for the whole preview, as in the macOS renders: the numbers were measured at
// 오후 4:50, ten minutes before "now" (오후 5:00), so the header status, the hover line and the
// tool pages all agree, and every reset time counts from the same now.
const NOW = new Date(2026, 9, 21, 17, 0).getTime();
const MEASURED_AT = NOW - 10 * 60_000;
const window_ = (
  displayPercent,
  remainingPercent,
  elapsedFraction,
  label,
  countdown,
  countdownCompact,
  minutesLeft,
  level = "comfortable",
) => ({
  displayPercent,
  remainingPercent,
  elapsedFraction,
  label,
  countdown,
  countdownCompact,
  resetsAt: NOW + minutesLeft * 60_000,
  level,
});

const providers = [
  {
    id: "claude",
    title: "Claude",
    plan: "Max",
    message: null,
    measuredAt: MEASURED_AT,
    session: window_(94, 94, 0.234, "5시간", "3시간 50분", "3h 50m", 230),
    weekly: window_(37, 37, 0.57, "주간", "3일 0시간", "3d 0h", 4320),
    // Where the usage history puts each tool an hour ago; the constellation draws a trail from it.
    hourAgo: { session: 100, weekly: 38 },
  },
  {
    id: "codex",
    title: "Codex",
    plan: "Plus",
    message: null,
    measuredAt: MEASURED_AT,
    session: window_(8, 8, 0.843, "5시간", "47분", "47m", 47, "critical"),
    weekly: window_(26, 26, 0.4, "주간", "6일 16시간", "6d 16h", 9600, "low"),
    hourAgo: { session: 21, weekly: 27 },
  },
  {
    id: "gemini",
    title: "Gemini",
    plan: "Pro",
    message: null,
    measuredAt: MEASURED_AT,
    session: window_(71, 71, 0.6, "일간", "9시간 0분", "9h 0m", 540),
    weekly: window_(88, 88, 0.28, "주간", "5일 0시간", "5d 0h", 7200),
    hourAgo: { session: 74, weekly: 88 },
  },
  {
    id: "cursor",
    title: "Cursor",
    plan: "Pro",
    message: null,
    measuredAt: MEASURED_AT,
    session: window_(46, 46, 0.46, "5시간", "2시간 10분", "2h 10m", 130),
    weekly: window_(53, 53, 0.4, "월간", "16일 16시간", "16d 16h", 24000),
    hourAgo: { session: 52, weekly: 54 },
  },
];

const mockState = {
  usage: { measuredAt: MEASURED_AT, providers },
  opacity: 1,
  isShown: true,
  hasGlass: true,
  layout: "dial",
  /** What the backend lists for the header picker: all twelve forms, as on macOS. */
  layouts: FORMS.map(([id, title]) => ({ id, title })),
  scale: 1,
};

// Stands in for window.__TAURI_INTERNALS__ so the app's own bridge code runs in a plain browser.
function installTauriMock(state, frozenSeconds) {
  let callbackId = 0;
  window.__TAURI_INTERNALS__ = {
    metadata: {
      currentWindow: { label: "main" },
      currentWebview: { windowLabel: "main", label: "main" },
    },
    transformCallback: () => ++callbackId,
    invoke: async (command) => (command === "get_state" ? state : 0),
  };
  const origin = performance.now();
  performance.now = () => origin + frozenSeconds * 1000;
}

// Draws one panel over `background` and returns it as a 2x PNG, `margin` points around.
async function renderPanel(
  browser,
  port,
  style,
  background,
  margin,
  layout = "dial",
  toolCount = STILL_TOOLS,
  interact = null,
) {
  const page = await browser.newPage();
  try {
    await page.setViewport({
      width: 800,
      height: 400,
      deviceScaleFactor: SCALE,
    });
    await page.evaluateOnNewDocument(
      installTauriMock,
      {
        ...mockState,
        style,
        layout,
        usage: { ...mockState.usage, providers: providers.slice(0, toolCount) },
      },
      FROZEN_SECONDS,
    );
    await page.evaluateOnNewDocument(
      (css) =>
        document.addEventListener("DOMContentLoaded", () => {
          const sheet = document.createElement("style");
          sheet.textContent = css;
          document.head.append(sheet);
        }),
      `html{background:${background}!important;padding:${margin}px}`,
    );
    await page.goto(`http://127.0.0.1:${port}/`);
    await page.waitForSelector(".panel");
    if (interact) {
      await interact(page);
      await new Promise((resolve) => setTimeout(resolve, SETTLE_MS));
    }
    const box = await (await page.$(".panel")).boundingBox();
    return await page.screenshot({
      clip: {
        x: box.x - margin,
        y: box.y - margin,
        width: box.width + margin * 2,
        height: box.height + margin * 2,
      },
    });
  } finally {
    await page.close();
  }
}

// Sets rendered panels on one backdrop in `columns` columns, each under its label if it has one.
async function composeSheet(browser, items, path, columns) {
  const page = await browser.newPage();
  try {
    const { x, y, gap } = SHEET_PADDING;
    const cells = items
      .map(({ png, label }) => {
        const caption = label ? `<figcaption>${label}</figcaption>` : "";
        return `<figure>${caption}<img src="data:image/png;base64,${Buffer.from(png).toString("base64")}"></figure>`;
      })
      .join("");
    await page.setContent(
      `<style>body{margin:0;width:max-content;padding:${y}px ${x}px;background:${BACKDROP};display:grid;grid-template-columns:repeat(${columns},max-content);justify-content:start;align-items:start;gap:${gap}px}` +
        `figure{margin:0}figcaption{margin:0 0 10px 4px;font:500 13px "Segoe UI","Apple SD Gothic Neo","Malgun Gothic",system-ui,sans-serif;color:${LABEL_COLOR}}img{display:block}</style>${cells}`,
    );
    // The PNGs are 2x; showing them at half their pixel size makes them 1x layout points again.
    await page.$$eval(
      "img",
      async (nodes, scale) => {
        await Promise.all(nodes.map((node) => node.decode()));
        nodes.forEach(
          (node) => (node.style.width = `${node.naturalWidth / scale}px`),
        );
      },
      SCALE,
    );
    // The body hugs the grid, so its box includes the padding on every side.
    const { width, height } = await page.$eval("body", (body) => {
      const box = body.getBoundingClientRect();
      return { width: Math.ceil(box.width), height: Math.ceil(box.height) };
    });
    await page.setViewport({ width, height, deviceScaleFactor: SCALE });
    return await page.screenshot({ path });
  } finally {
    await page.close();
  }
}

attachSampleHistory();
const server = await serve();
const browser = await puppeteer.launch({
  executablePath: chrome,
  headless: "shell",
});
try {
  const { port } = server.address();
  const heroBackdrop = "radial-gradient(circle at 50% 40%,#202020,#101010)";
  await writeFile(
    output,
    await renderPanel(browser, port, "mono", heroBackdrop, MARGIN),
  );
  console.log(`wrote ${output}`);

  const graphs = [];
  for (const [index, [layout, label]] of FORMS.entries()) {
    const style = GRAPH_ROW_STYLES[Math.floor(index / GRAPH_COLUMNS)];
    graphs.push({
      png: await renderPanel(
        browser,
        port,
        style,
        BACKDROP,
        0,
        layout,
        providers.length,
      ),
      label,
    });
  }
  await composeSheet(browser, graphs, graphsOutput, GRAPH_COLUMNS);
  console.log(`wrote ${graphsOutput}`);

  const styles = [];
  for (const style of STYLES)
    styles.push({ png: await renderPanel(browser, port, style, BACKDROP, 0) });
  await composeSheet(browser, styles, stylesOutput, 1);
  console.log(`wrote ${stylesOutput}`);

  const openTool = (page) => page.click(`.tab[data-tab="${INTERACTION_TOOL}"]`);
  const hoverCell = (page) =>
    page.hover(`.cell[data-tool="${INTERACTION_HOVERED}"]`);
  const interaction = [];
  for (const style of STYLES) {
    const [form, mark] = FOCUS_FORMS[style];
    const focusMark = (page) => page.hover(mark);
    interaction.push({
      png: await renderPanel(
        browser,
        port,
        style,
        BACKDROP,
        0,
        "dial",
        providers.length,
        openTool,
      ),
    });
    interaction.push({
      png: await renderPanel(
        browser,
        port,
        style,
        BACKDROP,
        0,
        "dial",
        providers.length,
        hoverCell,
      ),
    });
    interaction.push({
      png: await renderPanel(
        browser,
        port,
        style,
        BACKDROP,
        0,
        form,
        providers.length,
        focusMark,
      ),
    });
  }
  await composeSheet(browser, interaction, interactionOutput, 3);
  console.log(`wrote ${interactionOutput}`);
} finally {
  await browser.close();
  server.close();
}
