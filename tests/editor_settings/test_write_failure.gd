extends SceneTree
## The PowerShell runner holds this fixture open without delete sharing.


func _initialize() -> void:
	var path: String = OS.get_cmdline_user_args()[0]
	assert(not SafeFile.write_text(path, "replacement").ok)
	assert(FileAccess.get_file_as_string(path) == "original")
	print("Locked-file save failure check passed.")
	quit()
