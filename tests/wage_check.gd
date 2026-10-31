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

## Wages: paid per day at sea on arrival; unpaid crew desert, highest wage first.
func _initialize() -> void:
	var state := _state()
	state.voyage["pirate_chance"] = 0.0
	state.cargo_capacity = 40
	state.sign_on("navigator")
	state.sign_on("deckhand")
	var per_day: int = state.wages_per_day()
	if per_day != 3:
		return _fail("navigator 2 + deckhand 1 should be 3/day, got %d" % per_day)
	state.food = 10
	state.water = 10
	state.gold = 50
	state.set_destination("lisbon")
	state.depart()
	var days: int = state.last_voyage_days
	if state.gold != 50 - per_day * days:
		return _fail("wages not paid: gold %d after %d days" % [state.gold, days])
	state.gold = 1
	state.set_destination("madeira")
	state.depart()
	if state.crew_count() != 1 or state.crew[0]["profession"] != "deckhand":
		return _fail("the navigator (highest wage) should desert first")
	if not state.message.contains("deserted"):
		return _fail("no desertion message: %s" % state.message)
	print("wage check ok: %d/day" % per_day)
	quit(0)
