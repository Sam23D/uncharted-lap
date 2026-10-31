extends SceneTree
## Unloading provisions: frees a hold slot, refunds voyage.json "supply_refund",
## refuses when there is none left, and can't happen at sea.

func _fail(text: String) -> void:
	push_error(text)
	quit(1)

func _initialize() -> void:
	var state: Node = load("res://scripts/game_state.gd").new()
	root.add_child(state)
	state.load_ports()
	state.load_supply("food")
	state.load_supply("food")
	var gold: int = state.gold
	var used: int = state.cargo_used()
	if not state.unload_supply("food"):
		return _fail("unload food failed")
	if state.food != 2 or state.cargo_used() != used - 1:
		return _fail("unload did not free a slot: food %d used %d" % [state.food, state.cargo_used()])
	if state.gold != gold + int(state.voyage["supply_refund"]):
		return _fail("refund wrong: %d -> %d" % [gold, state.gold])
	if int(state.voyage["supply_refund"]) > int(state.voyage["supply_price"]):
		return _fail("refund above price makes free gold")
	state.unload_supply("water")
	if state.unload_supply("water"):
		return _fail("unloaded water that was not there")
	if not state.message.begins_with("No water"):
		return _fail("no refusal message: %s" % state.message)
	state.encounter = true
	if state.unload_supply("food"):
		return _fail("unloaded at sea")
	print("unload check ok: food %d water %d gold %d" % [state.food, state.water, state.gold])
	quit(0)
