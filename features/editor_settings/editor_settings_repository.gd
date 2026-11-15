class_name EditorSettingsRepository
extends RefCounted
## Stores sparse overrides and preserves sections/keys outside this form.

const Keys = preload("res://features/editor_settings/editor_settings_keys.gd")

var _root: String


func _init(root: String = "user://") -> void:
	_root = ProjectSettings.globalize_path(root)


## Creates the initial Built-in default only when the file has never existed.
func load_default() -> Dictionary:
	var path: String = _root.path_join(Keys.DEFAULT_FILE)
	var result: Dictionary = _read(path)
	if not result.ok or result.exists:
		return result
	var seed: ConfigFile = ConfigFile.new()
	var error: Error = seed.load(Keys.SEED_PATH)
	if error != OK:
		return SafeFile.failure(Keys.SEED_PATH, error)
	seed.erase_section("ui")
	seed.erase_section("backend")
	result = SafeFile.write_text(path, seed.encode_to_text())
	return _read(path) if result.ok else result


## Missing and empty overrides are valid and do not create files.
func load_project(project_id: String) -> Dictionary:
	var result: Dictionary = project_path(project_id, Keys.PROJECTS_DIRECTORY)
	if not result.ok:
		return result
	return _read(result.path.path_join(Keys.OVERRIDE_FILE))


## Saves managed fields while retaining unrelated configuration.
func save_default(values: Dictionary) -> Dictionary:
	return _save(_root.path_join(Keys.DEFAULT_FILE), values)


## Omitting a managed key removes its override instead of snapshotting the default.
func save_project(project_id: String, overrides: Dictionary) -> Dictionary:
	var result: Dictionary = project_path(project_id, Keys.PROJECTS_DIRECTORY)
	if not result.ok:
		return result
	return _save(result.path.path_join(Keys.OVERRIDE_FILE), overrides)


## Both storage and runtime paths are derived exclusively from a validated ID.
func project_path(project_id: String, directory: String) -> Dictionary:
	if not ProjectIdentity.is_valid(project_id) or directory not in [Keys.PROJECTS_DIRECTORY, Keys.RUNTIME_DIRECTORY]:
		return {"ok": false, "error": "EDITOR_SETTINGS_INVALID_ID", "detail": project_id}
	return SafeFile.check_path(_root.path_join(directory).path_join(project_id), _root)


func _read(path: String) -> Dictionary:
	var result: Dictionary = SafeFile.check_path(path, _root)
	if not result.ok:
		return result
	result = SafeFile.recover(path)
	if not result.ok:
		return result
	var cfg: ConfigFile = ConfigFile.new()
	var exists: bool = FileAccess.file_exists(path) or DirAccess.dir_exists_absolute(path)
	if exists:
		var error: Error = cfg.load(path)
		if error != OK:
			return SafeFile.failure(path, error)
		var schema: Variant = cfg.get_value("meta", "schema_version", Keys.SCHEMA if cfg.get_sections().is_empty() else null)
		if typeof(schema) != TYPE_INT or schema != Keys.SCHEMA:
			return {"ok": false, "error": "EDITOR_SETTINGS_SCHEMA_ERROR", "detail": path}
	var values: Dictionary = {}
	if cfg.has_section(Keys.SECTION):
		for key: String in cfg.get_section_keys(Keys.SECTION):
			values[key] = cfg.get_value(Keys.SECTION, key)
	return {"ok": true, "cfg": cfg, "values": values, "exists": exists, "path": path}


func _save(path: String, values: Dictionary) -> Dictionary:
	var validation: Dictionary = EditorSettingsResolver.validate(values)
	if not validation.ok:
		return validation
	var current: Dictionary = _read(path)
	if not current.ok:
		return current
	var cfg: ConfigFile = current.cfg
	var previous: String = cfg.encode_to_text()
	for key: String in Keys.TYPES:
		if values.has(key):
			cfg.set_value(Keys.SECTION, key, values[key])
		elif cfg.has_section_key(Keys.SECTION, key):
			cfg.erase_section_key(Keys.SECTION, key)
	if previous == cfg.encode_to_text():
		return {"ok": true}
	cfg.set_value("meta", "schema_version", Keys.SCHEMA)
	return SafeFile.write_text(path, cfg.encode_to_text())
