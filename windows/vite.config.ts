import { defineConfig } from "vite";

// Tauri serves the built files from disk, so assets must resolve relative to index.html.
export default defineConfig({
  base: "./",
  clearScreen: false,
  server: { port: 1420, strictPort: true },
  build: { target: "es2022", outDir: "dist" },
});
