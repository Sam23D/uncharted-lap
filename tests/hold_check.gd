extends SceneTree

func _initialize() -> void:
	var state: Node = load("res://scripts/game_state.gd").new()
	root.add_child(state)
	state.load_ports()
	while state.free_cargo() > 0:
		state.load_supply("food")
	var extra := 0
	while state.load_supply("water"):
		extra += 1
	if extra > 1 or state.free_cargo() < 0:
		push_error("loaded past a full hold")
		quit(1)
		return
	if not state.message.begins_with("Hold full"):
		push_error("no hold-full message: %s" % state.message)
		quit(1)
		return
	print("hold check ok: %s" % state.message)
	quit(0)
