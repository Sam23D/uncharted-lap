extends SceneTree
## Economy rules the port data must keep:
## - one port is the cheapest place to buy sugar, another the cheapest for cheese;
## - the classic loop (cheap sugar -> best sugar market, cheap cheese -> best cheese
##   market) makes money on both legs;
## - a short starter hop from home makes money too;
## - no port buys a good back for more than it sells it (no same-port arbitrage);
## - one port hires cheapest (hire_mult), another repairs cheapest.

func _fail(text: String) -> void:
	push_error(text)
	quit(1)

func _best(state: Node, good: String, side: String, lowest: bool) -> String:
	var pick := ""
	for id in state.ports:
		var p := int(state.ports[id]["goods"][good][side])
		if pick == "":
			pick = id
			continue
		var cur := int(state.ports[pick]["goods"][good][side])
		if (lowest and p < cur) or (not lowest and p > cur):
			pick = id
	return pick

func _service_best(state: Node, key: String) -> String:
	var pick := ""
	for id in state.ports:
		if pick == "" or state.service(key, id) < state.service(key, pick):
			pick = id
	return pick

func _initialize() -> void:
	var state: Node = load("res://scripts/game_state.gd").new()
	root.add_child(state)
	state.load_ports()
	for id in state.ports:
		for good in ["sugar", "cheese"]:
			var g: Dictionary = state.ports[id]["goods"][good]
			if int(g["sell"]) >= int(g["buy"]):
				return _fail("%s sells %s back at %d >= buy %d" % [id, good, int(g["sell"]), int(g["buy"])])
	var sugar_src := _best(state, "sugar", "buy", true)
	var sugar_dst := _best(state, "sugar", "sell", false)
	var cheese_src := _best(state, "cheese", "buy", true)
	var cheese_dst := _best(state, "cheese", "sell", false)
	if sugar_src == cheese_src:
		return _fail("sugar and cheese are cheapest at the same port (%s)" % sugar_src)
	var sugar_margin: int = int(state.ports[sugar_dst]["goods"]["sugar"]["sell"]) - int(state.ports[sugar_src]["goods"]["sugar"]["buy"])
	var cheese_margin: int = int(state.ports[cheese_dst]["goods"]["cheese"]["sell"]) - int(state.ports[cheese_src]["goods"]["cheese"]["buy"])
	if sugar_margin <= 0 or cheese_margin <= 0:
		return _fail("loop legs must both pay: sugar %+d, cheese %+d" % [sugar_margin, cheese_margin])
	if sugar_dst != cheese_src or cheese_dst != sugar_src:
		return _fail("the loop should be a round trip: sugar %s->%s, cheese %s->%s" % [sugar_src, sugar_dst, cheese_src, cheese_dst])
	# Starter: the nearest port from home buys home sugar at a profit.
	state.current_port_id = sugar_src
	var near: String = state.destinations()[0]
	var starter: int = int(state.ports[near]["goods"]["sugar"]["sell"]) - int(state.ports[sugar_src]["goods"]["sugar"]["buy"])
	if starter <= 0:
		return _fail("starter hop %s->%s loses money on sugar" % [sugar_src, near])
	var crew := ""
	for id in state.ports:
		if crew == "" or state.service_f("hire_mult", id) < state.service_f("hire_mult", crew):
			crew = id
	var yard := _service_best(state, "repair_cost")
	if state.service_f("hire_mult", crew) >= float(state.voyage["hire_mult"]):
		return _fail("no port hires cheaper than the default")
	if state.service("repair_cost", yard) >= int(state.voyage["repair_cost"]):
		return _fail("no port repairs cheaper than the default")
	if crew == yard:
		return _fail("crew port and shipyard port should differ")
	print("economy check ok: sugar %s->%s %+d, cheese %s->%s %+d, starter %s %+d, crew %s, yard %s" % [
		sugar_src, sugar_dst, sugar_margin, cheese_src, cheese_dst, cheese_margin, near, starter, crew, yard])
	quit(0)
