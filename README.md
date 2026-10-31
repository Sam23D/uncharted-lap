# Uncharted Lap

Godot 4.5 trading game: sugar and cheese runs between four ports, a fleet ladder, a hired crew and pirate fights.

Win: trade your way up from the starting Sloop to a **Brig** (tier 3). A scripted greedy captain wins around day 31 (`tests/full_run_check.gd`).

## Run

```
/home/sam23d/Desktop/Godot_v4.5.1-stable_linux.x86_64 --path /home/sam23d/Documents/coding/uncharted-lap
```

`~/.local/bin/godot-dev` is a Hermes profile launcher, not the engine.

## Data

- Ports, prices, flags, chart position (`map`, 0-1 across the chart): `data/ports.json`
- Sailing days between ports: `data/routes.json` (one entry per pair, both directions)
- Supplies, pirate odds, fight and wage rules, armory prices, day modifiers: `data/voyage.json`
- Ships for sale (price, tier, hold, bunks, gun ports, hull, speed, minimum crew, sprite): `data/ships.json`
- Crew professions, wages and perks, sailor names: `data/crew.json`
- Pirate types (power, loot, shortest route they appear on): `data/pirates.json`

Rules beyond the market live in `scripts/rules/` as pure functions over `GameState`: `ship_rules.gd` (prices, trade-in, refusals), `crew_rules.gd` (rosters, wages, rations) and `combat_rules.gd` (pirate pick, fight power, outcomes).

To add a port, add it to `ports.json` with a `map` position and give it at least one route in `routes.json`. The chart and the destination list pick it up automatically.

| Route | Days |
|---|---|
| Madeira - Lisbon | 1 |
| Lisbon - London | 2 |
| London - Oslo | 2 |
| Madeira - London | 3 |
| Lisbon - Oslo | 3 |
| Madeira - Oslo | 3 |

Sugar sells for more the farther north you go: Lisbon 6, London 8, Oslo 12 (it costs 4 at Madeira).

## Economy

| Port | Sugar buy / sell | Cheese buy / sell | Specialty |
|---|---|---|---|
| Madeira | **4** / 3 | 14 / **11** | cheapest sugar, best cheese price; sells Cutter and Fluyt; many cooks |
| Lisbon | 7 / 6 | 11 / 8 | **crew**: signing fees halved, many navigators |
| London | 10 / 8 | 7 / 6 | **shipyard**: repair 1 (usually 4); sells Fluyt and Brig; many marksmen |
| Oslo | 14 / **12** | **3** / 2 | cheapest cheese, best sugar price; sells Cutter and Brig; many swordsmen |

Basic strategies:

- **The loop:** sugar Madeira → Oslo (+8 a unit), cheese Oslo → Madeira (+8 a unit). The best money, but 3 days each way, so it needs supplies and a bigger hold.
- **Starter hop:** sugar Madeira → Lisbon (+2 a unit, 1 day). Little supply weight, and crew sign on for half price there.
- **Middle route:** sugar Madeira → London (+4), cheese London → Madeira (+4). Repair cheaply while docked.

A port's `services` block in `ports.json` overrides `repair_cost`, `hire_mult` and `ship_mult` from `voyage.json`; its `tavern` weights which professions show up, and its `shipyard` lists the ships it sells. The Store, Tavern, and Shipyard hints say what the current port is best at, or which port does it cheaper. `tests/economy_check.gd` guards these rules: two different cheap sources, a round trip that pays both ways, a starter hop that pays, no port selling a good back for more than it charges, and separate crew and repair ports.

## Days at sea

Trip days = route days, then:

- **Light hold** (under half full): 1 day faster, never less than 1.
- **No navigator**: +1 day.
- **Running from the pirate**: +1 day and you drop 1 cargo.

About a third of voyages meet a pirate (`pirate_chance` in `voyage.json`, 0.34). On a clear trip you simply arrive. With a pirate you choose Run or Fight mid-voyage.

Departing plays the sea leg (`scripts/sea_view.gd`, built at runtime). The ship sails left to right over scrolling, bobbing water, with the route and a day counter on top. A pirate pulls alongside from behind, and the ship stops while you choose:
- **Run:** a crate goes overboard and the pirate falls behind.
- **Fight:** the status line shows the pirate's power against yours (cannons + muskets + boarding) first. Cannon fire hits the loser: a beaten pirate sinks; if you lose, you're plundered and sail on, and only a hull at 0 goes down.

The game rules resolve in `GameState` (on Depart for a clear trip, or on Run/Fight). The animation only shows the result, then returns to port or the end panel.

Each day at sea eats 1 food and 1 water for the captain, plus half of each per crew member (a cook cuts the food). Fractions carry over between trips. Run out before you arrive and the crew starves. Two food or two water fit in a hold slot (`supply_stack`).

## Ships

| Ship | Tier | Price | Hold | Bunks | Gun ports | Hull | Speed | Min crew | Sold in |
|---|---|---|---|---|---|---|---|---|---|
| Sloop | 1 | 40 | 10 | 2 | 1 | 3 | normal | 0 | (start) |
| Cutter | 2 | 60 | 10 | 4 | 2 | 3 | 1 day faster | 1 | Madeira, Lisbon, Oslo |
| Fluyt | 2 | 70 | 22 | 3 | 1 | 4 | 1 day slower | 2 | Madeira, Lisbon, London |
| Brig | 3 | 300 | 18 | 6 | 4 | 5 | normal | 3 | London, Oslo — **wins** |

Buying a ship trades yours in for half its price, refills the hull, and sells cannons the new ship has no ports for. The yard refuses while your crew, cargo or weapons don't fit. You can't depart with less than the ship's minimum crew.

## Crew

Each port's tavern offers 3–4 named sailors, re-rolled every 4 days (`roster_refresh_days`). Signing on costs 3 days' wages (half in Lisbon). Wages are paid on arrival for each day at sea; if you can't pay, the best-paid crew desert first.

| Profession | Wage/day | Does |
|---|---|---|
| Deckhand | 1 | counts toward minimum crew; fists (1) in a fight |
| Navigator | 2 | removes the +1 day for sailing without one |
| Cook | 2 | food per day ×0.75 |
| Marksman | 2 | fights at 2 with a musket and ammo, else 1 |
| Swordsman | 2 | fights at 2 with a sword, else 1 |

`crew.json` already holds level 2–3 wages and perks; rosters only roll level 1 for now (`level_weights`).

## Armory and pirates

About a third of voyages meet a pirate (`pirate_chance`, 0.34): a skiff (power 3, loot 8) on any route, or a corsair sloop (power 6, loot 15) on routes of 2+ days. Fight power is added in order while powder and shot last: each cannon 2 (1 powder + 1 shot), each armed marksman 2 (1 powder + 1 shot), then boarding (armed swordsmen 2, everyone else's fists). Cannons are bought in the Shipyard (one per gun port); muskets, swords, powder and shot in the Armory. Five powder or five shot fit in a hold slot; muskets and swords take no space but are capped at one per bunk.

- **Win** (power > pirate): take the loot; −1 hull unless you had 1.5× its power.
- **Loss**: hull −half the difference (at least 1), and the pirates take a quarter of your gold and half your goods. You sail on; only a hull at 0 sinks you.
- **Run**: −1 cargo, +1 day, no ammo used.

## Port screen

- **Voyage column** (left, always visible): a header line with the port, gold, and day, then labelled sections:
  - **Voyage:** destination and days at sea (fight-run).
  - **Provisions:** food and water. Each shows what the trip needs and turns red with "need N more" while you're short.
  - **Cargo:** hold slots used and free, and the goods aboard.
  - **Crew:** aboard / bunks and their jobs.
  - **Crew:** aboard / bunks, wages a day, and the professions aboard.
  - **Ship:** name and tier, hull, and arms (fight power, cannons, powder/shot).
  - **Chart course** and **Depart**, side by side.
- **Store** tab, in two sections:
  - **Cargo:** sugar and cheese, with buy and sell prices, how many are aboard, and Buy/Sell on each row.
  - **Provisions:** food and water, how many are aboard and what the trip needs (red when short), with Load/Unload on each row. Supplies cost `supply_price` and unloading refunds `supply_refund` (both 1 gold, in `voyage.json`). Unloading frees a hold slot, e.g. to make room for sugar.
- **Tavern** tab: today's roster with Hire buttons (hover a row for what the profession does), and your crew with Dismiss. The **i** badge lists every profession.

Rows stay short (`have N`; every Buy/Sell/Load/Unload/Hire/Repair button shows its price, e.g. `Buy (7)`; `g` = gold); the rules behind them (supply prices and stacking, ammo use, fight power) are on the **i** badges.
- **Shipyard** tab: your ship, hull and Repair, cannons, and the ships for sale here with their price after trade-in. The **i** badge explains your ship.
- **Armory** tab: muskets, swords, powder and shot, with your current fight power on top. The Weapons **i** badge explains fights; the Ammunition one explains powder and shot.

**Chart course** opens the map (`scripts/map_view.gd`). It shows:

- every port and your ship;
- the routes from where you are, each labelled with its fight-run days;
- a list of destinations, nearest first.

Hover a port (on the chart or in the list) to see its details in the side panel: blurb, supplies the trip needs, a Buy / Sell / Profit table for sugar and cheese, and crew and shipyard prices. Profit is that port's sell price minus the buy price where you are, per unit, green when it pays. Hovering your own port shows its prices with no profit column. The chart lights that port's routes in yellow and labels each with its length in days. The route from where you are is labelled with your trip estimate (fight-run days, with your hold and crew); the others show plain route days. The chosen course stays red and labelled. Move the mouse away and the panel and routes go back to the chosen course. Click a port or a list entry to set course. **Set sail** departs, and **Back to port** returns to the port screen. Until you pick one, the course is the nearest port.

The port layout is generated by `tools/build_port_hud.gd`. Edit that file, then rebuild it in the editor with the port scene open:

```gdscript
var s: GDScript = load("res://tools/build_port_hud.gd")
s.source_code = FileAccess.get_file_as_string(s.resource_path); s.reload(true)
s.new().build(EditorInterface.get_edited_scene_root()); EditorInterface.save_scene()
```

`scripts/port_screen.gd` finds rows and buttons by node name. Keep the names when you change the layout. The map is built at runtime from the data, so it has no layout in the scene.

## Playthrough

1. At Madeira: Load food and water for the trip, buy sugar, Chart course → Oslo → Set sail. If a pirate shows up, Run.
2. At Oslo: sell sugar, buy cheese, sail home and sell it.
3. With ~90 gold at Madeira, hire two cheap sailors and trade the Sloop for a Fluyt (22 hold).
4. Run Madeira ⇄ Oslo with full holds; buy powder, shot and cannons once pirates start to cost you.
5. With ~265 gold in Oslo or London, buy the Brig.

## Checks

```
G=/home/sam23d/Desktop/Godot_v4.5.1-stable_linux.x86_64
P=/home/sam23d/Documents/coding/uncharted-lap
$G --headless --path "$P" --quit
for s in $(ls "$P"/tests/*_check.gd | xargs -n1 basename | sed 's/.gd$//'); do
  $G --headless --path "$P" --script "res://tests/$s.gd"
done
```
