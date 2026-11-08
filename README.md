# Colony4X

A clean-room, turn-based 4X. The **rules run in Ada**. The browser page only draws.

## Play

- **Live:** [robertboettchersf.github.io/colony4x](https://robertboettchersf.github.io/colony4x/) — same address as before. One file, `index.html`, with the WebAssembly embedded. Nothing is fetched, including `/api/ping`.
- **Offline:** open `index.html` (double-click, or `file://`). Press **Watch a game**. That is the whole demo: four AI factions, seed 7919, 36×24, Steward difficulty. Fast autoplay is on, so cities and units move without another click.
- **Play yourself:** the quieter button. You lead the Lumen Collective. Arrows move, B founds a city or warren, J digs a tunnel, K collapses one, L floods one, O bombards, D opens diplomacy, Enter ends the turn. Research and policy call the same engine. Help is on the Help button.

If the engine cannot start, the page says so and stops. It does not switch to a JavaScript copy of the rules.

## Build

```sh
sudo apt-get install gnat gprbuild lld rpm2cpio cpio unzip clang
./tools/get-toolchain.sh   # AdaWebPack 24 into ./toolchain (gitignored)
./build.sh                 # native scenario, wasm, report comparison, index.html
```

`./scenario` prints three lines, `WATCH`, `MANUAL` and `MECH`. Each line carries `status=pass` when every expectation held and `status=fail` when one did not. `code=0` is only a success code next to `status=pass`; a line that merely contains `0` is not a pass. The process exits 0 only when every line is `status=pass`. `node tools/smoke_wasm.mjs obj/wasm/colony.wasm` prints the same three lines and exits non-zero on `status=fail` or a non-zero code. `./build.sh` fails if the native and WebAssembly reports differ, or if the `MECH` line differs from `node tools/js_mechanics.mjs` (the JavaScript rules, same fixtures).

Browser check (system Chrome, `puppeteer-core` on `NODE_PATH`):

```sh
node tools/browser_test.mjs
```

It opens `index.html` from disk, watches until cities appear, founds a city by hand, checks that walking into the sea is rejected, ends the turn, then loads the page over HTTP with `?live=1` against a server that 404s `/api/ping` and checks the indicator says unavailable while the game still runs.

The watched map is checked against the JavaScript edition’s generator for seed 7919 at 36×24: same land, moisture, rock, fungus and the same four start tiles. After that, both the native binary and WebAssembly run the Ada rules and must agree with each other for 20 AI turns and for a scripted found / illegal move / legal move. `MECH` and `REST` replay the ported rules on fresh copies of that map and must match `game.js`: warren supply, tunnels, bombardment, diplomacy, the opening strategic plans, fog-ghost strength, the `warTarget` ceasefire exception, burrower rush, ferry boarding, and diplomatic and cooperative victories.

## What this build plays

The map generator, yields, growth, production, research, fog, morale, policies, territory, and the JavaScript victory set: conquest, ascension, economic, dominion, score, diplomatic, and cooperative. The default rule word is 911, the same switches as `game.js` `DEFAULT_RULES` (those victories, plus events). Warren supply, tunnel dig / flood / collapse, naval bombardment, the diplomacy bargain and trade AI, the depth-3 strategic planner, burrower rush, and troop transports (board, carry, land, and sail cargo toward another landmass) are in the Ada engine. `classic.html` is the previous JavaScript edition, linked from the landing card; a failed engine does not fall back to it. Nothing here changes the live Pages root until the pull request is merged.

A 25-turn smoke (`long=1`) finishes with cities on the map in both engines. It is not a byte-identical autoplay. On seed 7919, 36×24, events off, after 25 turns the JavaScript edition had 5 cities, population 16 and 21 units; this Ada engine had 7 cities, population 15 and 20 units. The single-step colonist, terraformer and military choices on a fresh map match `game.js` (`col`, `terra`, `mil` on the `REST` line). The later difference comes from the rest of the turn, not from a shortened copy of those three loops.

Checklist of what is still not the JavaScript edition:

- City production, growth, morale and riots are not a line-for-line port, so a long game drifts even when a single order matches.
- A strike march uses the forward path. The JavaScript `marchTo` walks a path searched from the destination, which can pick another shortest path when several exist.
- The `aggressive` rules switch is off in both defaults. It is not a separate bit in the rule word.
- An own-land trade shuttle skips every land city when the home port is on land. The JavaScript rule skips that city only when it is on the same landmass. Sea-city shuttles, which the fixture checks, follow the original choice.

## Other ways to run it

- `python3 play.py` serves the folder and opens `index.html?live=1`, so the optional live log (`/api/ping`, `/api/log`, `col-feedback.json`) still works. The public page never asks for that.
- `python3 play.py --classic` opens `classic.html`, the previous JavaScript edition, also only pinging when `?live=1` is present.
- `game.js` remains the JavaScript edition used by `classic.html`, `sim.js` and the map-parity oracle. The demo does not load it.

## Licence

MIT. All original content © Robert Boettcher. The Ada port was built with assistance from a coding agent under that project’s direction.
