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
if (typeof exp.c4x_check_watch !== "function" || typeof exp.c4x_check_mechanics !== "function" || !exp.memory) {
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

function expectPass(label, code, line) {
  console.log(line);
  // status=pass means every expectation held. status=fail is a mismatch.
  // code=0 is only meaningful together with status=pass. A line that merely
  // contains the digits 0 is not success.
  if (code !== 0 || !line.includes("status=pass") || line.includes("status=fail")) {
    console.error(label + " failed", code);
    process.exit(1);
  }
}
expectPass("watch", exp.c4x_check_watch(), text(20));
expectPass("manual", exp.c4x_check_manual(), text(20));
expectPass("mechanics", exp.c4x_check_mechanics(), text(20));
