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

## Food and water: 1/day solo, +0.5 per crew; a cook cuts food (not water).
func _initialize() -> void:
	var state := _state()
	if absf(state.food_per_day() - 1.0) > 0.001:
		return _fail("solo should eat 1/day")
	state.sign_on("deckhand")
	state.sign_on("deckhand")
	if absf(state.food_per_day() - 2.0) > 0.001 or absf(state.water_per_day() - 2.0) > 0.001:
		return _fail("2 crew should use 2/day")
	state.crew.pop_back()
	state.sign_on("cook")
	if absf(state.food_per_day() - 1.5) > 0.001 or absf(state.water_per_day() - 2.0) > 0.001:
		return _fail("cook: food %.2f water %.2f" % [state.food_per_day(), state.water_per_day()])
	state.crew.clear()
	state.sign_on("deckhand")
	state.food = 10
	state.water = 10
	state._consume_days(3)
	if state.food != 6 or absf(state.food_frac - 0.5) > 0.001:
		return _fail("1.5/day for 3 days should eat 4 and leave half: food %d frac %.2f" % [state.food, state.food_frac])
	print("ration check ok")
	quit(0)
