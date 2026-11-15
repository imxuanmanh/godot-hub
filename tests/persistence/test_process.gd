extends SceneTree
## Validates spawning and error reporting with real child processes.


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var root: String = ProjectSettings.globalize_path("res://build/process-tests").path_join(ProjectIdentity.create())
	assert(DirAccess.make_dir_recursive_absolute(root) == OK)
	var output: String = root.path_join("child.cfg")
	var args: PackedStringArray = PackedStringArray([
		"--headless", "--path", ProjectSettings.globalize_path("res://"),
		"--script", "res://tests/persistence/child_probe.gd", "--", output,
	])
	var result: Dictionary = ProcessService.spawn(OS.get_executable_path(), args)
	assert(result.ok, str(result))
	while OS.is_process_running(result.pid):
		await create_timer(0.1).timeout
	var report: ConfigFile = ConfigFile.new()
	assert(report.load(output) == OK)
	assert(int(report.get_value("test", "pid")) == result.pid)
	result = ProcessService.spawn(root.path_join("missing.exe"), PackedStringArray(["--version"]))
	assert(not result.ok and result.error == "PROCESS_SPAWN_ERROR")
	print("Process checks passed.")
	quit()
