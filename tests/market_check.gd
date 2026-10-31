extends SceneTree

func _initialize() -> void:
	var state: Node = load("res://scripts/game_state.gd").new()
	root.add_child(state)
	state.load_ports()
	state.food = 0
	state.water = 0
	var start: int = state.gold
	if not state.buy("sugar", state.cargo_capacity):
		push_error("buy sugar at Madeira failed")
		quit(1)
		return
	state.switch_port("oslo")
	if not state.sell("sugar", int(state.cargo.get("sugar", 0))):
		push_error("sell sugar at Oslo failed")
		quit(1)
		return
	if state.gold <= start:
		push_error("gold did not rise: %d -> %d" % [start, state.gold])
		quit(1)
		return
	print("market check ok gold %d -> %d" % [start, state.gold])
	quit(0)
