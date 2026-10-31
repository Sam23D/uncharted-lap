extends SceneTree

func _initialize() -> void:
	var state: Node = load("res://scripts/game_state.gd").new()
	root.add_child(state)
	state.load_ports()
	state.voyage["pirate_chance"] = 1.0
	state.food = 6
	state.water = 6
	state.cargo_capacity = 20
	state.sign_on("navigator")
	var before: int = state.food
	state.set_destination("oslo")
	state.depart()
	if not state.encounter:
		push_error("depart did not leave port")
		quit(1)
		return
	state.resolve_run()
	if state.current_port_id != "oslo" or state.ended != "":
		push_error("voyage did not arrive")
		quit(1)
		return
	if state.food >= before:
		push_error("supplies were not consumed")
		quit(1)
		return
	var light: int = state.voyage_days(0)
	state.cargo["sugar"] = 20
	state.cargo_capacity = 20
	var full: int = state.voyage_days(0)
	if light >= full:
		push_error("light hold was not faster: %d vs %d" % [light, full])
		quit(1)
		return
	state.ended = ""
	state.encounter = false
	state.current_port_id = "madeira"
	state.food = 0
	state.water = 6
	state.set_destination("oslo")
	state.depart()
	if state.ended != "starved" or state.current_port_id != "madeira":
		push_error("empty food should starve in port waters and not arrive")
		quit(1)
		return
	print("sail check ok")
	quit(0)
