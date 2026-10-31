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

## Pirate types: short routes only meet skiffs; longer ones can meet corsairs.
func _initialize() -> void:
	var state := _state()
	var seen := {}
	for i in 300:
		var id: String = state.CombatRules.pick_pirate(state.rng, state.pirates, 1)
		if int(state.pirates[id]["min_days"]) > 1:
			return _fail("%s on a 1-day route" % id)
	for i in 300:
		seen[state.CombatRules.pick_pirate(state.rng, state.pirates, 3)] = true
	if seen.size() < 2:
		return _fail("3-day route should roll several pirate types, got %s" % str(seen.keys()))
	print("pirate pick check ok: %s" % str(seen.keys()))
	quit(0)
