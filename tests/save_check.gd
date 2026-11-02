extends SceneTree
## Autosave round trip: play 3 legs, save, load into a fresh GameState, compare every field
## and the log; then sail one more identical leg on both (rng restored) and compare again.

func _fail(text: String) -> void:
	push_error(text)
	quit(1)

func _state(seed: int) -> Node:
	var s: Node = load("res://scripts/game_state.gd").new()
	root.add_child(s)
	s.save_path = "user://save_check.json"
	s.rng.seed = seed
	s.load_ports()
	return s

func _leg(s: Node, to: String, good: String) -> void:
	s.set_destination(to)
	for i in 3:
		s.load_supply("food")
		s.load_supply("water")
	if good != "" and s.produces(good):
		s.buy(good, 4)
	s.depart()
	if s.encounter:
		s.resolve_run()
	for g in s.cargo.keys():
		s.sell(g, int(s.cargo[g]))

func _snapshot(s: Node) -> String:
	return JSON.stringify(s.SaveGame.to_dict(s), "", true)

func _initialize() -> void:
	var a := _state(11)
	a.voyage["pirate_chance"] = 0.5
	a.hint_seen = true
	_leg(a, "lisbon", "sugar")
	_leg(a, "madeira", "olive_oil")
	_leg(a, "oslo", "sugar")
	if a.ended != "":
		return _fail("run ended early: " + a.ended)
	a.hire(str(a.roster()[0]["id"]))
	if not a.save_game() or not a.has_save():
		return _fail("save failed")
	var b := _state(99)
	var why: String = b.load_game()
	if why != "":
		return _fail("load failed: " + why)
	if _snapshot(a) != _snapshot(b):
		return _fail("loaded state differs:\n%s\n---\n%s" % [_snapshot(a), _snapshot(b)])
	if b.ship_log.entries.size() != a.ship_log.entries.size() or b.ship_log.entries.is_empty():
		return _fail("log lost")
	if b.cargo_capacity != a.cargo_capacity or b.ship_name != a.ship_name or b.routes.size() != a.routes.size():
		return _fail("derived ship/routes not rebuilt")
	# Same rng, same next leg.
	b.voyage["pirate_chance"] = 0.5
	_leg(a, "london", "cheese")
	_leg(b, "london", "cheese")
	if _snapshot(a) != _snapshot(b):
		return _fail("next leg diverged after load")
	# Typed values survive JSON.
	if typeof(b.gold) != TYPE_INT or typeof(b.food_frac) != TYPE_FLOAT:
		return _fail("types lost: gold %d frac %d" % [typeof(b.gold), typeof(b.food_frac)])
	# Newer saves are refused; finished runs aren't saved; delete removes the slot.
	var f := FileAccess.open(b.save_path, FileAccess.WRITE)
	f.store_string(JSON.stringify({"save_version": 99, "ship_id": "sloop", "current_port_id": "madeira"}))
	f.close()
	if b.load_game() == "":
		return _fail("newer save accepted")
	b.ended = "starved"
	b.delete_save()
	if b.save_game() or b.has_save():
		return _fail("finished run saved / not deleted")
	print("save check ok: day %d, %d log entries" % [a.day, a.ship_log.entries.size()])
	quit(0)
