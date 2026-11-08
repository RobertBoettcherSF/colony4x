// Reference outcomes for the ported rules, taken from game.js itself.
import { createRequire } from "node:module";
import path from "node:path";
import { fileURLToPath } from "node:url";

const require = createRequire(import.meta.url);
const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const G = require(path.join(root, "game.js"));

function game() {
  return G.newGame({
    seed: 7919, w: 36, h: 24, allAI: false, numAI: 3, playerKey: "meridian",
    difficulty: 2,
    rules: Object.assign({}, G.DEFAULT_RULES, {
      events: false, diplomatic: false, cooperative: false
    })
  });
}
function rocky(S) {
  for (let i = 0; i < S.tiles.length; i++) {
    const t = S.tiles[i];
    if (t.land && G.X(S, i) > 2 && G.Y(S, i) > 2 && (t.r === 2 || t.e > 0.6)) return i;
  }
  return -1;
}
function coastal(S) {
  for (let i = 0; i < S.tiles.length; i++) {
    if (!S.tiles[i].land) continue;
    if (G.nbrs(S, i).some(n => !S.tiles[n].land)) return i;
  }
  return -1;
}
function firstSea(S, at) {
  for (const n of G.nbrs(S, at)) if (!S.tiles[n].land) return n;
  return -1;
}
function landStand(S, at) {
  for (const n of G.nbrs(S, at)) if (S.tiles[n].land && n !== at) return n;
  return at;
}

const out = { code: 0 };
{
  const S = game();
  const site = rocky(S);
  S.factions[0].techs.push("boring");
  const u = G.makeUnit(S, 0, "burrower", site);
  const founded = G.act(S, { type: "found", u: u.id, f: 0 });
  if (!founded.ok) out.code = 2;
  else {
    const c = S.cities[S.cities.length - 1];
    const n = G.nbrs(S, c.at)[0];
    G.makeUnit(S, 1, "lancer", n);
    G.updateSeen(S, 0);
    G.supplyTurn(S); G.supplyTurn(S); G.supplyTurn(S);
    out.air = c.res.air; out.food = c.res.food; out.pow = c.res.pow;
    out.cut = c.cut ? 1 : 0; out.wpop = c.pop;
  }
}
{
  const S = game();
  let site = -1;
  for (let i = 0; i < S.tiles.length; i++) {
    if (S.tiles[i].land && G.X(S, i) > 2 && G.Y(S, i) > 2) { site = i; break; }
  }
  S.tiles[site].tun = 0;
  const foe = G.makeUnit(S, 1, "trooper", site);
  foe.hp = 8;
  const id = foe.id;
  G.makeUnit(S, 0, "scout", landStand(S, site));
  const err = G.collapseTunnel(S, 0, site);
  if (err) out.code = 3;
  else {
    const left = S.units.find(u => u.id === id);
    out.col_hp = left ? left.hp : 0;
    out.collapsed = S.tiles[site].col ? 1 : 0;
  }
}
{
  const S = game();
  const site = coastal(S);
  const stand = landStand(S, site);
  S.tiles[site].tun = 1;
  const foe = G.makeUnit(S, 1, "trooper", site);
  foe.hp = 6;
  const id = foe.id;
  const own = G.makeUnit(S, 0, "scout", stand);
  const err = G.floodTunnel(S, own, site);
  if (err) out.code = 4;
  else {
    const left = S.units.find(u => u.id === id);
    out.flood_hp = left ? left.hp : 0;
    out.flooded = S.tiles[site].fl ? 1 : 0;
  }
}
{
  const S = game();
  const site = coastal(S);
  const u = G.makeUnit(S, 0, "colonist", site);
  const founded = G.act(S, { type: "found", u: u.id, f: 0 });
  if (!founded.ok) out.code = 5;
  else {
    const c = S.cities[S.cities.length - 1];
    const sea = firstSea(S, c.at);
    const ship = G.makeUnit(S, 1, "frigate", sea);
    const err = G.bombard(S, ship, c.at);
    if (err) out.code = 5;
    else {
      const ev = S.log[S.log.length - 1];
      out.bomb_hits = ev.hits;
      out.bomb_hp = ship.hp;
      out.bomb_pop = c.pop;
      out.bomb_prod = c.prod;
      out.bomb_rs = S.rs >>> 0;
    }
  }
}
{
  const S = game();
  G.dip(S);
  S.dip.contact[0][2] = S.dip.contact[2][0] = 1;
  S.factions[0].ai = true;
  S.factions[2].ai = true;
  const iron = G.propose(S, 2, 0, { kind: "ceasefire" });
  out.iron_cease = S.dip.rel[2][0] === "war" ? 0 : 1;
  if (!iron.ok) out.code = 6;
  const verd = G.propose(S, 0, 2, { kind: "ceasefire" });
  out.verdant_rel = { war: 0, ceasefire: 1, peace: 2, alliance: 3 }[S.dip.rel[0][2]];
  if (!verd.ok) out.code = 6;
  S.dip.since[0][2] = S.dip.since[2][0] = S.turn - 3;
  const peace = G.propose(S, 0, 2, { kind: "peace" });
  out.peace_rel = { war: 0, ceasefire: 1, peace: 2, alliance: 3 }[S.dip.rel[0][2]];
  if (!peace.ok) out.code = 6;
  S.factions[2].credits = 100;
  const trade = G.propose(S, 0, 2, { kind: "trade", res: "minerals", amt: 2, price: 23, buy: false });
  if (!trade.ok) out.code = 6;
  out.trade = S.dip.contracts.some(c => c.seller === 0 && c.buyer === 2) ? 2 : (S.dip.rel[0][2] === "peace" ? 1 : 0);
  out.sell_cr = S.factions[0].credits;
  out.buy_cr = S.factions[2].credits;
}
{
  const S = game();
  let site = -1;
  for (let i = 0; i < S.tiles.length; i++) {
    if (S.tiles[i].land && G.X(S, i) > 2 && G.Y(S, i) > 2 && S.tiles[i].r !== 2) { site = i; break; }
  }
  S.factions[0].techs.push("boring");
  const u = G.makeUnit(S, 0, "burrower", site);
  const r = G.act(S, { type: "terra", u: u.id, f: 0, kind: "tunnel" });
  if (!r.ok) out.code = 7;
  else out.dig = u.work.left;
  out.far = 0;
  for (let i = 0; i < S.tiles.length; i++) {
    if (!S.tiles[i].land) continue;
    if (S.units.some(u => G.dist(S, u.at, i) <= 2)) continue;
    S.tiles[i].tun = 0;
    out.far = G.collapseTunnel(S, 0, i) ? 1 : 0;
    break;
  }
}
{
  const S = game();
  const site = coastal(S);
  const stand = landStand(S, site);
  S.tiles[site].tun = 1;
  const own = G.makeUnit(S, 0, "scout", stand);
  const err = G.floodTunnel(S, own, null);
  out.aflood = !err && S.tiles[site].fl ? 1 : 0;
}
{
  const S = game();
  const site = rocky(S);
  S.factions[0].techs.push("boring");
  const u = G.makeUnit(S, 0, "burrower", site);
  const founded = G.act(S, { type: "found", u: u.id, f: 0 });
  if (!founded.ok) out.code = 8;
  else {
    const c = S.cities[S.cities.length - 1];
    c.res = { air: 0, food: 8, pow: 6 };
    c.airOut = 1;
    c.pop = 1;
    G.makeUnit(S, 0, "trooper", c.at);
    const n = G.nbrs(S, c.at)[0];
    G.makeUnit(S, 1, "lancer", n);
    G.updateSeen(S, 0);
    G.supplyTurn(S);
    out.surr = c.f;
    out.leftu = S.units.filter(u => u.at === c.at && u.f === 0).length;
  }
}
{
  const S = game();
  G.dip(S);
  for (const [a, b] of [[0, 2], [0, 3], [2, 3]]) S.dip.contact[a][b] = S.dip.contact[b][a] = 1;
  for (const f of S.factions) f.ai = true;
  G.setRel(S, 0, 2, "peace", "test");
  S.dip.since[0][2] = S.dip.since[2][0] = S.turn - 8;
  S.dip.rep[0] = 70;
  const ally = G.propose(S, 0, 2, { kind: "alliance" });
  if (!ally.ok) out.code = 9;
  out.ally = { war: 0, ceasefire: 1, peace: 2, alliance: 3 }[S.dip.rel[0][2]];
  G.setRel(S, 3, 2, "peace", "test");
  S.dip.rep[3] = 50;
  const borders = G.propose(S, 3, 2, { kind: "openBorders" });
  if (!borders.ok) out.code = 9;
  out.ob = S.dip.ob[3][2] ? 1 : 0;
  G.setRel(S, 0, 3, "peace", "test");
  S.factions[0].credits = 100;
  S.factions[3].credits = 100;
  S.dip.rep[0] = 50;
  const lo = G.propose(S, 0, 3, { kind: "trade", res: "minerals", amt: 2, price: 22, buy: true });
  if (!lo.ok) out.code = 9;
  out.tlo = S.dip.contracts.some(c => c.live !== false) ? 1 : 0;
  const hi = G.propose(S, 0, 3, { kind: "trade", res: "minerals", amt: 2, price: 23, buy: true });
  if (!hi.ok) out.code = 9;
  out.thi = S.dip.contracts.length ? 1 : 0;
}
const status = out.code === 0 ? "status=pass" : "status=fail";
const line = [
  "MECH", status, "code=" + out.code,
  "air=" + out.air, "food=" + out.food, "pow=" + out.pow, "cut=" + out.cut, "wpop=" + out.wpop,
  "col_hp=" + out.col_hp, "collapsed=" + out.collapsed,
  "flood_hp=" + out.flood_hp, "flooded=" + out.flooded,
  "bomb_hits=" + out.bomb_hits, "bomb_hp=" + out.bomb_hp, "bomb_pop=" + out.bomb_pop,
  "bomb_prod=" + out.bomb_prod, "bomb_rs=" + out.bomb_rs,
  "iron_cease=" + out.iron_cease, "verdant_rel=" + out.verdant_rel,
  "peace_rel=" + out.peace_rel, "trade=" + out.trade,
  "sell_cr=" + out.sell_cr, "buy_cr=" + out.buy_cr,
  "dig=" + out.dig, "far=" + out.far, "aflood=" + out.aflood,
  "surr=" + out.surr, "leftu=" + out.leftu,
  "ally=" + out.ally, "ob=" + out.ob, "tlo=" + out.tlo, "thi=" + out.thi
].join(" ");
console.log(line);
if (out.code !== 0) process.exit(1);
