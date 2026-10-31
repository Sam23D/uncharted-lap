extends Control
## Sea chart. Built from GameState.ports (name, flag, map position) and
## GameState.routes when opened, so new ports in data/*.json appear on their own.
## Left: the chart with routes and days. Right: destinations from here, the
## selected trip's supplies and prices, Set sail / Back to port.

signal closed
signal sail_requested

const UI := "res://assets/vendor/kenney-ui-pack-pixel-adventure/Tiles/Large tiles/Thick outline/"
const SEA := preload("res://assets/vendor/kenney-pirate-pack/PNG/Default size/Tiles/tile_73.png")
const INK := Color(0.18, 0.11, 0.05)
const CREAM := Color(1.0, 0.97, 0.88)
const WARN := Color(0.7, 0.1, 0.06)
const CHART := Rect2(8, 8, 392, 344)
const SIDE := Rect2(408, 8, 224, 344)

var selected := ""
## Port under the mouse (marker or list row); the side panel shows it instead of `selected`.
var hovered := ""
var _detail: VBoxContainer
var _tags: Control
## Routes from the hovered port.
const HOVER := Color(1.0, 0.82, 0.3)
const GOOD := Color(0.1, 0.42, 0.14)

func open() -> void:
	selected = GameState.destination_id()
	hovered = ""
	visible = true
	_rebuild()

func close() -> void:
	visible = false
	closed.emit()

func _rebuild() -> void:
	for child in get_children():
		child.queue_free()
	_build_markers()
	_build_side()
	queue_redraw()

func _point(id: String) -> Vector2:
	var m: Array = GameState.ports[id]["map"]
	return CHART.position + Vector2(float(m[0]), float(m[1])) * CHART.size

func _draw() -> void:
	draw_texture_rect(SEA, CHART, true)
	var here: String = GameState.current_port_id
	var drawn := {}
	for a in GameState.routes:
		for b in GameState.routes[a]:
			var key := [a, b] if str(a) < str(b) else [b, a]
			if drawn.has(str(key)):
				continue
			drawn[str(key)] = true
			var from_here: bool = a == here or b == here
			var to_selected: bool = from_here and (a == selected or b == selected)
			var focus := _focus()
			var from_focus: bool = a == focus or b == focus
			var color := Color(CREAM, 0.35)
			var width := 1.0
			if to_selected:
				color = WARN
				width = 3.0
			elif from_here and focus != here and (a == focus or b == focus):
				color = HOVER
				width = 3.0
			elif from_focus:
				color = HOVER if focus != here else CREAM
				width = 2.0
			draw_dashed_line(_point(a), _point(b), color, width, 6.0)
	draw_rect(CHART, INK, false, 2.0)

func _build_markers() -> void:
	var here: String = GameState.current_port_id
	var reachable: Dictionary = GameState.routes.get(here, {})
	# Day labels live in their own layer so hovering can redo them without touching the markers.
	_tags = Control.new()
	_tags.name = "Tags"
	_tags.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_tags)
	_build_tags()
	for id in GameState.ports:
		var spec: Dictionary = GameState.ports[id]
		var p := _point(id)
		var marker := Button.new()
		marker.flat = true
		marker.focus_mode = Control.FOCUS_NONE
		marker.position = p - Vector2(14, 14)
		marker.size = Vector2(28, 28)
		marker.tooltip_text = str(spec.get("blurb", ""))
		marker.disabled = not reachable.has(id)
		marker.name = "Marker_" + id
		marker.mouse_entered.connect(_hover.bind(id))
		marker.mouse_exited.connect(_unhover.bind(id))
		add_child(marker)
		var ring := NinePatchRect.new()
		ring.texture = load(UI + ("tile_0033.png" if id == selected else "tile_0001.png"))
		ring.patch_margin_left = 6
		ring.patch_margin_top = 6
		ring.patch_margin_right = 6
		ring.patch_margin_bottom = 6
		ring.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
		marker.add_child(ring)
		ring.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var flag := TextureRect.new()
		flag.texture = load(str(spec["flag"]))
		flag.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		flag.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		flag.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		flag.mouse_filter = Control.MOUSE_FILTER_IGNORE
		marker.add_child(flag)
		flag.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		flag.offset_left = 5
		flag.offset_top = 5
		flag.offset_right = -5
		flag.offset_bottom = -5
		if reachable.has(id):
			marker.pressed.connect(_select.bind(id))
		var name_tag := _tag(str(spec["name"]) + (" (you)" if id == here else ""), INK)
		name_tag.position = p + Vector2(-30, 15)
		if id == here:
			var ship := TextureRect.new()
			ship.texture = load(GameState.hull_texture())
			ship.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			ship.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			ship.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			ship.mouse_filter = Control.MOUSE_FILTER_IGNORE
			ship.size = Vector2(26, 34)
			ship.position = p + Vector2(-13, -50)
			add_child(ship)

## The port whose routes are lit: the hovered one, else where you are.
func _focus() -> String:
	return hovered if hovered != "" else GameState.current_port_id

## Day labels at the middle of each route from the focus port. From here they are trip
## estimates (fight-run, with your hold and crew); from another port, plain route days.
func _build_tags() -> void:
	if _tags == null:
		return
	for child in _tags.get_children():
		child.free()
	var here: String = GameState.current_port_id
	var focus := _focus()
	for id in GameState.routes.get(focus, {}):
		var mid := (_point(focus) + _point(id)) / 2.0
		var text := ""
		var outline := INK
		if focus == here or id == here:
			# Your own trip: estimate with your hold and crew.
			var dest: String = id if focus == here else focus
			text = "%d-%d d" % [GameState.estimate_days(false, dest), GameState.estimate_days(true, dest)]
			outline = WARN if dest == selected else INK
		else:
			text = "%d d" % int(GameState.routes[focus][id])
		var tag := _tag(text, outline, _tags)
		tag.position = mid - Vector2(30, 9)
	# Keep the chosen course labelled while another port is hovered.
	if focus != here and focus != selected and selected != "":
		var course := _tag("%d-%d d" % [GameState.estimate_days(false, selected), GameState.estimate_days(true, selected)], WARN, _tags)
		course.position = (_point(here) + _point(selected)) / 2.0 - Vector2(30, 9)

## Small cream label outlined in `outline` (ink, or red for the chosen route) so it reads on the water.
func _tag(text: String, outline: Color, parent: Node = null) -> Label:
	var label := Label.new()
	label.text = text
	label.size = Vector2(60, 18)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", CREAM)
	label.add_theme_color_override("font_outline_color", outline)
	label.add_theme_constant_override("outline_size", 5)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	(parent if parent != null else self).add_child(label)
	return label

func _build_side() -> void:
	var panel := NinePatchRect.new()
	panel.texture = load(UI + "tile_0000.png")
	panel.patch_margin_left = 5
	panel.patch_margin_top = 5
	panel.patch_margin_right = 5
	panel.patch_margin_bottom = 5
	panel.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	panel.position = SIDE.position
	panel.size = SIDE.size
	add_child(panel)
	var box := VBoxContainer.new()
	box.position = Vector2(10, 8)
	box.size = SIDE.size - Vector2(20, 16)
	box.add_theme_constant_override("separation", 3)
	panel.add_child(box)
	var here: Dictionary = GameState.port()
	_text(box, "Chart from %s" % str(here["name"]), 14, INK)
	_text(box, "Days if you fight - if you run.", 11, Color(INK, 0.7))
	for id in GameState.destinations():
		var spec: Dictionary = GameState.ports[id]
		var row := _plate(box, "%s   %d-%d days" % [str(spec["name"]), GameState.estimate_days(false, id), GameState.estimate_days(true, id)], "tile_0002.png" if id == selected else "tile_0003.png", INK if id == selected else CREAM)
		row.name = "Row_" + id
		row.pressed.connect(_select.bind(id))
		row.mouse_entered.connect(_hover.bind(id))
		row.mouse_exited.connect(_unhover.bind(id))
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 4)
	box.add_child(gap)
	_detail = VBoxContainer.new()
	_detail.name = "Detail"
	_detail.add_theme_constant_override("separation", 2)
	box.add_child(_detail)
	_fill_detail()
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(spacer)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 6)
	box.add_child(buttons)
	var back := _plate(buttons, "Back to port", "tile_0001.png", CREAM)
	back.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	back.pressed.connect(close)
	var sail := _plate(buttons, "Set sail", "tile_0033.png", INK)
	sail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sail.pressed.connect(_sail)

func _text(parent: Node, text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label

## Table cell: no autowrap (wrapping labels collapse to zero width inside a GridContainer).
func _cell(parent: Node, text: String, color: Color, font_size: int = 11, min_width: int = 30) -> Label:
	var label := _text(parent, text, font_size, color)
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.custom_minimum_size = Vector2(min_width, 0)
	return label

func _plate(parent: Node, text: String, tile: String, color: Color) -> Button:
	var button := Button.new()
	button.flat = true
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(0, 26)
	parent.add_child(button)
	var frame := NinePatchRect.new()
	frame.texture = load(UI + tile)
	frame.patch_margin_left = 6
	frame.patch_margin_top = 6
	frame.patch_margin_right = 6
	frame.patch_margin_bottom = 6
	frame.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(frame)
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", color)
	button.add_child(label)
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return button

func _hover(id: String) -> void:
	hovered = id
	_hover_changed()

func _unhover(id: String) -> void:
	if hovered == id:
		hovered = ""
		_hover_changed()

func _hover_changed() -> void:
	_fill_detail()
	_build_tags()
	queue_redraw()

## Side-panel details for the hovered port, else the chosen course. Prices sit in a
## small table with a "Profit" column: their sell price minus the buy price here.
func _fill_detail() -> void:
	if _detail == null:
		return
	for child in _detail.get_children():
		child.free()
	var id := hovered if hovered != "" else selected
	if id == "" or not GameState.ports.has(id):
		return
	var here_id: String = GameState.current_port_id
	var spec: Dictionary = GameState.ports[id]
	var title := str(spec["name"])
	if id == here_id:
		title += "  (you are here)"
	elif id == selected:
		title += "  (course set)"
	elif GameState.routes.get(here_id, {}).has(id):
		title += "  (click to pick)"
	_text(_detail, title, 13, INK)
	_text(_detail, str(spec.get("blurb", "")), 11, Color(INK, 0.75))
	if id != here_id and GameState.routes.get(here_id, {}).has(id):
		var need: int = GameState.supplies_needed(id)
		var short := GameState.food < need or GameState.water < need
		var need_w: int = GameState.water_needed(id)
		short = GameState.food < need or GameState.water < need_w
		_text(_detail, "Needs %d food, %d water (have %d, %d)" % [need, need_w, GameState.food, GameState.water], 11, WARN if short else INK)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 0)
	_detail.add_child(grid)
	for head in ["", "Buy", "Sell", "Profit"]:
		var cell := _cell(grid, head, Color(INK, 0.55), 10)
		if head == "Profit":
			cell.tooltip_text = "Their sell price minus the buy price here, per unit."
			cell.mouse_filter = Control.MOUSE_FILTER_PASS
	var here_goods: Dictionary = GameState.port()["goods"]
	var goods: Dictionary = spec["goods"]
	for good in ["sugar", "cheese"]:
		_cell(grid, good.capitalize(), INK, 11, 48)
		_cell(grid, str(int(goods[good]["buy"])), INK)
		_cell(grid, str(int(goods[good]["sell"])), INK)
		if id == here_id:
			_cell(grid, "-", Color(INK, 0.55))
		else:
			var gain := int(goods[good]["sell"]) - int(here_goods[good]["buy"])
			_cell(grid, "%+d" % gain, GOOD if gain > 0 else WARN)
	if id == here_id:
		_text(_detail, "Hover another port to compare.", 10, Color(INK, 0.55))
	var weights: Dictionary = spec.get("tavern", {}).get("weights", {})
	var lean := ""
	for prof in weights:
		if lean == "" or float(weights[prof]) > float(weights[lean]):
			lean = prof
	var yard: Array[String] = []
	for ship_id in spec.get("shipyard", []):
		yard.append(str(GameState.ships[ship_id]["name"]))
	var fees := " · half-price signing" if GameState.service_f("hire_mult", id) < 1.0 else ""
	var lean_name := str(GameState.crew_data["professions"].get(lean, {"name": "sailor"})["name"]).to_lower()
	lean_name = lean_name.replace("man", "men") if lean_name.ends_with("man") else lean_name + "s"
	_text(_detail, "Tavern: %s%s" % [lean_name, fees], 11, INK)
	_text(_detail, "Yard: %s · repair %dg" % [", ".join(yard), GameState.service("repair_cost", id)], 11, INK)

func _select(id: String) -> void:
	if GameState.set_destination(id):
		selected = id
		_rebuild()

func _sail() -> void:
	if selected != "":
		GameState.set_destination(selected)
	visible = false
	sail_requested.emit()
