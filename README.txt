Colony4X v0.7
PLAY: double-click index.html (works offline in GNOME Web, Firefox, Chrome). Press ? in game for help.

FEEDBACK: F9 or the purple "Save feedback (F9)" button, at any time, downloads col-feedback.json to Downloads.
  Everything since the page opened is logged continuously in browser storage (survives reloads): clicks, keys,
  dialogs, toasts, errors, every game action, autoplay speed / take-control / hand-back, turn summaries, stats,
  full game state. Uncaught errors download col-feedback.json automatically (max once a minute); game end once.
  Optional: python3 play.py serves the game on localhost and rewrites col-feedback.json here after every action.

NEW IN v0.7 – full social policy
 - Four policy axes, four choices each (the first is neutral):
   Economy: Balanced Ledger / Open Exchange (+20% energy, -10% minerals, Reputation gains +25%) /
     Directed Output (+15% minerals, -15% energy) / Symbiotic Charter (+1 nutrient per city, -10% minerals,
     fungus relations +5)
   Focus: Civic Balance / Inquiry Mandate (+20% labs, -10% minerals) / Vigilance Doctrine (+20% attack,
     -15% labs) / Prosperity Pact (+1 nutrient per city, -10% labs)
   Society: Civic Assembly / Merit Councils (research -12%, growth 10% slower) / Frontier Charter
     (colonists -30%, growth 10% faster, +1 upkeep per 4 cities, -5% labs) / Martial Levy (military -10%,
     Reputation gains -25%, double switch unrest)
   Environment: Managed Land / Extractive Drive (+12% minerals, more Spore Beasts, fungus relations -12) /
     Fungal Harmony (free fungus moves, beasts calmer, fungus relations +10, -10% minerals) /
     Reclamation Corps (terraforming 35% faster, +1 energy per 3 cities, -5% energy, fungus relations -5)
 - Policy screen (Y): all axes, current choices, switch cost, net one-line effect, rivals' policies.
   Free until turn 20; after that each switch costs 20 + 3 credits per city and causes 3 turns of unrest
   (-15% minerals and labs; shown in the top bar).
 - AI picks by personality (Iron military, Lumen research, Drift expansion, Verdant eco/fungus) and
   revises every 10 turns when behind, threatened, or near an ascension, economic or dominion win.
 - Every change is logged (policyChanged with cost, unrest and reason); F9 logs have a policies block.

NEW IN v0.6 – ships and navies
 - Hydrodynamic Hulls unlocks Coastal Docks (coastal cities), Scout Skiff, Troop Transport (carries 3) and
   Frigate; Naval Ordnance + Armoured Hulls unlock the Assault Cruiser. Fisheries / Tidal Collectors add
   +1 nutrients / +1 energy per worked ocean tile.
 - Land units board by moving onto their transport (or E) and land by moving onto a shore tile. A sunk
   transport loses its cargo. Ships defend x1.25 on coasts, x0.9 in open ocean, x0.6 in port; attacks
   from a transport are x0.7.
 - Frigates and Cruisers bombard (O, or click) coastal cities and warren entrances next to them.
 - With docks, Sea Colonists sail alone and found up to 3 tiles from land. Ocean tiles held by sea
   cities count toward dominion.
 - AI: Iron and Drift ferry assaults and run sea trade routes, Lumen scouts, Verdant guards its coasts;
   all ferry colonists to other islands. New "islands" map type in setup and batch (MAP=islands in sim).
 - The log records ship builds, boardings, landings, sinkings, bombardments and trade runs, plus a naval block.

NEW IN v0.5 – diplomacy
 - Relations: every pair of factions is at war, ceasefire (lapses after 15 turns), peace or alliance; plus open
   borders and resource trades (credits for energy or minerals, delivered over 10 turns). Press D or the
   "Diplomacy (D)" button: standing with everyone, Reputation, lock-outs, running contracts, recent deals,
   the offer log, offers waiting for your answer, and propose / trade / declare-war buttons.
 - Under a treaty you cannot attack that faction or enter its land (unless open borders or allied); declare
   war first. Keeping treaties raises Reputation; breaking a ceasefire/peace/alliance costs 15/25/35 and
   locks you out of good deals for 30 turns. AIs read Reputation and their personality: Iron fights and only
   makes peace when losing, Lumen buys energy for research, Drift sells for credits, Verdant seeks peace and
   fungus-friendly pacts. All deterministic, every offer and answer logged (F9 col-feedback "diplomacy").
 - New victories (rules screen switches): diplomatic (top-score faction at peace/allied with a majority of
   living factions, Reputation 60+, 15 turns, from turn 120) and cooperative (shared win with allies).
 - Tests: test-dip.js (engine) plus diplomacy checks in test-ui.js (WebKit, Firefox, Chrome).

NEW IN v0.4.1 – warren supply, sieges, collapse/flood, anti-stalemate
 - Supply: a warren needs at least one held surface entrance, linked to it by your unflooded tunnels. An
   entrance is its own shaft or a tunnel tile next to one of your surface cities. It counts as held while no
   enemy combat unit stands next to it.
   Supplied warrens refill their reserves (+2 per turn). Cut off, they drain:
     air  3 (+2 with CO2 Scrubbers): -1 per turn, half speed with Scrubbers
     food 8 (16 with Hydroponic Vats): -1 per turn, half speed with Vats
     power 6: -1 per turn; at 0 production stops
   No air: units inside take 2 damage a turn and the population suffocates. After 2 airless turns the warren
   surrenders to the besieger (or is abandoned if nobody is next to it). Units standing in cut-off tunnels
   cannot heal and lose 1 HP a turn (never below 1).
 - Collapse tunnel (K on a selected empty tunnel tile of yours, or the tile panel button): needs one of your
   units within 2 tiles or a base within 3. The tile is lost and anyone inside takes 5 damage.
   Flood tunnel (L with a unit next to a tunnel): needs water next to the tunnel or Seismic Sapping. The
   tunnel stops working and anyone inside takes 3 damage. A Burrower re-digs or pumps out with J.
 - New tech Seismic Sapping (Lithic Boring + Plasma Lance): your units can assault warrens from the surface,
   the x1.5 warren defence does not apply against you, and you can flood any tunnel.
 - Warrens claim territory only within 2 tiles. Victory projects still cannot be built underground.
 - Anti-stalemate: large-map project costs and city/pop requirements are scaled back (Array needs 6 cities and
   42 pop on big maps, the charge takes 15 turns). The economic target grows only 25% with map area (3500 on
   64x40). After turn 200 the dominion threshold eases from 50% to 40% by turn 250.
 - AI: besiegers send every third unit next to an enemy warren, flood tunnels near it and assault when they
   can. Defenders collapse tunnel tiles that intruders reach next to their warrens and build Scrubbers.
 - Map/UI: the city panel shows reserves and SUPPLY CUT. Warning triangles mark warrens (orange = cut/low,
   red = almost out of air). Flooded tunnels are drawn blue and collapsed ones as grey rubble/X.
 - New events: supplyCut, supplyRestored, reservesLow, tunnelCollapsed, tunnelFlooded, tunnelRepaired,
   warrenSurrendered. Stats add sieges, cutOff, collapses, floods, surrenders.
 - Speed: route searches are memoised within a turn (identical results, verified by hash).

NEW IN v0.4 – underground bases ("Warrens") and tunnels
 - Tech Lithic Boring (after Deep Core Sampling) unlocks the Burrower (U, cost 35).
 - B with a Burrower on rocky or high ground (elevation > 0.6) founds an Underground Base (costs the unit).
   It works the rock below its own radius: 0 nutrients, minerals 1 + rockiness (+1 on rocky), +1 energy on
   tunnel tiles. Pop cap 6 (10 with a Dome; Hydroponics Vat helps it grow). It ignores fungus, Spore Beasts and
   surface events and defends at x1.5. Enemies can attack it only from a tunnel tile next to it or with an
   attack-4+ unit (Lancer, Skimmer, Striker). Victory projects cannot be built underground.
 - J with a Burrower digs a tunnel on its tile (2 turns, 3 on rocky). Your units move free between your own
   tunnel tiles (up to 8 steps a turn). Any enemy unit that steps onto your tunnel tile breaches it and the
   tile becomes theirs. Tunnels do not add territory.
 - If your capital is captured or destroyed, the capital moves to a warren if you have one, otherwise to your
   biggest city (event capitalMoved).
 - View: U (or the "View" button) toggles Surface/Underground. Underground shows rock, tunnels in faction
   colours, warrens and the units in tunnels. On the surface, tunnel entrances are small dark squares and
   warrens are dark tiles with a coloured frame. The city and unit panels work as usual.
 - AI: builds Burrowers once it has Lithic Boring and 2+ cities. It founds up to 2 warrens (militant: 3) on
   the most mineral-rich rocky sites, then tunnels from each warren to its nearest city. A faction down to
   1-2 cities builds a refuge warren. Militant factions at war dig "war tunnels" towards the target city so
   that troopers can breach warrens. All of it is deterministic, so replays stay exact.
 - New log events: cityFounded{ug}, tunnelDug{rush}, tunnelBreached, capitalMoved, ui:view. statsTable adds
   warrens, warrensFounded, tunnels, rushTiles, breaches, ugCapital. sim.js reports per-faction usage.
 - Speed: the AI reuses route searches and per-turn lookups (army marches share one route search).
 - Tests: node test-ug.js (46 checks for underground bases and tunnels incl. exact replay); test-ui.js checks U/J,
   the drawing and the help page in WebKit, Firefox and Chromium.

NEW IN v0.3.3
 - AI speed: pathfinding rewritten (occupancy mask, typed-array queue, one search per move order) – about 3-4x
   faster; worst AI turn ~70-120 ms in node on large 4-faction maps (deterministic, replay exact).
 - Balance: Iron Meridian +12% attack (+25% from turn 100) and tribute from captured cities; Verdant fungus
   yields 1/1/1 before Mycelial Accord and beasts ignore it only 1 time in 4; Lumen starts with an extra trooper;
   Free Drift grows 15% faster. Large maps: victory projects cost more (scaled by map area), the Array needs
   7 cities / 48 pop and charges for 18 turns.

NEW IN v0.3.2
 - Batch runs (and sim.js) cycle every faction subset and rotate start slots, so each faction plays equally often.
 - Fewer early knock-outs: AI does not attack cities during the grace period (longer on small maps), young
   cities (<15 turns) +50% defence, a faction's last city +75% defence before turn 100.
 - Economic target scales with map size; Verdant Covenant is ignored by Spore Beasts a third of the time;
   Lumen Collective +45% research.

NEW IN v0.3.1
 - Main menu > "Batch run": N AI-only games headless in the browser with progress bar + Cancel; results table;
   one compact col-feedback.json (per-game summaries, 10-turn samples, key events, plan counts, seeds).
 - Balance: AI "grace period" before strikes and random events (longer on easy levels), sturdier capitals,
   dominion needs 50% land, Spore Beasts no longer fully ignore the Verdant Covenant, Free Drift growth +10%.
 - F9 right after a game end says the game-end log was already saved.
 - sim.js now rotates which faction takes which start slot (env F=factions, RS=1 random seeds).

NEW IN v0.3
 - Main menu (Start game, Quick start = last settings, Load game, Watch autoplay, Credits) and one setup page:
   rules (Standard / Customize), 6 difficulty levels with explanations, map, faction.
 - Toggleable rules: conquest, ascension, economic, dominion victories; full map survey, accelerated start,
   slower research, blind research, aggressive rivals, random events. Score victory at turn 300 always on.
 - Multi-stage ascension: Ascendant Convergence -> Resonance Beacon -> Ascension Array (needs 5 cities, 35 pop,
   announced to everyone) -> 12-turn charge that fails if the city is captured. Rivals strike the builder.
 - AI strategy: depth-3 minimax (alpha-beta) over an abstract economy model each turn (expand/econ/military/
   project/strike); AI buys and hurries projects; per-turn AI time logged in turn summaries (aiMs).
 - Anti-snowball: inefficiency per city, upkeep per city, research cost scales with empire size.
 - Social policy (Y): four axes (see v0.7). Random events. ~40 original land + 12 sea
   city names per faction. Docs: docs/CONCEPTS.md (concepts we have + prioritised backlog).

NEW IN v0.2
 - Autoplay: tick "Autoplay" on the New game screen. Speed Pause/1x/Fast/Max (P), Follow camera, Reveal map (V).
   C = take control of any faction (autoplay pauses) / hand back to AI (autoplay resumes). Works in normal games too.
 - Stats panel (G, and automatically at game end): cities, pop, techs, units, built/lost/kills/founded, score;
   charts of score, population and cities over time.
 - Usability: red toast for rejected orders/keys, greyed-out units without moves, auto-next unit, End turn
   glows when all units are done, tile move cost + territory in tile info, numpad 1-9 with NumLock on or off
   (5 = skip), unit-count badges on cities/stacks, clickable "Units here" list.
 - Cities: name prompt when founding, rename (city panel), dashed work-radius box, faction territory borders
   (radius 3, 4 for pop 5+); nobody can found inside a rival's territory.
 - Sea cities: Tidal Harvest unlocks the Sea Colonist; stand on the coast and press B to found on adjacent ocean.
 - Fixed: log events with undefined type (setResearch etc.).

Balance: node sim.js game.js 24   (env D=0..5 difficulty, H=1 treat faction 0 as the human)
Tests: node test-ug.js (underground); node test-batch.js (batch mode); node test.js (engine, 6x200-turn AI games, territory, replay); with `npm i playwright`:
  node test-ui.js (dialogs, F9, keys, cities, persistence), node test-autoplay.js (autoplay to game end,
  take control / hand back), node test-live.js (play.py live log). Run in WebKit, Firefox and Chromium.
