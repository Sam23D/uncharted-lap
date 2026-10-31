extends Control
## Title screen: a scrolling sea with ships sailing both ways behind the game's name,
## a New voyage button (starts a fresh run in the port) and the credit line.
## Built at runtime; ship sprites point down in the Kenney pack, so they are turned ±90°.

const UI := "res://assets/vendor/kenney-ui-pack-pixel-adventure/Tiles/Large tiles/Thick outline/"
const PACK := "res://assets/vendor/kenney-pirate-pack/PNG/Default size/"
const PORT_SCENE := "res://scenes/port.tscn"
const INK := Color(0.18, 0.11, 0.05)
const CREAM := Color(1.0, 0.97, 0.88)
const SHIP_SIZE := Vector2(53, 90)
## [sprite, lane y, speed px/s (negative sails left), scale, start x]. Far lanes are
## higher, smaller and slower.
const FLEET := [
	["ship (6).png", 58.0, 14.0, 0.5, 80.0],
	["ship (2).png", 92.0, -18.0, 0.6, 520.0],
	["ship (5).png", 250.0, 30.0, 0.85, 300.0],
	["ship (3).png", 300.0, -38.0, 1.0, 600.0],
	["ship (1).png", 322.0, 46.0, 1.1, -40.0],
]

var _water: TextureRect
var _ships: Array[Dictionary] = []
var _t := 0.0

func _ready() -> void:
	clip_contents = true
	_water = TextureRect.new()
	_water.texture = load(PACK + "Tiles/tile_73.png")
	_water.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_water.stretch_mode = TextureRect.STRETCH_TILE
	_water.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_water.size = Vector2(640 + 128, 360 + 128)
	_water.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_water)
	for spec in FLEET:
		_add_ship(spec)
	# Haze over the far sea so the far ships sit back and the title reads.
	var haze := ColorRect.new()
	haze.color = Color(CREAM, 0.12)
	haze.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(haze)
	haze.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	move_child(haze, 3)
	_build_title()
	_build_credit()

func _add_ship(spec: Array) -> void:
	var ship := TextureRect.new()
	ship.texture = load(PACK + "Ships/" + str(spec[0]))
	ship.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ship.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ship.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	ship.size = SHIP_SIZE * float(spec[3])
	ship.pivot_offset = ship.size / 2.0
	ship.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ship.position = Vector2(float(spec[4]), float(spec[1]) - ship.size.y / 2.0)
	add_child(ship)
	_ships.append({"node": ship, "lane": float(spec[1]), "speed": float(spec[2]), "phase": randf() * TAU})

func _build_title() -> void:
	var plate := NinePatchRect.new()
	plate.name = "Plate"
	plate.texture = load(UI + "tile_0000.png")
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		plate.set_patch_margin(side, 5)
	plate.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	plate.position = Vector2(170, 120)
	plate.size = Vector2(300, 112)
	add_child(plate)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 4)
	plate.add_child(box)
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.offset_top = 8
	box.offset_bottom = -10
	var title := _label(box, "GameName", "Uncharted Lap", 30, INK)
	title.add_theme_color_override("font_shadow_color", Color(INK, 0.25))
	title.add_theme_constant_override("shadow_offset_x", 2)
	title.add_theme_constant_override("shadow_offset_y", 2)
	_label(box, "Tagline", "Chart the seas, trade spice and gold. Win a Galleon.", 11, Color(INK, 0.7))
	var start := _button(box, "NewVoyage", "New voyage")
	start.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	start.pressed.connect(_new_voyage)
	start.call_deferred("grab_focus")

func _build_credit() -> void:
	var credit := _label(self, "Credit", "Created by s.blanc", 11, CREAM)
	credit.add_theme_color_override("font_shadow_color", Color(INK, 0.8))
	credit.add_theme_constant_override("shadow_offset_x", 1)
	credit.add_theme_constant_override("shadow_offset_y", 1)
	credit.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	credit.position = Vector2(640 - 116, 360 - 22)
	credit.size = Vector2(108, 16)
	credit.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

func _new_voyage() -> void:
	GameState.reset()
	get_tree().change_scene_to_file(PORT_SCENE)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		_new_voyage()

func _process(delta: float) -> void:
	_t += delta
	_water.position.x = -fposmod(_t * 8.0, 64.0)
	_water.position.y = -fposmod(_t * 3.0, 64.0)
	for s in _ships:
		var node: TextureRect = s["node"]
		var speed: float = s["speed"]
		var phase: float = s["phase"]
		node.position.x += speed * delta
		if speed > 0.0 and node.position.x > 660.0:
			node.position.x = -node.size.x - 20.0
		elif speed < 0.0 and node.position.x < -node.size.x - 20.0:
			node.position.x = 660.0
		var facing := -PI / 2.0 if speed > 0.0 else PI / 2.0
		node.rotation = facing + sin(_t * 1.6 + phase) * 0.05
		node.position.y = float(s["lane"]) - node.size.y / 2.0 + sin(_t * 2.2 + phase) * 2.0

func _label(parent: Node, id: String, text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.name = id
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label

func _button(parent: Node, id: String, text: String) -> Button:
	var button := Button.new()
	button.name = id
	button.flat = true
	button.custom_minimum_size = Vector2(150, 30)
	parent.add_child(button)
	var frame := NinePatchRect.new()
	frame.texture = load(UI + "tile_0033.png")
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		frame.set_patch_margin(side, 6)
	frame.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(frame)
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var label := _label(button, "Text", text, 14, INK)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return button
