extends SceneTree
## Pirates show up on about 1 in 5 trips (voyage.json "pirate_chance").
## A clear trip resolves on Depart: days pass, supplies are eaten, you arrive.

func _fail(text: String) -> void:
	push_error(text)
	quit(1)

func _initialize() -> void:
	var state: Node = load("res://scripts/game_state.gd").new()
	root.add_child(state)
	state.load_ports()
	var chance := float(state.voyage["pirate_chance"])
	if chance <= 0.15 or chance >= 0.25:
		return _fail("pirate_chance should be about 1/5, got %.2f" % chance)

	# Clear trip.
	state.voyage["pirate_chance"] = 0.0
	state.food = 5
	state.water = 5
	state.set_destination("lisbon")
	var day: int = state.day
	state.depart()
	if state.encounter or state.met_pirate:
		return _fail("chance 0 still met a pirate")
	if state.current_port_id != "lisbon" or state.day <= day or state.food >= 5:
		return _fail("clear trip did not sail: at %s day %d food %d" % [state.current_port_id, state.day, state.food])
	if state.last_from != "madeira" or state.last_to != "lisbon":
		return _fail("last_from/last_to not recorded: %s -> %s" % [state.last_from, state.last_to])

	# Rate over many seeded departures.
	state.load_ports()
	state.rng.seed = 7
	var met := 0
	var trips := 600
	for _i in trips:
		state.ended = ""
		state.encounter = false
		state.current_port_id = "madeira"
		state.food = 9
		state.water = 9
		state.depart()
		if state.met_pirate:
			met += 1
	var rate := float(met) / trips
	if rate < 0.15 or rate > 0.25:
		return _fail("pirate rate %.2f is not about 1/5" % rate)
	print("voyage check ok: clear trip to lisbon, pirate rate %.2f" % rate)
	quit(0)
