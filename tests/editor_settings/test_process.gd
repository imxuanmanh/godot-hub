extends SceneTree
## Validates inheritance and restoration using real child processes.

const VARIABLE: String = "GODOT_HUB_ENV_TEST"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var existed: bool = OS.has_environment(VARIABLE)
	var original: String = OS.get_environment(VARIABLE)
	OS.unset_environment(VARIABLE)
	var roaming: String = OS.get_environment("APPDATA")
	var root: String = ProjectSettings.globalize_path("res://build/process-tests").path_join(ProjectIdentity.create())
	assert(DirAccess.make_dir_recursive_absolute(root) == OK)
	var output: String = root.path_join("child.cfg")
	var args: PackedStringArray = PackedStringArray(["--headless", "--path", ProjectSettings.globalize_path("res://"), "--script", "res://tests/editor_settings/environment_child.gd", "--", output])
	var result: Dictionary = ProcessService.spawn(OS.get_executable_path(), args, {VARIABLE: "child", "APPDATA": root})
	assert(result.ok and not OS.has_environment(VARIABLE))
	assert(OS.get_environment("APPDATA") == roaming)
	while OS.is_process_running(result.pid):
		await create_timer(0.1).timeout
	var report: ConfigFile = ConfigFile.new()
	assert(report.load(output) == OK)
	assert(report.get_value("test", "value") == "child")
	assert(report.get_value("test", "appdata") == root)
	OS.set_environment(VARIABLE, "parent")
	result = ProcessService.spawn(root.path_join("missing.exe"), args, {VARIABLE: "child"})
	assert(not result.ok and OS.get_environment(VARIABLE) == "parent")
	OS.unset_environment(VARIABLE)
	result = ProcessService.spawn(root.path_join("missing.exe"), args, {VARIABLE: "child"})
	assert(not result.ok and not OS.has_environment(VARIABLE))
	if existed:
		OS.set_environment(VARIABLE, original)
	result = await ProcessService.capture(OS.get_executable_path(), PackedStringArray(["--version"]), self)
	assert(result.ok and result.output.begins_with("4.7.1.stable."), str(result))
	print("Process checks passed.")
	quit()
