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

## Ship data: a real ladder, and stats come from data/ships.json.
func _initialize() -> void:
	var state := _state()
	if state.ship_id != "sloop" or state.cargo_capacity != 10 or state.gun_ports != 1:
		return _fail("start ship should be the sloop with hold 10, 1 gun port")
	var tiers := {}
	for id in state.ships:
		var s: Dictionary = state.ships[id]
		if int(s["price"]) <= 0 or int(s["hold"]) < 2 or int(s["bunks"]) < 1:
			return _fail("%s has bad stats" % id)
		tiers[int(s["tier"])] = true
		if not ResourceLoader.exists(str(s["sprite"])):
			return _fail("%s sprite missing" % id)
	for t in [1, 2, 3]:
		if not tiers.has(t):
			return _fail("no tier %d ship" % t)
	var sells_win := false
	for p in state.ports:
		for id in state.ports[p]["shipyard"]:
			if not state.ships.has(id):
				return _fail("%s sells unknown ship %s" % [p, id])
			if int(state.ships[id]["tier"]) >= int(state.voyage["win_ship_tier"]):
				sells_win = true
	if not sells_win:
		return _fail("no port sells a winning ship")
	print("ship check ok: %d ships" % state.ships.size())
	quit(0)
