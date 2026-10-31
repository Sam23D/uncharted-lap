extends Control
## Ship's log viewer, built at runtime from GameState.ship_log (scripts/ship_log.gd).
## Newest first, grouped by leg: the trip (provisions, encounter), then the trades made
## at its destination. Emits `closed` when the player goes back.

signal closed

const UI := "res://assets/vendor/kenney-ui-pack-pixel-adventure/Tiles/Large tiles/Thick outline/"
const INK := Color(0.18, 0.11, 0.05)
const CREAM := Color(1.0, 0.97, 0.88)
const WARN := Color(0.7, 0.1, 0.06)
const GOOD := Color(0.1, 0.42, 0.14)
const MUTED := Color(0.18, 0.11, 0.05, 0.6)
const GRAY := Color(0.42, 0.42, 0.42, 0.75)

var _list: VBoxContainer

func open() -> void:
	visible = true
	_rebuild()

func close() -> void:
	visible = false
	closed.emit()

func _rebuild() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	var panel := NinePatchRect.new()
	panel.texture = load(UI + "tile_0000.png")
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		panel.set_patch_margin(side, 5)
	panel.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 8
	panel.offset_top = 8
	panel.offset_right = -8
	panel.offset_bottom = -8
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	panel.add_child(box)
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 14
	box.offset_top = 10
	box.offset_right = -14
	box.offset_bottom = -10

	var log: RefCounted = GameState.ship_log
	var head := HBoxContainer.new()
	box.add_child(head)
	var title := _text(head, "SHIP'S LOG", 15, INK)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var change: int = GameState.gold - int(log.start_gold)
	_text(head, "gold %d → %d (%s) · %d trips" % [int(log.start_gold), GameState.gold, _signed(change), log.trips()], 12, GOOD if change >= 0 else WARN)
	var rule := ColorRect.new()
	rule.color = Color(INK, 0.25)
	rule.custom_minimum_size = Vector2(0, 1)
	box.add_child(rule)

	var scroll := ScrollContainer.new()
	scroll.name = "Scroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	_list = VBoxContainer.new()
	_list.name = "Entries"
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 0)
	scroll.add_child(_list)
	_fill(log)

	var back := _plate(box, "Back")
	back.size_flags_horizontal = Control.SIZE_SHRINK_END
	back.custom_minimum_size = Vector2(110, 26)
	back.pressed.connect(close)

## Newest first, split by a gray dotted "Day N" divider whenever the day changes.
## A trip sits under the day it left port; trades under the day they were made.
func _fill(log: RefCounted) -> void:
	var entries: Array = log.entries
	if entries.is_empty():
		_line("No trips yet. Trades and voyages will be recorded here.", MUTED, 0)
		return
	var last_day := -1
	var last_port := ""
	for i in range(entries.size() - 1, -1, -1):
		var e: Dictionary = entries[i]
		var d: int = int(e["day_start"]) if e["type"] == "trip" else int(e["day"])
		if d != last_day:
			_divider(d)
			last_day = d
			last_port = ""
		if e["type"] == "trip":
			_trip(e, log.trip_profit(i))
			last_port = ""
			continue
		if e["type"] == "chart":
			_line("Charted %s: %s" % [str(e["name"]), ", ".join(e["ports"])], GOOD, 0, 12)
			continue
		if str(e["port"]) != last_port:
			last_port = str(e["port"])
			_line("At %s" % _port(last_port), INK, 0, 12)
		_trade(e)

func _divider(day: int) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	_list.add_child(row)
	_text(row, "Day %d" % day, 10, GRAY)
	var line := Control.new()
	line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.custom_minimum_size = Vector2(0, 14)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.draw.connect(func() -> void:
		var y := floorf(line.size.y / 2.0) + 0.5
		line.draw_dashed_line(Vector2(0, y), Vector2(line.size.x, y), GRAY, 1.0, 3.0))
	row.add_child(line)

func _trip(t: Dictionary, profit: int) -> void:
	var row := HBoxContainer.new()
	_list.add_child(row)
	var days := int(t["days"])
	var head := _text(row, "%s → %s · %d day%s" % [_port(str(t["from"])), _port(str(t["to"])), days, "" if days == 1 else "s"], 12, INK)
	head.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if str(t["ended"]) == "" and profit != 0:
		var net := _text(row, "%s trip" % _signed(profit, "g"), 12, GOOD if profit > 0 else WARN)
		net.tooltip_text = "Sale margins at the destination, plus loot or minus plunder and lost cargo, minus wages."
		net.mouse_filter = Control.MOUSE_FILTER_PASS
	var food := "Ate %d food · drank %d water" % [int(t["food"]), int(t["water"])]
	if int(t["wages"]) > 0:
		food += " · wages %dg" % int(t["wages"])
	if not t["deserters"].is_empty():
		food += " · %s deserted" % ", ".join(t["deserters"])
	_line(food, MUTED, 1)
	var e: Dictionary = t["encounter"]
	if e.is_empty():
		if str(t["ended"]) == "":
			_line("Clear seas", MUTED, 1)
	else:
		var text := "⚔ %s (%d vs %d): " % [str(e["name"]), int(e["theirs"]), int(e["mine"])]
		var color := INK
		match str(e["outcome"]):
			"run":
				text += "ran · dropped %s" % _goods(e["lost"])
				if int(e["lost_value"]) > 0:
					text += " (−%dg)" % int(e["lost_value"])
				color = WARN if not e["lost"].is_empty() else INK
			"clean":
				text += "won clean · +%dg · used %d ammo" % [int(e["gold"]), int(e["ammo"])]
				color = GOOD
			"win":
				text += "won · +%dg · hull −%d · used %d ammo" % [int(e["gold"]), int(e["damage"]), int(e["ammo"])]
				color = GOOD
			"loss":
				text += "lost · −%dg plundered" % -int(e["gold"])
				if not e["lost"].is_empty():
					text += " · −%s" % _goods(e["lost"])
				text += " · hull −%d" % int(e["damage"])
				color = WARN
			"sunk":
				text += "fought · sunk"
				color = WARN
			_:
				text += "still in sight"
		_line(text, color, 1)
	match str(t["ended"]):
		"starved":
			_line("Starved on day %d" % int(t["day_end"]), WARN, 1)
		"sunk":
			_line("Sunk on day %d" % int(t["day_end"]), WARN, 1)

func _trade(t: Dictionary) -> void:
	var qty := int(t["qty"])
	var text := ""
	var color := INK
	if t["side"] == "buy":
		text = "Bought %d %s @ %d = −%dg" % [qty, GameState.good_name(str(t["good"])), int(t["price"]), int(t["total"])]
	else:
		var margin := int(t["price"]) - int(t["cost_each"])
		var each := " (%s each)" % _signed(margin) if int(t["cost_each"]) > 0 else ""
		text = "Sold %d %s @ %d%s = +%dg" % [qty, GameState.good_name(str(t["good"])), int(t["price"]), each, int(t["total"])]
		if int(t["cost_each"]) > 0:
			color = GOOD if margin > 0 else WARN
	_line(text, color, 1)

func _goods(lost: Dictionary) -> String:
	if lost.is_empty():
		return "nothing"
	var parts: Array[String] = []
	for good in lost:
		parts.append("%d %s" % [int(lost[good]), GameState.good_name(str(good))])
	return ", ".join(parts)

func _signed(n: int, unit: String = "") -> String:
	return ("+%d" % n if n >= 0 else "−%d" % -n) + unit

func _port(id: String) -> String:
	return str(GameState.ports.get(id, {}).get("name", id))

func _line(text: String, color: Color, indent: int, font_size: int = 11) -> void:
	var label := _text(_list, ("    " if indent > 0 else "") + text, font_size, color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

func _text(parent: Node, text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label

func _plate(parent: Node, text: String) -> Button:
	var button := Button.new()
	button.name = text
	button.flat = true
	button.focus_mode = Control.FOCUS_NONE
	parent.add_child(button)
	var frame := NinePatchRect.new()
	frame.texture = load(UI + "tile_0001.png")
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		frame.set_patch_margin(side, 6)
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
	label.add_theme_color_override("font_color", CREAM)
	button.add_child(label)
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return button
