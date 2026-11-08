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

const rest = { code: 0 };
const planName = { expand: 0, econ: 1, military: 2, project: 3, strike: 4 };
{
  const S = game();
  const plans = [];
  for (const f of S.factions) {
    G.planFaction(S, f.id);
    plans.push(planName[f.plan]);
  }
  rest.plans = plans.join(",");
}
{
  const S = game();
  let a = -1, b = -1, best = 0;
  for (let i = 0; i < S.tiles.length; i++) {
    if (!S.tiles[i].land) continue;
    for (let j = 0; j < S.tiles.length; j++) {
      if (!S.tiles[j].land) continue;
      const d = G.dist(S, i, j);
      if (d > best && d < 20) { best = d; a = i; b = j; }
    }
  }
  for (const u of S.units) if (u.f === 0) u.at = a;
  const foe = G.makeUnit(S, 1, "trooper", G.nbrs(S, a).find(n => S.tiles[n].land));
  G.updateSeen(S, 0);
  for (const u of S.units) if (u.f === 0) u.at = b;
  foe.at = a;
  G.updateSeen(S, 0);
  rest.ghost = Math.round(G.knownMil(S, 0, 1) * 100);
}
{
  const S = game();
  G.makeUnit(S, 1, "striker", S.factions[1].start);
  G.dip(S);
  S.dip.contact[0][1] = S.dip.contact[1][0] = 1;
  S.factions[0].ai = S.factions[1].ai = true;
  S.factions[1].warTarget = 0;
  G.propose(S, 0, 1, { kind: "ceasefire" });
  rest.wt = S.dip.rel[0][1] === "war" ? 0 : 1;
  S.factions[1].warTarget = null;
  G.propose(S, 0, 1, { kind: "ceasefire" });
  rest.wt2 = { war: 0, ceasefire: 1, peace: 2, alliance: 3 }[S.dip.rel[0][1]];
}
{
  const S = game();
  let job = -1;
  outer: for (let i = 0; i < S.tiles.length; i++) {
    if (!S.tiles[i].land || G.X(S, i) < 3 || G.Y(S, i) < 3) continue;
    for (const n of G.nbrs(S, i)) {
      if (!S.tiles[n].land) continue;
      for (const c of G.nbrs(S, n)) {
        if (c !== i && S.tiles[c].land && G.dist(S, i, c) === 2 && !G.cityAt(S, c)) { job = [i, n, c]; break outer; }
      }
    }
  }
  const [anchor, mid, city] = job;
  S.tiles[anchor].tun = 0;
  const bur = G.makeUnit(S, 0, "burrower", anchor);
  const founder = G.makeUnit(S, 1, "colonist", city);
  const founded = G.act(S, { type: "found", u: founder.id, f: 1 });
  if (!founded.ok) rest.code = 3;
  else {
    G.updateSeen(S, 0);
    S.factions[0].warTarget = 1;
    const ok = G.aiRush(S, bur);
    rest.rush = ok ? 1 : 0;
    rest.rjob = bur.tgt;
    rest.rleft = bur.work ? bur.work.left : -1;
    if (mid !== bur.tgt && rest.rush) rest.mid = mid;
  }
}
{
  const S = game();
  const site = coastal(S);
  const sea = G.nbrs(S, site).find(n => !S.tiles[n].land);
  const ship = G.makeUnit(S, 0, "transport", sea);
  const man = G.makeUnit(S, 0, "colonist", site);
  const boarded = G.act(S, { type: "move", u: man.id, f: 0, to: sea });
  rest.aboard = boarded.ok && man.on === ship.id ? 1 : 0;
  const next = G.nbrs(S, sea).find(n => !S.tiles[n].land && G.nbrs(S, n).some(k => S.tiles[k].land));
  if (next == null) rest.code = 4;
  else {
    const sailed = G.act(S, { type: "move", u: ship.id, f: 0, to: next });
    rest.carried = sailed.ok && man.at === ship.at ? 1 : 0;
    const shore = G.nbrs(S, ship.at).find(n => S.tiles[n].land);
    man.mp = G.UNITS.colonist.mv * 3;
    const landed = shore == null ? { ok: false } : G.act(S, { type: "move", u: man.id, f: 0, to: shore });
    rest.landed = landed.ok && man.on == null && man.mp === 0 && S.tiles[man.at].land ? 1 : 0;
  }
}
{
  const S = game();
  const site = coastal(S);
  const ship = G.makeUnit(S, 0, "transport", site);
  const man = G.makeUnit(S, 0, "colonist", site);
  man.wantShip = true;
  G.loadWaiters(S, ship);
  rest.loaded = man.on === ship.id ? 1 : 0;
}
{
  const S = game();
  S.opts.rules = Object.assign({}, S.opts.rules, { diplomatic: true, cooperative: false, events: false });
  S.turn = 120;
  G.dip(S);
  const founder = S.units.find(u => u.f === 0 && u.type === "colonist");
  const founded = G.act(S, { type: "found", u: founder.id, f: 0 });
  if (!founded.ok) rest.code = 5;
  else {
    G.setRel(S, 0, 1, "peace", "test");
    G.setRel(S, 0, 2, "peace", "test");
    S.dip.since[0][1] = S.dip.since[1][0] = 100;
    S.dip.since[0][2] = S.dip.since[2][0] = 100;
    S.dip.rep[0] = 60;
    for (let i = 0; i < 15; i++) G.diploVictory(S);
    rest.dwin = S.winner == null ? -1 : S.winner;
    rest.dtype = S.winType === "diplomatic" ? 7 : 0;
  }
}
{
  const S = game();
  S.opts.rules = Object.assign({}, S.opts.rules, { diplomatic: false, cooperative: true, events: false });
  S.turn = 120;
  G.dip(S);
  S.factions[2].alive = S.factions[3].alive = false;
  const founder = S.units.find(u => u.f === 0 && u.type === "colonist");
  G.act(S, { type: "found", u: founder.id, f: 0 });
  G.setRel(S, 0, 1, "alliance", "test");
  S.dip.since[0][1] = S.dip.since[1][0] = S.turn - 10;
  S.factions[0].landShare = 0.4;
  S.factions[1].landShare = 0.3;
  for (let i = 0; i < 15; i++) G.diploVictory(S);
  rest.cwin = S.winner == null ? -1 : S.winner;
  rest.ctype = S.winType === "cooperative" ? 8 : 0;
}
const rstatus = rest.code === 0 ? "status=pass" : "status=fail";
console.log([
  "REST", rstatus, "code=" + rest.code,
  "plans=" + rest.plans, "ghost=" + rest.ghost,
  "wt=" + rest.wt, "wt2=" + rest.wt2,
  "rush=" + rest.rush, "rjob=" + rest.rjob, "rleft=" + rest.rleft,
  "aboard=" + rest.aboard, "carried=" + rest.carried, "landed=" + rest.landed, "loaded=" + rest.loaded,
  "dwin=" + rest.dwin, "dtype=" + rest.dtype, "cwin=" + rest.cwin, "ctype=" + rest.ctype
].join(" "));
if (out.code !== 0 || rest.code !== 0) process.exit(1);
