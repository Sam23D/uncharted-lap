extends RefCounted
## Crew rules (data/crew.json). A member is {id, name, profession, level, wage}.

static func _weighted(rng: RandomNumberGenerator, weights: Dictionary) -> String:
	var total := 0.0
	for k in weights:
		total += float(weights[k])
	var roll := rng.randf() * total
	for k in weights:
		roll -= float(weights[k])
		if roll < 0.0:
			return str(k)
	return str(weights.keys()[-1])

static func stat(crew_data: Dictionary, member: Dictionary, key: String, fallback: Variant = 0) -> Variant:
	var spec: Dictionary = crew_data["professions"].get(str(member["profession"]), {})
	if not spec.has(key):
		return fallback
	var values: Array = spec[key]
	return values[clampi(int(member["level"]) - 1, 0, values.size() - 1)]

static func make_member(crew_data: Dictionary, id: String, name: String, profession: String, level: int) -> Dictionary:
	var m := {"id": id, "name": name, "profession": profession, "level": level}
	m["wage"] = int(stat(crew_data, m, "wage", 1))
	return m

## A fresh tavern roster for a port. Ids are "<port>-<day>-<n>" so they never repeat.
static func roll_roster(rng: RandomNumberGenerator, crew_data: Dictionary, port_id: String, tavern: Dictionary, size_range: Array, day: int) -> Array:
	var size := rng.randi_range(int(size_range[0]), int(size_range[1]))
	var names: Array = crew_data["names"].duplicate()
	var out: Array = []
	var levels: Array = tavern.get("level_weights", [1])
	var level_weights := {}
	for i in levels.size():
		level_weights[str(i + 1)] = levels[i]
	for n in size:
		var prof := _weighted(rng, tavern.get("weights", {"deckhand": 1}))
		var level := int(_weighted(rng, level_weights))
		var max_level: int = crew_data["professions"][prof]["wage"].size()
		var name := str(names.pop_at(rng.randi_range(0, names.size() - 1)))
		out.append(make_member(crew_data, "%s-%d-%d" % [port_id, day, n], name, prof, mini(level, max_level)))
	return out

static func wages_per_day(crew: Array) -> int:
	var total := 0
	for m in crew:
		total += int(m["wage"])
	return total

static func hire_fee(member: Dictionary, fee_days: int, hire_mult: float) -> int:
	return maxi(1, int(round(float(member["wage"]) * fee_days * hire_mult)))

static func count(crew: Array, profession: String) -> int:
	var n := 0
	for m in crew:
		if str(m["profession"]) == profession:
			n += 1
	return n

## Food eaten per day: 1 for the captain + 0.5 per crew, x the best cook's multiplier.
static func food_per_day(crew: Array, crew_data: Dictionary) -> float:
	var mult := 1.0
	for m in crew:
		if str(m["profession"]) == "cook":
			mult = minf(mult, float(stat(crew_data, m, "food_mult", 1.0)))
	return water_per_day(crew) * mult

static func water_per_day(crew: Array) -> float:
	return 1.0 + 0.5 * crew.size()

## Pays `days` of wages from gold. Unpaid crew desert, highest wage first.
## Returns {"paid": int, "deserters": Array[String]} and edits state.crew/gold.
static func pay(state: Node, days: int) -> Dictionary:
	var deserters: Array = []
	var owed := wages_per_day(state.crew) * days
	while owed > state.gold and not state.crew.is_empty():
		var worst := 0
		for i in state.crew.size():
			if int(state.crew[i]["wage"]) > int(state.crew[worst]["wage"]):
				worst = i
		var gone: Dictionary = state.crew.pop_at(worst)
		deserters.append(str(gone["name"]))
		owed -= int(gone["wage"]) * days
	state.gold -= owed
	return {"paid": owed, "deserters": deserters}
