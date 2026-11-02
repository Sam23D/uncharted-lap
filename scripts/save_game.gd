extends RefCounted
## Save / load of a run in port as plain JSON (one autosave slot, see GameState.save_game).
## Only state that changes during play is stored; data (ports, prices, ships...) is reloaded
## from data/*.json, so a save stays small and survives price retunes.
## On the Web build `user://` lives in the browser's IndexedDB.

const VERSION := 1
## GameState vars stored as-is (JSON-safe values).
const FIELDS := [
	"gold", "day", "current_port_id", "cargo", "food", "water", "food_frac", "water_frac",
	"ship_id", "hull", "crew", "rosters", "armory", "charted", "carto_away", "destination",
	"had_profitable_sale", "last_voyage_days", "last_from", "last_to", "message", "hint_seen",
]
const LOG_FIELDS := ["entries", "cost", "start_gold", "max_entries", "_trip", "_stay"]

static func to_dict(state: Node) -> Dictionary:
	var d := {"save_version": VERSION, "game_version": str(ProjectSettings.get_setting("application/config/version", ""))}
	for f in FIELDS:
		d[f] = state.get(f)
	var log_d := {}
	for f in LOG_FIELDS:
		log_d[f] = state.ship_log.get(f)
	d["log"] = log_d
	# 64-bit rng values don't survive JSON numbers (doubles): keep them as strings.
	d["rng_seed"] = str(state.rng.seed)
	d["rng_state"] = str(state.rng.state)
	return d

## Applies a saved dictionary onto a freshly reset GameState. Returns "" or why it refused.
static func apply(state: Node, raw: Variant) -> String:
	if typeof(raw) != TYPE_DICTIONARY:
		return "The save file is damaged."
	var d: Dictionary = _ints(raw)
	if int(d.get("save_version", 0)) > VERSION:
		return "This save is from a newer version of the game."
	if not state.ships.has(str(d.get("ship_id", ""))) or not state.ports.has(str(d.get("current_port_id", ""))):
		return "The save file doesn't match this game's data."
	for f in FIELDS:
		if d.has(f):
			state.set(f, d[f])
	var log_d: Dictionary = d.get("log", {})
	for f in LOG_FIELDS:
		if log_d.has(f):
			state.ship_log.set(f, log_d[f])
	state.rng.seed = int(str(d.get("rng_seed", "0")))
	state.rng.state = int(str(d.get("rng_state", "0")))
	state._apply_ship()
	state.rebuild_routes()
	state.ensure_roster(state.current_port_id)
	state.ended = ""
	state.encounter = false
	return ""

## JSON numbers come back as floats; whole ones become ints again so `==` and keys match.
static func _ints(v: Variant) -> Variant:
	match typeof(v):
		TYPE_FLOAT:
			return int(v) if float(v) == floor(float(v)) and absf(float(v)) < 9.0e15 else v
		TYPE_DICTIONARY:
			var out := {}
			for k in v:
				out[k] = _ints(v[k])
			return out
		TYPE_ARRAY:
			var arr: Array = []
			for x in v:
				arr.append(_ints(x))
			return arr
	return v
