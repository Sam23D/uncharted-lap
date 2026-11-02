extends Node
## Screenshot driver for UI checks (dev only; tools/ is excluded from exports).
##   godot --path . res://tools/shots.tscn -- steps=/abs/steps.gd out=/abs/dir
## The steps file is a GDScript with `func run(d) -> void` (may await). `d` is this node:
##   d.scene(path)        change scene and wait for it
##   d.wait(sec)          let frames run
##   d.shot(name)         save <out>/<name>.png
##   d.tree               the SceneTree
var out := "user://shots"
var tree: SceneTree

func _ready() -> void:
	_start.call_deferred()

func _start() -> void:
	tree = get_tree()
	# Stay alive across change_scene: stop being the current scene.
	tree.current_scene = null
	var steps := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("steps="):
			steps = arg.substr(6)
		elif arg.begins_with("out="):
			out = arg.substr(4)
	DirAccess.make_dir_recursive_absolute(out)
	var script := GDScript.new()
	script.source_code = FileAccess.get_file_as_string(steps)
	if script.reload() != OK:
		push_error("steps script failed to compile: " + steps)
		tree.quit(1)
		return
	var runner: Object = script.new()
	await runner.run(self)
	tree.quit(0)

func scene(path: String) -> Node:
	tree.change_scene_to_file(path)
	await tree.process_frame
	await tree.process_frame
	return tree.current_scene

func wait(sec: float) -> void:
	await tree.create_timer(sec, true, false, true).timeout

func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(out.path_join(name + ".png"))
	print("saved ", name)
