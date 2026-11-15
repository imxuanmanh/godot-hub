extends Node
## Checks that an exported runtime can materialize and invoke an editor helper.


func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	assert(args.size() == 2)
	var root: String = args[1].replace("\\", "/")
	var plugin_dir: String = root.path_join("bootstrap/addons/probe")
	assert(DirAccess.make_dir_recursive_absolute(plugin_dir) == OK)
	_write(plugin_dir.path_join("probe.gd"), FileAccess.get_file_as_string("res://probe.gd.txt"))
	_write(plugin_dir.path_join("plugin.cfg"), '[plugin]\nname="Probe"\nscript="probe.gd"\n')
	_write(root.path_join("bootstrap/project.godot"), 'config_version=5\n[editor_plugins]\nenabled=PackedStringArray("res://addons/probe/plugin.cfg")\n')
	var original_roaming: String = OS.get_environment("APPDATA")
	var original_local: String = OS.get_environment("LOCALAPPDATA")
	OS.set_environment("APPDATA", root.path_join("roaming"))
	OS.set_environment("LOCALAPPDATA", root.path_join("local"))
	OS.set_environment("HUB_SPIKE_EXTERNAL", "true")
	var pid: int = OS.create_process(args[0], PackedStringArray([
		"--headless", "--editor", "--path", root.path_join("bootstrap"),
	]))
	OS.set_environment("APPDATA", original_roaming)
	OS.set_environment("LOCALAPPDATA", original_local)
	OS.unset_environment("HUB_SPIKE_EXTERNAL")
	assert(pid > 0)
	while OS.is_process_running(pid):
		await get_tree().create_timer(0.1).timeout
	assert(FileAccess.file_exists(root.path_join("bootstrap/report.json")))
	get_tree().quit()


func _write(path: String, content: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	assert(file != null)
	file.store_string(content)
	file.close()
