import "./style.css";
import { bridge } from "./bridge";
import { Panel } from "./panel";

async function start(): Promise<void> {
  const root = document.getElementById("root");
  if (!root) throw new Error("Missing #root");
  const panel = new Panel(root, await bridge.state());
  await bridge.onUsage((usage) => panel.render(usage));
  await bridge.onVisibility((isShown) => panel.setShown(isShown));
}

start().catch((error) => console.error("UsageGauge failed to start", error));
