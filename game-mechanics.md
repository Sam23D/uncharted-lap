# Uncharted Lap: game mechanics

The full rules of the game. For setup, running and building, see [README.md](README.md).

Contents: [Trade](#trade) · [Charts and cartographers](#charts-and-cartographers) · [Days at sea](#days-at-sea) · [Ships](#ships) · [Crew](#crew) · [Armory and pirates](#armory-and-pirates) · [Title screen](#title-screen) · [Ship's log](#ships-log) · [Port screen](#port-screen) · [Playthrough](#playthrough) · [Data files](#data-files)

## Goal

Start in Madeira with a Sloop. Trade your way up the fleet and buy a **Galleon** (tier 4, 1200 gold, sold in Genoa and Calicut) to win. There is no day limit. A run ends early if the crew starves or the ship sinks. A scripted greedy captain wins around day 112 (`tests/full_run_check.gd`).

## Trade

| Category | Goods |
|---|---|
| Food | sugar, cheese, olive oil, rock salt, grain |
| Spices | pepper, cinnamon, clove |
| Textiles | wool, cotton cloth, silk cloth |
| Metals | iron ore, copper ore, gold |

Each port **makes** a few goods: you can buy them there, cheap. **Every port buys every good**, so you can sell anything anywhere. Every unit takes one hold slot.

| Port | Chart | Makes (buy price) | Known for |
|---|---|---|---|
| Madeira | home | sugar 4, cheese 14 | cheapest sugar, best cheese price; many cooks |
| Lisbon | home | sugar 7, cheese 11, olive oil 6, rock salt 5 | half-price crew; sells the Carrack |
| London | home | sugar 10, cheese 7, wool 8 | repairs for 1 |
| Oslo | home | sugar 14, cheese 3, iron ore 8 | cheapest cheese, best sugar price |
| Genoa | Mediterranean | olive oil 4, silk cloth 22 | sells the Galleon |
| Alexandria | Mediterranean | pepper 22, cinnamon 31, cotton cloth 9, grain 3 | pays well for silk and cheese |
| Hamburg | Baltic | wool 7, iron ore 12, copper ore 11 | best northern spice prices; sells the Carrack |
| Danzig | Baltic | grain 2 | pays the most for salt and sugar |
| Arguin | Guinea | rock salt 2, gold 52 | navigators |
| Elmina | Guinea | gold 42, pepper 14 | pays the most for cloth, oil and copper |
| Cape Town | Cape route | grain 4 | repairs for 1, half-price crew |
| Calicut | Cape route | pepper 4, cinnamon 6, clove 8, cotton cloth 4 | pays 96 for gold; sells the Galleon |

Measured as profit per unit per day of sailing, the best trade grows with distance: home 2.67 (sugar Madeira → Oslo), Mediterranean/Baltic 3.33 (silk Genoa → Lisbon), Guinea 4.8 (gold Elmina → Lisbon), Cape 6.0 (gold Elmina → Calicut). The home loop (sugar Madeira → Oslo +8, cheese back +8) still works all game.

A port's `services` block in `ports.json` overrides `repair_cost`, `hire_mult` and `ship_mult` from `voyage.json`; its `tavern` weights which professions show up, and its `shipyard` lists the ships it sells. The Store, Tavern, and Shipyard hints say what the current port is best at, or which port does it cheaper. `tests/economy_check.gd` (a GDScript port of the balance script) guards: no port selling a good back for more than it charges, every port pricing every good, every good paying somewhere, every port worth sailing to and from, the per-tier bands rising with distance, the home loop and starter hop, and separate crew and repair ports.

## Charts and cartographers

You start with the four home ports. The rest of the chart is fog ("Terra incognita") until a **cartographer** charts it:

| Chart | Cartographer in | Fee | Needs | Ports (landfall first) |
|---|---|---|---|---|
| Mediterranean | Lisbon | 40 | - | Genoa, Alexandria |
| Baltic | London | 30 | - | Hamburg, Danzig |
| Guinea coast | Madeira | 60 | a tier-2 ship | Arguin, Elmina |
| Cape route | Elmina | 150 | the Guinea chart and a hold of 18+ | Cape Town, Calicut |

Hire one in the tavern's **Cartographer** section. They take a bunk and a daily wage, and the chart shows their landfall as a **?** you can sail to. Arriving there charts the whole region (its ports and routes), writes it in the ship's log, and the cartographer goes ashore. Dismiss them, or let them desert unpaid, and the fee is lost; they return to their tavern after 4 days (`carto_return_days`). `tests/chart_check.gd` covers it.

Farther seas have their own pirates (`regions` in `pirates.json`): a Barbary galley (power 9) in the Mediterranean, a coast raider (8) on the Guinea coast, an Indies brig (12) on the Cape route. The chart lists who sails each route.

## Days at sea

Trip days = route days, then:

- **Light hold** (under half full): 1 day faster, never less than 1.
- **No navigator**: +1 day.
- **Running from the pirate**: +1 day and you drop 1 cargo.

About 1 in 5 voyages meets a pirate (`pirate_chance` in `voyage.json`, 0.2). On a clear trip you simply arrive. With a pirate you choose Run or Fight mid-voyage.

Departing plays the sea leg (`scripts/sea_view.gd`, built at runtime). The ship sails left to right over scrolling, bobbing water, with the route and a day counter on top. Each day at sea is one sun cycle: the sun crosses the sky, dusk turns the sea orange, night darkens it under a moon, and the counter ticks at sunrise. A pirate pulls alongside from behind, and the ship stops while you choose:
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
| Brig | 3 | 300 | 18 | 6 | 4 | 5 | normal | 3 | London, Oslo, Genoa, Hamburg |
| Carrack | 3 | 220 | 34 | 5 | 2 | 5 | 1 day slower | 3 | Lisbon, Hamburg, Calicut |
| Galleon | 4 | 1200 | 40 | 10 | 6 | 7 | 1 day slower | 5 | Genoa, Calicut — **wins** |

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

About 1 in 5 voyages meets a pirate (`pirate_chance`, 0.2): a skiff (power 3, loot 8) on any route, a corsair sloop (power 6, loot 15) on routes of 2+ days, and the regional pirates above. Fight power is added in order while powder and shot last: each cannon 2 (1 powder + 1 shot), each armed marksman 2 (1 powder + 1 shot), then boarding (armed swordsmen 2, everyone else's fists). Cannons are bought in the Shipyard (one per gun port); muskets, swords, powder and shot in the Armory. Five powder or five shot fit in a hold slot; muskets and swords take no space but are capped at one per bunk.

- **Win** (power > pirate): take the loot; −1 hull unless you had 1.5× its power.
- **Loss**: hull −half the difference (at least 1), and the pirates take a quarter of your gold and half your goods. You sail on; only a hull at 0 sinks you.
- **Run**: −1 cargo, +1 day, no ammo used.

## Title screen

The game opens on `scenes/title.tscn` (`scripts/title_screen.gd`, the main scene): a scrolling sea with five ships sailing both ways (smaller and slower further up, for depth), the game's name, **New voyage** (or Enter) which resets `GameState` and loads the port, and the credit "Created by s.blanc".

## Ship's log

**Log** (next to Chart and Depart, and on the end panel) opens the ship's log (`scripts/log_view.gd`), newest first, split by a gray dotted **Day N** line whenever the day changes (a trip sits under the day it left port):

- **Trip line:** route, days at sea, and the trip's net result: sale margins at the destination, plus loot or minus plunder and lost cargo, minus wages.
- **Provisions line:** food and water eaten, wages paid, deserters.
- **Encounter line:** "Clear seas", or the pirate's power against yours and what it cost:
  - **ran:** the cargo dropped and what it had cost you;
  - **won:** loot, hull damage, ammo used;
  - **lost:** gold and goods plundered, hull damage;
  - **sunk.**
- **Trade lines:** "Bought 4 sugar @ 4 = −16g". Repeated clicks at the same price in one port stay merge into one line. Sales show the margin over the average price you paid ("+8 each").

The header shows gold at the start and now, and the trip count. A trip that ends the game is marked "Starved" or "Sunk".

The data lives in `scripts/ship_log.gd` (`GameState.ship_log`). `GameState` writes to it on buy, sell, depart, run, fight and arrival. The log keeps the last `log_max_entries` (200) and is cleared on New voyage. `tests/log_check.gd` covers merging, margins, run and fight costs, starvation, sinking and the cap.

## Port screen

- **Voyage column** (left, always visible): a header line with the port, gold, and day, then labelled sections:
  - **Voyage:** destination and days at sea (fight-run).
  - **Provisions:** food and water. Each shows what the trip needs and turns red with "need N more" while you're short.
  - **Cargo:** hold slots used and free, and the goods aboard.
  - **Crew:** aboard / bunks, wages a day, and the professions aboard.
  - **Ship:** name and tier, hull, and arms (fight power, cannons, powder/shot).
  - **Log**, **Chart** (course) and **Depart**, side by side.
- **Store** tab, in two sections:
  - **Provisions:** food and water, how many are aboard and what the trip needs (red when short), with Load/Unload on each row. Supplies cost `supply_price` and unloading refunds `supply_refund` (both 1 gold, in `voyage.json`). Unloading frees a hold slot, e.g. to make room for sugar.
  - **Cargo:** a scrolling list under category headers: the goods this port makes (Buy and Sell) and the goods in your hold (Sell only), each with how many you have and the charted port that pays the most ("best: London 34").
- **Tavern** tab: the cartographer offering a chart here (if any), today's roster with Hire buttons (hover a row for what the profession does), and your crew with Dismiss. The **i** badge lists every profession.

Rows stay short (`have N`; every Buy/Sell/Load/Unload/Hire/Repair button shows its price, e.g. `Buy (7)`; `g` = gold); the rules behind them (supply prices and stacking, ammo use, fight power) are on the **i** badges.
- **Shipyard** tab: your ship, hull and Repair, cannons, and the ships for sale here with their price after trade-in. The **i** badge explains your ship.
- **Armory** tab: muskets, swords, powder and shot, with your current fight power on top. The Weapons **i** badge explains fights; the Ammunition one explains powder and shot.

**Chart course** opens the map (`scripts/map_view.gd`). It shows:

- every charted port and your ship, with fog over uncharted regions and a **?** for a cartographer's landfall;
- the routes from where you are, each labelled with its fight-run days;
- a list of destinations, nearest first.

Hover a port (on the chart or in the list) to see its details in the side panel: blurb, supplies the trip needs, the pirates on that route, the three best goods to carry there from here (buy here, sell there, profit per unit, green when it pays), what that port makes, and its tavern and shipyard. Hovering your own port lists what it makes. The chart lights that port's routes in yellow and labels each with its length in days. The route from where you are is labelled with your trip estimate (fight-run days, with your hold and crew); the others show plain route days. The chosen course stays red and labelled. Move the mouse away and the panel and routes go back to the chosen course. Click a port or a list entry to set course. **Set sail** departs, and **Back to port** returns to the port screen. Until you pick one, the course is the nearest port.

## Playthrough

1. At Madeira: Load food and water for the trip, buy sugar, Chart course → Oslo → Set sail. If a pirate shows up, Run.
2. At Oslo: sell sugar, buy cheese, sail home and sell it.
3. With ~90 gold at Madeira, hire two cheap sailors and trade the Sloop for a Fluyt (22 hold).
4. Hire the Madeira cartographer (60) and chart the Guinea coast: olive oil and rock salt south, gold and pepper back north.
5. Chart the Mediterranean from Lisbon (40) and buy a Carrack (34 hold) there.
6. From Elmina, chart the Cape route (150): carry gold to Calicut (96), bring clove home (up to 72).
7. With ~1200 gold, buy the Galleon in Genoa or Calicut.

## Data files

- Goods and their categories (name, icon): `data/goods.json`
- Charts (home waters, Mediterranean, Baltic, Guinea coast, Cape route), each with a tier, a landfall port and its ports: `data/charts.json`
- Ports: what each makes (`goods`: buy/sell), what it pays for everything else (`pays`), chart, flag, chart position (`map`, 0-1 across the chart), tavern, shipyard, services, cartographer: `data/ports.json`
- Sailing days between ports, and the chart each route belongs to: `data/routes.json` (one entry per pair, both directions)
- Supplies, pirate odds, fight and wage rules, armory prices, day modifiers: `data/voyage.json`
- Ships for sale (price, tier, hold, bunks, gun ports, hull, speed, minimum crew, sprite): `data/ships.json`
- Crew professions, wages and perks, sailor names: `data/crew.json`
- Pirate types (power, loot, shortest route they appear on): `data/pirates.json`

Rules beyond the market live in `scripts/rules/` as pure functions over `GameState`: `ship_rules.gd` (prices, trade-in, refusals), `crew_rules.gd` (rosters, wages, rations) and `combat_rules.gd` (pirate pick, fight power, outcomes).

**Prices, routes and charts are generated.** `tools/trade_data.py` holds the price table, routes, charts, the new ports and the cartographers. `python3 tools/trade_data.py` checks the balance rules; `--write` rewrites `goods.json`, `charts.json`, `routes.json` and the generated fields of `ports.json` (other fields of the four home ports are kept). Change prices there, not in the JSON.

### Port screen layout

The port layout is generated by `tools/build_port_hud.gd`. Edit that file, then rebuild it in the editor with the port scene open:

```gdscript
var s: GDScript = load("res://tools/build_port_hud.gd")
s.source_code = FileAccess.get_file_as_string(s.resource_path); s.reload(true)
s.new().build(EditorInterface.get_edited_scene_root()); EditorInterface.save_scene()
```

`scripts/port_screen.gd` finds rows and buttons by node name. Keep the names when you change the layout. The map is built at runtime from the data, so it has no layout in the scene.
