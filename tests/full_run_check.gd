extends SceneTree
## A greedy captain plays from a fresh start (seed 7, real pirate odds) and must buy the
## winning ship (the Galleon) within MAX_DAYS. Guards the whole economy: prices, charts and
## cartographers, ships, crew, food, regional pirates.
##
## Each stop: sell everything, repair, maybe buy a bigger ship, maybe hire a cartographer
## (sailing straight to their "?"), then carry the good with the best gold-per-day to a
## reachable port. Once it can afford a Galleon, it sails toward the nearest Galleon yard.
const MAX_DAYS := 140
const MIN_DAYS := 80
var log_lines: Array[String] = []

func _fail(text: String) -> void:
	for l in log_lines:
		print(l)
	push_error(text)
	quit(1)

## Days on this ship with a full hold, running from a pirate (the plan's worst case).
func _days(state: Node, dest: String) -> int:
	return state.ShipRules.days(state.route_days(dest), int(state.ship()["speed"])) + (0 if state.count("navigator") > 0 else int(state.voyage["nav_penalty_days"])) + int(state.voyage["run_extra_days"])

## Best cargo for one leg from `from` to `dest` with `gold` to spend: {good, units, profit, days, food, water}.
func _leg(state: Node, from: String, dest: String, gold: int) -> Dictionary:
	var days: int = state.ShipRules.days(int(state.all_days(from, dest)), int(state.ship()["speed"])) + (0 if state.count("navigator") > 0 else int(state.voyage["nav_penalty_days"])) + int(state.voyage["run_extra_days"])
	var f := int(floor(state.food_frac + days * state.food_per_day() + 0.0001))
	var w := int(floor(state.water_frac + days * state.water_per_day() + 0.0001))
	var room: int = state.cargo_capacity - state.supply_slots(f, w) - state.ammo_slots()
	var leg := {"good": "", "units": 0, "profit": 0, "days": days, "food": f, "water": w}
	for good in state.goods_order():
		if not state.produces(good, from):
			continue
		var margin: int = state.price(good, "sell", dest) - state.price(good, "buy", from)
		var units := mini(room, (gold - f - w) / maxi(1, state.price(good, "buy", from)))
		if units > 0 and margin > 0 and units * margin > int(leg["profit"]):
			leg = {"good": good, "units": units, "profit": units * margin, "days": days, "food": f, "water": w}
	return leg

## Two-leg lookahead: gold per day over (here -> dest) plus the best next leg out of dest,
## so the captain will sail empty-ish to where the rich cargo is.
func _plan(state: Node, only: String = "") -> Dictionary:
	var best := {"score": -1.0}
	var here: String = state.current_port_id
	for dest in state.destinations():
		if only != "" and dest != only:
			continue
		var leg := _leg(state, here, dest, state.gold)
		var next_best := 0.0
		var next_days := 1
		for after in state.routes.get(dest, {}):
			var leg2 := _leg(state, dest, after, state.gold + int(leg["profit"]))
			var rate := float(int(leg["profit"]) + int(leg2["profit"])) / float(int(leg["days"]) + int(leg2["days"]))
			if rate > next_best:
				next_best = rate
		var score := maxf(next_best, float(leg["profit"]) / float(leg["days"]))
		var pick := {"score": score, "dest": dest, "good": leg["good"], "units": leg["units"], "food": leg["food"], "water": leg["water"]}
		if only != "" or score > float(best["score"]):
			best = pick
	return best

## Next hop toward the nearest port selling a ship of `tier`+ (fewest days over sailable routes).
func _toward_yard(state: Node, tier: int) -> String:
	var dist := {state.current_port_id: 0}
	var first := {}
	var todo: Array = [state.current_port_id]
	while not todo.is_empty():
		todo.sort_custom(func(a, b): return int(dist[a]) < int(dist[b]))
		var p: String = todo.pop_front()
		if p != state.current_port_id:
			for id in state.ports[p].get("shipyard", []):
				if int(state.ships[id]["tier"]) >= tier:
					return str(first[p])
		for n in state.routes.get(p, {}):
			var d: int = int(dist[p]) + int(state.routes[p][n])
			if d < int(dist.get(n, 1 << 30)):
				dist[n] = d
				first[n] = n if p == state.current_port_id else first[p]
				todo.append(n)
	return ""

func _hire_until(state: Node, n: int) -> void:
	while state.crew_count() < n:
		var list: Array = state.roster()
		if list.is_empty():
			return
		var pick: Dictionary = list[0]
		for m in list:
			if m["profession"] == "navigator" and state.count("navigator") == 0:
				pick = m
				break
			if int(m["wage"]) < int(pick["wage"]):
				pick = m
		if not state.hire(str(pick["id"])):
			return

func _initialize() -> void:
	var state: Node = load("res://scripts/game_state.gd").new()
	root.add_child(state)
	state.rng.seed = 7
	state.load_ports()
	var win_tier := int(state.voyage["win_ship_tier"])
	var departures := 0
	for trip in 200:
		for good in state.cargo.keys():
			state.sell(good, int(state.cargo[good]))
		while state.food > 0 and state.unload_supply("food"):
			pass
		while state.water > 0 and state.unload_supply("water"):
			pass
		if state.hull < state.hull_max:
			while state.hull < state.hull_max and state.repair():
				pass
		# Upgrades: the winning ship if affordable, else a bigger hold when there's spare gold.
		for id in state.port().get("shipyard", []):
			var tier: int = int(state.ships[id]["tier"])
			if tier >= win_tier:
				_hire_until(state, int(state.ships[id]["min_crew"]))
				if state.buy_ship(id):
					var logged: Array = state.ship_log.entries.filter(func(e): return e["type"] == "trip")
					if logged.size() != departures:
						return _fail("log has %d trips for %d departures" % [logged.size(), departures])
					log_lines.append("day %d: bought the %s at %s" % [state.day, id, state.current_port_id])
					if state.day < MIN_DAYS:
						return _fail("won too fast: day %d (want %d-%d)" % [state.day, MIN_DAYS, MAX_DAYS])
					print("full run check ok: won on day %d with %d gold, charts %s\n%s" % [state.day, state.gold, str(state.charted), "\n".join(log_lines)])
					quit(0)
					return
			elif tier > int(state.ship()["tier"]) and int(state.ships[id]["hold"]) > state.cargo_capacity and state.gold >= state.ship_net_price(id) + 60:
				_hire_until(state, int(state.ships[id]["min_crew"]))
				if state.buy_ship(id):
					log_lines.append("day %d: bought the %s, crew %d, gold %d" % [state.day, id, state.crew_count(), state.gold])
		_hire_until(state, state.min_crew())
		# A navigator saves a day on every leg: worth a bunk once the ship has room.
		if state.count("navigator") == 0 and state.crew_count() < state.bunks:
			for m in state.roster():
				if m["profession"] == "navigator" and state.gold >= state.hire_fee(m) + 40:
					state.hire(str(m["id"]))
					break
		# Cartographers: hire when it leaves money to trade, then head for the "?".
		var carto: Dictionary = state.cartographer()
		if not carto.is_empty() and state.carto_refusal(carto) == "" and state.gold >= int(carto["fee"]) + 80 and state.crew_count() < state.bunks:
			if state.hire_cartographer():
				log_lines.append("day %d: hired %s for %s" % [state.day, str(carto["name"]), str(carto["chart"])])
		var plan := {}
		var landfall := ""
		if state.carto_chart() != "":
			landfall = str(state.charts[state.carto_chart()]["landfall"])
		var galleon: int = 0
		for id in state.ships:
			if int(state.ships[id]["tier"]) >= win_tier:
				galleon = state.ships[id]["price"] - state.trade_in_value()
		if landfall != "" and state.routes.get(state.current_port_id, {}).has(landfall):
			plan = _plan(state, landfall)
		elif state.gold >= galleon + 20:
			var hop := _toward_yard(state, win_tier)
			if hop != "":
				plan = _plan(state, hop)
		if not plan.has("dest"):
			plan = _plan(state)
		if not plan.has("dest"):
			return _fail("day %d: no plan at %s with %d gold" % [state.day, state.current_port_id, state.gold])
		state.set_destination(str(plan["dest"]))
		for i in int(plan["food"]):
			state.load_supply("food")
		for i in int(plan["water"]):
			state.load_supply("water")
		if str(plan["good"]) != "":
			state.buy(str(plan["good"]), mini(int(plan["units"]), state.free_cargo()))
		var from: String = state.current_port_id
		if not state.depart():
			return _fail("day %d: could not depart: %s" % [state.day, state.message])
		departures += 1
		var note := "clear"
		if state.encounter:
			var mine: int = int(state.fight_power()["total"])
			if mine > int(state.pirates[state.pirate_id]["power"]):
				state.resolve_fight()
				note = "fought %s" % state.pirate_id
			else:
				state.resolve_run()
				note = "ran from %s" % state.pirate_id
		log_lines.append("day %d: %s -> %s %d %s (%s), gold %d, %s" % [state.day, from, plan["dest"], int(plan["units"]), plan["good"], note, state.gold, state.ship_id])
		if state.ended != "":
			return _fail("run ended: %s" % state.ended)
		if state.day > MAX_DAYS:
			return _fail("no winning ship by day %d (gold %d)" % [state.day, state.gold])
	_fail("ran out of trips")
