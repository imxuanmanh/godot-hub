class_name NativeSettingsAdapter
extends Node
## Windows backend: an editor-only helper prepares a private native resource.

const Keys = preload("res://features/editor_settings/editor_settings_keys.gd")
const PROJECT_TEXT: String = 'config_version=5\n[application]\nconfig/name="Godot Hub bootstrap"\n[editor_plugins]\nenabled=PackedStringArray("res://addons/hub/plugin.cfg")\n'
const PLUGIN_TEXT: String = '[plugin]\nname="Godot Hub bootstrap"\nscript="bootstrap.gd"\n'

var repository: EditorSettingsRepository


## Unsupported platforms keep the legacy launch path without project overrides.
static func platform_supported() -> bool:
	var policy: ConfigFile = ConfigFile.new()
	return policy.load(Keys.SEED_PATH) == OK and OS.get_name() == policy.get_value("backend", "platform")


## Returns a child environment only after the native helper reports success.
func prepare(executable: String, project_id: String, values: Dictionary) -> Dictionary:
	var policy: ConfigFile = ConfigFile.new()
	policy.load(Keys.SEED_PATH)
	if not platform_supported():
		return {"ok": false, "error": "EDITOR_SETTINGS_PLATFORM_ERROR", "detail": OS.get_name()}
	for marker: String in ["_sc_", "._sc_"]:
		if FileAccess.file_exists(executable.get_base_dir().path_join(marker)):
			return {"ok": false, "error": "EDITOR_SETTINGS_PORTABLE_ERROR", "detail": executable}
	var query: Dictionary = await ProcessService.capture(executable, PackedStringArray(["--version"]), get_tree())
	var version: String = query.output
	var supported: bool = false
	for prefix: String in policy.get_value("backend", "version_prefixes"):
		supported = supported or version.begins_with(prefix)
	if not query.ok or not supported:
		return {"ok": false, "error": "EDITOR_SETTINGS_ENGINE_ERROR", "detail": version}
	var location: Dictionary = repository.project_path(project_id, Keys.RUNTIME_DIRECTORY)
	if not location.ok:
		return location
	return await _prepare_runtime(executable, location.path, version, values)


func _prepare_runtime(executable: String, root: String, version: String, values: Dictionary) -> Dictionary:
	var version_parts: PackedStringArray = version.split(".")
	var native_file: String = "editor_settings-%s.%s.tres" % [version_parts[0], version_parts[1]]
	var native_path: String = root.path_join("roaming/Godot").path_join(native_file)
	var result: Dictionary = _check_runtime(root, native_path)
	if not result.ok:
		return result
	if not FileAccess.file_exists(native_path):
		var baseline: String = OS.get_config_dir().path_join("Godot").path_join(native_file)
		if FileAccess.file_exists(baseline):
			var error: Error = DirAccess.copy_absolute(baseline, native_path)
			if error != OK:
				return SafeFile.failure(native_path, error)
	if FileAccess.file_exists(native_path):
		var error: Error = DirAccess.copy_absolute(native_path, native_path + SafeFile.BACKUP_SUFFIX)
		if error != OK:
			return SafeFile.failure(native_path, error)
	var bootstrap: String = root.path_join("bootstrap")
	var files: Dictionary = {
		"addons/hub/bootstrap.gd": FileAccess.get_file_as_string(Keys.HELPER_PATH),
		"addons/hub/plugin.cfg": PLUGIN_TEXT, "project.godot": PROJECT_TEXT,
	}
	var cfg: ConfigFile = ConfigFile.new()
	for key: String in values:
		cfg.set_value(Keys.SECTION, key, values[key])
	files["request.cfg"] = cfg.encode_to_text()
	for relative: String in files:
		result = SafeFile.write_text(bootstrap.path_join(relative), files[relative])
		if not result.ok:
			return result
	var report: String = bootstrap.path_join("result.cfg")
	result = SafeFile.write_text(report, "")
	if not result.ok:
		return result
	var environment: Dictionary = {"APPDATA": root.path_join("roaming"), "LOCALAPPDATA": root.path_join("local")}
	result = ProcessService.spawn(executable, PackedStringArray(["--headless", "--editor", "--path", bootstrap]), environment)
	if not result.ok:
		return result
	result = await _wait_for_helper(result.pid, report)
	if not result.ok and FileAccess.file_exists(native_path + SafeFile.BACKUP_SUFFIX):
		DirAccess.copy_absolute(native_path + SafeFile.BACKUP_SUFFIX, native_path)
	if result.ok:
		# VSCode otherwise inherits the private APPDATA and starts with an empty user profile.
		var flags: String = result.values.get(Keys.EXEC_FLAGS, "")
		if OS.get_environment("VSCODE_APPDATA").is_empty() and not flags.contains("--user-data-dir"):
			environment["VSCODE_APPDATA"] = OS.get_environment("APPDATA")
		result.environment = environment
		result.version = version
	return result


func _check_runtime(root: String, native_path: String) -> Dictionary:
	for relative: String in ["bootstrap/addons/hub/bootstrap.gd", "bootstrap/addons/hub/plugin.cfg", "bootstrap/project.godot", "bootstrap/request.cfg", "bootstrap/result.cfg", "local", "roaming/Godot/app_userdata", "roaming/Godot/export_templates", "bootstrap/.godot"]:
		var safe: Dictionary = SafeFile.check_path(root.path_join(relative), root)
		if not safe.ok:
			return safe
	for candidate: String in [native_path, native_path + SafeFile.BACKUP_SUFFIX]:
		var result: Dictionary = SafeFile.check_path(candidate, root)
		if not result.ok:
			return result
	for directory: String in [native_path.get_base_dir(), root.path_join("local")]:
		var error: Error = DirAccess.make_dir_recursive_absolute(directory)
		if error != OK:
			return SafeFile.failure(directory, error)
	return {"ok": true}


func _wait_for_helper(pid: int, path: String) -> Dictionary:
	var started: int = Time.get_ticks_msec()
	while OS.is_process_running(pid):
		if Time.get_ticks_msec() - started > int(Keys.TIMEOUT_SECONDS * 1000):
			OS.kill(pid)
			return {"ok": false, "error": "EDITOR_SETTINGS_HELPER_ERROR", "detail": path}
		await get_tree().create_timer(Keys.POLL_SECONDS).timeout
	var cfg: ConfigFile = ConfigFile.new()
	var error: Error = cfg.load(path)
	if error != OK or cfg.get_value("result", "code", FAILED) != OK:
		return {"ok": false, "error": cfg.get_value("result", "error", "EDITOR_SETTINGS_HELPER_ERROR"), "detail": path + "\n" + str(cfg.get_value("result", "detail", ""))}
	var values: Dictionary = {}
	if cfg.has_section(Keys.SECTION):
		for key: String in cfg.get_section_keys(Keys.SECTION):
			values[key] = cfg.get_value(Keys.SECTION, key)
	return {"ok": true, "values": values}
