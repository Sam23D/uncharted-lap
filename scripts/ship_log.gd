extends RefCounted
## Ship's log: trades and trips as plain dictionaries, oldest first.
## GameState calls these at the points where its rules already change state;
## nothing here changes the game. See README "Ship's log".

var entries: Array = []
## good -> {"qty": int, "paid": int}: average cost of what is in the hold.
var cost: Dictionary = {}
var max_entries := 200
var start_gold := 0
## Index of the open trip entry, or -1 in port.
var _trip := -1
## Bumped on every departure, so trades merge only within one port stay.
var _stay := 0

func clear(gold: int) -> void:
	entries = []
	cost = {}
	start_gold = gold
	_trip = -1
	_stay = 0

func _push(entry: Dictionary) -> void:
	entries.append(entry)
	while entries.size() > max_entries:
		entries.pop_front()
		_trip -= 1

func avg_cost(good: String) -> int:
	var c: Dictionary = cost.get(good, {})
	if int(c.get("qty", 0)) <= 0:
		return 0
	return int(round(float(c["paid"]) / float(c["qty"])))

## Removes units from the cost basis; returns what they had cost.
func _take(good: String, qty: int) -> int:
	var c: Dictionary = cost.get(good, {})
	if c.is_empty() or int(c["qty"]) <= 0:
		return 0
	var n := mini(qty, int(c["qty"]))
	var value := n * avg_cost(good)
	if n >= int(c["qty"]):
		cost.erase(good)
	else:
		c["paid"] = maxi(0, int(c["paid"]) - value)
		c["qty"] = int(c["qty"]) - n
	return value

func trade(day: int, port: String, side: String, good: String, qty: int, price: int) -> void:
	var cost_each := 0
	if side == "buy":
		var c: Dictionary = cost.get(good, {"qty": 0, "paid": 0})
		c["qty"] = int(c["qty"]) + qty
		c["paid"] = int(c["paid"]) + qty * price
		cost[good] = c
	else:
		cost_each = avg_cost(good)
		_take(good, qty)
	var last: Dictionary = entries[-1] if not entries.is_empty() else {}
	if last.get("type") == "trade" and int(last["stay"]) == _stay and last["side"] == side \
			and last["good"] == good and int(last["price"]) == price and int(last["cost_each"]) == cost_each:
		last["qty"] = int(last["qty"]) + qty
		last["total"] = int(last["qty"]) * price
		return
	_push({"type": "trade", "day": day, "port": port, "side": side, "good": good, "qty": qty,
		"price": price, "total": qty * price, "cost_each": cost_each, "stay": _stay})

func open_trip(day: int, from: String, to: String, food: int, water: int) -> void:
	_stay += 1
	_push({"type": "trip", "day_start": day, "day_end": day, "from": from, "to": to, "days": 0,
		"food": food, "water": water, "wages": 0, "deserters": [], "encounter": {}, "ended": ""})
	_trip = entries.size() - 1

func current_trip() -> Dictionary:
	return entries[_trip] if _trip >= 0 and _trip < entries.size() else {}

func pirate(id: String, name: String, theirs: int, mine: int) -> void:
	var t := current_trip()
	if not t.is_empty():
		t["encounter"] = {"pirate": id, "name": name, "theirs": theirs, "mine": mine, "choice": "",
			"outcome": "", "gold": 0, "damage": 0, "ammo": 0, "lost": {}, "lost_value": 0}

func _lost(e: Dictionary, lost: Dictionary) -> void:
	e["lost"] = lost
	var value := 0
	for good in lost:
		value += _take(good, int(lost[good]))
	e["lost_value"] = value

func ran(lost: Dictionary) -> void:
	var e: Dictionary = current_trip().get("encounter", {})
	if e.is_empty():
		return
	e["choice"] = "run"
	e["outcome"] = "run"
	_lost(e, lost)

func fought(fight: Dictionary) -> void:
	var e: Dictionary = current_trip().get("encounter", {})
	if e.is_empty():
		return
	e["choice"] = "fight"
	e["outcome"] = str(fight.get("outcome", ""))
	e["mine"] = int(fight.get("total", e["mine"]))
	e["gold"] = int(fight.get("gold", 0))
	e["damage"] = int(fight.get("damage", 0))
	e["ammo"] = int(fight.get("ammo", 0))
	_lost(e, fight.get("lost", {}))

## Closes the open trip: food/water used = snapshot at departure - now.
func close_trip(day: int, days: int, food: int, water: int, wages: int, deserters: Array, ended: String = "") -> void:
	var t := current_trip()
	if t.is_empty():
		return
	t["day_end"] = day
	t["days"] = days
	t["food"] = int(t["food"]) - food
	t["water"] = int(t["water"]) - water
	t["wages"] = wages
	t["deserters"] = deserters
	t["ended"] = ended
	_trip = -1

func trips() -> int:
	var n := 0
	for e in entries:
		if e["type"] == "trip":
			n += 1
	return n

## Net result of the trip at `index`: margin on the sales made at its destination
## (before the next departure), plus loot or minus plunder, minus the cost of cargo
## lost to pirates, minus wages.
func trip_profit(index: int) -> int:
	var t: Dictionary = entries[index]
	var e: Dictionary = t["encounter"]
	var total := -int(t["wages"])
	if not e.is_empty():
		total += int(e["gold"]) - int(e["lost_value"])
	for i in range(index + 1, entries.size()):
		var row: Dictionary = entries[i]
		if row["type"] == "trip":
			break
		if row["side"] == "sell":
			total += (int(row["price"]) - int(row["cost_each"])) * int(row["qty"])
	return total
