#!/usr/bin/env python3
"""Trade data for Uncharted Lap: the single source of truth for goods, prices, routes and charts.

  python3 tools/trade_data.py            check the balance rules (see below)
  python3 tools/trade_data.py --write    check, then write data/goods.json, data/charts.json,
                                          data/routes.json and the goods/pays/map/chart fields of
                                          data/ports.json (other port fields are kept)
  add --known to write only the four starting ports (Milestone T1)

Balance model for the trade expansion (cartographers + 12 goods).

Prints the price table and checks the balance rules from
uncharted-lap-cartographers-trade.md:
  - no same-port arbitrage (sell < buy where a good is produced);
  - every good has a source and a better market somewhere;
  - best margin per unit per day, by tier, rises tier by tier and stays in its band;
  - every port has a profitable export and import.
Spec: ~/Documents/hermes_artifacts/uncharted-lap-cartographers-trade.md
"""
import heapq, itertools, json, os, sys

TIER = {"madeira": 0, "lisbon": 0, "london": 0, "oslo": 0,
        "genoa": 1, "alexandria": 1, "hamburg": 1, "danzig": 1,
        "arguin": 2, "elmina": 2, "capetown": 3, "calicut": 3}
# Upper limit on the best margin/unit/day for routes whose farthest port is tier N.
BAND = {0: 3.0, 1: 3.5, 2: 5.0, 3: 6.5}

ROUTES = [  # existing six, then the new charts
    ("madeira", "lisbon", 1), ("lisbon", "london", 2), ("london", "oslo", 2),
    ("madeira", "london", 3), ("lisbon", "oslo", 3), ("madeira", "oslo", 3),
    # Mediterranean chart
    ("lisbon", "genoa", 3), ("genoa", "alexandria", 3), ("lisbon", "alexandria", 5), ("madeira", "genoa", 4),
    # Baltic chart
    ("london", "hamburg", 2), ("oslo", "hamburg", 2), ("hamburg", "danzig", 2), ("oslo", "danzig", 3),
    # Guinea chart
    ("madeira", "arguin", 2), ("lisbon", "arguin", 3), ("arguin", "elmina", 3), ("madeira", "elmina", 4),
    # Cape chart (ocean legs)
    ("elmina", "capetown", 4), ("lisbon", "capetown", 7), ("capetown", "calicut", 5),
]

CATEGORY = {"sugar": "Food", "cheese": "Food", "olive_oil": "Food", "rock_salt": "Food", "grain": "Food",
            "pepper": "Spices", "cinnamon": "Spices", "clove": "Spices",
            "wool": "Textiles", "cotton_cloth": "Textiles", "silk_cloth": "Textiles",
            "iron_ore": "Metals", "copper_ore": "Metals", "gold": "Metals"}
PORTS = list(TIER)
P = ["madeira", "lisbon", "london", "oslo", "genoa", "alexandria", "hamburg", "danzig", "arguin", "elmina", "capetown", "calicut"]
# SELL[good] = what each port pays, in the order of P. BUY[good] = {port: price} where produced.
SELL = {
    "sugar":        [3, 6, 8, 12, 11, 9, 13, 14, 8, 9, 10, 12],
    "cheese":       [11, 8, 6, 2, 10, 13, 6, 8, 12, 14, 12, 10],
    "olive_oil":    [8, 5, 11, 12, 3, 7, 12, 13, 11, 14, 9, 9],
    "rock_salt":    [6, 4, 8, 9, 7, 6, 9, 11, 1, 9, 6, 6],
    "grain":        [9, 8, 7, 6, 8, 2, 7, 1, 9, 10, 3, 7],
    "pepper":       [28, 30, 34, 32, 32, 18, 34, 34, 22, 11, 16, 3],
    "cinnamon":     [36, 38, 42, 40, 38, 25, 44, 44, 26, 28, 22, 5],
    "clove":        [62, 66, 72, 70, 66, 48, 72, 72, 36, 38, 30, 6],
    "wool":         [12, 11, 6, 9, 13, 14, 5, 13, 12, 13, 11, 12],
    "cotton_cloth": [12, 13, 12, 13, 12, 7, 13, 13, 16, 18, 14, 3],
    "silk_cloth":   [30, 32, 36, 34, 18, 31, 36, 36, 30, 34, 30, 22],
    "iron_ore":     [10, 11, 12, 6, 12, 13, 10, 11, 14, 15, 12, 13],
    "copper_ore":   [13, 14, 15, 15, 16, 17, 9, 14, 20, 22, 18, 20],
    "gold":         [60, 66, 64, 60, 66, 68, 64, 62, 46, 36, 56, 96],
}
BUY = {
    "sugar": {"madeira": 4, "lisbon": 7, "london": 10, "oslo": 14},
    "cheese": {"madeira": 14, "lisbon": 11, "london": 7, "oslo": 3},
    "olive_oil": {"lisbon": 6, "genoa": 4},
    "rock_salt": {"lisbon": 5, "arguin": 2},
    "grain": {"alexandria": 3, "danzig": 2, "capetown": 4},
    "pepper": {"alexandria": 22, "elmina": 14, "calicut": 4},
    "cinnamon": {"alexandria": 31, "calicut": 6},
    "clove": {"calicut": 8},
    "wool": {"london": 8, "hamburg": 7},
    "cotton_cloth": {"alexandria": 9, "calicut": 4},
    "silk_cloth": {"genoa": 22},
    "iron_ore": {"oslo": 8, "hamburg": 12},
    "copper_ore": {"hamburg": 11},
    "gold": {"elmina": 42, "arguin": 52},
}

def days_between():
    graph = {p: [] for p in PORTS}
    for a, b, d in ROUTES:
        graph[a].append((b, d)); graph[b].append((a, d))
    dist = {}
    for src in PORTS:
        best = {src: 0}; q = [(0, src)]
        while q:
            d, p = heapq.heappop(q)
            if d > best[p]: continue
            for n, w in graph[p]:
                if d + w < best.get(n, 1e9):
                    best[n] = d + w; heapq.heappush(q, (d + w, n))
        for dst, d in best.items():
            dist[(src, dst)] = d
    return dist

def sell(good, port):
    return SELL[good][P.index(port)]

def main():
    dist = days_between()
    errors = []
    # Same-port arbitrage, sources and sinks.
    for good, sources in BUY.items():
        for port, price in sources.items():
            if sell(good, port) >= price:
                errors.append(f"{good}: {port} sells at {sell(good, port)} >= buy {price}")
        best_sink = max(SELL[good])
        if best_sink <= min(sources.values()):
            errors.append(f"{good}: no profitable market")
    # Best margin/day per port pair (direct or multi-hop, by shortest days).
    best_by_tier = {t: (0, "") for t in BAND}
    exports = {p: 0 for p in PORTS}; imports = {p: 0 for p in PORTS}
    for a, b in itertools.permutations(PORTS, 2):
        d = dist[(a, b)]
        tier = max(TIER[a], TIER[b])
        for good, sources in BUY.items():
            if a not in sources: continue
            m = sell(good, b) - sources[a]
            if m <= 0: continue
            exports[a] += 1; imports[b] += 1
            rate = m / d
            if rate > best_by_tier[tier][0]:
                best_by_tier[tier] = (rate, f"{good} {a}->{b} +{m} in {d}d")
    for t, (rate, what) in best_by_tier.items():
        flag = "" if rate <= BAND[t] else "  << over band"
        print(f"tier {t}: best {rate:.2f}/unit/day ({what}), band <= {BAND[t]}{flag}")
        if rate > BAND[t]: errors.append(f"tier {t} over band: {what}")
    rates = [best_by_tier[t][0] for t in sorted(BAND)]
    if rates != sorted(rates): errors.append("tiers should pay more the farther you go")
    for p in PORTS:
        if exports[p] == 0 and p != "capetown": errors.append(f"{p}: nothing worth exporting")
        if imports[p] == 0: errors.append(f"{p}: nothing worth importing")
    # Round trips that matter for the plan.
    loops = [("madeira", "oslo"), ("lisbon", "london"), ("genoa", "alexandria"), ("hamburg", "danzig"),
             ("lisbon", "elmina"), ("elmina", "calicut"), ("lisbon", "calicut")]
    print("\nround trips (best good each way, per unit):")
    for a, b in loops:
        out = max(((sell(g, b) - s[a], g) for g, s in BUY.items() if a in s), default=(0, "-"))
        back = max(((sell(g, a) - s[b], g) for g, s in BUY.items() if b in s), default=(0, "-"))
        d = 2 * dist[(a, b)]
        print(f"  {a}<->{b}: {d}d, out {out[1]} +{out[0]}, back {back[1]} +{back[0]}  = {(out[0] + back[0]) / d:.2f}/unit/day")
    tri = [("lisbon", "elmina"), ("elmina", "calicut"), ("calicut", "lisbon")]
    total, days = 0, 0
    print("\nendgame triangle Lisbon -> Elmina -> Calicut -> Lisbon:")
    for a, b in tri:
        m, g = max(((sell(g, b) - s[a], g) for g, s in BUY.items() if a in s), default=(0, "-"))
        total += m; days += dist[(a, b)]
        print(f"  {a}->{b}: {dist[(a, b)]}d, {g} +{m}")
    print(f"  = +{total} per unit in {days}d = {total / days:.2f}/unit/day")
    print("\nerrors:" if errors else "\nall balance rules pass")
    for e in errors: print("  " + e)
    return 1 if errors else 0

# --- Data writer ----------------------------------------------------------------

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "data")
ITEMS = "res://assets/vendor/kenney-generic-items/PNG/Colored/genericItem_color_%03d.png"
FLAG = "res://assets/vendor/kenney-pirate-pack/PNG/Default size/Ship parts/sailLarge (%d).png"
# Port emblems: a sail with a crest (3/9/21 red cross, 4/10/22 green swords, 5/11/23 blue horse,
# 6/12/24 yellow X, 1/7/19 plain; 2/8/20 are pirate skulls). Neighbours get different crests.
FLAGS = {"madeira": 3, "lisbon": 6, "london": 5, "oslo": 4, "genoa": 11, "alexandria": 7,
         "hamburg": 12, "danzig": 23, "arguin": 19, "elmina": 21, "capetown": 22, "calicut": 24}
CATEGORIES = {"food": ("Food", 114), "spices": ("Spices", 112), "textiles": ("Textiles", 133), "metals": ("Metals", 21)}
GOOD_ICONS = {"sugar": 143, "cheese": 141, "olive_oil": 127, "rock_salt": 122, "grain": 155,
              "pepper": 123, "cinnamon": 140, "clove": 154, "wool": 156, "cotton_cloth": 133,
              "silk_cloth": 117, "iron_ore": 58, "copper_ore": 59, "gold": 160}
CHARTS = {
    "known": {"name": "Home waters", "tier": 0, "landfall": "", "ports": ["madeira", "lisbon", "london", "oslo"]},
    "mediterranean": {"name": "the Mediterranean", "tier": 1, "landfall": "genoa", "ports": ["genoa", "alexandria"]},
    "baltic": {"name": "the Baltic", "tier": 1, "landfall": "hamburg", "ports": ["hamburg", "danzig"]},
    "guinea": {"name": "the Guinea coast", "tier": 2, "landfall": "arguin", "ports": ["arguin", "elmina"]},
    "cape": {"name": "the Cape route", "tier": 3, "landfall": "capetown", "ports": ["capetown", "calicut"]},
}
MAP = {"madeira": [0.07, 0.6], "lisbon": [0.2, 0.48], "london": [0.34, 0.27], "oslo": [0.46, 0.14],
       "genoa": [0.55, 0.47], "alexandria": [0.86, 0.56], "hamburg": [0.56, 0.27], "danzig": [0.74, 0.14],
       "arguin": [0.12, 0.76], "elmina": [0.38, 0.84], "capetown": [0.64, 0.88], "calicut": [0.93, 0.78]}
NEW_PORTS = {
    "genoa": {"name": "Genoa", "flag": FLAG % FLAGS["genoa"], "blurb": "Silk capital. Cheapest olive oil.",
              "tavern": {"deckhand": 2, "navigator": 2, "cook": 1, "marksman": 2, "swordsman": 2}, "shipyard": ["cutter", "brig", "galleon"]},
    "alexandria": {"name": "Alexandria", "flag": FLAG % FLAGS["alexandria"], "blurb": "Eastern spices at a markup; pays well for silk.",
                   "tavern": {"deckhand": 3, "navigator": 1, "cook": 2, "marksman": 1, "swordsman": 2}, "shipyard": ["fluyt"]},
    "hamburg": {"name": "Hamburg", "flag": FLAG % FLAGS["hamburg"], "blurb": "Baltic workshop: copper, iron, wool.",
                "tavern": {"deckhand": 2, "navigator": 1, "cook": 1, "marksman": 3, "swordsman": 1}, "shipyard": ["fluyt", "brig", "carrack"],
                "services": {"repair_cost": 2}},
    "danzig": {"name": "Danzig", "flag": FLAG % FLAGS["danzig"], "blurb": "Breadbasket. Pays the most for salt and sugar.",
               "tavern": {"deckhand": 4, "navigator": 1, "cook": 2, "marksman": 1, "swordsman": 1}, "shipyard": ["fluyt"]},
    "arguin": {"name": "Arguin", "flag": FLAG % FLAGS["arguin"], "blurb": "Desert salt and gold. Navigators' haunt.",
               "tavern": {"deckhand": 2, "navigator": 4, "cook": 1, "marksman": 1, "swordsman": 1}, "shipyard": []},
    "elmina": {"name": "Elmina", "flag": FLAG % FLAGS["elmina"], "blurb": "The Gold Coast. Pays the most for cloth and oil.",
               "tavern": {"deckhand": 2, "navigator": 1, "cook": 1, "marksman": 2, "swordsman": 3}, "shipyard": ["cutter"]},
    "capetown": {"name": "Cape Town", "flag": FLAG % FLAGS["capetown"], "blurb": "Waystation: cheap repairs, half-price crew.",
                 "tavern": {"deckhand": 2, "navigator": 2, "cook": 3, "marksman": 1, "swordsman": 1}, "shipyard": [],
                 "services": {"repair_cost": 1, "hire_mult": 0.5}},
    "calicut": {"name": "Calicut", "flag": FLAG % FLAGS["calicut"], "blurb": "Spice coast: pepper, cinnamon, clove. Pays 96 for gold.",
                "tavern": {"deckhand": 2, "navigator": 2, "cook": 2, "marksman": 2, "swordsman": 1}, "shipyard": ["carrack", "galleon"]},
}
KNOWN_YARDS = {"lisbon": ["cutter", "fluyt", "carrack"]}
KNOWN_BLURBS = {
    "madeira": "Home. Cheapest sugar, best cheese price.",
    "lisbon": "Sailors' town. Olive oil and rock salt.",
    "london": "Busy docks: cheap repairs, wool.",
    "oslo": "Far north. Cheapest cheese and iron, best sugar price.",
}
CARTOGRAPHERS = {
    "lisbon": {"chart": "mediterranean", "name": "Duarte", "fee": 40, "wage": 2, "requires": {}},
    "london": {"chart": "baltic", "name": "Mercator", "fee": 30, "wage": 2, "requires": {}},
    "madeira": {"chart": "guinea", "name": "Cadamosto", "fee": 60, "wage": 2, "requires": {"ship_tier": 2}},
    "elmina": {"chart": "cape", "name": "Dias", "fee": 150, "wage": 3, "requires": {"hold": 18, "charts": ["guinea"]}},
}

def chart_of(port):
    return next(c for c, spec in CHARTS.items() if port in spec["ports"])

def write(known_only):
    keep = [p for p in P if not known_only or chart_of(p) == "known"]
    goods = {"categories": {k: {"name": v[0], "icon": ITEMS % v[1]} for k, v in CATEGORIES.items()},
             "goods": {g: {"name": g.replace("_", " ").capitalize(), "category": CATEGORY[g].lower(), "icon": ITEMS % GOOD_ICONS[g]} for g in SELL}}
    path = os.path.join(ROOT, "ports.json")
    ports = json.load(open(path))
    out = {}
    for p in keep:
        base = ports.get(p)
        if p in NEW_PORTS:  # new ports are fully defined here; regenerate them every time
            n = NEW_PORTS[p]
            base = {"name": n["name"], "flag": n["flag"], "blurb": n["blurb"],
                    "tavern": {"weights": n["tavern"], "level_weights": [1]}, "shipyard": n["shipyard"]}
            if "services" in n:
                base["services"] = n["services"]
        base["flag"] = FLAG % FLAGS[p]
        base["map"] = MAP[p]
        base["chart"] = chart_of(p)
        base["goods"] = {g: {"buy": BUY[g][p], "sell": sell(g, p)} for g in SELL if p in BUY[g]}
        base["pays"] = {g: sell(g, p) for g in SELL if p not in BUY[g]}
        if p in CARTOGRAPHERS and not known_only:
            base["cartographer"] = CARTOGRAPHERS[p]
        else:
            base.pop("cartographer", None)
        if p in KNOWN_YARDS and not known_only:
            base["shipyard"] = KNOWN_YARDS[p]
        if chart_of(p) == "known" and p in KNOWN_BLURBS:
            base["blurb"] = KNOWN_BLURBS[p]
        out[p] = base
    routes = [{"from": a, "to": b, "days": d, "chart": "known" if chart_of(a) == chart_of(b) == "known" else max(chart_of(a), chart_of(b), key=lambda c: (CHARTS[c]["tier"], c != "known"))}
              for a, b, d in ROUTES if a in keep and b in keep]
    # Lisbon-Cape belongs to the Cape chart (both non-known: take the higher tier).
    charts = {c: v for c, v in CHARTS.items() if not known_only or c == "known"}
    for name, data in [("goods.json", goods), ("ports.json", out), ("routes.json", routes), ("charts.json", charts)]:
        with open(os.path.join(ROOT, name), "w") as f:
            json.dump(data, f, indent=2, ensure_ascii=False)
            f.write("\n")
    print(f"wrote {len(out)} ports, {len(routes)} routes, {len(goods['goods'])} goods")

if __name__ == "__main__":
    code = main()
    if code == 0 and "--write" in sys.argv:
        write("--known" in sys.argv)
    raise SystemExit(code)
