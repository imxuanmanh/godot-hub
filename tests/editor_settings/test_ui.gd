extends SceneTree
## Tests the real form/controller and every Projects tab launch action.

const Keys = preload("res://features/editor_settings/editor_settings_keys.gd")
const DIALOG: PackedScene = preload("res://features/editor_settings/ui/editor_settings_dialog.tscn")
const PROJECTS: PackedScene = preload("res://ui/ProjectsTab.tscn")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	get_root().size = Vector2i(1152, 648)
	get_root().gui_embed_subwindows = true
	var root: String = ProjectSettings.globalize_path("res://build/ui-tests").path_join(ProjectIdentity.create())
	var feature: EditorSettingsFeature = EditorSettingsFeature.new()
	feature.repository = EditorSettingsRepository.new(root)
	get_root().add_child(feature)
	await process_frame
	var id: String = ProjectIdentity.create()
	feature.open_project(id, "Game")
	var dialog: EditorSettingsDialog = feature.get_node("EditorSettingsDialog")
	assert(dialog.visible and dialog.get_node("%Status").text == tr("EDITOR_SETTINGS_USING_DEFAULT"))
	dialog.get_node("%SaveButton").pressed.emit()
	assert(not dialog.visible and not feature.repository.load_project(id).exists)
	feature.open_project(id, "Game")
	dialog.get_node("%EditorOverride").button_pressed = true
	dialog.get_node("%CancelButton").pressed.emit()
	dialog.hide()
	assert(not feature.repository.load_project(id).exists)
	feature.open_project(id, "Game")
	dialog.get_node("%EditorOverride").button_pressed = true
	dialog.get_node("%SaveButton").pressed.emit()
	assert(feature.repository.load_project(id).values[Keys.USE_EXTERNAL] == false)
	assert(feature.repository.save_default({Keys.USE_EXTERNAL: true, Keys.EXEC_PATH: OS.get_executable_path()}).ok)
	feature.open_project(id, "Game")
	assert(dialog.get_node("%EditorChoice").selected == 0)
	dialog.get_node("%EditorOverride").button_pressed = false
	assert(dialog.get_node("%EditorChoice").selected == 1)
	dialog.get_node("%SaveButton").pressed.emit()
	assert(not feature.repository.load_project(id).values.has(Keys.USE_EXTERNAL))
	feature.open_default()
	assert(dialog.get_node("%EditorChoice").selected == 1)
	dialog.hide()
	feature.queue_free()
	_test_launch_actions()
	await process_frame
	print("UI checks passed: save/cancel/reset, inheritance and all three launch paths.")
	quit()


func _test_launch_actions() -> void:
	var tab: ProjectsTab = PROJECTS.instantiate()
	get_root().add_child(tab)
	tab.set_versions([{"name": "Fixture", "is_mono": false}])
	tab.set_projects([{"name": "Game", "project_dir": "/fixture", "engine_index": 0, "pinned": false, "tags": []}])
	var calls: Array[Vector2i] = []
	tab.launch_requested.connect(func(project: int, engine: int) -> void: calls.append(Vector2i(project, engine)))
	tab._select_item(0)
	tab.launch_panel.launch_requested.emit()
	tab._on_item_double_clicked(0)
	tab._context_index = 0
	tab._on_context_menu_pressed(0)
	assert(calls == [Vector2i.ZERO, Vector2i.ZERO, Vector2i.ZERO])
	tab.set_launch_busy(true)
	tab._on_item_double_clicked(0)
	assert(calls.size() == 3)
	tab.queue_free()
