extends SceneTree

func _initialize() -> void:
	var state: Node = load("res://scripts/game_state.gd").new()
	root.add_child(state)
	state.load_ports()
	state.voyage["pirate_chance"] = 1.0
	if state.destination_id() != "lisbon":
		push_error("default course should be the nearest port, Lisbon")
		quit(1)
		return
	state.set_destination("oslo")
	state.sign_on("navigator")
	state.cargo_capacity = 20
	for _i in 10:
		if state.food < state.supplies_needed():
			state.load_supply("food")
		if state.water < state.water_needed():
			state.load_supply("water")
	var need: int = state.supplies_needed()
	if state.food < need or state.water < state.water_needed():
		push_error("could not load the estimate: need %d" % need)
		quit(1)
		return
	var estimate: int = state.estimate_days(true)
	state.set_destination("oslo")
	state.depart()
	state.resolve_run()
	if state.ended != "" or state.current_port_id != "oslo":
		push_error("estimated supplies did not reach Oslo: %s" % state.ended)
		quit(1)
		return
	if state.last_voyage_days > estimate:
		push_error("trip took %d days, estimate said %d" % [state.last_voyage_days, estimate])
		quit(1)
		return
	state.reset()
	state.voyage["pirate_chance"] = 1.0
	state.set_destination("oslo")
	state.sign_on("navigator")
	need = state.supplies_needed()
	state.food = need - 1
	state.water = state.water_needed()
	state.set_destination("oslo")
	state.depart()
	state.resolve_run()
	if state.ended != "starved":
		push_error("one food short of the estimate should starve")
		quit(1)
		return
	print("trip check ok need %d days %d" % [need, estimate])
	quit(0)
