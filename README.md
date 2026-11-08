# Colony4X

A clean-room, turn-based 4X. The **rules run in Ada**. The browser page only draws.

## Play

- **Live:** [robertboettchersf.github.io/colony4x](https://robertboettchersf.github.io/colony4x/) — same address as before. One file, `index.html`, with the WebAssembly embedded. Nothing is fetched, including `/api/ping`.
- **Offline:** open `index.html` (double-click, or `file://`). Press **Watch a game**. That is the whole demo: four AI factions, seed 7919, 36×24, Steward difficulty. Fast autoplay is on, so cities and units move without another click.
- **Play yourself:** the quieter button. You lead the Lumen Collective. Arrows move, B founds a city, Enter ends the turn. Research and policy call the same engine. Help is on the Help button.

If the engine cannot start, the page says so and stops. It does not switch to a JavaScript copy of the rules.

## Build

```sh
sudo apt-get install gnat gprbuild lld rpm2cpio cpio unzip clang
./tools/get-toolchain.sh   # AdaWebPack 24 into ./toolchain (gitignored)
./build.sh                 # native scenario, wasm, report comparison, index.html
```

`./scenario` prints two lines. `node tools/smoke_wasm.mjs obj/wasm/colony.wasm` prints the same lines. `./build.sh` fails if they differ.

Browser check (system Chrome, `puppeteer-core` on `NODE_PATH`):

```sh
node tools/browser_test.mjs
```

It opens `index.html` from disk, watches until cities appear, founds a city by hand, checks that walking into the sea is rejected, ends the turn, then loads the page over HTTP with `?live=1` against a server that 404s `/api/ping` and checks the indicator says unavailable while the game still runs.

The watched map is checked against the JavaScript edition’s generator for seed 7919 at 36×24: same land, moisture, rock, fungus and the same four start tiles. After that, both the native binary and WebAssembly run the Ada rules and must agree with each other for 20 AI turns and for a scripted found / illegal move / legal move.

## What this build plays

Surface colonisation: the real map generator, yields, growth, production, research tree, fog of war, morale, the four policy axes, territory, conquest / economic / dominion / ascension / score victories, natives and the land AI (expand, then military or economy). Factions start at war, which is Colony4X’s opening state, and this build keeps them there.

Not in this WebAssembly build, and not silently faked: warren supply sieges, tunnel flood and collapse, naval bombardment, and the diplomacy bargain / trade AI. Ships can still be built after Hydrodynamic Hulls and Coastal Docks, and they can move and fight at sea. The research blurbs say when an order is absent.

## Other ways to run it

- `python3 play.py` serves the folder and opens `index.html?live=1`, so the optional live log (`/api/ping`, `/api/log`, `col-feedback.json`) still works. The public page never asks for that.
- `python3 play.py --classic` opens `classic.html`, the previous JavaScript edition, also only pinging when `?live=1` is present.
- `game.js` remains the JavaScript edition used by `classic.html`, `sim.js` and the map-parity oracle. The demo does not load it.

## Licence

MIT. All original content © Robert Boettcher. The Ada port was built with assistance from a coding agent under that project’s direction.
