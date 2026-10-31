extends SceneTree
## Economy rules the data must keep (GDScript port of tools/trade_data.py, over every port in
## data/, charted or not):
## - no same-port arbitrage: where a port makes a good, it pays less than it charges;
## - every port has a price for every good, and every good made somewhere sells for more
##   somewhere else;
## - every port has something worth bringing, and something worth carrying away
##   (Cape Town, a waystation, is exempt from exports);
## - the best margin per unit per day stays inside its tier's band, and farther tiers pay more;
## - home: Madeira sugar -> Oslo and Oslo cheese -> Madeira both pay, and so does the
##   starter hop Madeira -> Lisbon;
## - one home port hires cheapest, another repairs cheapest.
const BAND := {0: 3.0, 1: 3.5, 2: 5.0, 3: 6.5}

func _fail(text: String) -> void:
	push_error(text)
	quit(1)

## Shortest days between every pair of ports over all routes (charted or not).
func _distances(state: Node) -> Dictionary:
	var graph := {}
	for r in state.all_routes:
		for pair in [[str(r["from"]), str(r["to"])], [str(r["to"]), str(r["from"])]]:
			if not graph.has(pair[0]):
				graph[pair[0]] = {}
			graph[pair[0]][pair[1]] = int(r["days"])
	var dist := {}
	for src in state.ports:
		var best := {src: 0}
		var todo: Array = [src]
		while not todo.is_empty():
			todo.sort_custom(func(a, b): return int(best[a]) < int(best[b]))
			var p: String = todo.pop_front()
			for n in graph.get(p, {}):
				var d: int = int(best[p]) + int(graph[p][n])
				if d < int(best.get(n, 1 << 30)):
					best[n] = d
					todo.append(n)
		dist[src] = best
	return dist

func _tier(state: Node, port: String) -> int:
	return int(state.charts[str(state.ports[port].get("chart", "known"))]["tier"])

func _initialize() -> void:
	var state: Node = load("res://scripts/game_state.gd").new()
	root.add_child(state)
	state.load_ports()
	var goods: Array = state.goods_order()
	if goods.size() != 14:
		return _fail("expected 14 goods, got %d" % goods.size())
	for id in state.ports:
		for good in goods:
			if state.price(good, "sell", id) <= 0:
				return _fail("%s has no price for %s" % [id, good])
			if state.produces(good, id) and state.price(good, "sell", id) >= state.price(good, "buy", id):
				return _fail("%s sells %s back at %d >= buy %d" % [id, good, state.price(good, "sell", id), state.price(good, "buy", id)])
	var dist := _distances(state)
	var best_by_tier := {}
	var exports := {}
	var imports := {}
	for good in goods:
		var sources: Array = state.ports.keys().filter(func(id): return state.produces(good, id))
		if sources.is_empty():
			continue
		var paid := false
		for a in sources:
			for b in state.ports:
				if a == b or not dist[a].has(b):
					continue
				var margin: int = state.price(good, "sell", b) - state.price(good, "buy", a)
				if margin <= 0:
					continue
				paid = true
				exports[a] = true
				imports[b] = true
				var tier := maxi(_tier(state, a), _tier(state, b))
				var rate := float(margin) / float(dist[a][b])
				if rate > float(best_by_tier.get(tier, [0.0])[0]):
					best_by_tier[tier] = [rate, "%s %s->%s +%d in %dd" % [good, a, b, margin, dist[a][b]]]
		if not paid:
			return _fail("%s never sells above its cheapest source" % good)
	for id in state.ports:
		if not imports.has(id):
			return _fail("%s: nothing worth bringing" % id)
		if not exports.has(id) and id != "capetown":
			return _fail("%s: nothing worth carrying away" % id)
	var last := 0.0
	var tiers: Array = best_by_tier.keys()
	tiers.sort()
	var lines: Array[String] = []
	for t in tiers:
		var rate: float = best_by_tier[t][0]
		if rate > float(BAND[t]) + 0.001:
			return _fail("tier %d over its band %.1f: %.2f (%s)" % [t, BAND[t], rate, best_by_tier[t][1]])
		if rate < last:
			return _fail("tier %d pays less per day (%.2f) than the tier before (%.2f)" % [t, rate, last])
		last = rate
		lines.append("tier %d %.2f/u/d (%s)" % [t, rate, best_by_tier[t][1]])
	var sugar: int = state.price("sugar", "sell", "oslo") - state.price("sugar", "buy", "madeira")
	var cheese: int = state.price("cheese", "sell", "madeira") - state.price("cheese", "buy", "oslo")
	var starter: int = state.price("sugar", "sell", "lisbon") - state.price("sugar", "buy", "madeira")
	if sugar <= 0 or cheese <= 0 or starter <= 0:
		return _fail("home trades must pay: sugar %+d, cheese %+d, starter %+d" % [sugar, cheese, starter])
	var crew := ""
	var yard := ""
	for id in state.known_ports():
		if crew == "" or state.service_f("hire_mult", id) < state.service_f("hire_mult", crew):
			crew = id
		if yard == "" or state.service("repair_cost", id) < state.service("repair_cost", yard):
			yard = id
	if state.service_f("hire_mult", crew) >= float(state.voyage["hire_mult"]) or state.service("repair_cost", yard) >= int(state.voyage["repair_cost"]):
		return _fail("a home port should hire cheaper, and another repair cheaper, than the default")
	if crew == yard:
		return _fail("crew port and shipyard port should differ")
	print("economy check ok: %d ports; %s; home sugar %+d cheese %+d starter %+d; crew %s, yard %s" % [
		state.ports.size(), "; ".join(lines), sugar, cheese, starter, crew, yard])
	quit(0)
