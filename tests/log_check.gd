extends SceneTree
## Ship's log: trades merge per port stay with average cost; trips record provisions,
## encounters (run and fight costs), starvation, and trip profit.

func _fail(text: String) -> void:
	push_error(text)
	quit(1)

func _state() -> Node:
	var state: Node = load("res://scripts/game_state.gd").new()
	root.add_child(state)
	state.rng.seed = 7
	state.load_ports()
	return state

func _trips(state: Node) -> Array:
	return state.ship_log.entries.filter(func(e): return e["type"] == "trip")

func _initialize() -> void:
	var state := _state()
	var log: RefCounted = state.ship_log
	state.gold = 200
	state.cargo_capacity = 40
	for i in 3:
		state.buy("sugar")
	if log.entries.size() != 1 or int(log.entries[0]["qty"]) != 3 or int(log.entries[0]["total"]) != 12:
		return _fail("3 buys should merge into one: %s" % str(log.entries))
	state.buy("cheese")
	if log.entries.size() != 2:
		return _fail("another good should be a new line")

	# Clear trip to Lisbon with a navigator: provisions used match the hold.
	state.sign_on("navigator")
	state.voyage["pirate_chance"] = 0.0
	state.food = 6
	state.water = 6
	state.set_destination("lisbon")
	state.depart()
	var t: Dictionary = _trips(state)[-1]
	if t["from"] != "madeira" or t["to"] != "lisbon" or int(t["days"]) < 1:
		return _fail("trip not logged: %s" % str(t))
	if int(t["food"]) != 6 - state.food or int(t["water"]) != 6 - state.water or int(t["food"]) < 1:
		return _fail("provisions wrong: %s, now food %d water %d" % [str(t), state.food, state.water])
	if not t["encounter"].is_empty() or int(t["wages"]) != 2 * int(t["days"]):
		return _fail("clear trip: encounter %s wages %d" % [str(t["encounter"]), int(t["wages"])])

	# Sell at Lisbon: margin against the average cost (4).
	state.sell("sugar", 2)
	var sale: Dictionary = log.entries[-1]
	if sale["side"] != "sell" or int(sale["cost_each"]) != 4 or int(sale["price"]) != 6:
		return _fail("sale margin wrong: %s" % str(sale))
	var trip_index: int = log.entries.find(t)
	var expect := 2 * (6 - 4) - int(t["wages"])
	if log.trip_profit(trip_index) != expect:
		return _fail("trip profit should be margin 4 - wages = %d, got %d" % [expect, log.trip_profit(trip_index)])

	# Buying again in a new port stay is a new line even at the same price.
	state.buy("sugar")
	state.buy("sugar")

	# Run: dropped cargo is logged with what it cost.
	state.voyage["pirate_chance"] = 1.0
	state.food = 9
	state.water = 9
	state.set_destination("madeira")
	state.depart()
	state.resolve_run()
	var e: Dictionary = _trips(state)[-1]["encounter"]
	if e.get("outcome") != "run" or e["lost"].is_empty() or int(e["lost_value"]) <= 0:
		return _fail("run cost not logged: %s" % str(e))

	# Fight lost: plunder logged per good, plus gold and damage.
	state.armory = {"cannon": 0, "musket": 0, "sword": 0, "powder": 0, "shot": 0}
	state.crew.clear()
	state.hull = 5
	state.cargo = {"sugar": 4}
	state.ship_log.cost["sugar"] = {"qty": 4, "paid": 16}
	state.food = 9
	state.water = 9
	state.set_destination("oslo")
	state.depart()
	state.pirate_id = "corsair"
	state.resolve_fight()
	e = _trips(state)[-1]["encounter"]
	if e.get("outcome") != "loss" or int(e["lost"].get("sugar", 0)) != 2 or int(e["gold"]) >= 0 or int(e["damage"]) < 1:
		return _fail("loss not logged: %s" % str(e))

	# Sunk ends the trip with ended = sunk.
	state.hull = 1
	state.food = 9
	state.water = 9
	state.set_destination("madeira")
	state.depart()
	state.pirate_id = "corsair"
	state.resolve_fight()
	if _trips(state)[-1]["ended"] != "sunk":
		return _fail("sunk trip not marked")

	# Starved: one food short.
	state.reset()
	state.voyage["pirate_chance"] = 0.0
	state.set_destination("oslo")
	state.food = 1
	state.water = 9
	state.depart()
	var last: Dictionary = _trips(state)[-1]
	if state.ended != "starved" or last["ended"] != "starved":
		return _fail("starved trip not marked: %s %s" % [state.ended, str(last)])
	if _trips(state).size() != 1:
		return _fail("reset should clear the log")

	# Cap.
	state.reset()
	state.ship_log.max_entries = 5
	state.gold = 500
	for good in ["sugar", "cheese", "sugar", "cheese", "sugar", "cheese", "sugar"]:
		state.buy(good)
	if state.ship_log.entries.size() != 5:
		return _fail("log cap not applied: %d" % state.ship_log.entries.size())
	print("log check ok")
	quit(0)
