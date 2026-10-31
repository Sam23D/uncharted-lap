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

## Hiring from the roster: fee, bunks, the hire leaves the roster; navigator saves a day.
func _initialize() -> void:
	var state := _state()
	state.gold = 200
	var list: Array = state.roster()
	if list.size() < 3:
		return _fail("roster too small: %d" % list.size())
	var first: Dictionary = list[0]
	var fee: int = state.hire_fee(first)
	var gold: int = state.gold
	if not state.hire(str(first["id"])):
		return _fail("first hire failed: %s" % state.message)
	if state.gold != gold - fee or state.crew_count() != 1:
		return _fail("fee not charged")
	for m in state.roster():
		if m["id"] == first["id"]:
			return _fail("hired sailor still in the roster")
	state.bunks = 1
	if state.hire(str(state.roster()[0]["id"])):
		return _fail("hire above bunks was allowed")
	if not state.message.begins_with("Bunks full"):
		return _fail("no bunks message: %s" % state.message)
	if not state.dismiss(str(first["id"])) or state.crew_count() != 0:
		return _fail("dismiss failed")
	state.food = 8
	state.water = 8
	state.cargo_capacity = 20
	var slow: int = state.voyage_days(0)
	state.sign_on("navigator")
	var fast: int = state.voyage_days(0)
	if slow <= fast:
		return _fail("no navigator was not slower: %d vs %d" % [slow, fast])
	# Lisbon hires at half price.
	var lisbon: int = state.hire_fee(first, "lisbon")
	if lisbon >= state.hire_fee(first, "madeira"):
		return _fail("Lisbon should hire cheaper")
	print("crew check ok: fee %d (Lisbon %d)" % [fee, lisbon])
	quit(0)
