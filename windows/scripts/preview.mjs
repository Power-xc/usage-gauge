// Renders the frontend with mock data in headless Chrome and writes preview.png (iris) and
// preview-styles.png (all three styles stacked), both at 2x.
// The real frontend code runs unchanged; only the Tauri bridge is replaced by a mock.
import { createReadStream, existsSync, statSync } from "node:fs";
import { writeFile } from "node:fs/promises";
import { homedir } from "node:os";
import { dirname, extname, join, normalize } from "node:path";
import { createServer } from "node:http";
import { fileURLToPath } from "node:url";
import puppeteer from "puppeteer-core";

const root = join(dirname(fileURLToPath(import.meta.url)), "..");
const dist = join(root, "dist");
const output = join(root, "preview.png");
const stylesOutput = join(root, "preview-styles.png");
const chrome =
  process.env.CHROME_PATH ??
  join(homedir(), ".cache/puppeteer/chrome-headless-shell/mac_arm-155.0.8059.84/chrome-headless-shell-mac-arm64/chrome-headless-shell");
const SCALE = 2;
const FROZEN_SECONDS = 12.4;
const MARGIN = 28;
const STYLES = ["iris", "dot", "mono"];
const STACK_BACKGROUND = "#0b101a";
const STACK_PADDING = { x: 72, y: 77, gap: 29 };

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

const mockState = {
  usage: {
    measuredAt: new Date(2026, 9, 21, 12, 4).getTime(),
    providers: [
      {
        id: "claude", title: "Claude", plan: "Max", message: null,
        session: window_(94, 94, 0.234, "5시간", "3시간 50분", "3h 50m"),
        weekly: window_(37, 37, 0.57, "주간", "3일 0시간", "3d 0h"),
      },
      {
        id: "codex", title: "Codex", plan: "Plus", message: null,
        session: window_(8, 8, 0.843, "5시간", "47분", "47m", "critical"),
        weekly: window_(26, 26, 0.4, "주간", "6일 16시간", "6d 16h", "low"),
      },
    ],
  },
  opacity: 1,
  isShown: true,
  hasGlass: true,
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
async function renderPanel(browser, port, style, background, margin) {
  const page = await browser.newPage();
  try {
    await page.setViewport({ width: 800, height: 400, deviceScaleFactor: SCALE });
    await page.evaluateOnNewDocument(installTauriMock, { ...mockState, style }, FROZEN_SECONDS);
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

// Stacks the panels on one backdrop, the way the macOS reference render does.
async function stackPanels(browser, panels) {
  const page = await browser.newPage();
  try {
    const { x, y, gap } = STACK_PADDING;
    const images = panels.map((png) => `<img src="data:image/png;base64,${Buffer.from(png).toString("base64")}">`).join("");
    await page.setContent(
      `<style>body{margin:0;padding:${y}px ${x}px;background:${STACK_BACKGROUND};display:flex;flex-direction:column;align-items:flex-start;gap:${gap}px}img{display:block}</style>${images}`,
    );
    // The PNGs are 2x; showing them at half their pixel size makes them 1x layout points again.
    const widths = await page.$$eval("img", async (nodes, scale) => {
      await Promise.all(nodes.map((node) => node.decode()));
      nodes.forEach((node) => (node.style.width = `${node.naturalWidth / scale}px`));
      return nodes.map((node) => node.naturalWidth / scale);
    }, SCALE);
    const width = Math.max(...widths) + x * 2;
    const height = await page.$eval("body", (body) => body.scrollHeight);
    await page.setViewport({ width: Math.ceil(width), height, deviceScaleFactor: SCALE });
    return await page.screenshot({ path: stylesOutput });
  } finally {
    await page.close();
  }
}

const server = await serve();
const browser = await puppeteer.launch({ executablePath: chrome, headless: "shell" });
try {
  const { port } = server.address();
  const backdrop = "radial-gradient(circle at 50% 40%,#202020,#101010)";
  await writeFile(output, await renderPanel(browser, port, "iris", backdrop, MARGIN));
  console.log(`wrote ${output}`);
  const panels = [];
  for (const style of STYLES) panels.push(await renderPanel(browser, port, style, STACK_BACKGROUND, 0));
  await stackPanels(browser, panels);
  console.log(`wrote ${stylesOutput}`);
} finally {
  await browser.close();
  server.close();
}
