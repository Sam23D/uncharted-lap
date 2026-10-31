extends SceneTree

func _fail(text: String) -> void:
	push_error(text)
	quit(1)

func _state() -> Node:
	var state: Node = load("res://scripts/game_state.gd").new()
	root.add_child(state)
	state.rng.seed = 7
	state.load_ports()
	return state

## Fight and run through GameState: loss is not game over, a hull at 0 is, running drops cargo.
func _initialize() -> void:
	var state := _state()
	state.voyage["pirate_chance"] = 1.0
	state.food = 8
	state.water = 8
	state.cargo_capacity = 20
	state.sign_on("navigator")
	state.set_destination("oslo")
	state.depart()
	if not state.encounter or state.pirate_id == "":
		return _fail("no pirate rolled")
	state.pirate_id = "skiff"
	state.gold = 40
	state.resolve_fight()
	if state.ended != "" or state.current_port_id != "oslo" or state.gold >= 40:
		return _fail("unarmed loss should arrive plundered: %s gold %d" % [state.ended, state.gold])
	state.current_port_id = "madeira"
	state.food = 8
	state.water = 8
	state.hull = 1
	state.set_destination("oslo")
	state.depart()
	state.pirate_id = "corsair"
	state.resolve_fight()
	if state.ended != "sunk":
		return _fail("hull 1 vs corsair should sink")
	state.ended = ""
	state.hull = 3
	state.current_port_id = "madeira"
	state.food = 8
	state.water = 8
	state.cargo["sugar"] = 3
	state.armory = {"cannon": 1, "musket": 1, "sword": 1, "powder": 5, "shot": 5}
	state.set_destination("oslo")
	state.depart()
	state.resolve_run()
	if state.ended != "" or state.current_port_id != "oslo" or int(state.cargo.get("sugar", 0)) >= 3:
		return _fail("run should arrive with less cargo")
	if int(state.armory["powder"]) != 5:
		return _fail("running should not use ammo")
	print("pirate check ok")
	quit(0)
