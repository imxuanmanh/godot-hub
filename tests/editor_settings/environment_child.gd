extends SceneTree
## Reports only the two test variables, never the complete environment.


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var report: ConfigFile = ConfigFile.new()
	report.set_value("test", "value", OS.get_environment("GODOT_HUB_ENV_TEST"))
	report.set_value("test", "appdata", OS.get_environment("APPDATA"))
	assert(report.save(args[0]) == OK)
	quit()
