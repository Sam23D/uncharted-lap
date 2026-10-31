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

## Fight power (table) and outcomes.
func _power(state: Node, arms: Dictionary, crew: Array) -> int:
	state.armory = {"cannon": 0, "musket": 0, "sword": 0, "powder": 0, "shot": 0}
	for k in arms:
		state.armory[k] = arms[k]
	state.crew.clear()
	for p in crew:
		state.sign_on(p)
	return int(state.fight_power()["total"])

func _initialize() -> void:
	var state := _state()
	var table := [
		[{"cannon": 1}, [], 0, "cannon without ammo"],
		[{"cannon": 1, "powder": 1, "shot": 1}, [], 2, "fed cannon"],
		[{"cannon": 2, "powder": 1, "shot": 1}, [], 2, "ammo for one cannon only"],
		[{}, ["marksman"], 1, "unarmed marksman"],
		[{"musket": 1, "powder": 1, "shot": 1}, ["marksman"], 2, "armed marksman"],
		[{"cannon": 1, "musket": 1, "powder": 1, "shot": 1}, ["marksman"], 3, "cannon takes the ammo first"],
		[{"sword": 1}, ["swordsman"], 2, "armed swordsman"],
		[{}, ["swordsman", "deckhand", "cook", "navigator"], 2, "fists"],
	]
	for row in table:
		var got := _power(state, row[0], row[1])
		if got != int(row[2]):
			return _fail("%s: power %d, expected %d" % [row[3], got, int(row[2])])
	# Win: 2 fed cannons + armed swordsman (6) vs skiff (3) is clean.
	_power(state, {"cannon": 2, "sword": 1, "powder": 3, "shot": 3}, ["swordsman"])
	state.hull = 3
	var gold: int = state.gold
	var f: Dictionary = state.CombatRules.resolve(state, "skiff")
	if f["outcome"] != "clean" or state.gold != gold + 8 or state.hull != 3:
		return _fail("clean win wrong: %s" % str(f))
	if int(state.armory["powder"]) != 1:
		return _fail("ammo not used: powder %d" % int(state.armory["powder"]))
	# Loss: nothing vs corsair (6): hull -3 -> sunk from 3, but from 5 survives plundered.
	_power(state, {}, [])
	state.hull = 5
	state.gold = 100
	state.cargo = {"sugar": 4}
	f = state.CombatRules.resolve(state, "corsair")
	if f["outcome"] != "loss" or state.hull != 2 or state.gold != 75 or int(state.cargo["sugar"]) != 2:
		return _fail("loss wrong: %s hull %d gold %d" % [str(f), state.hull, state.gold])
	state.hull = 3
	f = state.CombatRules.resolve(state, "corsair")
	if f["outcome"] != "sunk":
		return _fail("hull 3 - 3 should sink")
	print("combat check ok")
	quit(0)
