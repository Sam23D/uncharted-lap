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

## Armory: cannons limited by gun ports, weapons by bunks, ammo stacks 5 per hold slot.
func _initialize() -> void:
	var state := _state()
	state.gold = 500
	if state.buy_arm("cannon"):
		return _fail("sloop has 1 gun port, already filled")
	var used: int = state.cargo_used()
	for i in 5:
		if not state.buy_arm("powder"):
			return _fail("powder refused: %s" % state.message)
	if state.cargo_used() != used + 1:
		return _fail("5 powder should take 1 slot, took %d" % (state.cargo_used() - used))
	state.buy_arm("powder")
	if state.cargo_used() != used + 2:
		return _fail("6 powder should take 2 slots")
	for i in state.bunks:
		state.buy_arm("musket")
	if state.buy_arm("musket"):
		return _fail("more muskets than bunks")
	var gold: int = state.gold
	if not state.sell_arm("musket") or state.gold <= gold:
		return _fail("musket sale paid nothing")
	if state.gold - gold > state.arm_price("musket"):
		return _fail("selling pays more than buying")
	while state.free_cargo() > 0:
		state.buy("sugar")
	state.armory["shot"] = 5
	if state.buy_arm("shot"):
		return _fail("shot past a full hold")
	print("armory check ok")
	quit(0)
