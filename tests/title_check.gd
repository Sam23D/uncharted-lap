extends SceneTree
## Title screen: game name, New voyage button, credit, and moving ships.

func _fail(text: String) -> void:
	push_error(text)
	quit(1)

func _initialize() -> void:
	if str(ProjectSettings.get_setting("application/run/main_scene")) != "res://scenes/title.tscn":
		return _fail("main scene should be the title screen")
	var title: Control = load("res://scenes/title.tscn").instantiate()
	root.add_child(title)
	await process_frame
	var name_label: Label = title.find_child("GameName", true, false)
	if name_label == null or name_label.text != "Uncharted Lap":
		return _fail("game name missing")
	var start := title.find_child("NewVoyage", true, false)
	if start == null or str(start.get_node("Text").text) != "New voyage":
		return _fail("New voyage button missing")
	var credit: Label = title.find_child("Credit", true, false)
	if credit == null or credit.text != "Created by s.blanc":
		return _fail("credit missing")
	var ship: Control = title._ships[0]["node"]
	var x := ship.position.x
	title._process(1.0)
	if is_equal_approx(ship.position.x, x):
		return _fail("ships should move")
	print("title check ok")
	quit(0)
