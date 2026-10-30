# Colony4X – concepts map and backlog

All names here are Colony4X originals. Ideas come from general 4X genre conventions and the publicly documented list
of mechanic categories (altitude, rainfall, rockiness, territory, inefficiency, random events, …). No text, names or
art from any existing game are used.

## Already in the game (v0.3)
| Concept | Colony4X version |
|---|---|
| Terrain: elevation, rainfall, rockiness | moisture 0-2, rockiness 0-2, elevation → nutrients / minerals / energy |
| Nutrients, minerals, energy, labs | city yields; energy slider splits credits vs labs |
| Research | 16 techs, prerequisites, cost scales with techs known and city count; optional blind research |
| Native life & fungus | spreading fungus, Spore Beasts, Mycelial Accord tech, Verdant Covenant affinity |
| Territory / borders | radius 3 (4 at pop 5+), no founding inside rival land, dominion victory |
| Inefficiency | -5% energy per city above 5 (max -50%), +1 credit upkeep per city above 8, research cost +4%/city above 4 |
| Energy reserves | credits; buying production; AI hurries projects with credits |
| Base conquest | capture or destroy cities; city loses 1 pop on capture |
| Damage & repair | 10 HP units, healing in the field and faster in cities |
| Victory & defeat | conquest, ascension (Beacon → Array → 12-turn charge, announced), economic (3000 credits), dominion (45% land for 10 turns), score at T300; all toggleable |
| Difficulty | six levels Cadet → Paragon (AI and player production/research multipliers, native pressure) |
| Random events | windfall, supply pod, solar flare, bumper harvest, fungal bloom, spore surge (toggle) |
| Social policy (minimal) | two axes – Economy (Balanced Ledger / Open Exchange / Directed Output / Symbiotic Charter) and Focus (Civic Balance / Inquiry Mandate / Vigilance Doctrine / Prosperity Pact); 30 credits to switch; AI picks by personality |
| AI strategy | depth-3 minimax with alpha-beta over an abstract economy/military model choosing expand / build up / arm / project / strike; rivals strike whoever is closest to winning |

## Backlog (prioritised)
1. ~~**Social policy, full version (HIGH)**~~ – DONE in v0.7 (four axes × four choices, switch cost + brief unrest, AI by personality/situation; no favoured/forbidden choices or lookahead yet) – four axes with real trade-offs and prerequisites:
   - *Governance*: Assembly Rule (+growth, -defence when at war), Directorate (+minerals, -happiness), Steward Council (+efficiency), Free Congress (+labs, AI dislikes you).
   - *Economy*: Open Exchange, Directed Output, Symbiotic Charter (eco: + fungus yields, -mineral cap).
   - *Values*: Inquiry, Vigilance, Prosperity, Harmony (fewer unrest, slower growth).
   - *Future tier* unlocked by late techs (e.g. Cybernetic Union, Neural Commons).
   Each faction has a favoured and a forbidden choice; AI evaluates policies through the same lookahead model.
2. ~~**Unrest / morale of citizens (HIGH)**~~ – DONE in v0.8 (content/restless/rioting, entertainment facilities, policy and difficulty pressure, riots, AI response) – content vs restless citizens, entertainment facilities, policy effects; also feeds difficulty (the classic "harder = more unrest" lever).
3. **Diplomacy – DONE in v0.5** – war / ceasefire / peace / alliance, open borders, credits↔energy/minerals trade contracts, Reputation (honour raises it, betrayal drops it hard and locks out good deals), personality-driven deterministic AI offers, diplomatic victory (council leader at peace/allied with a majority) and cooperative victory (shared win with allies), both switchable on the rules screen. Not done: tribute, shared vision, an elected council vote.
4. **Unit design workshop (MED)** – chassis + weapon + armour + ability → prototypes with a one-off extra cost.
5. **Zone of control & disengage (MED)** – can't move between two enemy-adjacent tiles; fast units may retreat.
6. ~~**Ships, sea transport, sea terraforming (MED)**~~ – DONE in v0.6: docks, skiffs, transports, frigates, cruisers, bombardment, fisheries, tidal collectors, far-out sea cities (no sea terraforming yet).
7. **Landmarks & ancient sites (MED)** – unique terrain with bonuses; ruins ("drop caches") giving random rewards.
8. **Specialists (MED)** – citizens as technicians / researchers instead of working tiles.
9. **Psi combat vs natives (LOW)** – native fights use a morale-based strength, not weapons.
10. **City governors & automation (LOW)** – auto-build / auto-explore / auto-terraform orders for the player.
11. ~~**True fog of war (HIGH)**~~ – DONE in v0.9: current vision radius per unit/city (fast units and ships farther, +1 on rocky/high ground, Sensor Lattice tech +1), explored-but-unseen land dimmed with last-known terrain, last-seen ghosts for rival cities and armies, AI and combat use only what each faction actually sees; logs cityRediscovered / stackLostInFog / fogEncounter.
11. **Energy grid & resonance links (LOW)** – bonuses for networks of connected cities/collectors.
12. **Deep Warrens & tunnels** – see README design note.

## AI heuristics in use (informed by public community strategy discussions; nothing copied)
- Expand hard early (the planner forces expansion while a faction has fewer than 4 cities before turn 25).
- Terraform worked tiles first: farms on wet flat land, mines on rocky land, solar where elevation is high; clear fungus.
- Defend before attacking: every city keeps a garrison; scholarly factions keep two from turn 12.
- Rush (buy) production with spare credits; hurry victory projects; stop spending when going for an economic win.
- Strike the leader: when a rival announces or charges the Ascension Array, every other AI switches to strike and marches on that city.

## v0.3.1 learnings applied (from public difficulty/strategy write-ups; paraphrased, nothing copied)
- Harder levels in the genre mostly change AI production cost and how early random events start; easy levels add
  protections. Colony4X now has a difficulty-scaled grace period (turn 45 on Cadet down to 30 on Paragon) before
  AI strikes and random events, on top of the existing production/labs multipliers.
- "Delayed gang-up" behaviour: AIs don't launch strikes during the grace period unless someone starts ascending.
- Capitals are sturdier (+50% defence, +80% for the research faction) so early rushes don't snowball.
- Backlog: unrest thresholds by difficulty (citizens become restless earlier on hard levels); AI not starting a
  victory project before the human has the prerequisite on easy levels.
