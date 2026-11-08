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

`./scenario` prints three lines, `WATCH`, `MANUAL` and `MECH`. Each line carries `status=pass` when every expectation held and `status=fail` when one did not. `code=0` is only a success code next to `status=pass`; a line that merely contains `0` is not a pass. The process exits 0 only when every line is `status=pass`. `node tools/smoke_wasm.mjs obj/wasm/colony.wasm` prints the same three lines and exits non-zero on `status=fail` or a non-zero code. `./build.sh` fails if the native and WebAssembly reports differ, if the `MECH` and `REST` lines differ from `node tools/js_mechanics.mjs`, or if `./scenario trace` differs from `node tools/js_trace.mjs`. That trace is the same seed 7919, 36×24 game for 25 turns with events, diplomatic victories and cooperative victories off, and it compares the full turn record: random stream, cities, population, units, credits, research, plans, and hashes of units, cities, fungus and unit locations.

Browser check (system Chrome, `puppeteer-core` on `NODE_PATH`):

```sh
node tools/browser_test.mjs
```

It opens `index.html` from disk, watches until cities appear, founds a city by hand, checks that walking into the sea is rejected, ends the turn, then loads the page over HTTP with `?live=1` against a server that 404s `/api/ping` and checks the indicator says unavailable while the game still runs.

The watched map is checked against the JavaScript edition’s generator for seed 7919 at 36×24: same land, moisture, rock, fungus and the same four start tiles. After that, both the native binary and WebAssembly run the Ada rules and must agree with each other for 20 AI turns and for a scripted found / illegal move / legal move. `MECH` and `REST` replay the ported rules on fresh copies of that map and must match `game.js`: warren supply, tunnels, bombardment, diplomacy, the opening strategic plans, fog-ghost strength, the `warTarget` ceasefire exception, burrower rush, ferry boarding, and diplomatic and cooperative victories.

## What this build plays

The map generator, yields, growth, production, research, fog, morale, policies, territory, and the JavaScript victory set: conquest, ascension, economic, dominion, score, diplomatic, and cooperative. The default rule word is 911, the same switches as `game.js` `DEFAULT_RULES` (those victories, plus events). Warren supply, tunnel dig / flood / collapse, naval bombardment, the diplomacy bargain and trade AI, the depth-3 strategic planner, burrower rush, and troop transports (board, carry, land, and sail cargo toward another landmass) are in the Ada engine. `classic.html` is the previous JavaScript edition, linked from the landing card; a failed engine does not fall back to it. Nothing here changes the live Pages root until the pull request is merged.

`./scenario trace` and `node tools/js_trace.mjs` print the same 26 snapshots for that events-off game, including the random stream. The comparison calls `act({type:'endTurn'})`, which is what the original client does, so production costs include the current policy. Calling `endTurn` by itself leaves that state unset and is not the played rules.

The landing card has an Aggressive rivals checkbox. It sets rule bit 10. The default word stays 911, so the switch is off unless the box is checked, matching `DEFAULT_RULES`.

## Rule map

These `game.js` rules are in the Ada engine and are what the 25-turn trace and the `MECH`/`REST` fixtures exercise: map generation, movement and combat, city work, yields, growth, production (including garrison support and the policy cost), morale, riots, mood events, war weariness, research, territory and sea dominion, supply, tunnels, bombardment, diplomacy including withdrawal after a treaty, the depth-3 planner, city build order, colonist and terraformer job choice, military orders, the reverse strike march, burrower rush, transports, the trade shuttle’s same-landmass test, and the victory checks.

Presentation only, not a second simulation: city and faction names, the event log wording, the canvas, and the help text.

Still not the same as `game.js`, and not exercised by the 25-turn trace:

- The AI policy reviser after turn 40. The engine does set each personality’s opening policy at turn 15. It does not re-evaluate that policy on the later schedule.
- The military “wait for a ship” branch that sends an army to a port when every known enemy city is on another landmass. Strike marches that stay on one landmass use the original reverse path.
- A full all-AI game with random events left on is not claimed to stay identical past the fixture. The trace above turns events off so the comparison can be exact. Event resolution itself (windfall, pod, flare, harvest, bloom, surge) is in the engine.

## Other ways to run it

- `python3 play.py` serves the folder and opens `index.html?live=1`, so the optional live log (`/api/ping`, `/api/log`, `col-feedback.json`) still works. The public page never asks for that.
- `python3 play.py --classic` opens `classic.html`, the previous JavaScript edition, also only pinging when `?live=1` is present.
- `game.js` remains the JavaScript edition used by `classic.html`, `sim.js` and the map-parity oracle. The demo does not load it.

## Licence

MIT. All original content © Robert Boettcher. The Ada port was built with assistance from a coding agent under that project’s direction.
