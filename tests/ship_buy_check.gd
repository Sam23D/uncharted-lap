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

## Buying ships: trade-in, refusals (stock, bunks, hold, gold), extra cannons sold, win tier.
func _initialize() -> void:
	var state := _state()
	state.gold = 500
	var net: int = state.ship_net_price("cutter")
	var expect: int = int(state.ships["cutter"]["price"]) - int(int(state.ships["sloop"]["price"]) * float(state.voyage["trade_in"]))
	if net != expect:
		return _fail("cutter net %d, expected %d" % [net, expect])
	if state.buy_ship("brig"):
		return _fail("Madeira should not sell the brig")
	state.current_port_id = "lisbon"
	state.cargo["sugar"] = 9
	if state.buy_ship("cutter"):
		return _fail("cutter (hold 10) took 11 slots: %s" % state.message)
	if not state.message.contains("Unload"):
		return _fail("no hold message: %s" % state.message)
	state.cargo.clear()
	state.cargo["sugar"] = 7
	state.armory["cannon"] = 1
	if not state.buy_ship("cutter"):
		return _fail("cutter refused: %s" % state.message)
	if state.cargo_capacity != int(state.ships["cutter"]["hold"]):
		return _fail("stats not applied")
	state.cargo.clear()
	state.armory["cannon"] = 2
	state.gold = 500
	if not state.buy_ship("fluyt"):
		return _fail("fluyt refused: %s" % state.message)
	if int(state.armory["cannon"]) != 1:
		return _fail("extra cannon not sold: %d" % int(state.armory["cannon"]))
	for i in 7:
		state.sign_on("deckhand")
	state.current_port_id = "london"
	if state.buy_ship("brig") or not state.message.contains("Dismiss"):
		return _fail("7 crew in 6 bunks should refuse: %s" % state.message)
	state.crew.pop_back()
	state.gold = 10
	if state.buy_ship("brig"):
		return _fail("bought without gold")
	state.gold = 500
	if not state.buy_ship("brig") or state.ended != "":
		return _fail("the brig is a mid-tier warship, not the win: %s" % state.message)
	# The Galleon (tier 4) wins.
	state.current_port_id = "genoa"
	state.gold = 2000
	if not state.buy_ship("galleon") or state.ended != "win":
		return _fail("galleon should win: %s" % state.message)
	print("ship buy check ok: cutter net %d" % net)
	quit(0)
