extends CanvasLayer
## Esc menu over the port, chart, log and sea: Resume, Ship's log, Back to title, Quit.
## Pauses the tree while open (the sea animation stops). The run is autosaved in port,
## so Back to title loses nothing that Continue can't bring back. Quit is hidden on the Web.

signal log_requested

const UI := "res://assets/vendor/kenney-ui-pack-pixel-adventure/Tiles/Large tiles/Thick outline/"
const TITLE_SCENE := "res://scenes/title.tscn"
const INK := Color(0.18, 0.11, 0.05)
const CREAM := Color(1.0, 0.97, 0.88)

var _root: Control

func _ready() -> void:
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.name = "Menu"
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.visible = false
	add_child(_root)
	var dim := ColorRect.new()
	dim.color = Color(INK, 0.55)
	_root.add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var plate := NinePatchRect.new()
	plate.texture = load(UI + "tile_0000.png")
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		plate.set_patch_margin(side, 5)
	plate.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	plate.position = Vector2(220, 82)
	plate.size = Vector2(200, 196)
	_root.add_child(plate)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 6)
	plate.add_child(box)
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var title := Label.new()
	title.text = "Paused"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", INK)
	box.add_child(title)
	_button(box, "Resume", "Resume", close)
	_button(box, "MenuLog", "Ship's log", _log)
	_button(box, "ToTitle", "Back to title", _to_title)
	if not OS.has_feature("web"):
		_button(box, "Quit", "Quit", _quit)
	else:
		plate.size.y -= 36
		plate.position.y += 18
	var note := Label.new()
	note.text = "Your voyage is saved in every port."
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.add_theme_font_size_override("font_size", 10)
	note.add_theme_color_override("font_color", Color(INK, 0.6))
	box.add_child(note)

func is_open() -> bool:
	return _root.visible

func open() -> void:
	_root.visible = true
	get_tree().paused = true
	var resume := _root.find_child("Resume", true, false) as Control
	if resume != null:
		resume.grab_focus()

func close() -> void:
	_root.visible = false
	get_tree().paused = false

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		if is_open():
			close()
		else:
			open()
		get_viewport().set_input_as_handled()

func _log() -> void:
	close()
	log_requested.emit()

func _to_title() -> void:
	GameState.save_game()
	close()
	get_tree().change_scene_to_file(TITLE_SCENE)

func _quit() -> void:
	GameState.save_game()
	get_tree().quit()

func _button(parent: Node, id: String, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.name = id
	button.flat = true
	button.custom_minimum_size = Vector2(150, 28)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	parent.add_child(button)
	var frame := NinePatchRect.new()
	frame.texture = load(UI + "tile_0033.png")
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
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", INK)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(label)
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	button.pressed.connect(action)
	return button
