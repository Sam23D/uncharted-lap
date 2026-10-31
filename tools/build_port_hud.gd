@tool
extends RefCounted
## Rebuilds the port HUD under Panel: an always-visible trip overview on the left,
## and Store / Tavern / Shipyard / Armory tabs on the right. Tavern rosters and ships
## for sale are lists that port_screen.gd fills at runtime (RosterList, CrewList, ShipList).
## Run in the editor with scenes/port.tscn open, then save the scene:
##   load("res://tools/build_port_hud.gd").new().build(EditorInterface.get_edited_scene_root())
## port_screen.gd finds rows and buttons by name, so keep the names stable.

const UI := "res://assets/vendor/kenney-ui-pack-pixel-adventure/Tiles/Large tiles/Thick outline/"
const ITEMS := "res://assets/vendor/kenney-generic-items/PNG/Colored/"
const PIRATE := "res://assets/vendor/kenney-pirate-pack/PNG/Default size/"
const INK := Color(0.18, 0.11, 0.05)
const CREAM := Color(1.0, 0.97, 0.88)
# Full-frame 9-patch plates from the Kenney pixel UI pack (32x32, ~6px border).
const WOOD := "tile_0001.png"
const TAB_ON := "tile_0002.png"
const TAB_OFF := "tile_0003.png"
const DEPART := "tile_0033.png"

var root: Node

func build(scene_root: Node) -> String:
	root = scene_root
	var panel: Control = root.get_node("Panel")
	for old in ["Columns", "Message", "Layout"]:
		var node := panel.get_node_or_null(old)
		if node != null:
			node.free()

	var layout: HBoxContainer = _add(panel, HBoxContainer.new(), "Layout")
	layout.set_anchors_preset(Control.PRESET_FULL_RECT)
	layout.offset_left = 12
	layout.offset_top = 10
	layout.offset_right = -12
	layout.offset_bottom = -10
	layout.add_theme_constant_override("separation", 10)

	# Left: the trip at a glance, grouped so each number has a home, plus the buttons that leave port.
	var overview: VBoxContainer = _add(layout, VBoxContainer.new(), "Overview")
	overview.custom_minimum_size = Vector2(220, 0)
	overview.add_theme_constant_override("separation", 1)
	var top: HBoxContainer = _add(overview, HBoxContainer.new(), "PortRow")
	top.add_theme_constant_override("separation", 4)
	_icon(top, "PortFlag", "", 18)
	_label(top, "Port", "-", 15, INK)
	var push: Control = _add(top, Control.new(), "Push")
	push.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_icon(top, "GoldIcon", ITEMS + "genericItem_color_159.png", 14)
	_label(top, "Gold", "-", 12, INK)
	_label(top, "Day", "-", 12, Color(INK, 0.65))

	_section(overview, "Voyage")
	_row(overview, "To", "To", "")
	_section(overview, "Provisions")
	_row(overview, "Food", "Food", ITEMS + "genericItem_color_114.png")
	_row(overview, "Water", "Water", ITEMS + "genericItem_color_118.png")
	_section(overview, "Cargo")
	_row(overview, "Cargo", "Hold", ITEMS + "genericItem_color_141.png")
	_row(overview, "Goods", "Goods", ITEMS + "genericItem_color_143.png")
	_section(overview, "Crew")
	_row(overview, "Aboard", "Aboard", ITEMS + "genericItem_color_119.png")
	_row(overview, "Roles", "Roles", ITEMS + "genericItem_color_162.png")
	_section(overview, "Ship")
	_row(overview, "Ship", "Ship", PIRATE + "Ships/ship (1).png")
	_row(overview, "Hull", "Hull", PIRATE + "Ship parts/wood (1).png")
	_row(overview, "Arms", "Power", PIRATE + "Ship parts/cannon.png")
	var spacer: Control = _add(overview, Control.new(), "Spacer")
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var leave: HBoxContainer = _add(overview, HBoxContainer.new(), "Leave")
	leave.add_theme_constant_override("separation", 6)
	for spec in [["OpenLog", "Log", WOOD, CREAM], ["ChartCourse", "Chart", WOOD, CREAM], ["Depart", "Depart", DEPART, INK]]:
		var b := _button(leave, str(spec[0]), str(spec[1]), str(spec[2]), spec[3])
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var line: ColorRect = _add(layout, ColorRect.new(), "Divider")
	line.custom_minimum_size = Vector2(1, 0)
	line.color = Color(INK, 0.25)

	# Right: one tab open at a time.
	var right: VBoxContainer = _add(layout, VBoxContainer.new(), "Right")
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 6)
	var tabs: HBoxContainer = _add(right, HBoxContainer.new(), "Tabs")
	tabs.add_theme_constant_override("separation", 4)
	for tab in ["Store", "Tavern", "Shipyard", "Armory"]:
		var tab_button := _button(tabs, "Tab" + tab, tab, TAB_ON if tab == "Store" else TAB_OFF, INK if tab == "Store" else CREAM)
		tab_button.custom_minimum_size = Vector2(0, 26)
		tab_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var pages: Control = _add(right, Control.new(), "Pages")
	pages.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var store := _page(pages, "Store", "-")
	# Section names are prefixed so they don't collide with the Voyage column's sections.
	_section(store, "Provisions", "StoreProvisions")
	_info_badge(store.get_node("StoreProvisionsSection"), "supply", false)
	_trade_row(store, "SupplyFood", "Food", ITEMS + "genericItem_color_114.png", [["LoadFood", "Load"], ["UnloadFood", "Unload"]])
	_trade_row(store, "SupplyWater", "Water", ITEMS + "genericItem_color_118.png", [["LoadWater", "Load"], ["UnloadWater", "Unload"]])
	# Goods are a runtime list (port_screen.gd): what this port makes, plus what's in the hold,
	# grouped by category (data/goods.json).
	_section(store, "Cargo", "StoreCargo")
	_info_badge(store.get_node("StoreCargoSection"), "market", false)
	var goods_scroll: ScrollContainer = _add(store, ScrollContainer.new(), "GoodsScroll")
	goods_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	goods_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var goods_list: VBoxContainer = _add(goods_scroll, VBoxContainer.new(), "GoodsList")
	goods_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	goods_list.add_theme_constant_override("separation", 1)

	var tavern := _page(pages, "Tavern", "-")
	# Cartographers (port_screen.gd fills CartoList; the section hides when nobody offers a chart).
	_section(tavern, "Cartographer", "TavernCarto")
	var carto: VBoxContainer = _add(tavern, VBoxContainer.new(), "CartoList")
	carto.add_theme_constant_override("separation", 2)
	_section(tavern, "In port", "TavernRoster")
	_info_badge(tavern.get_node("TavernRosterSection"), "crew", false)
	var roster: VBoxContainer = _add(tavern, VBoxContainer.new(), "RosterList")
	roster.add_theme_constant_override("separation", 2)
	_section(tavern, "Aboard", "TavernAboard")
	var crew_scroll: ScrollContainer = _add(tavern, ScrollContainer.new(), "CrewScroll")
	crew_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	crew_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var crew_list: VBoxContainer = _add(crew_scroll, VBoxContainer.new(), "CrewList")
	crew_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	crew_list.add_theme_constant_override("separation", 2)

	var yard := _page(pages, "Shipyard", "-")
	_trade_row(yard, "YardShip", "Ship", PIRATE + "Ships/ship (1).png", [])
	_info_badge(yard.get_node("YardShipRow"), "ship", false)
	_trade_row(yard, "YardHull", "Hull", PIRATE + "Ship parts/wood (1).png", [["Repair", "Repair"]])
	_trade_row(yard, "Cannon", "Cannons", PIRATE + "Ship parts/cannon.png", [["BuyCannon", "Buy"], ["SellCannon", "Sell"]])
	_section(yard, "For sale", "YardSale")
	var ships: VBoxContainer = _add(yard, VBoxContainer.new(), "ShipList")
	ships.add_theme_constant_override("separation", 2)

	var armory := _page(pages, "Armory", "-")
	_section(armory, "Weapons", "ArmoryWeapons")
	_info_badge(armory.get_node("ArmoryWeaponsSection"), "power", false)
	_trade_row(armory, "Musket", "Musket", ITEMS + "genericItem_color_001.png", [["BuyMusket", "Buy"], ["SellMusket", "Sell"]])
	_trade_row(armory, "Sword", "Sword", ITEMS + "genericItem_color_134.png", [["BuySword", "Buy"], ["SellSword", "Sell"]])
	_section(armory, "Ammunition", "ArmoryAmmo")
	_info_badge(armory.get_node("ArmoryAmmoSection"), "ammo", false)
	_trade_row(armory, "Powder", "Powder", ITEMS + "genericItem_color_104.png", [["BuyPowder", "Buy"], ["SellPowder", "Sell"]])
	_trade_row(armory, "Shot", "Shot", PIRATE + "Ship parts/cannonBall.png", [["BuyShot", "Buy"], ["SellShot", "Sell"]])

	var message: Label = _add(right, Label.new(), "Message")
	message.custom_minimum_size = Vector2(0, 32)
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	message.add_theme_color_override("font_color", Color(0.55, 0.12, 0.08))
	message.add_theme_font_size_override("font_size", 12)
	# The end screen uses the same plates. The old static Sail/Encounter nodes are
	# replaced by SeaView (scripts/sea_view.gd), which builds its own sprites and Run/Fight.
	for old_sea in ["Sail", "Encounter"]:
		var stale := root.get_node_or_null(old_sea)
		if stale != null:
			stale.free()
	for spec in [["End/Box/NewVoyage", WOOD, CREAM]]:
		var other := root.get_node_or_null(str(spec[0]))
		if other != null:
			restyle(other, str(spec[1]), spec[2])
	var sea := root.get_node_or_null("SeaView")
	if sea == null:
		sea = _add(root, Control.new(), "SeaView")
	root.move_child(sea, 0)
	sea.set_script(load("res://scripts/sea_view.gd"))
	sea.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sea.visible = false
	# The chart is built at runtime from data (scripts/map_view.gd); the scene only holds the node.
	var map := root.get_node_or_null("Map")
	if map == null:
		map = _add(root, Control.new(), "Map")
		root.move_child(map, panel.get_index() + 1)
	map.set_script(load("res://scripts/map_view.gd"))
	map.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	map.visible = false
	# Ship's log viewer (scripts/log_view.gd), drawn over everything else when open.
	var log_view := root.get_node_or_null("Log")
	if log_view == null:
		log_view = _add(root, Control.new(), "Log")
	root.move_child(log_view, root.get_child_count() - 1)
	log_view.set_script(load("res://scripts/log_view.gd"))
	log_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	log_view.visible = false
	# End panel: a Log button under New voyage, so a lost run can be read back.
	var end_box := root.get_node_or_null("End/Box")
	if end_box != null:
		var stale_log := end_box.find_child("EndLog", true, false)
		if stale_log != null:
			stale_log.free()
		var buttons: HBoxContainer = end_box.get_node_or_null("Buttons")
		if buttons == null:
			buttons = _add(end_box, HBoxContainer.new(), "Buttons")
		buttons.alignment = BoxContainer.ALIGNMENT_CENTER
		buttons.add_theme_constant_override("separation", 8)
		var again: Control = end_box.find_child("NewVoyage", true, false)
		if again.get_parent() != buttons:
			again.reparent(buttons)
			_own(again)
		var end_log := _button(buttons, "EndLog", "Ship's log", WOOD, CREAM)
		# Tall enough for icon, title, a 3-line reason, day, gold and the buttons.
		var end_panel: Control = root.get_node("End")
		end_panel.offset_top = -140
		end_panel.offset_bottom = 140
		end_panel.offset_left = -180
		end_panel.offset_right = 180
		for b in [again, end_log]:
			b.custom_minimum_size = Vector2(130, 28)
			b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	# Hover panel for the info badges. port_screen.gd fills the text from data.
	var old_popup := root.get_node_or_null("InfoPopup")
	if old_popup != null:
		old_popup.free()
	var popup: PanelContainer = _add(root, PanelContainer.new(), "InfoPopup")
	var style := StyleBoxTexture.new()
	style.texture = load(UI + "tile_0000.png")
	style.texture_margin_left = 5
	style.texture_margin_top = 5
	style.texture_margin_right = 5
	style.texture_margin_bottom = 5
	style.content_margin_left = 10
	style.content_margin_top = 8
	style.content_margin_right = 10
	style.content_margin_bottom = 8
	popup.add_theme_stylebox_override("panel", style)
	popup.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	popup.mouse_filter = Control.MOUSE_FILTER_IGNORE
	popup.visible = false
	var popup_text := _label(popup, "Text", "", 11, INK)
	popup_text.custom_minimum_size = Vector2(250, 0)
	popup_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	popup_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return "port hud built"

## Round "i" badge. Hovering it shows InfoPopup with the text for `key`
## (see port_screen.gd _info_text). Inside a button it pins to the right edge.
func _info_badge(parent: Control, key: String, pin_right: bool) -> void:
	var badge: Control = _add(parent, Control.new(), "Info")
	badge.custom_minimum_size = Vector2(18, 18)
	badge.mouse_filter = Control.MOUSE_FILTER_STOP
	badge.mouse_default_cursor_shape = Control.CURSOR_HELP
	badge.set_meta("info", key)
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	badge.add_to_group("info_badge", true)
	if pin_right:
		badge.anchor_left = 1.0
		badge.anchor_right = 1.0
		badge.anchor_top = 0.5
		badge.anchor_bottom = 0.5
		badge.offset_left = -23
		badge.offset_right = -5
		badge.offset_top = -9
		badge.offset_bottom = 9
	var circle: TextureRect = _add(badge, TextureRect.new(), "Circle")
	circle.texture = load(UI + "tile_0041.png")
	circle.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	circle.stretch_mode = TextureRect.STRETCH_SCALE
	circle.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	circle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	circle.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var glyph := _label(badge, "Glyph", "i", 12, INK)
	glyph.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	glyph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	glyph.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE

## Swap a button's background for a 9-patch plate and recolor its Text label.
func restyle(button: Button, tile: String, text_color: Color) -> void:
	for old in ["Slices", "Frame"]:
		var node := button.get_node_or_null(old)
		if node != null:
			node.free()
	var frame: NinePatchRect = _add(button, NinePatchRect.new(), "Frame")
	button.move_child(frame, 0)
	frame.texture = load(UI + tile)
	frame.patch_margin_left = 6
	frame.patch_margin_top = 6
	frame.patch_margin_right = 6
	frame.patch_margin_bottom = 6
	frame.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var text_label := button.get_node_or_null("Text")
	if text_label != null:
		text_label.add_theme_color_override("font_color", text_color)

## Re-own a moved subtree so the scene saves it.
func _own(node: Node) -> void:
	node.owner = root
	for child in node.get_children():
		_own(child)

func _add(parent: Node, node: Node, id: String) -> Node:
	node.name = id
	parent.add_child(node)
	node.owner = root
	return node

func _label(parent: Node, id: String, text: String, font_size: int, color: Color) -> Label:
	var label: Label = _add(parent, Label.new(), id)
	label.text = text
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", font_size)
	return label

func _header(parent: Node, id: String, text: String) -> void:
	_label(parent, id, text, 15, INK)

## Small caps section title with a rule to the right: "PROVISIONS ———".
func _section(parent: Node, title: String, id: String = "") -> void:
	var row: HBoxContainer = _add(parent, HBoxContainer.new(), (id if id != "" else title) + "Section")
	row.add_theme_constant_override("separation", 5)
	row.custom_minimum_size = Vector2(0, 15)
	var label := _label(row, "Title", title.to_upper(), 10, Color(INK, 0.55))
	label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	var rule: ColorRect = _add(row, ColorRect.new(), "Rule")
	rule.color = Color(INK, 0.2)
	rule.custom_minimum_size = Vector2(0, 1)
	rule.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rule.size_flags_vertical = Control.SIZE_SHRINK_CENTER

func _icon(parent: Node, id: String, path: String, px: int) -> TextureRect:
	var icon: TextureRect = _add(parent, TextureRect.new(), id)
	icon.custom_minimum_size = Vector2(px, px)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if path != "":
		icon.texture = load(path)
	return icon

func _page(pages: Node, id: String, blurb: String) -> VBoxContainer:
	var page: VBoxContainer = _add(pages, VBoxContainer.new(), id)
	page.set_anchors_preset(Control.PRESET_FULL_RECT)
	page.add_theme_constant_override("separation", 2)
	var hint := _label(page, id + "Hint", blurb, 11, Color(INK, 0.7))
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return page

func _row(parent: Node, id: String, title: String, icon_path: String) -> void:
	var row: HBoxContainer = _add(parent, HBoxContainer.new(), id + "Row")
	row.add_theme_constant_override("separation", 4)
	var icon: TextureRect = _add(row, TextureRect.new(), "PortFlag" if icon_path == "flag" else "Icon")
	icon.custom_minimum_size = Vector2(16, 16)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if icon_path != "" and icon_path != "flag":
		icon.texture = load(icon_path)
	var title_label := _label(row, id + "Title", title, 12, INK)
	title_label.custom_minimum_size = Vector2(46, 0)
	title_label.add_theme_color_override("font_color", Color(INK, 0.7))
	_label(row, id, "-", 12, INK)

## One item per line: icon, name, value, then its own small buttons on the right.
func _trade_row(parent: Node, id: String, title: String, icon_path: String, buttons: Array) -> void:
	_row(parent, id, title, icon_path)
	var row: HBoxContainer = parent.get_node(id + "Row")
	row.custom_minimum_size = Vector2(0, 26)
	var value: Label = row.get_node(id)
	value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	value.add_theme_font_size_override("font_size", 11)
	value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	for spec in buttons:
		var b := _button(row, str(spec[0]), str(spec[1]), WOOD, CREAM)
		b.custom_minimum_size = Vector2(72, 24)
		(b.get_node("Text") as Label).add_theme_font_size_override("font_size", 11)
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER

func _grid(parent: Node, buttons: Array) -> void:
	var gap: Control = _add(parent, Control.new(), "Gap")
	gap.custom_minimum_size = Vector2(0, 4)
	var grid: GridContainer = _add(parent, GridContainer.new(), "Actions")
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 4)
	for spec in buttons:
		var button := _button(grid, str(spec[0]), str(spec[1]), WOOD, CREAM)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL

func _button(parent: Node, id: String, text: String, tile: String, text_color: Color) -> Button:
	var button: Button = _add(parent, Button.new(), id)
	button.flat = true
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(0, 28)
	var text_label := _label(button, "Text", text, 12, text_color)
	text_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	text_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	text_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	restyle(button, tile, text_color)
	return button
