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

## Pirate types: short routes only meet skiffs; longer ones can meet corsairs; regional
## pirates (pirates.json "regions") only sail their chart's routes.
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
	if seen.has("galley") or seen.has("raider") or seen.has("indies_brig"):
		return _fail("regional pirates in home waters: %s" % str(seen.keys()))
	var by_region := {}
	for region in ["mediterranean", "guinea", "cape"]:
		var hits := {}
		for i in 300:
			var id: String = state.CombatRules.pick_pirate(state.rng, state.pirates, 5, region)
			var regions: Array = state.pirates[id].get("regions", [])
			if not regions.is_empty() and not region in regions:
				return _fail("%s on a %s route" % [id, region])
			hits[id] = true
		by_region[region] = hits.keys()
	if not "galley" in by_region["mediterranean"] or not "raider" in by_region["guinea"] or not "indies_brig" in by_region["cape"]:
		return _fail("each region should meet its own pirate: %s" % str(by_region))
	# GameState passes the route's chart.
	if state.route_chart("lisbon", "genoa") != "mediterranean" or state.route_chart("madeira", "lisbon") != "known":
		return _fail("route_chart wrong")
	print("pirate pick check ok: home %s, regions %s" % [str(seen.keys()), str(by_region)])
	quit(0)
