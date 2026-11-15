extends SceneTree
## Writes its PID so the parent test can prove the child really ran.


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var report: ConfigFile = ConfigFile.new()
	report.set_value("test", "pid", OS.get_process_id())
	report.set_value("test", "path", ProjectSettings.globalize_path("res://"))
	report.save(args[0])
	quit()
