extends SceneTree
## A greedy captain plays from a fresh start (seed 7, real pirate odds) and must buy the
## winning ship within MAX_DAYS. Guards the whole economy: prices, ships, crew, food, pirates.
const MAX_DAYS := 40
var log_lines: Array[String] = []

func _fail(text: String) -> void:
	for l in log_lines:
		print(l)
	push_error(text)
	quit(1)

func _plan(state: Node) -> Dictionary:
	var best := {"score": -1.0}
	for dest in state.destinations():
		for good in ["sugar", "cheese"]:
			var margin: int = int(state.ports[dest]["goods"][good]["sell"]) - state.price(good, "buy")
			# Hold full of goods: no light-hold bonus.
			var days: int = state.ShipRules.days(state.route_days(dest), int(state.ship()["speed"])) + (0 if state.count("navigator") > 0 else int(state.voyage["nav_penalty_days"])) + int(state.voyage["run_extra_days"])
			var f := int(floor(state.food_frac + days * state.food_per_day() + 0.0001))
			var w := int(floor(state.water_frac + days * state.water_per_day() + 0.0001))
			var room: int = state.cargo_capacity - state.supply_slots(f, w) - state.ammo_slots()
			var units := mini(room, (state.gold - f - w) / maxi(1, state.price(good, "buy")))
			var score := float(units * margin) / days
			if units > 0 and margin > 0 and score > float(best["score"]):
				best = {"score": score, "dest": dest, "good": good, "units": units, "food": f, "water": w}
	return best

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
	for trip in 60:
		for good in state.cargo.keys():
			state.sell(good, int(state.cargo[good]))
		while state.food > 0 and state.unload_supply("food"):
			pass
		while state.water > 0 and state.unload_supply("water"):
			pass
		if state.hull < state.hull_max:
			state.repair()
		# Upgrades: the winning ship if affordable, else the next tier when there's spare gold.
		for id in state.port()["shipyard"]:
			var tier: int = int(state.ships[id]["tier"])
			if tier >= int(state.voyage["win_ship_tier"]) and state.buy_ship(id):
				log_lines.append("day %d: bought the %s at %s" % [state.day, id, state.current_port_id])
				print("full run check ok: won on day %d with %d gold\n%s" % [state.day, state.gold, "\n".join(log_lines)])
				quit(0)
				return
			if tier > int(state.ship()["tier"]) and int(state.ships[id]["hold"]) > state.cargo_capacity and state.gold >= state.ship_net_price(id) + 40:
				_hire_until(state, int(state.ships[id]["min_crew"]))
				if state.buy_ship(id):
					log_lines.append("day %d: bought the %s, crew %d, gold %d" % [state.day, id, state.crew_count(), state.gold])
		_hire_until(state, state.min_crew())
		var plan := _plan(state)
		if not plan.has("dest"):
			return _fail("day %d: no profitable plan at %s with %d gold" % [state.day, state.current_port_id, state.gold])
		state.set_destination(str(plan["dest"]))
		for i in int(plan["food"]):
			state.load_supply("food")
		for i in int(plan["water"]):
			state.load_supply("water")
		state.buy(str(plan["good"]), mini(int(plan["units"]), state.free_cargo()))
		var from: String = state.current_port_id
		if not state.depart():
			return _fail("day %d: could not depart: %s" % [state.day, state.message])
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
