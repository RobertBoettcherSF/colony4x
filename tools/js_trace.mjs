// 25-turn snapshot oracle for the events-off seed 7919 game.
// Turns go through act(), the same entry the original client uses, so
// item costs see the current policy. Calling endTurn() directly leaves
// that state unset and is not how the game is played.
import { createRequire } from "node:module";
import path from "node:path";
import { fileURLToPath } from "node:url";

const require = createRequire(import.meta.url);
const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const G = require(path.join(root, "game.js"));
const kinds = ["colonist", "seacolony", "burrower", "terraformer", "scout", "trooper", "warden", "lancer", "striker", "skimmer", "skiff", "transport", "frigate", "cruiser", "beast", "rebel"];
const plans = { expand: 0, econ: 1, military: 2, project: 3, strike: 4 };

function mix(h, v) { return Math.imul(h, 16777619) ^ (v | 0); }
function snap(S) {
  let pop = 0, uh = 216613626, ch = 216613626, fh = 216613626, lh = 216613626;
  const cities = S.cities.slice().sort((a, b) => a.id - b.id);
  for (const c of cities) {
    pop += c.pop;
    ch = mix(ch, c.id); ch = mix(ch, c.f); ch = mix(ch, c.at); ch = mix(ch, c.pop); ch = mix(ch, c.food | 0); ch = mix(ch, c.prod | 0);
  }
  const units = S.units.slice().sort((a, b) => a.id - b.id);
  for (const u of units) {
    uh = mix(uh, u.id); uh = mix(uh, u.f); uh = mix(uh, kinds.indexOf(u.type)); uh = mix(uh, u.at); uh = mix(uh, u.hp | 0);
    lh = mix(lh, (u.id * 17 + u.at) | 0); lh = mix(lh, u.tgt == null ? -1 : u.tgt | 0); lh = mix(lh, (u.hp | 0) + 3);
  }
  for (let i = 0; i < S.tiles.length; i++) if (S.tiles[i].f) fh = mix(fh, i);
  const cr = S.factions.map(f => f.credits).join(",");
  const tc = S.factions.map(f => f.techs.length).join(",");
  const pl = S.factions.map(f => plans[f.plan] ?? 0).join(",");
  console.log("T" + S.turn + " rs=" + (S.rs >>> 0) + " c=" + S.cities.length + " p=" + pop + " u=" + S.units.length
    + " cr=" + cr + " tc=" + tc + " pl=" + pl + " uh=" + uh + " ch=" + ch + " fh=" + fh + " lh=" + lh);
}
const allAI = process.argv[2] === "ai";
const S = G.newGame({
  seed: 7919, w: 36, h: 24, allAI, numAI: 3, playerKey: "meridian", difficulty: 2,
  rules: Object.assign({}, G.DEFAULT_RULES, { events: false, diplomatic: false, cooperative: false })
});
for (let i = 0; i <= 25; i++) {
  snap(S);
  if (i < 25) G.act(S, { type: "endTurn", f: -1 });
}
