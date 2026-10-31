extends SceneTree
## Charts and cartographers: uncharted ports can't be reached; a cartographer hired in their
## tavern opens the way to the chart's landfall ("?"); arriving there charts every port and
## route of the chart, logs it and sends the cartographer ashore. Requirements refuse; a
## dismissed cartographer takes the fee with them and returns after carto_return_days.

func _fail(text: String) -> void:
	push_error(text)
	quit(1)

func _state() -> Node:
	var state: Node = load("res://scripts/game_state.gd").new()
	root.add_child(state)
	state.rng.seed = 3
	state.load_ports()
	state.voyage["pirate_chance"] = 0.0
	return state

func _initialize() -> void:
	var state := _state()
	# Part 1: charts hide ports and routes.
	if state.known_ports().size() != 4 or state.is_known("genoa"):
		return _fail("only the 4 home ports should be known: %s" % str(state.known_ports()))
	state.switch_port("lisbon")
	if state.routes.get("lisbon", {}).has("genoa") or state.set_destination("genoa"):
		return _fail("Genoa should be unreachable before it is charted")
	state.discover("baltic")
	if not state.is_known("hamburg") or not state.routes.get("london", {}).has("hamburg") or not state.routes.get("hamburg", {}).has("danzig"):
		return _fail("discover(baltic) should open Hamburg, Danzig and their routes")
	state.reset()
	state.voyage["pirate_chance"] = 0.0
	if state.is_known("hamburg") or state.charted != ["known"]:
		return _fail("reset should forget charts")

	# Part 2: the Lisbon cartographer.
	state.switch_port("lisbon")
	state.gold = 100
	var spec: Dictionary = state.cartographer()
	if spec.is_empty() or spec["chart"] != "mediterranean":
		return _fail("Lisbon should offer the Mediterranean chart: %s" % str(spec))
	state.switch_port("madeira")
	if state.cartographer()["chart"] != "guinea" or state.carto_refusal(state.cartographer()) == "":
		return _fail("Madeira's Guinea cartographer should need a tier-2 ship")
	if state.hire_cartographer():
		return _fail("hiring the Guinea cartographer on a Sloop should refuse")
	state.switch_port("lisbon")
	var gold: int = state.gold
	if not state.hire_cartographer():
		return _fail("hire failed: %s" % state.message)
	if state.gold != gold - int(spec["fee"]) or state.carto_chart() != "mediterranean" or not state.cartographer().is_empty():
		return _fail("hire should charge the fee, board the cartographer and empty the offer")
	if not state.routes.get("lisbon", {}).has("genoa") or state.is_known("genoa"):
		return _fail("the landfall route should open while Genoa stays uncharted")
	# Dismissed: fee lost, back after carto_return_days.
	state.dismiss("carto-mediterranean")
	if state.routes.get("lisbon", {}).has("genoa") or not state.cartographer().is_empty():
		return _fail("dismissing should close the route and keep the cartographer away")
	state.day += int(state.voyage["carto_return_days"])
	if state.cartographer().is_empty():
		return _fail("the cartographer should be back after %d days" % int(state.voyage["carto_return_days"]))
	state.gold = 100
	state.hire_cartographer()
	# Sail to the landfall.
	state.food = 9
	state.water = 9
	if not state.set_destination("genoa") or not state.depart():
		return _fail("could not sail to the landfall: %s" % state.message)
	if state.current_port_id != "genoa" or not state.is_known("alexandria") or state.carto_chart() != "":
		return _fail("arriving should chart the Mediterranean and send the cartographer ashore: %s" % state.message)
	if not state.routes.get("genoa", {}).has("alexandria") or not state.message.contains("Charted"):
		return _fail("Genoa-Alexandria should open; message: %s" % state.message)
	var logged: Array = state.ship_log.entries.filter(func(e): return e["type"] == "chart")
	if logged.size() != 1 or not "Alexandria" in logged[0]["ports"]:
		return _fail("the chart should be in the ship's log: %s" % str(logged))
	print("chart check ok: %s" % state.message)
	quit(0)
