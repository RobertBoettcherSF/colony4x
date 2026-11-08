// Runs the same Ada checks the native scenario runs, through WebAssembly.
import { readFileSync } from "node:fs";

const file = process.argv[2];
if (!file) {
  console.error("usage: node tools/smoke_wasm.mjs colony.wasm");
  process.exit(2);
}
const bytes = readFileSync(file);
let instance;
try {
  ({ instance } = await WebAssembly.instantiate(bytes, {}));
} catch (err) {
  console.error("WebAssembly instantiate failed:", err);
  process.exit(1);
}
const exp = instance.exports;
if (typeof exp.c4x_check_watch !== "function" || !exp.memory) {
  console.error("Ada exports missing");
  process.exit(1);
}

function text(kind, a = 0, b = 0) {
  const n = exp.c4x_text(kind, a, b);
  const ptr = exp.c4x_text_ptr() >>> 0;
  return new TextDecoder().decode(new Uint8Array(exp.memory.buffer, ptr, n));
}

if (exp.c4x_ready() !== 1 || text(0) !== "ada-wasm") {
  console.error("engine did not identify itself");
  process.exit(1);
}

const watch = exp.c4x_check_watch();
const watchLine = text(20);
console.log(watchLine);
if (watch !== 0 || !watchLine.startsWith("WATCH ok=0")) {
  console.error("watch check failed", watch);
  process.exit(1);
}
const manual = exp.c4x_check_manual();
const manualLine = text(20);
console.log(manualLine);
if (manual !== 0 || !manualLine.startsWith("MANUAL ok=0")) {
  console.error("manual check failed", manual);
  process.exit(1);
}
