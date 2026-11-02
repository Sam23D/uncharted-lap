extends Control
## Sea leg animation, built at runtime. GameState decides the outcome (on Depart,
## or on Run/Fight when a pirate shows up); this only shows it, then emits `finished`.
##
## Ship sprites point down in the Kenney pack, so they are turned -90° to sail right.

signal finished
signal _chosen(pick: String)

const UI := "res://assets/vendor/kenney-ui-pack-pixel-adventure/Tiles/Large tiles/Thick outline/"
const PACK := "res://assets/vendor/kenney-pirate-pack/PNG/Default size/"
const ITEMS := "res://assets/vendor/kenney-generic-items/PNG/Colored/"
const INK := Color(0.18, 0.11, 0.05)
const CREAM := Color(1.0, 0.97, 0.88)
const SECONDS_PER_DAY := 0.8
const LANE := 170.0
const PIRATE_LANE := 250.0
const SHIP_SIZE := Vector2(53, 90)

var playing := false
var _water: TextureRect
var _ship: TextureRect
var _pirate: TextureRect
var _boom: TextureRect
var _crate: TextureRect
var _route: Label
var _day: Label
var _status: Label
var _choice: HBoxContainer
var _hud: NinePatchRect
var _speed := 60.0
var _t := 0.0
var _shown_day := 0
## Day/night: _day_f is the fractional day (x.0 = sunrise, x.5 = sunset).
var _day_f := 0.0
var _sky: Control
var _night: ColorRect
const DUSK := Color(0.86, 0.36, 0.42, 0.26)
const NIGHT := Color(0.02, 0.04, 0.18, 0.55)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	_water = TextureRect.new()
	_water.texture = load(PACK + "Tiles/tile_73.png")
	_water.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_water.stretch_mode = TextureRect.STRETCH_TILE
	_water.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_water.size = Vector2(640 + 128, 360)
	_water.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_water)
	_crate = _sprite(ITEMS + "genericItem_color_141.png", Vector2(18, 18))
	_pirate = _sprite(PACK + "Ships/ship (2).png", SHIP_SIZE)
	_ship = _sprite("", SHIP_SIZE)
	_boom = _sprite(PACK + "Effects/explosion1.png", Vector2(52, 52))
	_night = ColorRect.new()
	_night.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_night.color = Color(0, 0, 0, 0)
	add_child(_night)
	_night.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_sky = Control.new()
	_sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_sky)
	_sky.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_sky.draw.connect(_draw_sky)
	_build_hud()
	_build_choice()

func _sprite(path: String, sz: Vector2) -> TextureRect:
	var s := TextureRect.new()
	if path != "":
		s.texture = load(path)
	s.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	s.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.size = sz
	s.pivot_offset = sz / 2.0
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	s.visible = false
	add_child(s)
	return s

func _build_hud() -> void:
	var plate := NinePatchRect.new()
	plate.texture = load(UI + "tile_0000.png")
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		plate.set_patch_margin(side, 5)
	plate.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	plate.position = Vector2(150, 8)
	plate.size = Vector2(340, 66)
	add_child(plate)
	_hud = plate
	var box := VBoxContainer.new()
	box.position = Vector2(10, 5)
	box.size = plate.size - Vector2(20, 10)
	box.add_theme_constant_override("separation", 0)
	plate.add_child(box)
	var top := HBoxContainer.new()
	box.add_child(top)
	_route = _label(top, 14, INK)
	_route.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_day = _label(top, 12, Color(INK, 0.7))
	_status = _label(box, 11, INK)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

func _label(parent: Node, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label

func _build_choice() -> void:
	_choice = HBoxContainer.new()
	_choice.position = Vector2(200, 312)
	_choice.size = Vector2(240, 30)
	_choice.add_theme_constant_override("separation", 10)
	_choice.visible = false
	add_child(_choice)
	for spec in [["Run", "run", "tile_0001.png", CREAM], ["Fight", "fight", "tile_0033.png", INK]]:
		var b := Button.new()
		b.name = str(spec[0])
		b.flat = true
		b.focus_mode = Control.FOCUS_NONE
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 30)
		_choice.add_child(b)
		var frame := NinePatchRect.new()
		frame.texture = load(UI + str(spec[2]))
		for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
			frame.set_patch_margin(side, 6)
		frame.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(frame)
		frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var text := Label.new()
		text.text = str(spec[0])
		text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		text.mouse_filter = Control.MOUSE_FILTER_IGNORE
		text.add_theme_font_size_override("font_size", 13)
		text.add_theme_color_override("font_color", spec[3])
		b.add_child(text)
		text.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		b.pressed.connect(func(): _chosen.emit(str(spec[1])))

func _process(delta: float) -> void:
	if not visible:
		return
	_t += delta
	_water.position.x -= _speed * delta
	if _water.position.x <= -64.0:
		_water.position.x += 64.0
	_bob(_ship, 0.0)
	_bob(_pirate, 1.3)

## Gentle roll and heave around the node's lane (meta "lane" = centre y).
func _bob(node: TextureRect, phase: float) -> void:
	if not node.visible or not node.has_meta("lane"):
		return
	node.rotation = -PI / 2.0 + sin(_t * 1.8 + phase) * 0.05
	node.position.y = float(node.get_meta("lane")) - node.size.y / 2.0 + sin(_t * 2.4 + phase) * 2.5

func _put(node: Control, center_x: float, lane: float) -> void:
	node.set_meta("lane", lane)
	node.position = Vector2(center_x - node.size.x / 2.0, lane - node.size.y / 2.0)
	node.modulate = Color.WHITE
	node.scale = Vector2.ONE
	node.visible = true

func _center(node: Control) -> Vector2:
	return node.position + node.size / 2.0

func _set_day(value: float) -> void:
	_day_f = value
	_shown_day = int(floor(value + 0.001))
	_day.text = "Day %d" % _shown_day
	_night.color = sky_tint(value)
	_sky.queue_redraw()

## Sea tint for a fractional day: clear by day, orange at dawn/dusk, dark blue at night.
static func sky_tint(day_f: float) -> Color:
	var s := sin(fposmod(day_f, 1.0) * TAU)
	if s > 0.0:
		var dusk := 1.0 - clampf(s * 2.0, 0.0, 1.0)
		return Color(DUSK, DUSK.a * dusk)
	return DUSK.lerp(NIGHT, clampf(-s * 2.5, 0.0, 1.0))

## Sun by day, moon by night, each on an arc from the left edge to the right.
func _draw_sky() -> void:
	var f := fposmod(_day_f, 1.0)
	var is_day := f < 0.5
	var t := (f if is_day else f - 0.5) * 2.0
	# Peaks just under the trip panel (bottom y 74) and above the ships.
	var pos := Vector2(lerpf(-20.0, 660.0, t), 140.0 - sin(t * PI) * 52.0)
	if is_day:
		_sky.draw_circle(pos, 22.0, Color(1.0, 0.85, 0.3, 0.25))
		_sky.draw_circle(pos, 13.0, Color(1.0, 0.86, 0.35))
	else:
		_sky.draw_circle(pos, 16.0, Color(0.85, 0.9, 1.0, 0.18))
		_sky.draw_circle(pos, 10.0, Color(0.92, 0.94, 1.0))
		_sky.draw_circle(pos + Vector2(4, -3), 8.0, Color(NIGHT, 0.9))

## Starts the animation for the departure GameState just made.
func play(start_day: int, est_days: int) -> void:
	playing = true
	visible = true
	_hud.visible = true
	_speed = 60.0
	_route.text = "%s  to  %s" % [_name(GameState.last_from), _name(GameState.last_to)]
	_set_day(start_day)
	_status.text = "Fair winds."
	_ship.texture = load(GameState.hull_texture())
	var scale_by := float(GameState.ship().get("scale", 1.0))
	_ship.size = SHIP_SIZE * scale_by
	_ship.pivot_offset = _ship.size / 2.0
	_put(_ship, -60.0, LANE)
	_pirate.visible = false
	_boom.visible = false
	_crate.visible = false
	_choice.visible = false
	var total := maxf(2.4, est_days * SECONDS_PER_DAY)
	if not GameState.met_pirate:
		await _leg(470.0, GameState.day, total * 0.8)
		if await _lost_at_sea():
			return
		_status.text = "Clear seas all the way."
		await _leg(720.0, GameState.day, 0.9)
		await _arrive()
		return
	await _leg(250.0, start_day + int(est_days / 2.0), total * 0.45)
	var foe: Dictionary = GameState.pirates[GameState.pirate_id]
	_pirate.texture = load(str(foe["sprite"]))
	_put(_pirate, -80.0, PIRATE_LANE)
	var p: Dictionary = GameState.fight_power()
	var theirs := int(foe["power"])
	var mine := int(p["total"])
	var verdict := "Fight to win its loot." if mine > theirs else "Fighting loses hull and cargo. Run?"
	if mine <= theirs and GameState.hull <= maxi(1, int(ceil((theirs - mine) / 2.0))):
		verdict = "Fighting will sink you. Run!"
	_status.text = "%s! Power %d vs your %d (cannons %d, muskets %d, boarding %d). %s" % [
		str(foe["name"]), theirs, mine, int(p["cannons"]), int(p["muskets"]), int(p["boarding"]), verdict]
	_speed = 20.0
	await _move(_pirate, 215.0, 1.1)
	_choice.visible = true
	var pick: String = await _chosen
	_choice.visible = false
	_speed = 60.0
	if pick == "run":
		GameState.resolve_run()
		_status.text = "All sails up! A crate goes overboard."
		_crate.position = _center(_ship) - Vector2(30, 9)
		_crate.visible = true
		var drift := create_tween().set_parallel(true)
		drift.tween_property(_crate, "position:x", -40.0, 1.6)
		drift.tween_property(_pirate, "position:x", -140.0, 1.6)
		await _leg(470.0, GameState.day, total * 0.45)
	else:
		GameState.resolve_fight()
		var f: Dictionary = GameState.last_fight
		var outcome := str(f.get("outcome", "sunk"))
		var won := outcome == "clean" or outcome == "win"
		_status.text = "Cannons roar..." if int(f.get("cannons", 0)) > 0 else "Boarding!"
		await _cannons(_pirate if won else _ship)
		match outcome:
			"sunk":
				_status.text = "Holed below the waterline."
				await _sink(_ship)
				_finish()
				return
			"loss":
				_status.text = "Plundered: -%d gold, -%d cargo, hull %d/%d." % [-int(f["gold"]), int(f["lost_cargo"]), GameState.hull, GameState.hull_max]
				var away := create_tween()
				away.tween_property(_pirate, "position:x", 700.0, 2.0)
				await _leg(470.0, GameState.day, total * 0.45)
			_:
				_status.text = "Pirate sunk! +%d gold. Hull %d/%d." % [int(f["gold"]), GameState.hull, GameState.hull_max]
				await _sink(_pirate)
				await _leg(470.0, GameState.day, total * 0.45)
	if await _lost_at_sea():
		return
	await _leg(720.0, GameState.day, 0.9)
	await _arrive()

func _name(id: String) -> String:
	return str(GameState.ports.get(id, {}).get("name", id)) if GameState.is_known(id) else "?"

## Sail the player ship to `center_x` while the day counter ticks to `to_day`.
func _leg(center_x: float, to_day: int, seconds: float) -> void:
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_ship, "position:x", center_x - _ship.size.x / 2.0, seconds).set_trans(Tween.TRANS_SINE)
	tw.tween_method(_set_day, float(_shown_day), float(maxi(to_day, _shown_day)), seconds)
	await tw.finished

func _move(node: Control, center_x: float, seconds: float) -> void:
	var tw := create_tween()
	tw.tween_property(node, "position:x", center_x - node.size.x / 2.0, seconds).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await tw.finished

func _cannons(target: Control) -> void:
	for i in 3:
		_boom.texture = load(PACK + "Effects/explosion%d.png" % (i + 1))
		_boom.position = _center(target) - _boom.size / 2.0 + Vector2(randf_range(-14, 14), randf_range(-10, 10))
		_boom.visible = true
		await get_tree().create_timer(0.22).timeout
	_boom.visible = false

func _sink(node: Control) -> void:
	var tw := create_tween().set_parallel(true)
	tw.tween_property(node, "modulate:a", 0.0, 1.2)
	tw.tween_property(node, "scale", Vector2(0.7, 0.7), 1.2)
	await tw.finished
	node.visible = false

## Starvation: the ship stops and drifts away. Returns true if the voyage ended here.
func _lost_at_sea() -> bool:
	if GameState.ended != "starved":
		return false
	_status.text = "Food and water ran out on day %d." % GameState.day
	_speed = 8.0
	await _sink(_ship)
	_finish()
	return true

func _arrive() -> void:
	_status.text = "Land ho! Arriving at %s." % _name(GameState.current_port_id)
	await get_tree().create_timer(0.6).timeout
	_finish()

## Behind the end panel: just the sea, no trip HUD or ships.
func end_backdrop() -> void:
	if playing:
		return
	_hud.visible = false
	_choice.visible = false
	_pirate.visible = false

func _finish() -> void:
	_speed = 10.0
	_set_day(GameState.day)
	# The end panel takes over from the trip HUD when the run is over.
	_hud.visible = GameState.ended == ""
	playing = false
	finished.emit()
