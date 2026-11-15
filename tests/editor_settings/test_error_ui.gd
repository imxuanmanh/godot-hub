extends SceneTree
## A validation error must remain visible above an open settings form.


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	get_root().size = Vector2i(1152, 648)
	get_root().gui_embed_subwindows = true
	var scene: PackedScene = load("res://Main.tscn")
	var hub: Control = scene.instantiate()
	get_root().add_child(hub)
	await process_frame
	hub._editor_settings.open_default()
	var dialog: EditorSettingsDialog = hub._editor_settings._dialog
	dialog._on_editor_selected(1)
	dialog._on_text_changed("", EditorSettingsKeys.EXEC_PATH)
	dialog.get_node("%SaveButton").pressed.emit()
	assert(hub.error_dialog.visible and dialog.visible)
	assert(hub._editor_settings.repository.load_default().values[EditorSettingsKeys.USE_EXTERNAL] == false)
	hub.queue_free()
	await process_frame
	print("Error UI check passed.")
	quit()
