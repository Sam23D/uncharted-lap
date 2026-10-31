extends Node
## All game state and rules. Numbers live in data/*.json; the bigger rule sets live in
## scripts/rules/ (ships, crew, combat) as pure functions over this node.

const ShipRules := preload("res://scripts/rules/ship_rules.gd")
const CrewRules := preload("res://scripts/rules/crew_rules.gd")
const CombatRules := preload("res://scripts/rules/combat_rules.gd")
const ShipLog := preload("res://scripts/ship_log.gd")
const START_MESSAGE := "Chart a course, load what the trip needs, then depart."
const ARMS := ["cannon", "musket", "sword", "powder", "shot"]

var gold: int = 60
var day: int = 1
var current_port_id: String = "madeira"
var cargo: Dictionary = {}
var food: int = 1
var water: int = 1
## Fractions of a ration already eaten (crew eat 0.5 a day); a whole unit leaves the hold at 1.0.
var food_frac: float = 0.0
var water_frac: float = 0.0

## Ship. Stats are copied from data/ships.json by _apply_ship(); tests may override them.
var ship_id: String = "sloop"
var ship_name: String = "Sloop"
var cargo_capacity: int = 10
var bunks: int = 2
var gun_ports: int = 1
var hull_max: int = 3
var hull: int = 3

## Crew aboard: [{id, name, profession, level, wage}], and each port's tavern roster.
var crew: Array = []
var rosters: Dictionary = {}
## cannon = mounted in gun ports; musket/sword carried by crew; powder/shot fill the hold.
var armory: Dictionary = {}

var ports: Dictionary = {}
var voyage: Dictionary = {}
var ships: Dictionary = {}
var crew_data: Dictionary = {}
var pirates: Dictionary = {}
## port id -> {other port id -> base days at sea}, both directions.
var routes: Dictionary = {}
## Chosen destination; "" means the nearest port from here.
var destination: String = ""
var ended: String = ""
var encounter: bool = false
var had_profitable_sale: bool = false
var last_voyage_days: int = 0
## Last departure, for the sea animation.
var last_from: String = ""
var last_to: String = ""
var met_pirate: bool = false
var pirate_id: String = ""
var last_fight: Dictionary = {}
## Rolls pirates and rosters. Tests seed it or force voyage["pirate_chance"] to 0/1.
var rng := RandomNumberGenerator.new()
var message: String = START_MESSAGE
## Ship's log of trades and trips (scripts/ship_log.gd). Cleared by reset().
var ship_log := ShipLog.new()

func _ready() -> void:
	rng.randomize()
	load_ports()

func reset() -> void:
	gold = 60
	day = 1
	current_port_id = "madeira"
	cargo = {}
	food = 1
	water = 1
	food_frac = 0.0
	water_frac = 0.0
	crew = []
	rosters = {}
	ended = ""
	encounter = false
	had_profitable_sale = false
	last_voyage_days = 0
	destination = ""
	pirate_id = ""
	last_fight = {}
	message = START_MESSAGE
	load_ports()

func _json(path: String) -> Variant:
	return JSON.parse_string(FileAccess.get_file_as_string(path))

func load_ports() -> void:
	ports = _json("res://data/ports.json")
	voyage = _json("res://data/voyage.json")
	ships = _json("res://data/ships.json")
	crew_data = _json("res://data/crew.json")
	pirates = _json("res://data/pirates.json")
	routes = {}
	for route in _json("res://data/routes.json"):
		var a := str(route["from"])
		var b := str(route["to"])
		if not routes.has(a):
			routes[a] = {}
		if not routes.has(b):
			routes[b] = {}
		routes[a][b] = int(route["days"])
		routes[b][a] = int(route["days"])
	ship_id = str(voyage["start_ship"])
	armory = voyage["start_armory"].duplicate()
	for k in armory:
		armory[k] = int(armory[k])
	_apply_ship()
	hull = hull_max
	ensure_roster(current_port_id)
	ship_log.clear(gold)
	ship_log.max_entries = int(voyage.get("log_max_entries", 200))

func _apply_ship() -> void:
	var spec: Dictionary = ships[ship_id]
	ship_name = str(spec["name"])
	cargo_capacity = int(spec["hold"])
	bunks = int(spec["bunks"])
	gun_ports = int(spec["gun_ports"])
	hull_max = int(spec["hull"])

func ship() -> Dictionary:
	return ships[ship_id]

func _refuse(text: String) -> bool:
	message = text
	return false

func _hold_full() -> bool:
	return _refuse("Hold full (%d/%d): sell, unload or get a bigger ship." % [cargo_used(), cargo_capacity])

## Port price for a service (repair_cost, hire_mult, ship_mult): the port's "services"
## override in ports.json, else the default in voyage.json.
func service(key: String, port_id: String = "") -> int:
	return int(round(service_f(key, port_id)))

func service_f(key: String, port_id: String = "") -> float:
	if port_id == "":
		port_id = current_port_id
	var overrides: Dictionary = ports.get(port_id, {}).get("services", {})
	return float(overrides.get(key, voyage[key]))

# --- Hold ---------------------------------------------------------------

## Powder and shot pack `ammo_stack` to a hold slot.
func ammo_slots(powder: int = -1, shot: int = -1) -> int:
	var stack := int(voyage["ammo_stack"])
	if powder < 0:
		powder = int(armory.get("powder", 0))
	if shot < 0:
		shot = int(armory.get("shot", 0))
	return int(ceil(powder / float(stack))) + int(ceil(shot / float(stack)))

## Food and water pack `supply_stack` units to a hold slot.
func supply_slots(f: int = -1, w: int = -1) -> int:
	var stack := float(voyage.get("supply_stack", 1))
	if f < 0:
		f = food
	if w < 0:
		w = water
	return int(ceil(f / stack)) + int(ceil(w / stack))

func cargo_used() -> int:
	var used := supply_slots() + ammo_slots()
	for amount in cargo.values():
		used += int(amount)
	return used

func free_cargo() -> int:
	return maxi(0, cargo_capacity - cargo_used())

func port() -> Dictionary:
	return ports[current_port_id]

func price(good: String, side: String) -> int:
	return int(port()["goods"][good][side])

func switch_port(port_id: String) -> void:
	if ports.has(port_id):
		current_port_id = port_id

# --- Store --------------------------------------------------------------

func buy(good: String, amount: int = 1) -> bool:
	if ended != "" or amount < 1 or not ports.has(current_port_id):
		return false
	if free_cargo() < amount:
		return _hold_full()
	var cost := price(good, "buy") * amount
	if gold < cost:
		return _refuse("Not enough gold: %d %s costs %d, you have %d." % [amount, good, cost, gold])
	gold -= cost
	cargo[good] = int(cargo.get(good, 0)) + amount
	ship_log.trade(day, current_port_id, "buy", good, amount, price(good, "buy"))
	message = "Bought %d %s for %d." % [amount, good, cost]
	return true

func sell(good: String, amount: int = 1) -> bool:
	if ended != "" or amount < 1:
		return false
	if int(cargo.get(good, 0)) < amount:
		return _refuse("No %s in the hold." % good)
	var before := gold
	gold += price(good, "sell") * amount
	cargo[good] = int(cargo[good]) - amount
	if int(cargo[good]) == 0:
		cargo.erase(good)
	if gold > before:
		had_profitable_sale = true
	ship_log.trade(day, current_port_id, "sell", good, amount, price(good, "sell"))
	message = "Sold %d %s for %d." % [amount, good, gold - before]
	return true

func load_supply(kind: String, amount: int = 1) -> bool:
	if ended != "" or amount < 1 or (kind != "food" and kind != "water"):
		return false
	var extra := supply_slots(food + (amount if kind == "food" else 0), water + (amount if kind == "water" else 0)) - supply_slots()
	if extra > free_cargo():
		return _hold_full()
	var cost := int(voyage["supply_price"]) * amount
	if gold < cost:
		return _refuse("Not enough gold for %s." % kind)
	gold -= cost
	if kind == "food":
		food += amount
	else:
		water += amount
	message = "Loaded %s. Food %d, water %d." % [kind, food, water]
	return true

## Put food or water back on the dock for a refund (voyage.json "supply_refund"), freeing hold space.
func unload_supply(kind: String, amount: int = 1) -> bool:
	if ended != "" or encounter or amount < 1 or (kind != "food" and kind != "water"):
		return false
	var have := food if kind == "food" else water
	if have < amount:
		return _refuse("No %s left to unload." % kind)
	if kind == "food":
		food -= amount
	else:
		water -= amount
	var refund := int(voyage.get("supply_refund", voyage["supply_price"])) * amount
	gold += refund
	var need := supplies_needed() if kind == "food" else water_needed()
	var left := food if kind == "food" else water
	message = "Unloaded %s for %d gold. %s %d%s" % [kind, refund, kind.capitalize(), left,
		"." if left >= need else ", trip needs %d." % need]
	return true

# --- Armory -------------------------------------------------------------

func arm_price(kind: String, port_id: String = "") -> int:
	if port_id == "":
		port_id = current_port_id
	var local: Dictionary = ports.get(port_id, {}).get("armory", {})
	return int(local.get(kind, voyage["armory_prices"][kind]))

func arm_sell_price(kind: String) -> int:
	var p := arm_price(kind)
	return mini(p, maxi(1, int(p * float(voyage["arm_sell_ratio"]))))

func arm_limit(kind: String) -> int:
	match kind:
		"cannon":
			return gun_ports
		"musket", "sword":
			return bunks
	return 999

func buy_arm(kind: String) -> bool:
	if ended != "" or encounter or not kind in ARMS:
		return false
	var have := int(armory.get(kind, 0))
	if have >= arm_limit(kind):
		if kind == "cannon":
			return _refuse("All %d gun ports full." % gun_ports)
		return _refuse("One %s per bunk: you have %d." % [kind, have])
	if kind in ["powder", "shot"]:
		var extra := ammo_slots(int(armory["powder"]) + (1 if kind == "powder" else 0), int(armory["shot"]) + (1 if kind == "shot" else 0)) - ammo_slots()
		if extra > free_cargo():
			return _hold_full()
	var cost := arm_price(kind)
	if gold < cost:
		return _refuse("Not enough gold: a %s costs %d." % [kind, cost])
	gold -= cost
	armory[kind] = have + 1
	message = "Bought %s for %d. %s" % [kind, cost, _arm_hint(kind)]
	return true

func _arm_hint(kind: String) -> String:
	match kind:
		"cannon":
			return "Cannons %d/%d." % [int(armory["cannon"]), gun_ports]
		"musket":
			return "Marksmen need it."
		"sword":
			return "Swordsmen need it."
	return "Powder %d, shot %d." % [int(armory["powder"]), int(armory["shot"])]

func sell_arm(kind: String) -> bool:
	if ended != "" or encounter or not kind in ARMS:
		return false
	if int(armory.get(kind, 0)) <= 0:
		return _refuse("No %s to sell." % kind)
	armory[kind] = int(armory[kind]) - 1
	gold += arm_sell_price(kind)
	message = "Sold %s for %d." % [kind, arm_sell_price(kind)]
	return true

func fight_power() -> Dictionary:
	return CombatRules.power(self)

# --- Shipyard -----------------------------------------------------------

func ship_price(id: String, port_id: String = "") -> int:
	return ShipRules.price(ships, id, service_f("ship_mult", port_id))

func trade_in_value() -> int:
	return ShipRules.trade_in_value(ships, ship_id, float(voyage["trade_in"]))

func ship_net_price(id: String) -> int:
	return ShipRules.net_price(ships, ship_id, id, service_f("ship_mult"), float(voyage["trade_in"]))

func buy_ship(id: String) -> bool:
	if ended != "" or encounter:
		return false
	var why := ShipRules.refusal(self, id)
	if why != "":
		return _refuse(why)
	var cost := ship_net_price(id)
	gold -= cost
	var old_name := ship_name
	ship_id = id
	_apply_ship()
	hull = hull_max
	var sold := 0
	while int(armory["cannon"]) > gun_ports:
		armory["cannon"] = int(armory["cannon"]) - 1
		sold += 1
		gold += arm_sell_price("cannon")
	message = "Traded the %s for a %s: %dg.%s" % [old_name, ship_name, cost,
		" Sold %d extra cannon." % sold if sold > 0 else ""]
	if int(ship()["tier"]) >= int(voyage["win_ship_tier"]):
		ended = "win"
	return true

func repair() -> bool:
	if ended != "":
		return false
	if hull >= hull_max:
		return _refuse("Hull is already sound.")
	if gold < service("repair_cost"):
		return _refuse("Not enough gold: repair costs %d." % service("repair_cost"))
	gold -= service("repair_cost")
	hull += 1
	message = "Repaired hull to %d/%d." % [hull, hull_max]
	return true

func hull_texture() -> String:
	return str(ship()["sprite"])

# --- Tavern -------------------------------------------------------------

## Rolls a fresh roster for a port the first time, then every roster_refresh_days.
func ensure_roster(port_id: String) -> void:
	var r: Dictionary = rosters.get(port_id, {})
	if not r.is_empty() and day - int(r["day"]) < int(voyage["roster_refresh_days"]):
		return
	var tavern: Dictionary = ports[port_id].get("tavern", {"weights": {"deckhand": 1}})
	rosters[port_id] = {"day": day, "list": CrewRules.roll_roster(rng, crew_data, port_id, tavern, voyage["roster_size"], day)}

func roster() -> Array:
	ensure_roster(current_port_id)
	return rosters[current_port_id]["list"]

func crew_count() -> int:
	return crew.size()

func count(profession: String) -> int:
	return CrewRules.count(crew, profession)

func wages_per_day() -> int:
	return CrewRules.wages_per_day(crew)

func hire_fee(member: Dictionary, port_id: String = "") -> int:
	return CrewRules.hire_fee(member, int(voyage["hire_fee_days"]), service_f("hire_mult", port_id))

func hire(member_id: String) -> bool:
	if ended != "" or encounter:
		return false
	var list := roster()
	var index := -1
	for i in list.size():
		if str(list[i]["id"]) == member_id:
			index = i
	if index < 0:
		return _refuse("That sailor has left the tavern.")
	var m: Dictionary = list[index]
	if crew.size() >= bunks:
		return _refuse("Bunks full (%d/%d): dismiss someone or get a bigger ship." % [crew.size(), bunks])
	var fee := hire_fee(m)
	if gold < fee:
		return _refuse("%s asks %d to sign on. You have %d." % [str(m["name"]), fee, gold])
	gold -= fee
	crew.append(list.pop_at(index))
	message = "Hired %s (%s) for %dg, %dg a day." % [str(m["name"]), _prof_name(m), fee, int(m["wage"])]
	return true

func dismiss(member_id: String) -> bool:
	if ended != "" or encounter:
		return false
	for i in crew.size():
		if str(crew[i]["id"]) == member_id:
			var m: Dictionary = crew.pop_at(i)
			message = "%s the %s went ashore." % [str(m["name"]), _prof_name(m)]
			return true
	return _refuse("No such crew member.")

func _prof_name(m: Dictionary) -> String:
	return str(crew_data["professions"][str(m["profession"])]["name"]).to_lower()

func min_crew() -> int:
	return int(ship()["min_crew"])

# --- Voyage -------------------------------------------------------------

func food_per_day() -> float:
	return CrewRules.food_per_day(crew, crew_data)

func water_per_day() -> float:
	return CrewRules.water_per_day(crew)

func voyage_days(extra: int = 0, to: String = "") -> int:
	if to == "":
		to = destination_id()
	var days := ShipRules.days(route_days(to), int(ship()["speed"]))
	if cargo_used() * 2 < cargo_capacity:
		days = maxi(1, days - int(voyage["light_hold_bonus_days"]))
	if count("navigator") < 1:
		days += int(voyage["nav_penalty_days"])
	return days + extra

## Ports reachable from here, nearest first.
func destinations() -> Array:
	var here: Dictionary = routes.get(current_port_id, {})
	var ids := here.keys()
	ids.sort_custom(func(a, b): return int(here[a]) < int(here[b]) or (int(here[a]) == int(here[b]) and str(a) < str(b)))
	return ids

func route_days(to: String) -> int:
	return int(routes.get(current_port_id, {}).get(to, 0))

func destination_id() -> String:
	if destination != "" and routes.get(current_port_id, {}).has(destination):
		return destination
	var options := destinations()
	return str(options[0]) if not options.is_empty() else current_port_id

func set_destination(id: String) -> bool:
	if not routes.get(current_port_id, {}).has(id):
		return _refuse("No route from here to %s." % id)
	destination = id
	message = "Course set for %s: %d-%d days." % [str(ports[id]["name"]), voyage_days(0, id), voyage_days(int(voyage["run_extra_days"]), id)]
	return true

func estimate_days(running: bool, to: String = "") -> int:
	return voyage_days(int(voyage["run_extra_days"]) if running else 0, to)

## Whole food units the slower trip (running) eats, counting what's already part-eaten.
func supplies_needed(to: String = "") -> int:
	return int(floor(food_frac + estimate_days(true, to) * food_per_day() + 0.0001))

func water_needed(to: String = "") -> int:
	return int(floor(water_frac + estimate_days(true, to) * water_per_day() + 0.0001))

func depart() -> bool:
	if ended != "" or encounter:
		return false
	if crew.size() < min_crew():
		return _refuse("The %s needs %d crew to sail. You have %d." % [ship_name, min_crew(), crew.size()])
	last_from = current_port_id
	last_to = destination_id()
	ship_log.open_trip(day, last_from, last_to, food, water)
	if food <= 0 or water <= 0:
		ended = "starved"
		_close_log()
		return true
	message = ""
	last_fight = {}
	met_pirate = rng.randf() < float(voyage.get("pirate_chance", 1.0))
	if met_pirate:
		pirate_id = CombatRules.pick_pirate(rng, pirates, route_days(last_to))
		encounter = true
		ship_log.pirate(pirate_id, str(pirates[pirate_id]["name"]), int(pirates[pirate_id]["power"]), int(fight_power()["total"]))
		return true
	pirate_id = ""
	if _consume_days(voyage_days(0)):
		_arrive("Clear seas.")
	else:
		_close_log()
	return true

func resolve_run() -> void:
	if not encounter:
		return
	ship_log.ran(_drop_cargo(int(voyage["run_cargo_drop"])))
	encounter = false
	if _consume_days(voyage_days(int(voyage["run_extra_days"]))):
		_arrive("Ran from the %s and lost cargo." % str(pirates[pirate_id]["name"]).to_lower())
	else:
		_close_log()

func resolve_fight() -> void:
	if not encounter:
		return
	encounter = false
	last_fight = CombatRules.resolve(self, pirate_id)
	ship_log.fought(last_fight)
	if str(last_fight["outcome"]) == "sunk":
		ended = "sunk"
		_close_log()
		return
	var note := ""
	match str(last_fight["outcome"]):
		"clean":
			note = "Beat the %s without a scratch: +%d gold." % [str(last_fight["pirate_name"]).to_lower(), int(last_fight["gold"])]
		"win":
			note = "Beat the %s: +%d gold, hull %d/%d." % [str(last_fight["pirate_name"]).to_lower(), int(last_fight["gold"]), hull, hull_max]
		"loss":
			note = "Lost to the %s: hull %d/%d, plundered %d gold and %d cargo." % [str(last_fight["pirate_name"]).to_lower(), hull, hull_max, -int(last_fight["gold"]), int(last_fight["lost_cargo"])]
	if _consume_days(voyage_days(0)):
		_arrive(note)
	else:
		_close_log()

## Throws `amount` units overboard; returns {good: units dropped}.
func _drop_cargo(amount: int) -> Dictionary:
	var dropped := {}
	var left := amount
	while left > 0 and not cargo.is_empty():
		var key: String = str(cargo.keys()[0])
		cargo[key] = int(cargo[key]) - 1
		dropped[key] = int(dropped.get(key, 0)) + 1
		left -= 1
		if int(cargo[key]) <= 0:
			cargo.erase(key)
	return dropped

## Closes the log's open trip (arrival, or the run ended at sea).
func _close_log(paid: int = 0, deserters: Array = []) -> void:
	var t: Dictionary = ship_log.current_trip()
	var days := day - int(t.get("day_start", day))
	ship_log.close_trip(day, days, food, water, paid, deserters, ended)

## Each day the captain and crew eat; a whole ration leaves the hold every time the
## fraction reaches 1. Running out of either ends the run.
func _consume_days(count_days: int) -> bool:
	last_voyage_days = count_days
	for _i in count_days:
		food_frac += food_per_day()
		water_frac += water_per_day()
		while food_frac >= 0.9999:
			if food <= 0:
				ended = "starved"
				return false
			food -= 1
			food_frac -= 1.0
		while water_frac >= 0.9999:
			if water <= 0:
				ended = "starved"
				return false
			water -= 1
			water_frac -= 1.0
		day += 1
	return true

func _arrive(note: String) -> void:
	current_port_id = destination_id()
	destination = ""
	var pay := CrewRules.pay(self, last_voyage_days)
	_close_log(int(pay["paid"]), pay["deserters"])
	ensure_roster(current_port_id)
	message = "%s Reached %s after %d days." % [note, str(port()["name"]), last_voyage_days]
	if int(pay["paid"]) > 0:
		message += " Paid %d in wages." % int(pay["paid"])
	if not pay["deserters"].is_empty():
		message += " Unpaid, %s deserted." % ", ".join(pay["deserters"])

## Tests and debug: put a crew member aboard for free.
func sign_on(profession: String, level: int = 1) -> Dictionary:
	var m := CrewRules.make_member(crew_data, "test-%d" % crew.size(), "Test%d" % crew.size(), profession, level)
	crew.append(m)
	return m
