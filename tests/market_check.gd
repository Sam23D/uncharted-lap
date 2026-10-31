extends SceneTree

func _initialize() -> void:
	var state: Node = load("res://scripts/game_state.gd").new()
	root.add_child(state)
	state.load_ports()
	state.food = 0
	state.water = 0
	var start: int = state.gold
	if not state.buy("sugar", state.cargo_capacity):
		push_error("buy sugar at Madeira failed")
		quit(1)
		return
	state.switch_port("oslo")
	if not state.sell("sugar", int(state.cargo.get("sugar", 0))):
		push_error("sell sugar at Oslo failed")
		quit(1)
		return
	if state.gold <= start:
		push_error("gold did not rise: %d -> %d" % [start, state.gold])
		quit(1)
		return
	# Ports only sell what they make; they buy anything.
	state.switch_port("madeira")
	if state.produces("olive_oil") or state.buy("olive_oil"):
		push_error("Madeira should not sell olive oil")
		quit(1)
		return
	if not state.message.contains("doesn't sell"):
		push_error("refusal should say the port doesn't sell it: %s" % state.message)
		quit(1)
		return
	state.switch_port("lisbon")
	if not state.buy("olive_oil", 2):
		push_error("Lisbon should sell olive oil: %s" % state.message)
		quit(1)
		return
	state.switch_port("madeira")
	var before: int = state.gold
	if not state.sell("olive_oil", 2) or state.gold - before != 2 * state.price("olive_oil", "sell"):
		push_error("Madeira should buy olive oil at its 'pays' price")
		quit(1)
		return
	print("market check ok gold %d -> %d; Lisbon oil sold in Madeira for %d each" % [start, state.gold, state.price("olive_oil", "sell")])
	quit(0)
