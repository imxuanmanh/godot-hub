@tool
extends EditorPlugin
## Exercises the native API in a disposable bootstrap project.

const USE_EXTERNAL: String = "text_editor/external/use_external_editor"


func _enter_tree() -> void:
	_apply.call_deferred()


func _apply() -> void:
	var settings: EditorSettings = EditorInterface.get_editor_settings()
	settings.set_setting(USE_EXTERNAL, OS.get_environment("HUB_SPIKE_EXTERNAL") == "true")
	var destination: String = OS.get_config_dir().path_join("Godot/editor_settings-4.6.tres")
	var error: Error = ResourceSaver.save(settings, destination)
	assert(error == OK)
	var report: Dictionary = {
		"version": Engine.get_version_info().string,
		"user_data": OS.get_user_data_dir(),
		"data": OS.get_data_dir(),
		"config": OS.get_config_dir(),
		"cache": OS.get_cache_dir(),
		"external": settings.get_setting(USE_EXTERNAL),
		"shortcut_count": settings.get("shortcuts").size(),
	}
	var output: FileAccess = FileAccess.open("res://report.json", FileAccess.WRITE)
	assert(output != null)
	output.store_string(JSON.stringify(report, "\t"))
	output.close()
	await get_tree().process_frame
	while EditorInterface.get_resource_filesystem().is_scanning():
		await get_tree().process_frame
	EditorInterface.get_base_control().get_tree().quit()
