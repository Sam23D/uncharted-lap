extends RefCounted
## Pirate fights (data/pirates.json). Power is added in order while ammo lasts:
## cannons (cannon_power each, 1 powder + 1 shot), marksmen (musket + ammo, else fists),
## then boarding (swordsmen with a sword, else fists; deckhands 1).
const CrewRules := preload("res://scripts/rules/crew_rules.gd")

## Pirates that sail this route: long enough, and in its chart's region ("regions" empty = anywhere).
static func pick_pirate(rng: RandomNumberGenerator, pirates: Dictionary, route_days: int, region: String = "known") -> String:
	var total := 0.0
	var options: Array = []
	for id in pirates:
		var regions: Array = pirates[id].get("regions", [])
		if int(pirates[id]["min_days"]) <= route_days and (regions.is_empty() or region in regions):
			options.append(id)
			total += float(pirates[id]["weight"])
	if options.is_empty():
		return str(pirates.keys()[0])
	var roll := rng.randf() * total
	for id in options:
		roll -= float(pirates[id]["weight"])
		if roll < 0.0:
			return str(id)
	return str(options[-1])

## Power breakdown for the ship as it stands. Reads only; `ammo` is what a fight would use.
static func power(state: Node) -> Dictionary:
	var powder := int(state.armory.get("powder", 0))
	var shot := int(state.armory.get("shot", 0))
	var used := 0
	var cannons := 0
	for _i in int(state.armory.get("cannon", 0)):
		if powder - used > 0 and shot - used > 0:
			cannons += int(state.voyage["cannon_power"])
			used += 1
	var muskets := 0
	var boarding := 0
	var muskets_left := int(state.armory.get("musket", 0))
	var swords_left := int(state.armory.get("sword", 0))
	var crew: Array = state.crew.duplicate()
	crew.sort_custom(func(a, b): return int(a["level"]) > int(b["level"]))
	for m in crew:
		var prof := str(m["profession"])
		if prof == "marksman":
			if muskets_left > 0 and powder - used > 0 and shot - used > 0:
				muskets += int(CrewRules.stat(state.crew_data, m, "armed_fight", 1))
				muskets_left -= 1
				used += 1
			else:
				muskets += int(CrewRules.stat(state.crew_data, m, "fight", 0))
		elif prof == "swordsman" and swords_left > 0:
			boarding += int(CrewRules.stat(state.crew_data, m, "armed_fight", 1))
			swords_left -= 1
		else:
			boarding += int(CrewRules.stat(state.crew_data, m, "fight", 0))
	return {"cannons": cannons, "muskets": muskets, "boarding": boarding,
		"total": cannons + muskets + boarding, "ammo": used}

## Fights `pirate_id`: uses ammo, applies loot or damage and plunder. Returns the breakdown
## plus "outcome" (clean, win, loss, sunk), "gold" (+loot or -plunder), "damage", "lost_cargo".
static func resolve(state: Node, pirate_id: String) -> Dictionary:
	var pirate: Dictionary = state.pirates[pirate_id]
	var fight := power(state)
	state.armory["powder"] = int(state.armory["powder"]) - int(fight["ammo"])
	state.armory["shot"] = int(state.armory["shot"]) - int(fight["ammo"])
	var theirs := int(pirate["power"])
	var mine := int(fight["total"])
	fight["pirate"] = theirs
	fight["pirate_name"] = str(pirate["name"])
	fight["damage"] = 0
	fight["lost_cargo"] = 0
	fight["lost"] = {}
	if mine > theirs:
		fight["outcome"] = "clean" if mine >= theirs * float(state.voyage["clean_win_ratio"]) else "win"
		fight["gold"] = int(pirate["loot"])
		state.gold += int(pirate["loot"])
		if fight["outcome"] == "win":
			fight["damage"] = int(state.voyage["hull_chip"])
	else:
		fight["outcome"] = "loss"
		fight["damage"] = maxi(1, int(ceil((theirs - mine) / 2.0)))
		var taken := int(state.gold * float(state.voyage["plunder_gold"]))
		state.gold -= taken
		fight["gold"] = -taken
		for good in state.cargo.keys():
			var lose := int(int(state.cargo[good]) * float(state.voyage["plunder_cargo"]))
			fight["lost_cargo"] += lose
			if lose > 0:
				fight["lost"][good] = lose
			state.cargo[good] = int(state.cargo[good]) - lose
			if int(state.cargo[good]) <= 0:
				state.cargo.erase(good)
	state.hull -= int(fight["damage"])
	if state.hull <= 0:
		state.hull = 0
		fight["outcome"] = "sunk"
	return fight
