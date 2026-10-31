extends SceneTree
## Routes and map data: every port is on the chart and reachable, days come from
## data/routes.json, and the first short hop leaves room in the hold to trade.

func _fail(text: String) -> void:
	push_error(text)
	quit(1)

func _initialize() -> void:
	var state: Node = load("res://scripts/game_state.gd").new()
	root.add_child(state)
	state.load_ports()
	state.voyage["pirate_chance"] = 1.0
	for id in state.ports:
		var spec: Dictionary = state.ports[id]
		if not spec.has("map") or spec["map"].size() != 2:
			return _fail("%s has no map position" % id)
		if not state.routes.has(id) or state.routes[id].is_empty():
			return _fail("%s has no routes" % id)
		for other in state.routes[id]:
			if not state.ports.has(other):
				return _fail("route %s -> %s points at an unknown port" % [id, other])
			if int(state.routes[other][id]) != int(state.routes[id][other]):
				return _fail("route %s <-> %s is not symmetric" % [id, other])
	var options: Array = state.destinations()
	if options.is_empty() or options[0] != "lisbon":
		return _fail("nearest from Madeira should be Lisbon, got %s" % str(options))
	if state.route_days("oslo") <= state.route_days("lisbon"):
		return _fail("Oslo should be farther than Lisbon")
	# Fresh start, course for Lisbon: load what the estimate asks for, then see what is left.
	state.set_destination("lisbon")
	while state.food < state.supplies_needed() and state.load_supply("food"):
		pass
	while state.water < state.supplies_needed() and state.load_supply("water"):
		pass
	var room: int = state.free_cargo()
	if room < 4:
		return _fail("only %d hold slots left for trade on the first hop" % room)
	state.buy("sugar", room)
	state.depart()
	state.resolve_run()
	if state.ended != "" or state.current_port_id != "lisbon":
		return _fail("first hop to Lisbon failed: %s" % state.ended)
	if state.destination != "":
		return _fail("course should clear on arrival")
	if state.set_destination("nowhere"):
		return _fail("unknown destination was accepted")
	print("route check ok: %d ports, first hop room %d, now at %s" % [state.ports.size(), room, state.current_port_id])
	quit(0)
