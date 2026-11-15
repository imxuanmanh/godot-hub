class_name EditorSettingsFeature
extends Node
## Composes the settings form, repositories and launch backend at one entry point.

signal error_occurred(result: Dictionary)
signal default_changed(choice: int)

const DIALOG: PackedScene = preload("res://features/editor_settings/ui/editor_settings_dialog.tscn")
const Keys = preload("res://features/editor_settings/editor_settings_keys.gd")

var repository: EditorSettingsRepository = EditorSettingsRepository.new()
var _launch_service: EditorLaunchService = EditorLaunchService.new()
var _dialog: EditorSettingsDialog
var _project_id: String = ""
var _arguments_hint: String = ""


func _ready() -> void:
	_launch_service.repository = repository
	add_child(_launch_service)
	_dialog = DIALOG.instantiate()
	add_child(_dialog)
	_dialog.submitted.connect(_on_submitted)
	var seed: ConfigFile = ConfigFile.new()
	seed.load(Keys.SEED_PATH)
	_arguments_hint = seed.get_value("ui", "external_arguments")
	if NativeSettingsAdapter.platform_supported():
		_refresh_default.call_deferred()


func launch(project: Dictionary, engine: Dictionary) -> Dictionary:
	return await _launch_service.launch(project, engine)


func open_default() -> void:
	_open("", "")


func open_project(project_id: String, project_name: String) -> void:
	_open(project_id, project_name)


func _open(project_id: String, project_name: String) -> void:
	if not NativeSettingsAdapter.platform_supported():
		error_occurred.emit({"ok": false, "error": "EDITOR_SETTINGS_PLATFORM_ERROR", "detail": OS.get_name()})
		return
	var defaults: Dictionary = repository.load_default()
	if not _valid(defaults):
		return
	var overrides: Dictionary = {"ok": true, "values": {}}
	if not project_id.is_empty():
		overrides = repository.load_project(project_id)
		if not _valid(overrides):
			return
	_project_id = project_id
	_dialog.present(defaults.values, overrides.values, not project_id.is_empty(), project_name, _arguments_hint)


func _valid(result: Dictionary) -> bool:
	if result.ok:
		var validation: Dictionary = EditorSettingsResolver.validate(result.values)
		if validation.ok:
			return true
		result = validation
	error_occurred.emit(result)
	return false


func _on_submitted(values: Dictionary) -> void:
	var effective: Dictionary = values
	if not _project_id.is_empty():
		var defaults: Dictionary = repository.load_default()
		if not _valid(defaults):
			return
		effective = EditorSettingsResolver.resolve(defaults.values, values).values
	var result: Dictionary = EditorLaunchService.validate_launch_settings(effective)
	if result.ok:
		result = repository.save_default(values) if _project_id.is_empty() else repository.save_project(_project_id, values)
	if not result.ok:
		error_occurred.emit(result)
		return
	_dialog.hide()
	_refresh_default()


func _refresh_default() -> void:
	var result: Dictionary = repository.load_default()
	if _valid(result):
		default_changed.emit(int(result.values[Keys.USE_EXTERNAL]) if result.values.has(Keys.USE_EXTERNAL) else 2)
