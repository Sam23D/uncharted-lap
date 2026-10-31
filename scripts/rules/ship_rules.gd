extends RefCounted
## Ship ladder rules (data/ships.json). Pure functions; GameState applies the result.

## List price at a port: ships.json price x the port's "ship_mult" service.
static func price(ships: Dictionary, id: String, ship_mult: float) -> int:
	return int(round(float(ships[id]["price"]) * ship_mult))

## What the yard pays for your current ship.
static func trade_in_value(ships: Dictionary, id: String, trade_in: float) -> int:
	return int(float(ships[id]["price"]) * trade_in)

## Gold you pay to swap `from_id` for `to_id` here (never below 0).
static func net_price(ships: Dictionary, from_id: String, to_id: String, ship_mult: float, trade_in: float) -> int:
	return maxi(0, price(ships, to_id, ship_mult) - trade_in_value(ships, from_id, trade_in))

## Days for a route on this ship: base days + ship speed, never below 1.
static func days(base_days: int, speed: int) -> int:
	return maxi(1, base_days + speed)

## Why you can't switch to `to_id` right now, or "" when you can.
static func refusal(state: Node, to_id: String) -> String:
	if not state.ships.has(to_id):
		return "No such ship."
	if to_id == state.ship_id:
		return "You already sail a %s." % str(state.ships[to_id]["name"])
	if not to_id in state.port().get("shipyard", []):
		return "This yard doesn't sell the %s." % str(state.ships[to_id]["name"])
	var spec: Dictionary = state.ships[to_id]
	var name := str(spec["name"])
	if state.crew.size() > int(spec["bunks"]):
		return "The %s has %d bunks. Dismiss %d crew first." % [name, int(spec["bunks"]), state.crew.size() - int(spec["bunks"])]
	if state.cargo_used() > int(spec["hold"]):
		return "The %s holds %d. Unload %d first." % [name, int(spec["hold"]), state.cargo_used() - int(spec["hold"])]
	for kind in ["musket", "sword"]:
		if int(state.armory.get(kind, 0)) > int(spec["bunks"]):
			return "Too many %ss for %d bunks. Sell some first." % [kind, int(spec["bunks"])]
	var cost: int = state.ship_net_price(to_id)
	if state.gold < cost:
		return "The %s costs %d after trade-in. You have %d." % [name, cost, state.gold]
	return ""
