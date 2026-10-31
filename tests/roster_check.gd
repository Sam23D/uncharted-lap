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

## Tavern rosters: 3-4 unique sailors, port weights respected, rotation every N days.
func _initialize() -> void:
	var state := _state()
	var ids := {}
	var navigators := 0
	var total := 0
	for i in 200:
		state.rosters.erase("lisbon")
		state.ensure_roster("lisbon")
		var list: Array = state.rosters["lisbon"]["list"]
		if list.size() < 3 or list.size() > 4:
			return _fail("roster size %d" % list.size())
		var seen := {}
		for m in list:
			if seen.has(m["id"]) or seen.has(m["name"]):
				return _fail("duplicate in roster")
			seen[m["id"]] = true
			seen[m["name"]] = true
			if int(m["wage"]) < 1:
				return _fail("free sailor")
			total += 1
			if m["profession"] == "navigator":
				navigators += 1
	var share := float(navigators) / total
	if share < 0.3:
		return _fail("Lisbon should lean to navigators, got %.2f" % share)
	var before: Array = state.rosters["lisbon"]["list"].duplicate()
	state.day += int(state.voyage["roster_refresh_days"]) - 1
	state.ensure_roster("lisbon")
	if state.rosters["lisbon"]["list"] != before:
		return _fail("roster rotated too early")
	state.day += 1
	state.ensure_roster("lisbon")
	if state.rosters["lisbon"]["day"] != state.day:
		return _fail("roster did not rotate")
	print("roster check ok: Lisbon navigators %.2f" % share)
	quit(0)
