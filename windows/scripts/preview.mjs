// Renders the frontend with mock data in headless Chrome and writes preview.png at 2x.
// The real frontend code runs unchanged; only the Tauri bridge is replaced by a mock.
import { createReadStream, existsSync, statSync } from "node:fs";
import { homedir } from "node:os";
import { dirname, extname, join, normalize } from "node:path";
import { createServer } from "node:http";
import { fileURLToPath } from "node:url";
import puppeteer from "puppeteer-core";

const root = join(dirname(fileURLToPath(import.meta.url)), "..");
const dist = join(root, "dist");
const output = join(root, "preview.png");
const chrome =
  process.env.CHROME_PATH ??
  join(homedir(), ".cache/puppeteer/chrome-headless-shell/mac_arm-155.0.8059.84/chrome-headless-shell-mac-arm64/chrome-headless-shell");
const SCALE = 2;
const FROZEN_SECONDS = 12.4;
const MARGIN = 28;

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

const window_ = (displayPercent, remainingPercent, elapsedFraction, label, countdown, level = "comfortable") => ({
  displayPercent, remainingPercent, elapsedFraction, label, countdown, level,
});

const mockState = {
  usage: {
    measuredAt: new Date(2026, 9, 21, 12, 4).getTime(),
    providers: [
      {
        id: "claude", title: "Claude", plan: "Max", message: null,
        session: window_(94, 94, 0.234, "5시간", "3시간 50분"),
        weekly: window_(37, 37, 0.57, "주간", "3일 0시간"),
      },
      {
        id: "codex", title: "Codex", plan: "Plus", message: null,
        session: window_(8, 8, 0.843, "5시간", "47분", "critical"),
        weekly: window_(26, 26, 0.4, "주간", "6일 16시간", "low"),
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

const server = await serve();
const browser = await puppeteer.launch({ executablePath: chrome, headless: "shell" });
try {
  const page = await browser.newPage();
  const { port } = server.address();
  await page.evaluateOnNewDocument(installTauriMock, mockState, FROZEN_SECONDS);
  await page.evaluateOnNewDocument((margin) => {
    document.addEventListener("DOMContentLoaded", () => {
      const style = document.createElement("style");
      style.textContent = `html{background:radial-gradient(circle at 50% 40%,#202020,#101010)!important;padding:${margin}px}`;
      document.head.append(style);
    });
  }, MARGIN);
  await page.goto(`http://127.0.0.1:${port}/`);
  await page.waitForSelector(".panel");
  const box = await (await page.$(".panel")).boundingBox();
  await page.setViewport({
    width: Math.ceil(box.width) + MARGIN * 2,
    height: Math.ceil(box.height) + MARGIN * 2,
    deviceScaleFactor: SCALE,
  });
  await page.reload();
  await page.waitForSelector(".panel");
  await page.screenshot({ path: output });
  console.log(`wrote ${output}`);
} finally {
  await browser.close();
  server.close();
}
