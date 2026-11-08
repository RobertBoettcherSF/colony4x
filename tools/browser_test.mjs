// Browser checks for the self-contained Colony4X page.
// Uses the system Chrome. No JavaScript rules engine is allowed to load.
import { createRequire } from "node:module";
import { spawn } from "node:child_process";
import { fileURLToPath } from "node:url";
import path from "node:path";
import http from "node:http";
import fs from "node:fs";

const require = createRequire(import.meta.url);
const puppeteer = require("puppeteer-core");
const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const html = path.join(root, "index.html");
const chrome = process.env.CHROME || "/usr/local/bin/google-chrome";
const shot = process.env.SHOT || "/tmp/colony4x-watch.png";
const shotManual = process.env.SHOT_MANUAL || "/tmp/colony4x-manual.png";

function fail(msg) {
  console.error("FAIL", msg);
  process.exit(1);
}

const browser = await puppeteer.launch({
  executablePath: chrome,
  headless: "new",
  args: ["--no-sandbox", "--disable-gpu", "--allow-file-access-from-files"]
});
const page = await browser.newPage();
await page.setViewport({ width: 1280, height: 800 });
const requests = [];
page.on("request", req => requests.push(req.url()));
page.on("pageerror", err => console.error("pageerror", err.message));
page.on("console", msg => {
  if (msg.type() === "error") console.error("console", msg.text());
});

await page.goto("file://" + html, { waitUntil: "load" });
await page.waitForFunction(() => document.getElementById("watchBtn") && !document.getElementById("watchBtn").disabled, { timeout: 15000 });
const engine = await page.evaluate(() => window.__c4x && window.__c4x.engine());
if (engine !== "ada-wasm") fail("engine is " + engine);
const classic = await page.$eval("#card a", a => a.getAttribute("href"));
if (classic !== "classic.html") fail("classic link is " + classic);
if (requests.some(u => u.includes("/api/ping"))) fail("file page requested /api/ping");
const errBox = await page.$eval("#errorBox", el => el.hidden);
if (!errBox) fail("error box visible before play");

await page.click("#watchBtn");
await page.waitForFunction(() => {
  const t = document.getElementById("turnLabel");
  const c = document.getElementById("cityLabel");
  if (!t || !c) return false;
  return Number(t.textContent) >= 8 && parseInt(c.textContent, 10) >= 2;
}, { timeout: 20000 });
const watched = await page.evaluate(() => ({
  turn: window.__c4x.turn(),
  cities: window.__c4x.cities(),
  feed: document.getElementById("feed").innerText
}));
if (watched.turn < 8 || watched.cities < 2) fail("watch did not progress " + JSON.stringify(watched));
if (!/founds|grows|discovers|emerges|fights/i.test(watched.feed)) fail("feed has no progress: " + watched.feed);
await page.screenshot({ path: shot });
console.log("WATCH", JSON.stringify(watched));

await page.goto("file://" + html, { waitUntil: "load" });
await page.waitForFunction(() => !document.getElementById("playBtn").disabled, { timeout: 15000 });
await page.click("#playBtn");
await page.waitForFunction(() => !document.getElementById("foundBtn").disabled, { timeout: 10000 });
await page.click("#diploBtn");
await page.waitForFunction(() => {
  const box = document.getElementById("mbox");
  return box && /Diplomacy/.test(box.innerText) && /War/.test(box.innerText) && /Offer trade/.test(box.innerText);
}, { timeout: 5000 });
await page.click("#mbox [data-close]");
await page.waitForFunction(() => document.getElementById("modal").hidden, { timeout: 5000 });
await page.click("#foundBtn");
await page.waitForFunction(() => /founds/.test(document.getElementById("feed").innerText), { timeout: 5000 });
await page.click("#map", { offset: { x: 4, y: 4 } });
await page.waitForFunction(() => {
  const toast = document.getElementById("toast");
  return toast && !toast.hidden && /sea|adjacent|cannot|rival|rejected/i.test(toast.textContent);
}, { timeout: 5000 });
const toast = await page.$eval("#toast", el => el.textContent);
await page.click("#endBtn");
await page.waitForFunction(() => Number(document.getElementById("turnLabel").textContent) === 2, { timeout: 5000 });
const manual = await page.evaluate(() => ({
  turn: window.__c4x.turn(),
  cities: window.__c4x.cities(),
  human: window.__c4x.human()
}));
if (manual.turn !== 2 || manual.cities < 1 || manual.human !== 0) fail("manual " + JSON.stringify(manual));
await page.screenshot({ path: shotManual });
console.log("MANUAL", JSON.stringify(manual), "toast:", toast);

await browser.close();

// Static server with no /api/ping. ?live=1 must say unavailable and still start.
const server = http.createServer((req, res) => {
  if (req.url.startsWith("/api/")) {
    res.writeHead(404, { "Content-Type": "text/plain" });
    res.end("no");
    return;
  }
  const file = path.join(root, req.url.split("?")[0] === "/" ? "index.html" : req.url.split("?")[0]);
  fs.readFile(file, (err, data) => {
    if (err) { res.writeHead(404); res.end("missing"); return; }
    res.writeHead(200, { "Content-Type": "text/html" });
    res.end(data);
  });
});
await new Promise(r => server.listen(0, "127.0.0.1", r));
const port = server.address().port;
const browser2 = await puppeteer.launch({
  executablePath: chrome,
  headless: "new",
  args: ["--no-sandbox", "--disable-gpu"]
});
const page2 = await browser2.newPage();
const seen = [];
page2.on("response", res => { if (res.url().includes("/api/")) seen.push(res.status() + " " + res.url()); });
await page2.goto(`http://127.0.0.1:${port}/index.html?live=1`, { waitUntil: "load" });
await page2.waitForFunction(() => document.getElementById("liveInd").textContent.includes("unavailable"), { timeout: 8000 });
await page2.waitForFunction(() => !document.getElementById("watchBtn").disabled, { timeout: 8000 });
await page2.click("#watchBtn");
await page2.waitForFunction(() => Number(document.getElementById("turnLabel").textContent) >= 2, { timeout: 10000 });
const ind = await page2.$eval("#liveInd", el => el.textContent);
if (!/unavailable/.test(ind)) fail("live indicator " + ind);
if (!seen.some(s => s.startsWith("404"))) fail("expected a 404 from the optional ping, saw " + seen.join(","));
console.log("LIVE", ind, seen.join(" | "));
await browser2.close();
server.close();
console.log("browser tests passed");
