class_name EditorLaunchService
extends Node
## One validated launch path shared by all project actions.

const Keys = preload("res://features/editor_settings/editor_settings_keys.gd")

var repository: EditorSettingsRepository = EditorSettingsRepository.new()
var _adapter: NativeSettingsAdapter = NativeSettingsAdapter.new()
var _busy: bool = false


func _ready() -> void:
	add_child(_adapter)
	_adapter.repository = repository


## Serializes preparation and returns success only for a valid editor PID.
func launch(project: Dictionary, engine: Dictionary) -> Dictionary:
	if _busy:
		return {"ok": false, "error": "EDITOR_SETTINGS_BUSY", "detail": ""}
	_busy = true
	var result: Dictionary = await _launch(project, engine)
	_busy = false
	return result


func _launch(project: Dictionary, engine: Dictionary) -> Dictionary:
	var executable: String = str(engine.get("path", ""))
	var project_dir: String = str(project.get("project_dir", ""))
	if not FileAccess.file_exists(executable) or not FileAccess.file_exists(project_dir.path_join("project.godot")):
		return {"ok": false, "error": "EDITOR_SETTINGS_LAUNCH_PATH_ERROR", "detail": executable + "\n" + project_dir}
	var id: String = str(project.get("id", ""))
	var overrides: Dictionary = repository.load_project(id)
	if not overrides.ok:
		return overrides
	var args: PackedStringArray = PackedStringArray(["--path", project_dir, "--editor"])
	if not NativeSettingsAdapter.platform_supported():
		if not overrides.values.is_empty():
			return {"ok": false, "error": "EDITOR_SETTINGS_PLATFORM_ERROR", "detail": OS.get_name()}
		return ProcessService.spawn(executable, args)
	var lock: Dictionary = repository.project_path(id, Keys.RUNTIME_DIRECTORY)
	if not lock.ok:
		return lock
	var lock_path: String = lock.path.path_join("editor.pid")
	lock = SafeFile.check_path(lock_path, lock.path)
	if not lock.ok:
		return lock
	if FileAccess.file_exists(lock_path):
		# shortcut: PID reuse can conservatively block a launch; add process identity checks if this recurs.
		var previous_pid: String = FileAccess.get_file_as_string(lock_path).strip_edges()
		if previous_pid == "pending" or (previous_pid.is_valid_int() and OS.is_process_running(previous_pid.to_int())):
			return {"ok": false, "error": "EDITOR_SETTINGS_ALREADY_RUNNING", "detail": lock_path}
	var defaults: Dictionary = repository.load_default()
	if not defaults.ok:
		return defaults
	var effective: Dictionary = EditorSettingsResolver.resolve(defaults.values, overrides.values)
	if effective.values.is_empty():
		return ProcessService.spawn(executable, args)
	for source: Dictionary in [defaults.values, overrides.values]:
		var validation: Dictionary = EditorSettingsResolver.validate(source)
		if not validation.ok:
			return validation
	var result: Dictionary = validate_launch_settings(effective.values)
	if not result.ok:
		return result
	result = await _adapter.prepare(executable, id, effective.values)
	if not result.ok:
		return result
	var environment: Dictionary = result.environment
	result = SafeFile.write_text(lock_path, "pending")
	if not result.ok:
		return result
	var spawned: Dictionary = ProcessService.spawn(executable, args, environment)
	var recorded: Dictionary = SafeFile.write_text(lock_path, str(spawned.pid) if spawned.ok else "0")
	return spawned if recorded.ok else recorded


## Native executable values absent from cfg are validated later by the engine helper.
static func validate_launch_settings(values: Dictionary) -> Dictionary:
	var result: Dictionary = EditorSettingsResolver.validate(values)
	if result.ok and values.get(Keys.USE_EXTERNAL, false) and values.has(Keys.EXEC_PATH):
		var executable: String = values.get(Keys.EXEC_PATH, "")
		if executable.is_empty() or not executable.is_absolute_path() or not FileAccess.file_exists(executable):
			return {"ok": false, "error": "EDITOR_SETTINGS_EXECUTABLE_ERROR", "detail": executable}
	return result
